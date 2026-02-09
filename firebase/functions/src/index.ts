import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

type MaterialEntry = {
  type: string;
  weight: number;
  pricePerKg?: number;
  isFree?: boolean;
};

type TransactionDraft = {
  materials: MaterialEntry[];
  totalWeight: number;
};

// --- CONFIG ---

const BASE_MULTIPLIER = 100; // points per kg (пример, можешь поменять)

// --- HELPERS ---

function calculatePoints(materials: MaterialEntry[]): number {
  let points = 0;
  for (const m of materials) {
    const weight = m.weight || 0;
    const isFree = !!m.isFree;
    const multiplier = isFree ? BASE_MULTIPLIER * 1.5 : BASE_MULTIPLIER;
    points += weight * multiplier;
  }
  return Math.round(points);
}

function aggregateStats(
  stats: Record<string, number> | undefined,
  materials: MaterialEntry[],
): Record<string, number> {
  const result: Record<string, number> = { ...(stats || {}) };
  for (const m of materials) {
    const prev = result[m.type] || 0;
    result[m.type] = prev + (m.weight || 0);
  }
  return result;
}

// --- HTTP callable: onQrScan ---

/**
 * Mobile клиент вызывает эту функцию после сканирования QR.
 * Вход:
 *  - qrId: string
 *
 * Требования:
 *  - auth обязателен (role=user)
 */
export const onQrScan = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  const role = (context.auth?.token as any)?.role;

  if (!uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  if (role !== "user") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only users can redeem QR codes",
    );
  }

  const qrId: string | undefined = data?.qrId;
  if (!qrId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "qrId is required",
    );
  }

  const qrRef = db.collection("qr_codes").doc(qrId);

  try {
    const result = await db.runTransaction(async (tx) => {
      const qrSnap = await tx.get(qrRef);
      if (!qrSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "QR code not found",
        );
      }

      const qrData = qrSnap.data() as {
        centerId: string;
        transactionDraft: TransactionDraft;
        used: boolean;
      };

      if (qrData.used) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "QR code already used",
        );
      }

      const { centerId, transactionDraft } = qrData;
      const materials = transactionDraft.materials || [];
      const totalWeight = transactionDraft.totalWeight || 0;

      const pointsUser = calculatePoints(materials);
      const pointsCenter = pointsUser; // можно сделать разную формулу

      const transactionRef = db.collection("transactions").doc();
      const now = admin.firestore.FieldValue.serverTimestamp();

      // Создаём транзакцию
      tx.set(transactionRef, {
        userId: uid,
        centerId,
        materials,
        totalWeight,
        pointsUser,
        pointsCenter,
        createdAt: now,
        qrCodeId: qrId,
      });

      // Обновляем пользователя
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);
      const userData = userSnap.data() || {};
      const userStats = aggregateStats(userData.stats, materials);

      // Backward compatibility: migrate old data if needed
      const currentPoints = userData.points || 0;
      const totalPointsAllTime = userData.totalPointsAllTime ?? currentPoints;
      const monthlyWeight = userData.monthlyWeight || 0;

      tx.set(
        userRef,
        {
          points: currentPoints + pointsUser, // Monthly points
          totalPointsAllTime: totalPointsAllTime + pointsUser, // All-time points
          totalWeight: (userData.totalWeight || 0) + totalWeight, // All-time weight
          monthlyWeight: monthlyWeight + totalWeight, // Monthly weight
          stats: userStats,
          lastTransactionAt: now,
        },
        { merge: true },
      );

      // Обновляем центр
      const centerRef = db.collection("centers").doc(centerId);
      const centerSnap = await tx.get(centerRef);
      const centerData = centerSnap.data() || {};

      // Backward compatibility: migrate old data if needed
      const currentCenterPoints = centerData.points || 0;
      const centerTotalPointsAllTime = centerData.totalPointsAllTime ?? currentCenterPoints;
      const centerMonthlyWeight = centerData.monthlyWeight || 0;

      tx.set(
        centerRef,
        {
          points: currentCenterPoints + pointsCenter, // Monthly points
          totalPointsAllTime: centerTotalPointsAllTime + pointsCenter, // All-time points
          totalWeight: (centerData.totalWeight || 0) + totalWeight, // All-time weight
          monthlyWeight: centerMonthlyWeight + totalWeight, // Monthly weight
          lastTransactionAt: now,
        },
        { merge: true },
      );

      // Помечаем QR как использованный
      tx.update(qrRef, {
        used: true,
        usedBy: uid,
        usedAt: now,
      });

      return {
        pointsUser,
        pointsCenter,
        totalWeight,
      };
    });

    return result;
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error("onQrScan error", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to redeem QR code",
    );
  }
});

