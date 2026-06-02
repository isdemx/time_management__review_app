import 'package:time_tracker/features/social_app_tracking/domain/entities/installed_external_app.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_day.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';
import 'package:time_tracker/features/social_app_tracking/domain/repositories/social_app_tracking_repository.dart';
import 'package:time_tracker/features/social_app_tracking/services/external_app_monitor_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/installed_apps_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/usage_access_permission_service.dart';

class GetInstalledAppsUseCase {
  final InstalledAppsService service;

  GetInstalledAppsUseCase(this.service);

  Future<List<InstalledExternalApp>> call() => service.getInstalledApps();
}

class CheckUsageAccessPermissionUseCase {
  final UsageAccessPermissionService service;

  CheckUsageAccessPermissionUseCase(this.service);

  Future<bool> call() => service.hasUsageAccess();
}

class OpenUsageAccessSettingsUseCase {
  final UsageAccessPermissionService service;

  OpenUsageAccessSettingsUseCase(this.service);

  Future<void> call() => service.openUsageAccessSettings();
}

class SaveTrackedExternalAppsUseCase {
  final SocialAppTrackingRepository repository;

  SaveTrackedExternalAppsUseCase(this.repository);

  Future<void> call(List<TrackedExternalApp> apps) async {
    for (final app in apps) {
      await repository.saveTrackedApp(app);
    }
  }
}

class GetTrackedExternalAppsUseCase {
  final SocialAppTrackingRepository repository;

  GetTrackedExternalAppsUseCase(this.repository);

  Future<List<TrackedExternalApp>> call({bool enabledOnly = false}) {
    return repository.getTrackedApps(enabledOnly: enabledOnly);
  }
}

class UpdateTrackedExternalAppUseCase {
  final SocialAppTrackingRepository repository;

  UpdateTrackedExternalAppUseCase(this.repository);

  Future<void> call(TrackedExternalApp app) => repository.updateTrackedApp(app);
}

class DeleteTrackedExternalAppUseCase {
  final SocialAppTrackingRepository repository;

  DeleteTrackedExternalAppUseCase(this.repository);

  Future<void> call(String id) => repository.deleteTrackedApp(id);
}

class HandleExternalAppOpenedUseCase {
  final ExternalAppMonitorService service;

  HandleExternalAppOpenedUseCase(this.service);

  Future<void> call() => service.restart();
}

class HandleExternalAppClosedUseCase {
  final ExternalAppMonitorService service;

  HandleExternalAppClosedUseCase(this.service);

  Future<void> call() => service.restart();
}

class GetExternalAppUsageForTodayUseCase {
  final SocialAppTrackingRepository repository;

  GetExternalAppUsageForTodayUseCase(this.repository);

  Future<ExternalAppUsageDay?> call(String packageName) {
    return repository.getUsageDay(
      packageName: packageName,
      date: DateTime.now(),
    );
  }
}

class SwitchToLinkedActivityUseCase {
  final ExternalAppMonitorService service;

  SwitchToLinkedActivityUseCase(this.service);

  Future<void> call(String packageName) {
    return service.switchToLinkedActivity(packageName);
  }
}
