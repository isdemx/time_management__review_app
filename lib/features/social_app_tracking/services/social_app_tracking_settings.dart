import 'package:shared_preferences/shared_preferences.dart';

class SocialAppTrackingSettings {
  static const _enabledKey = 'social_app_tracking_enabled';

  final bool enabled;

  const SocialAppTrackingSettings({required this.enabled});

  static const defaults = SocialAppTrackingSettings(enabled: false);

  static Future<SocialAppTrackingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SocialAppTrackingSettings(
      enabled: prefs.getBool(_enabledKey) ?? defaults.enabled,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  SocialAppTrackingSettings copyWith({bool? enabled}) {
    return SocialAppTrackingSettings(enabled: enabled ?? this.enabled);
  }
}