// --- HTTP callable: createQrForCenter ---

/**
 * Вызывается web‑админкой центра при создании нового приёма.
 * Создаёт документ в /qr_codes с черновиком транзакции.
 *
 * Вход:
 *  - centerId: string (обычно == uid центра)
 *  - materials: MaterialEntry[]
 *  - totalWeight: number
 */
export const createQrForCenter = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    const role = (context.auth?.token as any)?.role;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Center must be authenticated",
      );
    }
    if (role !== "center") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only centers can create QR codes",
      );
    }

    const centerId: string = data?.centerId || uid;
    const materials: MaterialEntry[] = data?.materials || [];
    const totalWeight: number = data?.totalWeight || 0;

    if (!Array.isArray(materials) || materials.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "materials must be a non-empty array",
      );
    }

    const qrRef = db.collection("qr_codes").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();

    await qrRef.set({
      centerId,
      transactionDraft: {
        materials,
        totalWeight,
      },
      used: false,
      usedBy: null,
      createdAt: now,
      usedAt: null,
    });

    return { qrId: qrRef.id };
  },
);

// --- TRIGGER: onTransactionCreate (опциональная доп. логика) ---

export const onTransactionCreate = functions.firestore
  .document("transactions/{transactionId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    console.log("New transaction created", context.params.transactionId, data);
    // Здесь можно:
    // - слать уведомления
    // - логировать в BigQuery
    // - строить дополнительные агрегаты
  });

// --- SCHEDULE: updateLeaderboards ---

export const updateLeaderboards = functions.pubsub
  .schedule("every 15 minutes")
  .onRun(async () => {
    const now = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();

    // --- USERS MONTHLY LEADERBOARD (sorted by monthly points) ---
    const usersMonthlySnap = await db
      .collection("users")
      .orderBy("points", "desc")
      .limit(100)
      .get();

    const usersMonthlyItems = usersMonthlySnap.docs.map((d) => ({
      id: d.id,
      points: d.get("points") || 0, // Monthly points
      monthlyWeight: d.get("monthlyWeight") || 0,
    }));

    const usersMonthlyLbRef = db.collection("leaderboards").doc("users_monthly");
    batch.set(usersMonthlyLbRef, {
      type: "users",
      period: "monthly",
      items: usersMonthlyItems,
      updatedAt: now,
    });

    // --- USERS ALL-TIME LEADERBOARD (sorted by totalPointsAllTime) ---
    const usersAllTimeSnap = await db
      .collection("users")
      .orderBy("totalPointsAllTime", "desc")
      .limit(100)
      .get();

    const usersAllTimeItems = usersAllTimeSnap.docs.map((d) => ({
      id: d.id,
      totalPointsAllTime: d.get("totalPointsAllTime") || 0,
      totalWeight: d.get("totalWeight") || 0,
    }));

    const usersAllTimeLbRef = db.collection("leaderboards").doc("users_all_time");
    batch.set(usersAllTimeLbRef, {
      type: "users",
      period: "all_time",
      items: usersAllTimeItems,
      updatedAt: now,
    });

    // --- CENTERS MONTHLY LEADERBOARD (sorted by monthly points) ---
    const centersMonthlySnap = await db
      .collection("centers")
      .orderBy("points", "desc")
      .limit(100)
      .get();

    const centersMonthlyItems = centersMonthlySnap.docs.map((d) => ({
      id: d.id,
      points: d.get("points") || 0, // Monthly points
      monthlyWeight: d.get("monthlyWeight") || 0,
    }));

    const centersMonthlyLbRef = db.collection("leaderboards").doc("centers_monthly");
    batch.set(centersMonthlyLbRef, {
      type: "centers",
      period: "monthly",
      items: centersMonthlyItems,
      updatedAt: now,
    });

    // --- CENTERS ALL-TIME LEADERBOARD (sorted by totalPointsAllTime) ---
    const centersAllTimeSnap = await db
      .collection("centers")
      .orderBy("totalPointsAllTime", "desc")
      .limit(100)
      .get();

    const centersAllTimeItems = centersAllTimeSnap.docs.map((d) => ({
      id: d.id,
      totalPointsAllTime: d.get("totalPointsAllTime") || 0,
      totalWeight: d.get("totalWeight") || 0,
    }));

    const centersAllTimeLbRef = db.collection("leaderboards").doc("centers_all_time");
    batch.set(centersAllTimeLbRef, {
      type: "centers",
      period: "all_time",
      items: centersAllTimeItems,
      updatedAt: now,
    });

    await batch.commit();
    console.log("Updated monthly and all-time leaderboards for users and centers");
  });

