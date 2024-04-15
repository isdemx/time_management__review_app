import 'package:flutter/material.dart';

class ColorHelpers {
  static Color getSprintColor(Duration duration, Duration maxDuration) {
    double t = duration.inSeconds / maxDuration.inSeconds;
    return Color.lerp(Colors.lightBlueAccent, Colors.blueAccent, t)!;
  }
}
