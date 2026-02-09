import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitakitar_mobile/models/user_model.dart';
import 'package:kitakitar_mobile/models/center_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  // Centers
  Stream<List<CenterModel>> getCentersStream({
    List<String>? materialTypes,
    double? minWeight,
    double? maxWeight,
  }) {
    Query query = _firestore
        .collection('centers')
        .where('isActive', isEqualTo: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CenterModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<List<CenterModel>> getCenters({
    List<String>? materialTypes,
    double? minWeight,
    double? maxWeight,
  }) async {
    Query query = _firestore
        .collection('centers')
        .where('isActive', isEqualTo: true);

    final snapshot = await query.get();
    final centers = snapshot.docs
        .map((doc) => CenterModel.fromFirestore(doc))
        .toList();

    // Filter by materials if needed
    if (materialTypes != null && materialTypes.isNotEmpty) {
      final filteredCenters = <CenterModel>[];
      for (final center in centers) {
        final materialsSnapshot = await _firestore
            .collection('centers')
            .doc(center.id)
            .collection('materials')
            .get();

        final hasMaterial = materialsSnapshot.docs.any((doc) {
          final material = CenterMaterial.fromFirestore(doc);
          return materialTypes.contains(material.type);
        });

        if (hasMaterial) {
          filteredCenters.add(center);
        }
      }
      return filteredCenters;
    }

    return centers;
  }

  Future<List<CenterMaterial>> getCenterMaterials(String centerId) async {
    final snapshot = await _firestore
        .collection('centers')
        .doc(centerId)
        .collection('materials')
        .get();

    return snapshot.docs
        .map((doc) => CenterMaterial.fromFirestore(doc))
        .toList();
  }

  // AI Scans
  Future<void> saveAiScan(
    String userId,
    String imageUrl,
    List<Map<String, dynamic>> detectedMaterials,
  ) async {
    await _firestore.collection('ai_scans').add({
      'userId': userId,
      'imageUrl': imageUrl,
      'detectedMaterials': detectedMaterials,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Leaderboards
  Stream<QuerySnapshot> getLeaderboard(String type) {
    return _firestore
        .collection('leaderboards')
        .doc('${type}_all_time')
        .collection('items')
        .orderBy('points', descending: true)
        .limit(100)
        .snapshots();
  }

  // Transactions
  Stream<QuerySnapshot> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}

