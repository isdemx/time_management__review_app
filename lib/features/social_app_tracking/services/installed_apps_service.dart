import 'dart:io';

import 'package:flutter/services.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/installed_external_app.dart';

class InstalledAppsService {
  static const MethodChannel _channel = MethodChannel(
    'chronika/social_app_tracking',
  );

  Future<List<InstalledExternalApp>> getInstalledApps() async {
    if (!Platform.isAndroid) {
      return const [];
    }
    final rawApps = await _channel.invokeMethod<List<dynamic>>(
          'getInstalledApps',
        ) ??
        const [];
    return rawApps
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (map) => InstalledExternalApp(
            packageName: map['packageName'] as String,
            appName: map['appName'] as String,
            iconPath: map['iconPath'] as String?,
          ),
        )
        .toList();
  }

  Future<String?> getForegroundAppPackageName() async {
    if (!Platform.isAndroid) {
      return null;
    }
    return _channel.invokeMethod<String>('getForegroundApp');
  }
}
