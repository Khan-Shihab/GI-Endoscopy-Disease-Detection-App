import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PolypDetectionApp());
}

class PolypDetectionApp extends StatelessWidget {
  const PolypDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polyp Detection',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
