class DetectedMaterial {
  final String type;
  final double estimatedWeight;
  final double confidence;

  DetectedMaterial({
    required this.type,
    required this.estimatedWeight,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'estimatedWeight': estimatedWeight,
      'confidence': confidence,
    };
  }

  factory DetectedMaterial.fromMap(Map<String, dynamic> map) {
    return DetectedMaterial(
      type: map['type'] ?? '',
      estimatedWeight: (map['estimatedWeight'] ?? 0).toDouble(),
      confidence: (map['confidence'] ?? 0).toDouble(),
    );
  }
}

