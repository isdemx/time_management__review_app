import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class AppGroupDirectory {
  static const _channel =
      MethodChannel('me.wolszon.app_group_directory/channel');

  /// Returns the container directory associated with the specified security
  /// application group identifier [groupId].
  ///
  /// Returns null if the app group does not exist or there is no access to it.
  /// Android does not support iOS app group directories and returns null.
  static Future<Directory?> getAppGroupDirectory(String groupId) async {
    final path =
        await _channel.invokeMethod<String>('getAppGroupDirectory', groupId);

    if (path == null) {
      return null;
    }

    return Directory(path);
  }
}
