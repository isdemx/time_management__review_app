import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';
import 'package:time_tracker/presentation/widgets/activity_timer_widget.dart';
import 'package:uuid/uuid.dart';

class ActivitiesListWidget extends StatelessWidget {
  const ActivitiesListWidget({Key? key}) : super(key: key);

  void _onActivityTap(BuildContext context, Activity activity) {
    context.read<SprintCubit>().startOrAddActivity(activity);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<SprintCubit, SprintState>(
            builder: (context, sprintState) {
              final activeSprint = sprintState is SprintLoaded ? sprintState.sprint : null;
              print('activeSprint $activeSprint');

              return BlocBuilder<ActivityCubit, ActivityState>(
                builder: (context, state) {
                  if (state is ActivityLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is ActivityLoaded) {
                    if (state.activities.isEmpty) {
                      return const Center(child: Text('No activities found'));
                    }
                    String? lastActivityId = activeSprint?.timeLine.isNotEmpty == true
                        ? activeSprint?.timeLine.last.activityId
                        : null;

                    return ListView.builder(
                      itemCount: state.activities.length,
                      itemBuilder: (context, index) {
                        final activity = state.activities[index];
                        final activityColor = ColorUtils.fromHex(activity.color);
                        final bool isActive = activity.id == lastActivityId;

                        return Container(
                          padding: const EdgeInsets.all(8.0),
                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          decoration: BoxDecoration(
                            color: activityColor,
                            borderRadius: BorderRadius.circular(8.0),
                            border: isActive ? Border.all(color: Colors.blue, width: 2.0) : null,
                          ),
                          child: ListTile(
                            title: Text(activity.name),
                            subtitle: ActivityTimerWidget(activityId: activity.id),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => context.read<ActivityCubit>().archiveActivity(activity.id),
                            ),
                            onTap: () => _onActivityTap(context, activity),
                          ),
                        );
                      },
                    );
                  } else if (state is ActivityError) {
                    return Center(child: Text(state.message));
                  }
                  return const Center(child: Text('No activities found'));
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: () => _showAddActivityDialog(context),
            child: const Icon(Icons.add),
            tooltip: 'Add New Activity',
          ),
        ),
      ],
    );
  }

  void _showAddActivityDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Activity'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Activity name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final String name = controller.text.trim();
                if (name.isNotEmpty) {
                  final color = ColorUtils.generateRandomLightColor();
                  final hexColor = '#${color.value.toRadixString(16).substring(2)}';
                  final Activity newActivity = Activity(
                    id: const Uuid().v4(),
                    name: name,
                    color: hexColor,
                    icon: 'iconValue',
                    isNotified: false,
                  );
                  context.read<ActivityCubit>().addActivity(newActivity);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
