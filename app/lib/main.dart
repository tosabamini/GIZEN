import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
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
