import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/presentation/blocs/activity_cubit.dart';
import 'package:time_tracker/domain/entities/activity.dart';

class ActivitiesListWidget extends StatelessWidget {
  const ActivitiesListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<ActivityCubit, ActivityState>(
            builder: (context, state) {
              if (state is ActivityLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ActivityLoaded) {
                return ListView.builder(
                  itemCount: state.activities.length,
                  itemBuilder: (context, index) {
                    final activity = state.activities[index];
                    return ListTile(
                      title: Text(activity.name),
                      // onTap: // TODO
                    );
                  },
                );
              } else if (state is ActivityError) {
                return Center(child: Text(state.message));
              }
              return const Center(child: Text('No activities found'));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: FloatingActionButton(
            onPressed: () => _showAddActivityDialog(context),
            tooltip: 'Add New Activity',
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
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
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final String name = controller.text.trim();
              if (name.isNotEmpty) {
                final String id = UniqueKey().toString();
                final Activity newActivity = Activity(
                    id: id,
                    name: name,
                    color: 'colorValue',
                    icon: 'iconValue',
                    isNotified: false);
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
