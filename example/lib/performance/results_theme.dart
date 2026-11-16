import 'package:flutter/material.dart';

ThemeData performanceResultsTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0C111B),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5ADDB0),
    brightness: Brightness.dark,
    surface: const Color(0xFF141D2B),
  ),
  useMaterial3: true,
);
