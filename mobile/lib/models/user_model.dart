import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final int points; // Monthly points (resets every month)
  final int totalPointsAllTime; // Cumulative points (never resets)
  final double totalWeight; // All-time total weight
  final double monthlyWeight; // Monthly weight (resets every month)
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastResetAt; // When points were last reset
  final String provider;
  final Map<String, double> stats; // material type -> weight

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.points,
    required this.totalPointsAllTime,
    required this.totalWeight,
    required this.monthlyWeight,
    required this.createdAt,
    this.lastLoginAt,
    this.lastResetAt,
    required this.provider,
    required this.stats,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentPoints = data['points'] ?? 0;
    
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'],
      points: currentPoints,
      // Backward compatibility: if totalPointsAllTime doesn't exist, use current points
      totalPointsAllTime: data['totalPointsAllTime'] ?? currentPoints,
      totalWeight: (data['totalWeight'] ?? 0).toDouble(),
      // Backward compatibility: if monthlyWeight doesn't exist, start at 0
      monthlyWeight: (data['monthlyWeight'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      lastResetAt: (data['lastResetAt'] as Timestamp?)?.toDate(),
      provider: data['provider'] ?? 'email',
      stats: Map<String, double>.from(
        (data['stats'] ?? {}) as Map,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'points': points,
      'totalPointsAllTime': totalPointsAllTime,
      'totalWeight': totalWeight,
      'monthlyWeight': monthlyWeight,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'lastResetAt': lastResetAt != null ? Timestamp.fromDate(lastResetAt!) : null,
      'provider': provider,
      'stats': stats,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    int? points,
    int? totalPointsAllTime,
    double? totalWeight,
    double? monthlyWeight,
    DateTime? lastLoginAt,
    DateTime? lastResetAt,
    Map<String, double>? stats,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      points: points ?? this.points,
      totalPointsAllTime: totalPointsAllTime ?? this.totalPointsAllTime,
      totalWeight: totalWeight ?? this.totalWeight,
      monthlyWeight: monthlyWeight ?? this.monthlyWeight,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastResetAt: lastResetAt ?? this.lastResetAt,
      provider: provider,
      stats: stats ?? this.stats,
    );
  }
}

