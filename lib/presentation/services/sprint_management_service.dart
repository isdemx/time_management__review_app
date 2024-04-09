import 'package:get_it/get_it.dart';
import 'package:time_tracker/presentation/blocs/sprint_cubit.dart';

class SprintManagementService {
  SprintCubit get _sprintCubit => GetIt.instance<SprintCubit>();

  void notifySprintFinished() {
    _sprintCubit.finishSprint();
  }

  void notifyTimerPaused() {
    print('notifyTimerPaused');
    _sprintCubit.addIdle();
  }
}
