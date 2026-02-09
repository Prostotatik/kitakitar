import 'package:cloud_firestore/cloud_firestore.dart';

class CenterModel {
  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final ManagerInfo manager;
  final int points; // Monthly points (resets every month)
  final int totalPointsAllTime; // Cumulative points (never resets)
  final double totalWeight; // All-time total weight
  final double monthlyWeight; // Monthly weight (resets every month)
  final DateTime createdAt;
  final DateTime? lastResetAt; // When points were last reset
  final bool isActive;

  CenterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.manager,
    required this.points,
    required this.totalPointsAllTime,
    required this.totalWeight,
    required this.monthlyWeight,
    required this.createdAt,
    this.lastResetAt,
    required this.isActive,
  });

  factory CenterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentPoints = data['points'] ?? 0;
    
    return CenterModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      location: data['location'] as GeoPoint,
      manager: ManagerInfo.fromMap(data['manager'] ?? {}),
      points: currentPoints,
      // Backward compatibility: if totalPointsAllTime doesn't exist, use current points
      totalPointsAllTime: data['totalPointsAllTime'] ?? currentPoints,
      totalWeight: (data['totalWeight'] ?? 0).toDouble(),
      // Backward compatibility: if monthlyWeight doesn't exist, start at 0
      monthlyWeight: (data['monthlyWeight'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastResetAt: (data['lastResetAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class ManagerInfo {
  final String name;
  final String phone;
  final String email;

  ManagerInfo({
    required this.name,
    required this.phone,
    required this.email,
  });

  factory ManagerInfo.fromMap(Map<String, dynamic> map) {
    return ManagerInfo(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
    );
  }
}

class CenterMaterial {
  final String id;
  final String type;
  final double minWeight;
  final double maxWeight;
  final double? pricePerKg;
  final bool isFree;

  CenterMaterial({
    required this.id,
    required this.type,
    required this.minWeight,
    required this.maxWeight,
    this.pricePerKg,
    required this.isFree,
  });

  factory CenterMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CenterMaterial(
      id: doc.id,
      type: data['type'] ?? '',
      minWeight: (data['minWeight'] ?? 0).toDouble(),
      maxWeight: (data['maxWeight'] ?? 0).toDouble(),
      pricePerKg: data['pricePerKg']?.toDouble(),
      isFree: data['isFree'] ?? false,
    );
  }

  bool acceptsMaterial(String materialType, double weight) {
    return type == materialType &&
        weight >= minWeight &&
        weight <= maxWeight;
  }
}

