import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/home/home_screen.dart';
import '../features/scan/scan_controller.dart';
import 'app_theme.dart';

class MediVoiceApp extends StatelessWidget {
  const MediVoiceApp({required this.controller, super.key});

  final ScanController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        title: 'MediVoice',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}
