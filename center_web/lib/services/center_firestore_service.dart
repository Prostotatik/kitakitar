import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/center_material.dart';
import '../models/center_profile.dart';

/// One QR code entry for list display (pending or completed).
class QrCodeListItem {
  const QrCodeListItem({
    required this.id,
    required this.totalWeight,
    required this.materialsCount,
    this.createdAt,
    required this.used,
    this.usedBy,
    this.usedAt,
  });

  final String id;
  final double totalWeight;
  final int materialsCount;
  final DateTime? createdAt;
  final bool used;
  final String? usedBy;
  final DateTime? usedAt;
}

/// Firestore service for recycling centers (web).
/// Structure: /centers/{centerId} + /centers/{centerId}/materials/{materialId}.
class CenterFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetches center document. Returns null if not found or error.
  Future<CenterProfile?> getCenter(String centerId) async {
    try {
      final doc = await _db.collection('centers').doc(centerId).get();
      return CenterProfile.fromFirestore(doc.data());
    } catch (_) {
      return null;
    }
  }

  /// Fetches materials subcollection. Uses kMaterialTypes for labels.
  Future<List<CenterMaterialEntry>> getMaterials(String centerId) async {
    try {
      final snap = await _db
          .collection('centers')
          .doc(centerId)
          .collection('materials')
          .get();
      final list = <CenterMaterialEntry>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        String label = type;
        for (final m in kMaterialTypes) {
          if (m['type'] == type) {
            label = m['label'] ?? type;
            break;
          }
        }
        list.add(CenterMaterialEntry(
          type: type,
          label: label,
          minWeightKg: (data['minWeight'] as num?)?.toDouble() ?? 0,
          maxWeightKg: (data['maxWeight'] as num?)?.toDouble() ?? 0,
          pricePerKg: (data['pricePerKg'] as num?)?.toDouble() ?? 0,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> createCenter({
    required String centerId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required String managerName,
    required String managerPhone,
    required String managerEmail,
    required List<CenterMaterialEntry> materials,
  }) async {
    final centerRef = _db.collection('centers').doc(centerId);
    await centerRef.set({
      'name': name,
      'address': address,
      'location': {
        'lat': lat,
        'lng': lng,
      },
      'manager': {
        'name': managerName,
        'phone': managerPhone,
        'email': managerEmail,
      },
      'points': 0,
      'totalWeight': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    for (final m in materials) {
      await centerRef.collection('materials').add(m.toFirestore());
    }
  }

  /// Creates an intake QR document in /qr_codes. Client scans this QR to claim points.
  /// [materialsWithWeights] = list of (type, weightKg). [centerMaterials] = center's
  /// accepted materials (for pricePerKg, isFree). Returns the new document id (qrId).
  Future<String> createIntakeQr({
    required String centerId,
    required List<({String type, double weightKg})> materialsWithWeights,
    required List<CenterMaterialEntry> centerMaterials,
  }) async {
    if (materialsWithWeights.isEmpty) {
      throw ArgumentError('At least one material with weight is required');
    }
    double totalWeight = 0;
    final draftMaterials = <Map<String, dynamic>>[];
    for (final e in materialsWithWeights) {
      if (e.weightKg <= 0) continue;
      totalWeight += e.weightKg;
      CenterMaterialEntry? mat;
      for (final m in centerMaterials) {
        if (m.type == e.type) {
          mat = m;
          break;
        }
      }
      final pricePerKg = mat?.pricePerKg ?? 0.0;
      final isFree = (mat?.isFree ?? true) || pricePerKg <= 0;
      draftMaterials.add({
        'type': e.type,
        'weight': e.weightKg,
        'pricePerKg': pricePerKg,
        'isFree': isFree,
      });
    }
    if (draftMaterials.isEmpty) {
      throw ArgumentError('At least one material must have weight > 0');
    }
    final ref = await _db.collection('qr_codes').add({
      'centerId': centerId,
      'transactionDraft': {
        'materials': draftMaterials,
        'totalWeight': totalWeight,
      },
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// One QR code doc for list display.
  static QrCodeListItem fromQrDoc(String id, Map<String, dynamic> data) {
    final draft = data['transactionDraft'] as Map<String, dynamic>? ?? {};
    final totalWeight = (draft['totalWeight'] as num?)?.toDouble() ?? 0.0;
    final materials = draft['materials'] as List<dynamic>? ?? [];
    final createdAt = (data['createdAt'] as dynamic)?.toDate() as DateTime?;
    final usedAt = (data['usedAt'] as dynamic)?.toDate() as DateTime?;
    return QrCodeListItem(
      id: id,
      totalWeight: totalWeight,
      materialsCount: materials.length,
      createdAt: createdAt,
      used: data['used'] as bool? ?? false,
      usedBy: data['usedBy'] as String?,
      usedAt: usedAt,
    );
  }

  /// Pending QR codes (used == false) for this center, newest first.
  Future<List<QrCodeListItem>> getPendingQrCodes(String centerId) async {
    try {
      final snap = await _db
          .collection('qr_codes')
          .where('centerId', isEqualTo: centerId)
          .get();
      final list = snap.docs
          .map((d) => fromQrDoc(d.id, d.data()))
          .where((e) => !e.used)
          .toList();
      list.sort((a, b) {
        final ta = a.createdAt ?? DateTime(0);
        final tb = b.createdAt ?? DateTime(0);
        return tb.compareTo(ta);
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Completed QR codes (used == true) for this center, newest first.
  Future<List<QrCodeListItem>> getCompletedQrCodes(String centerId) async {
    try {
      final snap = await _db
          .collection('qr_codes')
          .where('centerId', isEqualTo: centerId)
          .get();
      final list = snap.docs
          .map((d) => fromQrDoc(d.id, d.data()))
          .where((e) => e.used)
          .toList();
      list.sort((a, b) {
        final ta = a.usedAt ?? a.createdAt ?? DateTime(0);
        final tb = b.usedAt ?? b.createdAt ?? DateTime(0);
        return tb.compareTo(ta);
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Updates center document (name, address, location, manager). Does not change materials.
  Future<void> updateCenter({
    required String centerId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    required String managerName,
    required String managerPhone,
    required String managerEmail,
  }) async {
    await _db.collection('centers').doc(centerId).update({
      'name': name,
      'address': address,
      'location': {'lat': lat, 'lng': lng},
      'manager': {
        'name': managerName,
        'phone': managerPhone,
        'email': managerEmail,
      },
    });
  }
}
