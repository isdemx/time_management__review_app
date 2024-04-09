import 'package:get_it/get_it.dart';
import 'package:time_tracker/presentation/services/sprint_management_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton(() => SprintManagementService());
}
