// lib/utils/color_utils.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ColorUtils {
  static int _suggestionNonce = 0;

  static const List<Color> chronikaPalette = [
    Color(0xFFFFA000),
    Color(0xFFFF7043),
    Color(0xFFFF2D73),
    Color(0xFFD31BCE),
    Color(0xFF7C3CFF),
    Color(0xFF246BFE),
  ];

  static final List<Color> chronikaPalette256 = List<Color>.unmodifiable(
    List<Color>.generate(256, _chronikaColorAt),
  );

  static Color generateRandomLightColor() {
    final random = Random();
    return chronikaPalette256[random.nextInt(chronikaPalette256.length)];
  }

  static List<String> suggestedColorHexes({
    required String currentHex,
    int count = 4,
  }) {
    final normalizedCurrent = normalizeHex(currentHex);
    final random = Random(
      DateTime.now().microsecondsSinceEpoch ^ _suggestionNonce++,
    );
    final palette = [...chronikaPalette256.map(toHex)]..shuffle(random);
    final unique = <String>[];
    for (final color in palette) {
      final normalized = normalizeHex(color);
      if (normalized != normalizedCurrent && !unique.contains(normalized)) {
        unique.add(normalized);
      }
      if (unique.length == count) {
        return unique;
      }
    }
    return unique;
  }

  static Color fromHex(String hexColor) {
    final hexCode = normalizeHex(hexColor).replaceAll('#', '');
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

  static String normalizeHex(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '').toUpperCase();
    if (RegExp(r'^[0-9A-F]{6}$').hasMatch(hexCode)) {
      return '#$hexCode';
    }
    return '#FFFFFF';
  }

  static Color lighten(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount) ?? color;
  }

  static Color darken(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount) ?? color;
  }

  static Color _chronikaColorAt(int index) {
    final normalized = index / 256;
    final hue = (18 + index * 137.50776405) % 360;
    const saturations = [
      0.86,
      0.72,
      0.62,
      0.90,
      0.56,
      0.78,
      0.68,
      0.82,
    ];
    const lightnesses = [
      0.58,
      0.48,
      0.42,
      0.64,
      0.52,
      0.46,
      0.68,
      0.55,
    ];
    final saturation = saturations[index % saturations.length] +
        sin(normalized * pi * 12) * 0.035;
    final lightness =
        lightnesses[(index ~/ saturations.length) % lightnesses.length] +
            cos(normalized * pi * 10) * 0.035;
    return HSLColor.fromAHSL(
      1,
      hue,
      saturation.clamp(0.48, 0.92),
      lightness.clamp(0.36, 0.72),
    ).toColor();
  }
}
