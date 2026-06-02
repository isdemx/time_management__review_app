import 'dart:io';

import 'package:flutter/services.dart';

class UsageAccessPermissionService {
  static const MethodChannel _channel = MethodChannel(
    'chronika/social_app_tracking',
  );

  Future<bool> hasUsageAccess() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
  }

  Future<void> openUsageAccessSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }
}
