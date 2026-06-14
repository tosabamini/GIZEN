import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/trash_bin.dart';
import '../models/location_point.dart';
import '../services/location_service.dart';
import '../services/trash_bin_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  final _trashBinService = TrashBinService();

  static const _iitkgpCenter = LatLng(22.3149, 87.3105);

  Position? _currentPosition;
  List<TrashBin> _trashBins = [];
  List<LocationPoint> _cleanedLocations = [];
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pos = await _locationService.getCurrentPosition();
    final bins = await _trashBinService.loadAll();
    final cleaned = await _locationService.loadCleanedLocations();
    if (!mounted) return;
    setState(() {
      _currentPosition = pos;
      _trashBins = bins;
      _cleanedLocations = cleaned;
    });
    _locationService.getPositionStream().listen((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
  }

  // ─── Trash Bin CRUD ──────────────────────────────────────

  void _onMapLongPress(TapPosition _, LatLng point) {
    _showBinSheet(null, point);
  }

  void _showBinSheet(TrashBin? existing, LatLng? newPoint) {
    final isNew = existing == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final commentCtrl = TextEditingController(text: existing?.comment ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x26FF8F00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🗑️', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Text(
                isNew ? 'Add New Trash Bin' : 'Edit Trash Bin',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name (e.g. Near Main Building)',
                prefixIcon: const Icon(Icons.label_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Comment (condition, notes, etc.)',
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              if (!isNew) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(ctx, existing),
                    icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    label: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final comment = commentCtrl.text.trim();
                    if (isNew) {
                      final bin = TrashBin(
                          lat: newPoint!.latitude,
                          lng: newPoint.longitude,
                          name: name,
                          comment: comment);
                      await _trashBinService.add(bin);
                      if (!mounted) return;
                      setState(() => _trashBins.add(bin));
                    } else {
                      final updated =
                          existing.copyWith(name: name, comment: comment);
                      await _trashBinService.update(updated);
                      if (!mounted) return;
                      setState(() {
                        final i =
                            _trashBins.indexWhere((b) => b.id == updated.id);
                        if (i != -1) _trashBins[i] = updated;
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showSnack(isNew ? '✅ Trash bin added!' : '✅ Saved!');
                  },
                  icon: Icon(
                      isNew ? Icons.add_location_alt : Icons.save_rounded),
                  label: Text(isNew ? 'Add' : 'Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext sheetCtx, TrashBin bin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🗑️ Delete Trash Bin'),
        content: Text(
            'Delete "${bin.name.isEmpty ? 'Unnamed' : bin.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await _trashBinService.delete(bin.id);
              if (!mounted) return;
              setState(() => _trashBins.removeWhere((b) => b.id == bin.id));
              if (ctx.mounted) Navigator.pop(ctx);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              _showSnack('🗑️ Deleted');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── Cleaning Record ─────────────────────────────────────

  Future<void> _recordCleanedLocation() async {
    if (_currentPosition == null) {
      _showSnack('📍 Getting GPS location…');
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
    _showSnack('🌟 Area cleaned! Thank you!');
  }

  void _centerOnMyLocation() {
    if (_currentPosition != null) {
      _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          17);
    } else {
      _showSnack('📍 Cannot get current location');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xE600C853),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Text('🌿', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('GIZEN Map',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Text('🗑️', style: TextStyle(fontSize: 14)),
              label: Text('${_trashBins.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: Colors.white24,
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _iitkgpCenter,
              initialZoom: 15.0,
              minZoom: 13.0,
              maxZoom: 19.0,
              onLongPress: _onMapLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.gizen.gizen',
              ),
              MarkerLayer(markers: _cleanedMarkers()),
              MarkerLayer(markers: _trashBinMarkers()),
              if (_currentPosition != null)
                MarkerLayer(markers: [_currentLocationMarker()]),
            ],
          ),

          // Hint bar
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 8)
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('👆 Tap to edit  ',
                      style: TextStyle(fontSize: 12)),
                  Text('✋ Long press to add bin',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),

          // Legend
          Positioned(
            bottom: 90,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 6)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendRow('🗑️', 'Bins: ${_trashBins.length}'),
                  const SizedBox(height: 4),
                  _legendRow('✅', 'Cleaned: ${_cleanedLocations.length}'),
                  const SizedBox(height: 4),
                  const _LegendRow(emoji: '🔵', label: 'My location'),
                ],
              ),
            ),
          ),

          // My location button
          Positioned(
            bottom: 90,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              onPressed: _centerOnMyLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF00C853)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRecording ? null : _recordCleanedLocation,
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: _isRecording
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : const Text('✅', style: TextStyle(fontSize: 20)),
        label: const Text('Mark as Cleaned',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Marker builders ─────────────────────────────────────

  List<Marker> _trashBinMarkers() => _trashBins
      .map((bin) => Marker(
            point: LatLng(bin.lat, bin.lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => _showBinSheet(bin, null),
              child: _BinMarker(hasComment: bin.comment.isNotEmpty),
            ),
          ))
      .toList();

  List<Marker> _cleanedMarkers() => _cleanedLocations
      .map((p) => Marker(
            point: LatLng(p.lat, p.lng),
            width: 36,
            height: 36,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x4400C853),
                      blurRadius: 8,
                      spreadRadius: 2)
                ],
              ),
              child: const Center(
                  child: Text('✅', style: TextStyle(fontSize: 14))),
            ),
          ))
      .toList();

  Marker _currentLocationMarker() => Marker(
        point:
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        width: 24,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x662196F3),
                  blurRadius: 12,
                  spreadRadius: 4)
            ],
          ),
        ),
      );

  Widget _legendRow(String emoji, String label) =>
      _LegendRow(emoji: emoji, label: label);
}

// ─── Sub Widgets ─────────────────────────────────────────

class _BinMarker extends StatelessWidget {
  final bool hasComment;
  const _BinMarker({required this.hasComment});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFF6D00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66FF8F00), blurRadius: 8, spreadRadius: 2)
            ],
          ),
          child: const Center(
              child: Text('🗑️', style: TextStyle(fontSize: 20))),
        ),
        if (hasComment)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String emoji;
  final String label;
  const _LegendRow({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
