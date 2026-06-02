import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_day.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_session.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';

abstract class SocialAppTrackingRepository {
  Future<void> saveTrackedApp(TrackedExternalApp app);
  Future<void> updateTrackedApp(TrackedExternalApp app);
  Future<void> deleteTrackedApp(String id);
  Future<TrackedExternalApp?> getTrackedAppByPackage(String packageName);
  Future<List<TrackedExternalApp>> getTrackedApps({bool enabledOnly = false});

  Future<ExternalAppUsageDay?> getUsageDay({
    required String packageName,
    required DateTime date,
  });
  Future<List<ExternalAppUsageDay>> getUsageForDate(DateTime date);
  Future<void> upsertUsageDay(ExternalAppUsageDay usage);

  Future<void> saveUsageSession(ExternalAppUsageSession session);
  Future<void> updateUsageSession(ExternalAppUsageSession session);
  Future<ExternalAppUsageSession?> getOpenUsageSession(String packageName);
}
