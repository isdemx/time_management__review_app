import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/constants.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:flutter/foundation.dart';

class AmplitudeService {
  static const _apiKey = '3456cab2dfb8d1a6622cf568c92710d2';

  Amplitude? _amplitude;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    try {
      final amplitude = Amplitude(
        Configuration(
          apiKey: _apiKey,
          serverZone: ServerZone.eu,
        ),
      );
      final built = await amplitude.isBuilt;
      _amplitude = amplitude;
      _initialized = built;
      if (kDebugMode) {
        debugPrint(
          built
              ? 'Amplitude initialized'
              : 'Warning: Amplitude initialization returned false',
        );
      }
    } catch (error, stackTrace) {
      _warn('Amplitude init failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> setUserId(String? userId) async {
    final amplitude = _amplitude;
    if (!_initialized || amplitude == null) {
      return;
    }
    try {
      await amplitude.setUserId(userId);
      if (kDebugMode) {
        debugPrint('Amplitude user id set: $userId');
      }
    } catch (error, stackTrace) {
      _warn('Amplitude setUserId failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> logEvent(
    String name, [
    Map<String, Object?> params = const {},
  ]) async {
    final amplitude = _amplitude;
    if (!_initialized || amplitude == null) {
      if (kDebugMode) {
        debugPrint('Amplitude skipped event "$name": SDK is not initialized');
      }
      return;
    }

    try {
      await amplitude.track(
        BaseEvent(
          name,
          eventProperties: Map<String, dynamic>.from(params),
        ),
      );
      if (kDebugMode) {
        debugPrint('Amplitude event: $name $params');
      }
    } catch (error, stackTrace) {
      _warn('Amplitude event "$name" failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> setUserProperties(Map<String, Object?> properties) async {
    final amplitude = _amplitude;
    if (!_initialized || amplitude == null || properties.isEmpty) {
      return;
    }
    try {
      final identify = Identify();
      for (final entry in properties.entries) {
        identify.set(entry.key, entry.value);
      }
      await amplitude.identify(identify);
      if (kDebugMode) {
        debugPrint('Amplitude user properties: $properties');
      }
    } catch (error, stackTrace) {
      _warn('Amplitude setUserProperties failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void _warn(String message) {
    debugPrint('Warning: $message');
  }
}
