import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:time_tracker/data/datasources/local/local_actitvity_data_source.dart';
import 'package:time_tracker/data/repositories/activity_repository_impl.dart';
import 'package:time_tracker/domain/use_cases/activity/add_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/archive_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/get_all_activities.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_actitivty_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/archive_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/get_all_sprints.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';
import 'package:time_tracker/presentation/blocs/sprint_timer_cubit.dart';
import 'package:time_tracker/presentation/pages/home_page.dart';
import 'package:time_tracker/domain/use_cases/sprint/create_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_idle_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/finish_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/get_active_sprint.dart';
import 'package:time_tracker/data/repositories/sprint_repository_impl.dart';
import 'package:time_tracker/data/datasources/local/local_sprint_data_source.dart';

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

  // Database and repository initialization for Activity
  final localActivityDataSource = LocalActivityDataSource();
  final activityRepository =
      ActivityRepositoryImpl(localDataSource: localActivityDataSource);

  // Database and repository initialization for Sprint
  final localSprintDataSource = LocalSprintDataSource();
  final sprintRepository =
      SprintRepositoryImpl(localDataSource: localSprintDataSource);

  // Use Cases initialization for Activity
  final getAllActivities = GetAllActivities(activityRepository);
  final addActivity = AddActivity(activityRepository);
  final archiveActivity = ArchiveActivity(activityRepository);

  // Use Cases initialization for Sprint
  final createSprint = CreateSprint(sprintRepository);
  final addActivityToSprint = AddActivityToSprint(sprintRepository);
  final addIdleToSprint = AddIdleToSprint(sprintRepository);
  final finishSprint = FinishSprint(sprintRepository);
  final getActiveSprint = GetActiveSprint(sprintRepository);
  final getAllSprints = GetAllSprints(sprintRepository);
  final archiveSprint = ArchiveSprint(sprintRepository);

  final activityCubit = ActivityCubit(
    getAllActivities: getAllActivities,
    addActivityUseCase: addActivity,
    archiveActivityUseCase: archiveActivity,
  );

  // Create SprintCubit
  final sprintCubit = SprintCubit(
      createSprint: createSprint,
      addActivityToSprint: addActivityToSprint,
      addIdleToSprint: addIdleToSprint,
      finishSprint: finishSprint,
      getActiveSprint: getActiveSprint,
      getAllSprints: getAllSprints,
      archiveSprint: archiveSprint);

  // Create SprintTimerCubit
  final sprintTimerCubit = SprintTimerCubit(sprintCubit: sprintCubit);

  runApp(MultiBlocProvider(
    providers: [
      BlocProvider<ActivityCubit>(
        create: (context) => activityCubit,
      ),
      BlocProvider<SprintCubit>(
        create: (context) => sprintCubit,
      ),
      BlocProvider<SprintTimerCubit>(
        create: (context) => sprintTimerCubit,
      ),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: BlocProvider.of<ActivityCubit>(context),
        ),
        BlocProvider.value(
          value: BlocProvider.of<SprintCubit>(context),
        ),
        BlocProvider.value(
          value: BlocProvider.of<SprintTimerCubit>(context),
        ),
      ],
      child: MaterialApp(
        title: 'Time Management Reviewer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
