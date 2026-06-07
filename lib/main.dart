import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_platform.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_service.dart';
import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/application/onboarding/onboarding_service.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';
import 'package:time_tracker/application/templates/template_seed_service.dart';
import 'package:time_tracker/core/analytics/amplitude_service.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';
import 'package:time_tracker/core/analytics/analytics_service.dart';
import 'package:time_tracker/core/analytics/appsflyer_service.dart';
import 'package:time_tracker/core/payments/apphud_service.dart';
import 'package:time_tracker/data/database/app_database.dart';
import 'package:time_tracker/data/repositories/daily_rhythm_repository_impl.dart';
import 'package:time_tracker/data/repositories/session_v2_repository_impl.dart';
import 'package:time_tracker/data/repositories/timeline_repository_impl.dart';
import 'package:time_tracker/data/repositories/trackable_repository_impl.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_focus_apps_settings_service.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_screen_time_service.dart';
import 'package:time_tracker/features/social_app_tracking/data/repositories/social_app_tracking_repository_impl.dart';
import 'package:time_tracker/features/social_app_tracking/domain/repositories/social_app_tracking_repository.dart';
import 'package:time_tracker/features/social_app_tracking/services/external_app_monitor_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/installed_apps_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/social_app_notification_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/usage_access_permission_service.dart';
import 'package:time_tracker/infrastructure/active_session_bar/flutter_local_notifications_active_session_bar_platform.dart';
import 'package:time_tracker/infrastructure/active_session_bar/live_activities_active_session_bar_platform.dart';
import 'package:time_tracker/presentation/navigation/app_navigator.dart';
import 'package:time_tracker/presentation/onboarding/app_launch_gate.dart';
import 'package:time_tracker/presentation/theme/app_theme_controller.dart';
import 'package:time_tracker/presentation/theme/chronika_theme.dart';

void main() async {
  // setupLocator();
  WidgetsFlutterBinding.ensureInitialized();
  final appsFlyerService = AppsFlyerService();
  try {
    await appsFlyerService.init();
  } catch (error) {
    debugPrint('Warning: AppsFlyer startup failed: $error');
  }
  final amplitudeService = AmplitudeService();
  try {
    await amplitudeService.init();
  } catch (error) {
    debugPrint('Warning: Amplitude startup failed: $error');
  }
  final analyticsService = AnalyticsService(
    appsFlyerService: appsFlyerService,
    amplitudeService: amplitudeService,
  );
  try {
    await analyticsService.track(
      AnalyticsEvent.appOpened,
      properties: const {AnalyticsProperties.source: 'cold_start'},
    );
  } catch (error) {
    debugPrint('Warning: Analytics app_opened failed: $error');
  }
  final apphudService = ApphudService();
  try {
    await apphudService.init();
    final premium = await apphudService.syncPurchases();
    await analyticsService.setUserProperties(
      {AnalyticsUserProperties.premium: premium},
    );
  } catch (error) {
    debugPrint('Warning: Apphud startup failed: $error');
  }

  final appDatabase = AppDatabase();
  final sessionV2Repository = SessionV2RepositoryImpl(appDatabase: appDatabase);
  final trackableRepository = TrackableRepositoryImpl(appDatabase: appDatabase);
  final timelineRepository = TimelineRepositoryImpl(appDatabase: appDatabase);
  final dailyRhythmRepository = DailyRhythmRepositoryImpl(
    appDatabase: appDatabase,
  );
  final socialAppTrackingRepository = SocialAppTrackingRepositoryImpl(
    appDatabase: appDatabase,
  );
  await TemplateSeedService(
    appDatabase: appDatabase,
  ).seedDefaultTemplatesIfNeeded();
  final themeController = AppThemeController();
  final onboardingService = OnboardingService(
    analyticsService: analyticsService,
  );
  final paywallService = PaywallService(
    apphudService: apphudService,
    analyticsService: analyticsService,
  );
  final iosScreenTimeService = MethodChannelIOSScreenTimeService();
  final iosFocusAppsSettingsService = IOSFocusAppsSettingsService();
  final activeSessionBarService = ActiveSessionBarService(
    platform: _activeSessionBarPlatform(),
  );
  final dailyRhythmNotificationService = DailyRhythmNotificationService(
    plugin: FlutterLocalNotificationsPlugin(),
    dailyRhythmRepository: dailyRhythmRepository,
    sessionRepository: sessionV2Repository,
    timelineRepository: timelineRepository,
    trackableRepository: trackableRepository,
  );
  final usageAccessPermissionService = UsageAccessPermissionService();
  final installedAppsService = InstalledAppsService();
  final socialAppNotificationService = SocialAppNotificationService(
    plugin: FlutterLocalNotificationsPlugin(),
  );
  final externalAppMonitorService = ExternalAppMonitorService(
    installedAppsService: installedAppsService,
    permissionService: usageAccessPermissionService,
    trackingRepository: socialAppTrackingRepository,
    notificationService: socialAppNotificationService,
    sessionRepository: sessionV2Repository,
    timelineRepository: timelineRepository,
    trackableRepository: trackableRepository,
  );
  await activeSessionBarService.initialize();
  await dailyRhythmNotificationService.initialize(
    onPayload: (payload) {
      AppNavigator.handleDailyRhythmPayload(payload);
    },
  );
  await dailyRhythmNotificationService.scheduleDailyRhythmNotifications();
  await socialAppNotificationService.initialize(
    onPayload: (payload) async {
      final sessionId =
          await externalAppMonitorService.handleNotificationPayload(
        payload,
      );
      if (sessionId != null) {
        AppNavigator.openSession(sessionId);
      }
    },
  );
  await externalAppMonitorService.startIfEnabled();
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
        RepositoryProvider<DailyRhythmRepository>.value(
          value: dailyRhythmRepository,
        ),
        RepositoryProvider<SocialAppTrackingRepository>.value(
          value: socialAppTrackingRepository,
        ),
        RepositoryProvider<ActiveSessionBarService>.value(
          value: activeSessionBarService,
        ),
        RepositoryProvider<DailyRhythmNotificationService>.value(
          value: dailyRhythmNotificationService,
        ),
        RepositoryProvider<OnboardingService>.value(
          value: onboardingService,
        ),
        RepositoryProvider<PaywallService>.value(
          value: paywallService,
        ),
        RepositoryProvider<AppsFlyerService>.value(
          value: appsFlyerService,
        ),
        RepositoryProvider<AmplitudeService>.value(
          value: amplitudeService,
        ),
        RepositoryProvider<AnalyticsService>.value(
          value: analyticsService,
        ),
        RepositoryProvider<IOSScreenTimeService>.value(
          value: iosScreenTimeService,
        ),
        RepositoryProvider<IOSFocusAppsSettingsService>.value(
          value: iosFocusAppsSettingsService,
        ),
        RepositoryProvider<UsageAccessPermissionService>.value(
          value: usageAccessPermissionService,
        ),
        RepositoryProvider<InstalledAppsService>.value(
          value: installedAppsService,
        ),
        RepositoryProvider<SocialAppNotificationService>.value(
          value: socialAppNotificationService,
        ),
        RepositoryProvider<ExternalAppMonitorService>.value(
          value: externalAppMonitorService,
        ),
      ],
      child: AppThemeScope(
        controller: themeController,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNavigator.openPendingDailyRhythmPayload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chronika',
      theme: ChronikaTheme.dark(),
      darkTheme: ChronikaTheme.dark(),
      themeMode: ThemeMode.dark,
      navigatorKey: AppNavigator.navigatorKey,
      home: const AppLaunchGate(),
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
