import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

class AppsFlyerService {
  static const _devKey = 'ncZSXXnCgmYHfHQKbNGLCB';

  static const _iosAppId = String.fromEnvironment(
    'APPSFLYER_IOS_APP_ID',
    defaultValue: '6480464069',
  );

  AppsflyerSdk? _sdk;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    if (Platform.isIOS && _iosAppId.isEmpty) {
      _warn('AppsFlyer iOS App ID is not configured.');
      return;
    }

    try {
      final options = AppsFlyerOptions(
        afDevKey: _devKey,
        appId: Platform.isIOS ? _iosAppId : '',
        showDebug: kDebugMode,
      );
      final sdk = AppsflyerSdk(options);
      _sdk = sdk;
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      _initialized = true;
      if (kDebugMode) {
        debugPrint('AppsFlyer initialized');
      }
    } catch (error, stackTrace) {
      _warn('AppsFlyer init failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> logEvent(
    String name, [
    Map<String, dynamic> params = const {},
  ]) async {
    final sdk = _sdk;
    if (!_initialized || sdk == null) {
      if (kDebugMode) {
        debugPrint('AppsFlyer skipped event "$name": SDK is not initialized');
      }
      return;
    }

    try {
      await sdk.logEvent(name, params);
      if (kDebugMode) {
        debugPrint('AppsFlyer event: $name $params');
      }
    } catch (error, stackTrace) {
      _warn('AppsFlyer event "$name" failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> setCustomerUserId(String? userId) async {
    final sdk = _sdk;
    if (!_initialized || sdk == null || userId == null || userId.isEmpty) {
      return;
    }
    try {
      sdk.setCustomerUserId(userId);
      if (kDebugMode) {
        debugPrint('AppsFlyer customer user id set: $userId');
      }
    } catch (error, stackTrace) {
      _warn('AppsFlyer setCustomerUserId failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void _warn(String message) {
    debugPrint('Warning: $message');
  }
}
