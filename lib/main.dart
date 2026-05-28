import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_platform.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_service.dart';
import 'package:time_tracker/application/templates/template_seed_service.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/repositories/session_v2_repository_impl.dart';
import 'package:time_tracker/data/repositories/timeline_repository_impl.dart';
import 'package:time_tracker/data/repositories/trackable_repository_impl.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/infrastructure/active_session_bar/flutter_local_notifications_active_session_bar_platform.dart';
import 'package:time_tracker/infrastructure/active_session_bar/live_activities_active_session_bar_platform.dart';
import 'package:time_tracker/presentation/navigation/app_navigator.dart';
import 'package:time_tracker/presentation/pages/home_page.dart';
import 'package:time_tracker/presentation/theme/app_theme_controller.dart';
import 'package:time_tracker/presentation/theme/chronika_theme.dart';

void main() async {
  // setupLocator();
  WidgetsFlutterBinding.ensureInitialized();

  final appDatabase = AppDatabase();
  final sessionV2Repository = SessionV2RepositoryImpl(appDatabase: appDatabase);
  final trackableRepository = TrackableRepositoryImpl(appDatabase: appDatabase);
  final timelineRepository = TimelineRepositoryImpl(appDatabase: appDatabase);
  await TemplateSeedService(
    appDatabase: appDatabase,
  ).seedDefaultTemplatesIfNeeded();
  final themeController = AppThemeController();
  final activeSessionBarService = ActiveSessionBarService(
    platform: _activeSessionBarPlatform(),
  );
  await activeSessionBarService.initialize();
  activeSessionBarService.commands.listen(
    AppNavigator.handleActiveSessionBarCommand,
  );

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
        RepositoryProvider<ActiveSessionBarService>.value(
          value: activeSessionBarService,
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
    return MaterialApp(
      title: 'Chronika',
      theme: ChronikaTheme.dark(),
      darkTheme: ChronikaTheme.dark(),
      themeMode: ThemeMode.dark,
      navigatorKey: AppNavigator.navigatorKey,
      home: const HomePage(),
    );
  }
}

ActiveSessionBarPlatform _activeSessionBarPlatform() {
  if (Platform.isAndroid) {
    return FlutterLocalNotificationsActiveSessionBarPlatform(
      plugin: FlutterLocalNotificationsPlugin(),
    );
  }
  if (Platform.isIOS) {
    return LiveActivitiesActiveSessionBarPlatform(
      liveActivities: LiveActivities(),
    );
  }
  return NoopActiveSessionBarPlatform();
}
