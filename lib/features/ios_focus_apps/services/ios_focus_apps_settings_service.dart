import 'package:shared_preferences/shared_preferences.dart';
import 'package:time_tracker/features/ios_focus_apps/domain/ios_focus_apps_models.dart';

class IOSFocusAppsSettingsService {
  static const _authorizedKey = 'ios_focus_apps_authorized';
  static const _enabledKey = 'ios_focus_apps_enabled';
  static const _hasSelectionKey = 'ios_focus_apps_has_selection';
  static const _dailyModeKey = 'ios_focus_apps_daily_mode';
  static const _dailyLimitKey = 'ios_focus_apps_daily_limit';
  static const _focusBlockingKey = 'ios_focus_apps_focus_blocking';
  static const _breathingPauseKey = 'ios_focus_apps_breathing_pause';
  static const _temporaryUnlockKey = 'ios_focus_apps_temporary_unlock';
  static const _createdAtKey = 'ios_focus_apps_created_at';
  static const _updatedAtKey = 'ios_focus_apps_updated_at';

  Future<IOSFocusAppsSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final defaults = IOSFocusAppsSettings.defaults(now);
    return IOSFocusAppsSettings(
      isScreenTimeAuthorized:
          prefs.getBool(_authorizedKey) ?? defaults.isScreenTimeAuthorized,
      isEnabled: prefs.getBool(_enabledKey) ?? defaults.isEnabled,
      hasFamilyActivitySelection: prefs.getBool(_hasSelectionKey) ??
          defaults.hasFamilyActivitySelection,
      dailyMode: AppControlMode.values.byName(
        prefs.getString(_dailyModeKey) ?? defaults.dailyMode.name,
      ),
      dailyLimitMinutes:
          prefs.getInt(_dailyLimitKey) ?? defaults.dailyLimitMinutes,
      focusModeBlockingEnabled:
          prefs.getBool(_focusBlockingKey) ?? defaults.focusModeBlockingEnabled,
      breathingPauseSeconds:
          prefs.getInt(_breathingPauseKey) ?? defaults.breathingPauseSeconds,
      temporaryUnlockMinutes:
          prefs.getInt(_temporaryUnlockKey) ?? defaults.temporaryUnlockMinutes,
      createdAt: DateTime.tryParse(prefs.getString(_createdAtKey) ?? '') ??
          defaults.createdAt,
      updatedAt: DateTime.tryParse(prefs.getString(_updatedAtKey) ?? '') ??
          defaults.updatedAt,
    );
  }

  Future<void> save(IOSFocusAppsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authorizedKey, settings.isScreenTimeAuthorized);
    await prefs.setBool(_enabledKey, settings.isEnabled);
    await prefs.setBool(
      _hasSelectionKey,
      settings.hasFamilyActivitySelection,
    );
    await prefs.setString(_dailyModeKey, settings.dailyMode.name);
    final dailyLimit = settings.dailyLimitMinutes;
    if (dailyLimit == null) {
      await prefs.remove(_dailyLimitKey);
    } else {
      await prefs.setInt(_dailyLimitKey, dailyLimit);
    }
    await prefs.setBool(
      _focusBlockingKey,
      settings.focusModeBlockingEnabled,
    );
    await prefs.setInt(_breathingPauseKey, settings.breathingPauseSeconds);
    await prefs.setInt(_temporaryUnlockKey, settings.temporaryUnlockMinutes);
    await prefs.setString(_createdAtKey, settings.createdAt.toIso8601String());
    await prefs.setString(_updatedAtKey, settings.updatedAt.toIso8601String());
  }
}
