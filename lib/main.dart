import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/data/datasources/local/local_actitvity_data_source.dart';
import 'package:time_tracker/data/repositories/activity_repository_impl.dart';
import 'package:time_tracker/domain/use_cases/activity/add_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/get_all_activities.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/presentation/pages/main_activity_page.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
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

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Создаем экземпляры зависимостей
    final LocalActivityDataSource localActivityDataSource = LocalActivityDataSource();
    final ActivityRepositoryImpl activityRepository = ActivityRepositoryImpl(localDataSource: localActivityDataSource);
    
    return MultiProvider(
      providers: [
        BlocProvider<ActivityCubit>(
          create: (context) => ActivityCubit(
            getAllActivities: GetAllActivities(activityRepository),
            addActivityUseCase: AddActivity(activityRepository),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Time Management Reviewer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainActivityPage(),
      ),
    );
  }
}
