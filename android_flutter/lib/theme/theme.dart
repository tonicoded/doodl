import 'package:flutter/material.dart';

ThemeData buildDoodlTheme() {
  const seed = Color(0xFFFFFC00); // DOODL yellow
  return ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: null,
  );
}
