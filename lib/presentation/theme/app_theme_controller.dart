import 'package:flutter/material.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController() : super(ThemeMode.dark);

  void setThemeMode(ThemeMode mode) {
    value = mode;
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    Key? key,
    required AppThemeController controller,
    required Widget child,
  }) : super(
          key: key,
          notifier: controller,
          child: child,
        );

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope not found in widget tree');
    return scope!.notifier!;
  }
}
