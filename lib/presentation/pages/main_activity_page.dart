import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/use_cases/activity/add_activity.dart';
import 'package:time_tracker/domain/use_cases/activity/get_all_activities.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/presentation/widgets/activities_list_widget.dart';

class MainActivityPage extends StatelessWidget {
  const MainActivityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Предполагается, что GetAllActivities и AddActivity уже предоставлены через провайдер или инъекцию зависимостей
    final getAllActivities = context.read<GetAllActivities>();
    final addActivityUseCase = context.read<AddActivity>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Activity Page'),
      ),
      body: BlocProvider<ActivityCubit>(
        create: (context) => ActivityCubit(
          getAllActivities: getAllActivities,
          addActivityUseCase: addActivityUseCase,
        ),
        child: const ActivitiesListWidget(),
      ),
    );
  }
}
