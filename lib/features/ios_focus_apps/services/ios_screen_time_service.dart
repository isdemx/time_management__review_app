import 'dart:io';

import 'package:flutter/services.dart';
import 'package:time_tracker/features/ios_focus_apps/domain/ios_focus_apps_models.dart';

abstract class IOSScreenTimeService {
  Future<bool> requestAuthorization();
  Future<bool> isAuthorized();
  Future<bool> openFamilyActivityPicker();
  Future<bool> hasSelection();
  Future<void> startDailyMonitoring();
  Future<void> stopDailyMonitoring();
  Future<void> applyShield();
  Future<void> clearShield();
  Future<void> startFocusBlocking();
  Future<void> stopFocusBlocking();
  Future<void> temporaryUnlock(Duration duration);
  Future<void> restoreBlocking();
  Future<void> configure(IOSFocusAppsSettings settings);
  Future<IOSFocusAppsBlockingState> getBlockingState();
}

class MethodChannelIOSScreenTimeService implements IOSScreenTimeService {
  static const MethodChannel _channel = MethodChannel('chronika/screen_time');

  @override
  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS) return false;
    return await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
  }

  @override
  Future<bool> isAuthorized() async {
    if (!Platform.isIOS) return false;
    return await _channel.invokeMethod<bool>('isAuthorized') ?? false;
  }

  @override
  Future<bool> openFamilyActivityPicker() async {
    if (!Platform.isIOS) return false;
    return await _channel.invokeMethod<bool>('openFamilyActivityPicker') ??
        false;
  }

  @override
  Future<bool> hasSelection() async {
    if (!Platform.isIOS) return false;
    return await _channel.invokeMethod<bool>('hasSelection') ?? false;
  }

  @override
  Future<void> startDailyMonitoring() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('startDailyMonitoring');
  }

  @override
  Future<void> stopDailyMonitoring() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('stopDailyMonitoring');
  }

  @override
  Future<void> applyShield() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('applyShield');
  }

  @override
  Future<void> clearShield() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('clearShield');
  }

  @override
  Future<void> startFocusBlocking() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('startFocusBlocking');
  }

  @override
  Future<void> stopFocusBlocking() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('stopFocusBlocking');
  }

  @override
  Future<void> temporaryUnlock(Duration duration) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('temporaryUnlock', {
      'minutes': duration.inMinutes <= 0 ? 1 : duration.inMinutes,
    });
  }

  @override
  Future<void> restoreBlocking() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('restoreBlocking');
  }

  @override
  Future<void> configure(IOSFocusAppsSettings settings) async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('configure', {
      'enabled': settings.isEnabled,
      'dailyMode': settings.dailyMode.name,
      'dailyLimitMinutes': settings.dailyLimitMinutes,
      'focusModeBlockingEnabled': settings.focusModeBlockingEnabled,
      'breathingPauseSeconds': settings.breathingPauseSeconds,
      'temporaryUnlockMinutes': settings.temporaryUnlockMinutes,
    });
  }

  @override
  Future<IOSFocusAppsBlockingState> getBlockingState() async {
    if (!Platform.isIOS) return IOSFocusAppsBlockingState.inactive;
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'getBlockingState',
    );
    if (raw == null) return IOSFocusAppsBlockingState.inactive;
    return IOSFocusAppsBlockingState(
      isFocusModeActive: raw['focusModeActive'] == true,
      areAppsCurrentlyBlocked: raw['blocked'] == true,
      blockingReason: _blockingReason(raw['reason'] as String?),
      temporaryUnlockStartedAt: _date(raw['temporaryUnlockStartedAt']),
      temporaryUnlockEndsAt: _date(raw['temporaryUnlockEndsAt']),
      lastBlockedAppName: _string(raw['lastBlockedAppName']),
    );
  }

  BlockingReason _blockingReason(String? value) {
    return switch (value) {
      'dailyLimitReached' => BlockingReason.dailyLimitReached,
      'focusMode' => BlockingReason.focusMode,
      'manual' => BlockingReason.manual,
      _ => BlockingReason.none,
    };
  }

  DateTime? _date(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
