import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../models/building.dart';
import '../models/cleaning_session.dart';
import '../models/trash_bin.dart';
import '../services/auth_service.dart';
import '../services/building_service.dart';
import '../services/cleaning_session_service.dart';
import '../services/location_service.dart';
import '../services/trash_bin_service.dart';
import 'auth_screen.dart';
import 'log_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  final _trashBinService = TrashBinService();
  final _buildingService = BuildingService();
  final _sessionService = CleaningSessionService();

  static const _iitkgpCenter = LatLng(22.3149, 87.3105);
  static const _campusSW = LatLng(22.292, 87.276);
  static const _campusNE = LatLng(22.348, 87.345);
  static const _tileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  // Location
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSub;
  LatLng? _lastValidPoint;
  DateTime? _lastPointTime;

  // Data
  List<TrashBin> _trashBins = [];
  List<Building> _buildings = [];
  List<CleaningSession> _sessions = [];

  // Cleaning session
  bool _isCleaning = false;
  DateTime? _sessionStart;
  List<LatLng> _currentPath = [];
  Duration _elapsed = Duration.zero;
  Timer? _cleanTimer;

  // UI toggles
  bool _showBuildingLabels = true;

  // Download
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cleanTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final pos = await _locationService.getCurrentPosition();
    final bins = await _trashBinService.loadAll();
    final buildings = await _buildingService.loadAll();
    final sessions = await _sessionService.loadAll();
    if (!mounted) return;
    setState(() {
      _currentPosition = pos;
      _trashBins = bins;
      _buildings = buildings;
      _sessions = sessions;
      if (pos != null) {
        _lastValidPoint = LatLng(pos.latitude, pos.longitude);
        _lastPointTime = DateTime.now();
      }
    });
    _restartPositionStream(background: false);
  }

  void _restartPositionStream({required bool background}) {
    _positionSub?.cancel();
    final stream = background
        ? _locationService.getBackgroundPositionStream()
        : _locationService.getPositionStream();
    _positionSub = stream.listen((pos) {
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      final valid = _isValidGpsPoint(point);
      setState(() {
        _currentPosition = pos;
        if (valid) {
          if (_isCleaning) _currentPath.add(point);
          _lastValidPoint = point;
          _lastPointTime = DateTime.now();
        }
      });
    });
  }

  // ─── GPS outlier filter ──────────────────────────────────

  bool _isValidGpsPoint(LatLng point) {
    if (_lastValidPoint == null || _lastPointTime == null) return true;
    final dist = const Distance()
        .as(LengthUnit.Meter, _lastValidPoint!, point);
    final elapsedSec =
        DateTime.now().difference(_lastPointTime!).inMilliseconds / 1000.0;
    // Reject if speed > 8 m/s (~30 km/h) or jump > 100m
    if (dist > 100) return false;
    if (elapsedSec > 0 && dist / elapsedSec > 8) return false;
    return true;
  }

  // ─── Cleaning session ────────────────────────────────────

  void _startCleaning() {
    if (_currentPosition == null) {
      _showSnack('📍 GPS not ready yet. Please wait.');
      return;
    }
    final startPoint =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    setState(() {
      _isCleaning = true;
      _sessionStart = DateTime.now();
      _elapsed = Duration.zero;
      _currentPath = [startPoint];
      _lastValidPoint = startPoint;
      _lastPointTime = DateTime.now();
    });
    _cleanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_sessionStart!));
      }
    });
    // Switch to background-capable GPS stream
    _restartPositionStream(background: true);
  }

  Future<void> _stopCleaning() async {
    _cleanTimer?.cancel();
    _cleanTimer = null;

    if (_currentPath.length < 2) {
      setState(() {
        _isCleaning = false;
        _currentPath = [];
        _sessionStart = null;
        _elapsed = Duration.zero;
      });
      _showSnack('⚠️ Path too short to record.');
      return;
    }

    final path = List<LatLng>.from(_currentPath);
    final startTime = _sessionStart!;
    final endTime = DateTime.now();

    setState(() {
      _isCleaning = false;
      _currentPath = [];
      _sessionStart = null;
      _elapsed = Duration.zero;
    });

    // Return to normal (non-background) GPS stream
    _restartPositionStream(background: false);

    if (mounted) _showSessionSummarySheet(path, startTime, endTime);
  }

  void _showSessionSummarySheet(
      List<LatLng> path, DateTime startTime, DateTime endTime) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) => _SessionSummarySheet(
        path: path,
        startTime: startTime,
        endTime: endTime,
        onSave: (session) async {
          await _sessionService.add(session);
          if (!mounted) return;
          setState(() => _sessions.add(session));
          final dist = session.distanceMeters;
          final distStr = dist >= 1000
              ? '${(dist / 1000).toStringAsFixed(1)} km'
              : '${dist.toInt()} m';
          if (ctx.mounted) Navigator.pop(ctx);
          _showSnack(
              '🌟 Saved! $distStr in ${_formatDuration(session.duration)}');
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Trash Bin CRUD ──────────────────────────────────────

  void _onMapLongPress(TapPosition _, LatLng point) {
    if (!_isCleaning) _showBinSheet(null, point);
  }

  void _showBinSheet(TrashBin? existing, LatLng? newPoint) {
    final isNew = existing == null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final commentCtrl = TextEditingController(text: existing?.comment ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          BinSize selectedSize = existing?.size ?? BinSize.medium;

          Widget sizeChip(BinSize s, String label, Color color) {
            final selected = selectedSize == s;
            return GestureDetector(
              onTap: () => setSheetState(() => selectedSize = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? color : color.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected ? color : color.withAlpha(80),
                      width: 1.5),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            );
          }

          return Container(
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
                const SizedBox(height: 14),
                const Text('Bin Size',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    sizeChip(BinSize.small, 'S  Small',
                        const Color(0xFFFFAB00)),
                    const SizedBox(width: 8),
                    sizeChip(BinSize.medium, 'M  Medium',
                        const Color(0xFFFF6D00)),
                    const SizedBox(width: 8),
                    sizeChip(
                        BinSize.large, 'L  Large', const Color(0xFFE53935)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(children: [
                  if (!isNew) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmDelete(ctx, existing),
                        icon: const Icon(Icons.delete_rounded,
                            color: Colors.red),
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
                              comment: comment,
                              size: selectedSize);
                          await _trashBinService.add(bin);
                          if (!mounted) return;
                          setState(() => _trashBins.add(bin));
                        } else {
                          final updated = existing.copyWith(
                              name: name,
                              comment: comment,
                              size: selectedSize);
                          await _trashBinService.update(updated);
                          if (!mounted) return;
                          setState(() {
                            final i = _trashBins
                                .indexWhere((b) => b.id == updated.id);
                            if (i != -1) _trashBins[i] = updated;
                          });
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSnack(
                            isNew ? '✅ Trash bin added!' : '✅ Saved!');
                      },
                      icon: Icon(isNew
                          ? Icons.add_location_alt
                          : Icons.save_rounded),
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
          );
        },
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
              setState(
                  () => _trashBins.removeWhere((b) => b.id == bin.id));
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

  // ─── Building labels ─────────────────────────────────────

  static const _presetColors = [
    0xF0FFFFFF,
    0xFFFFF9C4,
    0xFFE8F5E9,
    0xFFE3F2FD,
    0xFFFCE4EC,
    0xFFEDE7F6,
    0xFFFFF3E0,
    0xFFE0F2F1,
  ];

  void _showBuildingSheet(Building building) {
    final nameCtrl = TextEditingController(text: building.name);
    int selectedColor = building.colorValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
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
                    color: const Color(0x2600C853),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_city_rounded,
                      color: Color(0xFF00C853), size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Edit Building Label',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Building name',
                  prefixIcon: const Icon(Icons.edit_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              Text('Label color',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 8),
              Row(
                children: _presetColors
                    .map((c) => GestureDetector(
                          onTap: () =>
                              setModalState(() => selectedColor = c),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == c
                                    ? const Color(0xFF00C853)
                                    : Colors.grey.shade300,
                                width: selectedColor == c ? 2.5 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x22000000),
                                    blurRadius: 4)
                              ],
                            ),
                            child: selectedColor == c
                                ? const Icon(Icons.check,
                                    size: 16, color: Color(0xFF00C853))
                                : null,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _confirmDeleteBuilding(ctx, building),
                    icon: const Icon(Icons.delete_rounded,
                        color: Colors.red),
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
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final trimmed = nameCtrl.text.trim();
                      final updated = building.copyWith(
                        name: trimmed.isEmpty ? building.name : trimmed,
                        colorValue: selectedColor,
                      );
                      await _buildingService.update(updated);
                      if (!mounted) return;
                      setState(() {
                        final i = _buildings
                            .indexWhere((b) => b.id == updated.id);
                        if (i != -1) _buildings[i] = updated;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _showSnack('✅ Building updated!');
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save'),
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
      ),
    );
  }

  void _confirmDeleteBuilding(BuildContext sheetCtx, Building building) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🏛️ Remove Building Label'),
        content: Text(
            'Remove "${building.name}" from the map?\n(Only removes the label, not the actual building)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await _buildingService.delete(building.id);
              if (!mounted) return;
              setState(() =>
                  _buildings.removeWhere((b) => b.id == building.id));
              if (ctx.mounted) Navigator.pop(ctx);
              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
              _showSnack('🗑️ Label removed');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ─── Map download ─────────────────────────────────────────

  void _centerOnMyLocation() {
    if (_currentPosition != null) {
      _mapController.move(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          17);
    } else {
      _showSnack('📍 Cannot get current location');
    }
  }

  Future<void> _downloadCampus() async {
    if (_downloadProgress != null) return;
    setState(() => _downloadProgress = 0);

    final region = RectangleRegion(LatLngBounds(_campusSW, _campusNE));
    final downloadable = region.toDownloadable(
      minZoom: 14,
      maxZoom: 17,
      options: TileLayer(
        urlTemplate: _tileUrl,
        subdomains: const ['a', 'b', 'c', 'd'],
      ),
    );

    FMTCStore('campus').download.startForeground(
      region: downloadable,
      parallelThreads: 3,
      maxBufferLength: 200,
      skipExistingTiles: true,
      skipSeaTiles: false,
      maxReportInterval: const Duration(milliseconds: 500),
    ).listen(
      (progress) {
        if (mounted) {
          setState(
              () => _downloadProgress = progress.percentageProgress / 100);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _downloadProgress = null);
          _showSnack('✅ Campus map downloaded for offline use!');
        }
      },
      onError: (_) {
        if (mounted) {
          setState(() => _downloadProgress = null);
          _showSnack('⚠️ Download failed. Check connection.');
        }
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: const Duration(seconds: 3),
    ));
  }

  Widget _colorDot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

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
            padding: const EdgeInsets.only(left: 4),
            child: Chip(
              avatar: const Text('🗑️', style: TextStyle(fontSize: 14)),
              label: Text('${_trashBins.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: Colors.white24,
              side: BorderSide.none,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Cleaning Log',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogScreen())),
          ),
          if (_downloadProgress != null)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.cloud_download_rounded),
              tooltip: 'Download campus map for offline use',
              onPressed: _downloadCampus,
            ),
          IconButton(
            icon: Icon(AuthService.currentUser != null
                ? Icons.account_circle
                : Icons.account_circle_outlined),
            tooltip: AuthService.currentUser != null
                ? AuthService.displayName
                : 'Login / Register',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()));
              setState(() {}); // refresh login state in AppBar
            },
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
              minZoom: 14.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(_campusSW, _campusNE),
              ),
              onLongPress: _onMapLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.gizen.gizen',
                tileProvider: FMTCStore('campus').getTileProvider(
                  settings: FMTCTileProviderSettings(
                    behavior: CacheBehavior.cacheFirst,
                    cachedValidDuration: const Duration(days: 60),
                  ),
                ),
              ),
              // Past cleaning routes — stacked opacity = darker green per pass
              PolylineLayer(
                polylines: [
                  ..._sessions.map((s) => Polyline(
                        points: s.path,
                        strokeWidth: 7,
                        color: const Color(0x5500C853),
                      )),
                  if (_isCleaning && _currentPath.length > 1)
                    Polyline(
                      points: _currentPath,
                      strokeWidth: 7,
                      color: const Color(0xCC00E676),
                    ),
                ],
              ),
              if (_showBuildingLabels) MarkerLayer(markers: _buildingLabelMarkers()),
              MarkerLayer(markers: _trashBinMarkers()),
              if (_currentPosition != null)
                MarkerLayer(markers: [_currentLocationMarker()]),
            ],
          ),

          // Hint bar (hidden during cleaning)
          if (!_isCleaning)
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
                    Text('👆 Tap label to edit  ',
                        style: TextStyle(fontSize: 12)),
                    Text('✋ Long press to add bin',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Cleaning timer banner (shown during cleaning)
          if (_isCleaning)
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x4400C853),
                        blurRadius: 12,
                        spreadRadius: 2)
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🧹', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text(
                      'Cleaning...  ${_formatDuration(_elapsed)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Point count indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPath.length} pts',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
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
                  _LegendRow(emoji: '🗑️', label: 'Bins: ${_trashBins.length}'),
                  const SizedBox(height: 4),
                  _LegendRow(
                      emoji: '🧹',
                      label: 'Sessions: ${_sessions.length}'),
                  const SizedBox(height: 4),
                  const _LegendRow(emoji: '🔵', label: 'My location'),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  // Building label toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏛️',
                          style: TextStyle(
                              fontSize: 14,
                              color: _showBuildingLabels
                                  ? null
                                  : Colors.grey)),
                      const SizedBox(width: 6),
                      Text('Labels',
                          style: TextStyle(
                              fontSize: 12,
                              color: _showBuildingLabels
                                  ? null
                                  : Colors.grey)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() =>
                            _showBuildingLabels = !_showBuildingLabels),
                        child: Icon(
                          _showBuildingLabels
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 18,
                          color: _showBuildingLabels
                              ? const Color(0xFF00C853)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  // Bin size color legend
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _colorDot(const Color(0xFFFFD600)),
                      const SizedBox(width: 4),
                      const Text('S', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 10),
                      _colorDot(const Color(0xFFFF8F00)),
                      const SizedBox(width: 4),
                      const Text('M', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 10),
                      _colorDot(const Color(0xFFE53935)),
                      const SizedBox(width: 4),
                      const Text('L', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Download progress bar
          if (_downloadProgress != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white38,
                color: const Color(0xFF00C853),
                minHeight: 4,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isCleaning
          ? FloatingActionButton.extended(
              heroTag: 'stop',
              onPressed: _stopCleaning,
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.stop_rounded, size: 28),
              label: const Text('STOP',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            )
          : FloatingActionButton.extended(
              heroTag: 'start',
              onPressed: _startCleaning,
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Text('🧹', style: TextStyle(fontSize: 22)),
              label: const Text('Start Cleaning',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
    );
  }

  // ─── Marker builders ─────────────────────────────────────

  List<Marker> _buildingLabelMarkers() => _buildings
      .map((b) => Marker(
            point: b.location,
            width: 130,
            height: 36,
            child: GestureDetector(
              onTap: () => _showBuildingSheet(b),
              child: _BuildingLabel(name: b.name, colorValue: b.colorValue),
            ),
          ))
      .toList();

  List<Marker> _trashBinMarkers() => _trashBins
      .map((bin) => Marker(
            point: LatLng(bin.lat, bin.lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => _showBinSheet(bin, null),
              child: _BinMarker(hasComment: bin.comment.isNotEmpty, size: bin.size),
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
}

// ─── Sub Widgets ─────────────────────────────────────────

class _BuildingLabel extends StatelessWidget {
  final String name;
  final int colorValue;
  const _BuildingLabel({required this.name, required this.colorValue});

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(colorValue);
    final textColor = bgColor.computeLuminance() > 0.5
        ? const Color(0xFF2E7D32)
        : Colors.white;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _BinMarker extends StatelessWidget {
  final bool hasComment;
  final BinSize size;
  const _BinMarker({required this.hasComment, required this.size});

  @override
  Widget build(BuildContext context) {
    final (gradColors, shadowColor) = switch (size) {
      BinSize.small => (
          const [Color(0xFFFFD600), Color(0xFFFFAB00)],
          const Color(0x66FFD600),
        ),
      BinSize.medium => (
          const [Color(0xFFFF8F00), Color(0xFFFF6D00)],
          const Color(0x66FF8F00),
        ),
      BinSize.large => (
          const [Color(0xFFE53935), Color(0xFFB71C1C)],
          const Color(0x66E53935),
        ),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(color: shadowColor, blurRadius: 8, spreadRadius: 2)
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

// ─── Session Summary Sheet ────────────────────────────────

class _SessionSummarySheet extends StatefulWidget {
  final List<LatLng> path;
  final DateTime startTime;
  final DateTime endTime;
  final Future<void> Function(CleaningSession) onSave;

  const _SessionSummarySheet({
    required this.path,
    required this.startTime,
    required this.endTime,
    required this.onSave,
  });

  @override
  State<_SessionSummarySheet> createState() => _SessionSummarySheetState();
}

class _SessionSummarySheetState extends State<_SessionSummarySheet> {
  final _participantsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();

  int _bagCount = 0;
  final List<String> _imagePaths = [];
  bool _saving = false;

  late final Duration _duration;
  late final String _distStr;

  @override
  void initState() {
    super.initState();
    _participantsCtrl.text = AuthService.displayName;
    _duration = widget.endTime.difference(widget.startTime);
    double d = 0;
    final p = widget.path;
    for (int i = 1; i < p.length; i++) {
      d += const Distance().as(LengthUnit.Meter, p[i - 1], p[i]);
    }
    _distStr =
        d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.toInt()} m';
  }

  @override
  void dispose() {
    _participantsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _pickImages() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF00C853)),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF00C853)),
              title: const Text('Gallery (multiple)'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    if (source == ImageSource.gallery) {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      for (final img in images) {
        final path = await _saveLocally(img);
        if (path != null && mounted) setState(() => _imagePaths.add(path));
      }
    } else {
      final img =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (img != null) {
        final path = await _saveLocally(img);
        if (path != null && mounted) setState(() => _imagePaths.add(path));
      }
    }
  }

  Future<String?> _saveLocally(XFile xfile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/session_images');
      if (!await dir.exists()) await dir.create(recursive: true);
      final dest =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(xfile.path).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = CleaningSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startTime: widget.startTime,
      endTime: widget.endTime,
      path: widget.path,
      participants: _participantsCtrl.text.trim(),
      bagCount: _bagCount,
      notes: _notesCtrl.text.trim(),
      imagePaths: List.from(_imagePaths),
      creatorNickname: AuthService.displayName.isNotEmpty
          ? AuthService.displayName
          : null,
    );
    await widget.onSave(session);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),

              // Stats header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text('🌟 Cleaning Complete!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _pill('⏱ ${_fmt(_duration)}'),
                    const SizedBox(width: 8),
                    _pill('📍 $_distStr'),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // Participants
              TextField(
                controller: _participantsCtrl,
                decoration: InputDecoration(
                  labelText: 'Participants',
                  hintText: 'e.g. Alice, Bob, Charlie',
                  prefixIcon: const Icon(Icons.group_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 14),

              // Bag count
              Row(children: [
                const Icon(Icons.shopping_bag_rounded, color: Colors.grey),
                const SizedBox(width: 12),
                const Text('Bags collected', style: TextStyle(fontSize: 15)),
                const Spacer(),
                IconButton(
                  onPressed: _bagCount > 0
                      ? () => setState(() => _bagCount--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFF00C853),
                ),
                SizedBox(
                  width: 36,
                  child: Text('$_bagCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => setState(() => _bagCount++),
                  icon: const Icon(Icons.add_circle_outline),
                  color: const Color(0xFF00C853),
                ),
              ]),
              const SizedBox(height: 14),

              // Photos
              Row(children: [
                const Icon(Icons.photo_camera_rounded, color: Colors.grey),
                const SizedBox(width: 12),
                const Text('Photos', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Text('${_imagePaths.length}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _addPhotoBtn(),
                    ..._imagePaths.map(_thumbnail),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Found lots of plastic near the main gate',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Save
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Session',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      );

  Widget _addPhotoBtn() => GestureDetector(
        onTap: _pickImages,
        child: Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_rounded,
                  color: Color(0xFF00C853), size: 28),
              SizedBox(height: 4),
              Text('Add', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );

  Widget _thumbnail(String path) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path),
                  width: 80, height: 80, fit: BoxFit.cover),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => setState(() => _imagePaths.remove(path)),
                child: Container(
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      );
}
