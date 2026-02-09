import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/center_material.dart';

/// Firestore-сервис для центров переработки (web).
///
/// Структура: /centers/{centerId} + /centers/{centerId}/materials/{materialId}.
class CenterFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
}
