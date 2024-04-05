import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:time_tracker/data/datasources/local/local_actitvity_data_source.dart';
import 'package:time_tracker/data/repositories/activity_repository_impl.dart';
import 'package:time_tracker/domain/use_cases/activity/add_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/archive_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/get_all_activities.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_actitivty_to_sprint.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';
import 'package:time_tracker/presentation/pages/main_activity_page.dart';
import 'package:time_tracker/domain/use_cases/sprint/create_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_idle_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/finish_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/get_active_sprint.dart';
import 'package:time_tracker/data/repositories/sprint_repository_impl.dart';
import 'package:time_tracker/data/datasources/local/local_sprint_data_source.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация уведомлений
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

  // Инициализация базы данных и репозитория для Activity
  final localActivityDataSource = LocalActivityDataSource();
  final activityRepository = ActivityRepositoryImpl(localDataSource: localActivityDataSource);

  // Инициализация базы данных и репозитория для Sprint
  final localSprintDataSource = LocalSprintDataSource();
  final sprintRepository = SprintRepositoryImpl(localDataSource: localSprintDataSource);

  // Инициализация Use Cases для Activity
  final getAllActivities = GetAllActivities(activityRepository);
  final addActivity = AddActivity(activityRepository);
  final archiveActivity = ArchiveActivity(activityRepository);

  // Инициализация Use Cases для Sprint
  final createSprint = CreateSprint(sprintRepository);
  final addActivityToSprint = AddActivityToSprint(sprintRepository);
  final addIdleToSprint = AddIdleToSprint(sprintRepository);
  final finishSprint = FinishSprint(sprintRepository);
  final getActiveSprint = GetActiveSprint(sprintRepository);

  runApp(MultiBlocProvider(
    providers: [
      BlocProvider<ActivityCubit>(
        create: (context) => ActivityCubit(
          getAllActivities: getAllActivities,
          addActivityUseCase: addActivity,
          archiveActivityUseCase: archiveActivity,
        ),
      ),
      BlocProvider<SprintCubit>(
        create: (context) => SprintCubit(
          createSprint: createSprint,
          addActivityToSprint: addActivityToSprint,
          addIdleToSprint: addIdleToSprint,
          finishSprint: finishSprint,
          getActiveSprint: getActiveSprint,
        ),
      ),
    ],
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Time Management Reviewer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainActivityPage(),
    );
  }
}
