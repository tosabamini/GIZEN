import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

import 'firebase_options.dart';
import 'screens/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (requires flutterfire configure to be run first).
  // If not configured yet, the app runs in local-only mode.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('campus').manage.create();
  runApp(const GizenApp());
}

class GizenApp extends StatelessWidget {
  const GizenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GIZEN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MapScreen(),
    );
  }
}
