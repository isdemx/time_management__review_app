import 'package:shared_preferences/shared_preferences.dart';

class ActiveSessionVisibilitySettings {
  static const lockScreenKey = 'settings.visibility.lock_screen';
  static const dynamicIslandKey = 'settings.visibility.dynamic_island';
  static const compactIslandKey = 'settings.visibility.compact_island';
  static const backgroundIndicatorKey =
      'settings.visibility.background_indicator';

  final bool lockScreen;
  final bool dynamicIsland;
  final bool compactIsland;
  final bool backgroundIndicator;

  const ActiveSessionVisibilitySettings({
    required this.lockScreen,
    required this.dynamicIsland,
    required this.compactIsland,
    required this.backgroundIndicator,
  });

  const ActiveSessionVisibilitySettings.defaults()
      : lockScreen = true,
        dynamicIsland = true,
        compactIsland = false,
        backgroundIndicator = true;

  bool get liveIndicatorEnabled => lockScreen || dynamicIsland;

  ActiveSessionVisibilitySettings copyWith({
    bool? lockScreen,
    bool? dynamicIsland,
    bool? compactIsland,
    bool? backgroundIndicator,
  }) {
    return ActiveSessionVisibilitySettings(
      lockScreen: lockScreen ?? this.lockScreen,
      dynamicIsland: dynamicIsland ?? this.dynamicIsland,
      compactIsland: compactIsland ?? this.compactIsland,
      backgroundIndicator: backgroundIndicator ?? this.backgroundIndicator,
    );
  }

  static Future<ActiveSessionVisibilitySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ActiveSessionVisibilitySettings(
      lockScreen: prefs.getBool(lockScreenKey) ?? true,
      dynamicIsland: prefs.getBool(dynamicIslandKey) ?? true,
      compactIsland: prefs.getBool(compactIslandKey) ?? false,
      backgroundIndicator: prefs.getBool(backgroundIndicatorKey) ?? true,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(lockScreenKey, lockScreen);
    await prefs.setBool(dynamicIslandKey, dynamicIsland);
    await prefs.setBool(compactIslandKey, compactIsland);
    await prefs.setBool(backgroundIndicatorKey, backgroundIndicator);
  }
}
