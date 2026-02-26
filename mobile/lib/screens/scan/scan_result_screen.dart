import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';

class ScanResultScreen extends StatelessWidget {
  final List<DetectedMaterial> detectedMaterials;
  final String? preparationTip;
  final String? imagePath;

  const ScanResultScreen({
    super.key,
    required this.detectedMaterials,
    this.preparationTip,
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
                      'Weight: ${material.estimatedWeight.toStringAsFixed(2)} kg',
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
            if (preparationTip != null && preparationTip!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Preparation tip',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          preparationTip!,
                          style: TextStyle(fontSize: 15, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final provider = Provider.of<ScanFiltersProvider>(context, listen: false);
                  provider.setScanFilters(detectedMaterials);
                  context.go('/', extra: {'initialTab': 1});
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

