import 'dart:io';

import 'package:flutter/material.dart';
import '../models/cleaning_session.dart';
import '../services/cleaning_session_service.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _service = CleaningSessionService();
  List<CleaningSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _service.loadAll();
    setState(() {
      _sessions = all.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Text('🧹', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Cleaning Log'),
        ]),
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('No cleaning sessions yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Start cleaning from the map!',
              style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildList() {
    // Group by date
    final groups = <String, List<CleaningSession>>{};
    for (final s in _sessions) {
      final key = _dateLabel(s.startTime);
      groups.putIfAbsent(key, () => []).add(s);
    }

    // Total stats
    final totalBags = _sessions.fold(0, (sum, s) => sum + s.bagCount);
    final totalDist = _sessions.fold(0.0, (sum, s) => sum + s.distanceMeters);
    final totalMin =
        _sessions.fold(0, (sum, s) => sum + s.duration.inMinutes);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x3300C853), blurRadius: 10)
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip('${_sessions.length}', 'Sessions'),
              _statChip('$totalBags 🛍️', 'Bags'),
              _statChip(_formatDist(totalDist), 'Distance'),
              _statChip('${totalMin}m', 'Total time'),
            ],
          ),
        ),

        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              entry.key,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF2E7D32)),
            ),
          ),
          ...entry.value.map((s) => _SessionCard(
                session: s,
                onDelete: () => _deleteSession(s),
              )),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _statChip(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)}km' : '${m.toInt()}m';

  Future<void> _deleteSession(CleaningSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Session'),
        content: const Text(
            'Delete this cleaning session? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _service.delete(session.id);
    setState(() => _sessions.removeWhere((s) => s.id == session.id));
  }
}

class _SessionCard extends StatelessWidget {
  final CleaningSession session;
  final VoidCallback onDelete;
  const _SessionCard({required this.session, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final duration = session.duration;
    final durationStr =
        '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    final dist = session.distanceMeters;
    final distStr =
        dist >= 1000 ? '${(dist / 1000).toStringAsFixed(1)} km' : '${dist.toInt()} m';
    final time =
        '${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8)],
        border: Border.all(color: const Color(0xFFE8F5E9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time + creator row
            Row(
              children: [
                Text(time,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (session.creatorNickname?.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      session.creatorNickname!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF2E7D32)),
                    ),
                  ),
                ],
                const Spacer(),
                // Duration + distance pills
                _pill('⏱ $durationStr', const Color(0xFFF3E5F5)),
                const SizedBox(width: 6),
                _pill('📍 $distStr', const Color(0xFFE3F2FD)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: Colors.red),
                  ),
                ),
              ],
            ),

            // Participants
            if (session.participants.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Text('👥 ',
                    style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(session.participants,
                      style: const TextStyle(fontSize: 13)),
                ),
              ]),
            ],

            // Bags
            if (session.bagCount > 0) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Text('🛍️ ',
                    style: TextStyle(fontSize: 14)),
                Text('${session.bagCount} bag${session.bagCount != 1 ? 's' : ''} collected',
                    style: const TextStyle(fontSize: 13)),
              ]),
            ],

            // Notes
            if (session.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(session.notes,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ),
            ],

            // Photos
            if (session.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: session.imagePaths.length,
                  itemBuilder: (_, i) {
                    final f = File(session.imagePaths[i]);
                    return GestureDetector(
                      onTap: () => _showImageFullscreen(
                          context, session.imagePaths, i),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: f.existsSync()
                              ? Image.file(f,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover)
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImageFullscreen(
      BuildContext context, List<String> paths, int initial) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewer(paths: paths, initialIndex: initial),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  const _ImageViewer({required this.paths, required this.initialIndex});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final f = File(widget.paths[i]);
          return InteractiveViewer(
            child: Center(
              child: f.existsSync()
                  ? Image.file(f, fit: BoxFit.contain)
                  : const Icon(Icons.broken_image,
                      color: Colors.grey, size: 80),
            ),
          );
        },
      ),
    );
  }
}
