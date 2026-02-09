import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';

class ScanResultScreen extends StatelessWidget {
  final List<DetectedMaterial> detectedMaterials;
  final String? imagePath;

  const ScanResultScreen({
    super.key,
    required this.detectedMaterials,
    this.imagePath,
  });

  String _getMaterialLabel(String type) {
    switch (type.toLowerCase()) {
      case 'plastic':
        return 'Plastic';
      case 'paper':
        return 'Paper';
      case 'glass':
        return 'Glass';
      case 'metal':
        return 'Metal';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(imagePath!),
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Text(
              'Detected Materials:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...detectedMaterials.map((material) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.recycling, color: Color(0xFF4CAF50)),
                    title: Text(_getMaterialLabel(material.type)),
                    subtitle: Text(
                      'Weight: ${material.estimatedWeight.toStringAsFixed(2)} kg\n'
                      'Confidence: ${(material.confidence * 100).toStringAsFixed(0)}%',
                    ),
                    trailing: Text(
                      '${material.estimatedWeight.toStringAsFixed(2)} kg',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to map with filters applied
                  context.go('/');
                  // Switch to map tab and pass filters
                  // This would require state management to pass filters
                  // For now, just navigate to main screen
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Show on Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

