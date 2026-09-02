import 'package:flutter/material.dart';

Color hexColor(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

const lightcastBlue = Color(0xFF3B82F6);

final lightcastTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Color(0xFF090B10),
  colorScheme: ColorScheme.fromSeed(
    seedColor: lightcastBlue,
    brightness: Brightness.dark,
    surface: Color(0xFF151922),
  ),
  cardColor: Color(0xFF151922),
  dividerColor: Color(0xFF2A3140),
  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF202632),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide.none,
    ),
    isDense: true,
  ),
  sliderTheme: const SliderThemeData(
    activeTrackColor: lightcastBlue,
    thumbColor: Colors.white,
  ),
  useMaterial3: true,
);
