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
  const result: Record<string, number> = {...(stats || {})};
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

      const {centerId, transactionDraft} = qrData;
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

      tx.set(
        userRef,
        {
          points: (userData.points || 0) + pointsUser,
          totalWeight: (userData.totalWeight || 0) + totalWeight,
          stats: userStats,
          lastTransactionAt: now,
        },
        {merge: true},
      );

      // Обновляем центр
      const centerRef = db.collection("centers").doc(centerId);
      const centerSnap = await tx.get(centerRef);
      const centerData = centerSnap.data() || {};

      tx.set(
        centerRef,
        {
          points: (centerData.points || 0) + pointsCenter,
          totalWeight: (centerData.totalWeight || 0) + totalWeight,
          lastTransactionAt: now,
        },
        {merge: true},
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

    return {qrId: qrRef.id};
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
    // Пример: leaderboard по points для users и centers (all-time)
    const usersSnap = await db
      .collection("users")
      .orderBy("points", "desc")
      .limit(100)
      .get();

    const centersSnap = await db
      .collection("centers")
      .orderBy("points", "desc")
      .limit(100)
      .get();

    const now = admin.firestore.FieldValue.serverTimestamp();

    const usersItems = usersSnap.docs.map((d) => ({
      id: d.id,
      points: d.get("points") || 0,
      totalWeight: d.get("totalWeight") || 0,
    }));

    const centersItems = centersSnap.docs.map((d) => ({
      id: d.id,
      points: d.get("points") || 0,
      totalWeight: d.get("totalWeight") || 0,
    }));

    const batch = db.batch();

    const usersLbRef = db.collection("leaderboards").doc("users_all_time");
    batch.set(usersLbRef, {
      type: "users",
      period: "all_time",
      items: usersItems,
      updatedAt: now,
    });

    const centersLbRef = db.collection("leaderboards").doc("centers_all_time");
    batch.set(centersLbRef, {
      type: "centers",
      period: "all_time",
      items: centersItems,
      updatedAt: now,
    });

    await batch.commit();
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


