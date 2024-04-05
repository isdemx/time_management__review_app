// lib/utils/color_utils.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ColorUtils {
  static Color generateRandomLightColor() {
    Random random = Random();
    return Color.fromRGBO(
      150 + random.nextInt(106),
      150 + random.nextInt(106),
      150 + random.nextInt(106),
      1,
    );
  }

  static Color fromHex(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '');
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexCode)) {
      return Color(int.parse('FF$hexCode', radix: 16));
    } else {
      print("Not Correct HEX value: $hexColor");
      return Colors.white;
    }
  }
}
