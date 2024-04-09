import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/presentation/blocs/sprint_timer_cubit.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';

class ActivityTimerWidget extends StatelessWidget {
  final String activityId;

  const ActivityTimerWidget({Key? key, required this.activityId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SprintTimerCubit, SprintTimerState>(
      builder: (context, state) {
        Duration activityDuration = state.activityDurations[activityId] ?? Duration.zero;
        return Text(
          TimeFormatUtil.formatDuration(activityDuration),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        );
      },
    );
  }
}
