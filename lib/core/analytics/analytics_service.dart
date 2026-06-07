import 'package:flutter/foundation.dart';

import 'package:time_tracker/core/analytics/amplitude_service.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';
import 'package:time_tracker/core/analytics/appsflyer_service.dart';

class AnalyticsService {
  final AppsFlyerService? appsFlyerService;
  final AmplitudeService? amplitudeService;

  const AnalyticsService({
    this.appsFlyerService,
    this.amplitudeService,
  });

  Future<void> track(
    AnalyticsEvent event, {
    Map<String, dynamic>? properties,
  }) async {
    final normalizedProperties = properties ?? const <String, dynamic>{};
    if (kDebugMode) {
      debugPrint(
        'Analytics event: ${event.eventName} $normalizedProperties',
      );
    }

    await Future.wait([
      if (appsFlyerService != null)
        appsFlyerService!.logEvent(event.eventName, normalizedProperties),
      if (amplitudeService != null)
        amplitudeService!.logEvent(event.eventName, normalizedProperties),
    ]);
  }

  Future<void> setUserId(String? userId) async {
    if (kDebugMode) {
      debugPrint('Analytics user id: $userId');
    }
    await Future.wait([
      if (appsFlyerService != null) appsFlyerService!.setCustomerUserId(userId),
      if (amplitudeService != null) amplitudeService!.setUserId(userId),
    ]);
  }

  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    if (kDebugMode) {
      debugPrint('Analytics user properties: $properties');
    }
    await Future.wait([
      if (amplitudeService != null)
        amplitudeService!.setUserProperties(properties),
    ]);
  }
}
