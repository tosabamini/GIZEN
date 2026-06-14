import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../data/trash_bins.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();

  static const _iitkgpCenter = LatLng(22.3149, 87.3105);

  Position? _currentPosition;
  List<LocationPoint> _cleanedLocations = [];
  bool _showTrashBins = true;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pos = await _locationService.getCurrentPosition();
    final cleaned = await _locationService.loadCleanedLocations();
    if (!mounted) return;
    setState(() {
      _currentPosition = pos;
      _cleanedLocations = cleaned;
    });

    _locationService.getPositionStream().listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
  }

  Future<void> _recordCleanedLocation() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS位置を取得中です。しばらくお待ちください。')),
      );
      return;
    }
    setState(() => _isRecording = true);

    final point = LocationPoint(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
      timestamp: DateTime.now(),
    );
    await _locationService.saveCleanedLocation(point);
    if (!mounted) return;
    setState(() {
      _cleanedLocations.add(point);
      _isRecording = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('掃除完了地点を記録しました！'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  void _centerOnMyLocation() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        17,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在地を取得できません。GPS設定を確認してください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GIZEN - IIT KGP'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _showTrashBins ? Icons.delete_rounded : Icons.delete_outline,
            ),
            tooltip: 'ゴミ箱表示切替',
            onPressed: () => setState(() => _showTrashBins = !_showTrashBins),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _iitkgpCenter,
              initialZoom: 15.0,
              minZoom: 13.0,
              maxZoom: 19.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gizen.gizen',
              ),
              if (_showTrashBins)
                MarkerLayer(
                  markers: trashBinLatLngs
                      .map(
                        (ll) => Marker(
                          point: ll,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.red,
                            size: 32,
                          ),
                        ),
                      )
                      .toList(),
                ),
              MarkerLayer(
                markers: _cleanedLocations
                    .map(
                      (p) => Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 32,
                        height: 32,
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF2E7D32),
                          size: 28,
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x662196F3),
                              blurRadius: 10,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 現在地ボタン
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _centerOnMyLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // 凡例パネル
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendRow(
                    icon: Icons.delete_rounded,
                    color: Colors.red,
                    label: 'ゴミ箱 (${trashBinLatLngs.length})',
                  ),
                  const SizedBox(height: 4),
                  _LegendRow(
                    icon: Icons.check_circle,
                    color: const Color(0xFF2E7D32),
                    label: '掃除済み (${_cleanedLocations.length}箇所)',
                  ),
                  const SizedBox(height: 4),
                  const _LegendRow(
                    icon: Icons.circle,
                    color: Colors.blue,
                    label: '現在地',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRecording ? null : _recordCleanedLocation,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: _isRecording
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add_location_alt),
        label: const Text('掃除完了を記録'),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
