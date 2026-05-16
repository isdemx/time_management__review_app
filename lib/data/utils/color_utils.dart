// lib/utils/color_utils.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ColorUtils {
  static const List<Color> chronikaPalette = [
    Color(0xFFFFA000),
    Color(0xFFFF7043),
    Color(0xFFFF2D73),
    Color(0xFFD31BCE),
    Color(0xFF7C3CFF),
    Color(0xFF246BFE),
  ];

  static Color generateRandomLightColor() {
    final random = Random();
    return chronikaPalette[random.nextInt(chronikaPalette.length)];
  }

  static Color fromHex(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '');
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexCode)) {
      return Color(int.parse('FF$hexCode', radix: 16));
    } else {
      return Colors.white;
    }
  }

  static String toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  static Color lighten(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount) ?? color;
  }

  static Color darken(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount) ?? color;
  }
}
