import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/blocs/activity_cubit.dart';
import 'package:time_tracker/models/activity.dart';

class ActivityWidget extends StatelessWidget {
  final Activity activity;
  final Stream<ActivityStatus> activityStatusStream;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const ActivityWidget({
    Key? key,
    required this.activity,
    required this.activityStatusStream,
    required this.onSelect,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityCubit, ActivityState>(
      builder: (context, state) {
        print('isActive ${state.activeId} ${activity.id}');
        final isActive = state.activeId == activity.id;
        return StreamBuilder<ActivityStatus>(
          stream: activityStatusStream,
          builder: (context, snapshot) {
            final status = snapshot.data ??
                ActivityStatus(
                    timeSpent: Duration.zero, isActive: false, percents: null);
            return InkWell(
              onTap: onSelect,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                margin:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  color: activity.color.withOpacity(isActive ? 0.5 : 1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: isActive
                      ? Border.all(color: Colors.black, width: 2.0)
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(activity.name),
                    const Spacer(),
                    Text(_formatDuration(status.timeSpent)),
                    if (status.percents != null)
                      Text(': ' + status.percents!.toStringAsFixed(2) + '%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
