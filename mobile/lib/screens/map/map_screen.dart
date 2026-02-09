import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kitakitar_mobile/services/maps_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/models/center_model.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapsService _mapsService = MapsService();
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? _mapController;
  List<CenterModel> _centers = [];
  final Set<String> _selectedMaterials = {};
  double? _minWeight;
  double? _maxWeight;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    final centers = await _firestoreService.getCenters(
      materialTypes: _selectedMaterials.isEmpty ? null : _selectedMaterials.toList(),
      minWeight: _minWeight,
      maxWeight: _maxWeight,
    );
    setState(() {
      _centers = centers;
    });
  }

  Set<Marker> _buildMarkers() {
    return _centers.map((center) {
      return Marker(
        markerId: MarkerId(center.id),
        position: LatLng(
          center.location.latitude,
          center.location.longitude,
        ),
        infoWindow: InfoWindow(
          title: center.name,
          snippet: center.address,
        ),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.2995, 69.2401), // Tashkent default
              zoom: 12,
            ),
            markers: _buildMarkers(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          if (_showFilters)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: ['plastic', 'paper', 'glass', 'metal']
                          .map((material) => FilterChip(
                                label: Text(material),
                                selected: _selectedMaterials.contains(material),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedMaterials.add(material);
                                    } else {
                                      _selectedMaterials.remove(material);
                                    }
                                  });
                                  _loadCenters();
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Min. weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _minWeight = double.tryParse(value);
                              _loadCenters();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Max. weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _maxWeight = double.tryParse(value);
                              _loadCenters();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

