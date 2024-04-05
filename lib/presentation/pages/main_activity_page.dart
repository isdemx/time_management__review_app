import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';
import 'package:time_tracker/presentation/widgets/activities_list_widget.dart';

class MainActivityPage extends StatelessWidget {
  const MainActivityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Activity Page'),
      ),
      body: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: BlocProvider.of<ActivityCubit>(context),
          ),
          BlocProvider.value(
            value: BlocProvider.of<SprintCubit>(context),
          ),
        ],
        child: const ActivitiesListWidget(),
      ),
    );
  }
}