// --- SCHEDULE: cleanupExpiredQr ---

export const cleanupExpiredQr = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 1000 * 60 * 60 * 24 * 7, // 7 дней
    );

    const snap = await db
      .collection("qr_codes")
      .where("createdAt", "<", cutoff)
      .get();

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    if (!snap.empty) {
      await batch.commit();
    }
  });

// --- SCHEDULE: resetMonthlyPoints ---

/**
 * Runs on the 1st of every month at 00:00 UTC.
 * Resets monthly points and weight for all users and centers,
 * while preserving all-time statistics and transaction history.
 */
export const resetMonthlyPoints = functions.pubsub
  .schedule("0 0 1 * *") // Every 1st day of the month at midnight UTC
  .timeZone("UTC")
  .onRun(async () => {
    const now = admin.firestore.FieldValue.serverTimestamp();

    // Archive previous month's leaderboards before reset
    const prevMonth = new Date();
    prevMonth.setMonth(prevMonth.getMonth() - 1);
    const archiveKey = `${prevMonth.getFullYear()}_${String(prevMonth.getMonth() + 1).padStart(2, "0")}`;

    try {
      // Archive users leaderboard
      const usersLbSnap = await db.collection("leaderboards").doc("users_monthly").get();
      if (usersLbSnap.exists) {
        await db.collection("leaderboards").doc(`users_monthly_${archiveKey}`).set(usersLbSnap.data()!);
      }

      // Archive centers leaderboard
      const centersLbSnap = await db.collection("leaderboards").doc("centers_monthly").get();
      if (centersLbSnap.exists) {
        await db.collection("leaderboards").doc(`centers_monthly_${archiveKey}`).set(centersLbSnap.data()!);
      }
    } catch (error) {
      console.error("Error archiving leaderboards", error);
    }

    // Reset users in batches of 500
    let usersProcessed = 0;
    let usersBatch = db.batch();
    const usersSnap = await db.collection("users").get();

    usersSnap.docs.forEach((doc) => {
      usersBatch.update(doc.ref, {
        points: 0, // Reset monthly points
        monthlyWeight: 0, // Reset monthly weight
        lastResetAt: now,
        // totalPointsAllTime and totalWeight remain unchanged
      });

      usersProcessed++;
      if (usersProcessed % 500 === 0) {
        // Commit and start new batch
        usersBatch.commit().catch((err) => console.error("Batch commit error", err));
        usersBatch = db.batch();
      }
    });

    // Commit remaining users
    if (usersProcessed % 500 !== 0) {
      await usersBatch.commit();
    }

    console.log(`Reset monthly points for ${usersProcessed} users`);

    // Reset centers in batches of 500
    let centersProcessed = 0;
    let centersBatch = db.batch();
    const centersSnap = await db.collection("centers").get();

    centersSnap.docs.forEach((doc) => {
      centersBatch.update(doc.ref, {
        points: 0, // Reset monthly points
        monthlyWeight: 0, // Reset monthly weight
        lastResetAt: now,
        // totalPointsAllTime and totalWeight remain unchanged
      });

      centersProcessed++;
      if (centersProcessed % 500 === 0) {
        // Commit and start new batch
        centersBatch.commit().catch((err) => console.error("Batch commit error", err));
        centersBatch = db.batch();
      }
    });

    // Commit remaining centers
    if (centersProcessed % 500 !== 0) {
      await centersBatch.commit();
    }

    console.log(`Reset monthly points for ${centersProcessed} centers`);
  });

