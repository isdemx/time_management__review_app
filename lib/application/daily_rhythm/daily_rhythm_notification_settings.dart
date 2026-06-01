import 'package:shared_preferences/shared_preferences.dart';

class DailyRhythmNotificationSettings {
  static const enabledKey = 'settings.daily_rhythm.enabled';
  static const morningHourKey = 'settings.daily_rhythm.morning_hour';
  static const morningMinuteKey = 'settings.daily_rhythm.morning_minute';
  static const middayHourKey = 'settings.daily_rhythm.midday_hour';
  static const afternoonHourKey = 'settings.daily_rhythm.afternoon_hour';
  static const eveningNudgeHourKey = 'settings.daily_rhythm.evening_nudge_hour';
  static const reflectionHourKey = 'settings.daily_rhythm.reflection_hour';
  static const reflectionMinuteKey = 'settings.daily_rhythm.reflection_minute';

  final bool enabled;
  final int morningHour;
  final int morningMinute;
  final int middayHour;
  final int afternoonHour;
  final int eveningNudgeHour;
  final int reflectionHour;
  final int reflectionMinute;

  const DailyRhythmNotificationSettings({
    this.enabled = true,
    this.morningHour = 8,
    this.morningMinute = 0,
    this.middayHour = 12,
    this.afternoonHour = 15,
    this.eveningNudgeHour = 18,
    this.reflectionHour = 21,
    this.reflectionMinute = 30,
  });

  static Future<DailyRhythmNotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyRhythmNotificationSettings(
      enabled: prefs.getBool(enabledKey) ?? true,
      morningHour: prefs.getInt(morningHourKey) ?? 8,
      morningMinute: prefs.getInt(morningMinuteKey) ?? 0,
      middayHour: prefs.getInt(middayHourKey) ?? 12,
      afternoonHour: prefs.getInt(afternoonHourKey) ?? 15,
      eveningNudgeHour: prefs.getInt(eveningNudgeHourKey) ?? 18,
      reflectionHour: prefs.getInt(reflectionHourKey) ?? 21,
      reflectionMinute: prefs.getInt(reflectionMinuteKey) ?? 30,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
    await prefs.setInt(morningHourKey, morningHour);
    await prefs.setInt(morningMinuteKey, morningMinute);
    await prefs.setInt(middayHourKey, middayHour);
    await prefs.setInt(afternoonHourKey, afternoonHour);
    await prefs.setInt(eveningNudgeHourKey, eveningNudgeHour);
    await prefs.setInt(reflectionHourKey, reflectionHour);
    await prefs.setInt(reflectionMinuteKey, reflectionMinute);
  }
}
