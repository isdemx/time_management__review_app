import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/repositories/session_v2_repository_impl.dart';
import 'package:time_tracker/data/repositories/timeline_repository_impl.dart';
import 'package:time_tracker/data/repositories/trackable_repository_impl.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/pages/home_page.dart';
import 'package:time_tracker/presentation/theme/app_theme_controller.dart';
import 'package:time_tracker/presentation/theme/chronika_theme.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  // setupLocator();
  WidgetsFlutterBinding.ensureInitialized();

  var initializationSettingsAndroid =
      const AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializationSettingsIOS = const DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  var initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final appDatabase = AppDatabase();
  final sessionV2Repository = SessionV2RepositoryImpl(appDatabase: appDatabase);
  final trackableRepository = TrackableRepositoryImpl(appDatabase: appDatabase);
  final timelineRepository = TimelineRepositoryImpl(appDatabase: appDatabase);
  final themeController = AppThemeController();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SessionV2Repository>.value(
          value: sessionV2Repository,
        ),
        RepositoryProvider<TrackableRepository>.value(
          value: trackableRepository,
        ),
        RepositoryProvider<TimelineRepository>.value(
          value: timelineRepository,
        ),
      ],
      child: AppThemeScope(
        controller: themeController,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeController = AppThemeScope.of(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Chronika',
          theme: ChronikaTheme.light(),
          darkTheme: ChronikaTheme.dark(),
          themeMode: themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
