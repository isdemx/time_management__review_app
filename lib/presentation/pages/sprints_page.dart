import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';
import 'package:time_tracker/presentation/utils/color_helpers.dart';

class SprintsPage extends StatelessWidget {
  const SprintsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.read<SprintCubit>().loadAllSprints();
    return BlocBuilder<SprintCubit, SprintState>(
      builder: (context, state) {
        if (state is SprintLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is SprintsLoaded) {
          Duration maxDuration = (state.allSprints.isNotEmpty)
              ? state.allSprints
                  .map((s) =>
                      s.endTime?.difference(s.startTime) ?? Duration.zero)
                  .reduce((a, b) => a > b ? a : b)
              : Duration.zero;

          return ListView.builder(
            itemCount: state.allSprints.length,
            itemBuilder: (context, index) {
              var sprint = state.allSprints[index];
              Duration duration =
                  sprint.endTime?.difference(sprint.startTime) ?? Duration.zero;
              Color bgColor =
                  ColorHelpers.getSprintColor(duration, maxDuration);
              return Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('id ${sprint.id}'),
                      Text(
                          'Started: ${DateFormat('dd/MM/yy HH:mm').format(sprint.startTime)}'),
                      Text((sprint.endTime != null)
                          ? 'Finished: ${DateFormat('dd/MM/yy HH:mm').format(sprint.endTime!)}'
                          : 'Ongoing'),
                    ],
                  ),
                  subtitle: Text('Duration: ${duration.inMinutes} minutes'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      context.read<SprintCubit>().deleteSprint(sprint.id);
                    },
                  ),
                ),
              );
            },
          );
        } else if (state is SprintError) {
          return Center(child: Text(state.message));
        }
        return const Center(child: Text('No sprints found'));
      },
    );
  }
}
