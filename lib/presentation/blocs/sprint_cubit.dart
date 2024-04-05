import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_actitivty_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_idle_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/create_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/finish_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/get_active_sprint.dart';
import 'package:uuid/uuid.dart';

part 'sprint_state.dart';

class SprintCubit extends Cubit<SprintState> {
  final CreateSprint _createSprint;
  final AddActivityToSprint _addActivityToSprint;
  final AddIdleToSprint _addIdleToSprint;
  final FinishSprint _finishSprint;
  final GetActiveSprint _getActiveSprint;

  SprintCubit({
    required CreateSprint createSprint,
    required AddActivityToSprint addActivityToSprint,
    required AddIdleToSprint addIdleToSprint,
    required FinishSprint finishSprint,
    required GetActiveSprint getActiveSprint,
  })  : _createSprint = createSprint,
        _addActivityToSprint = addActivityToSprint,
        _addIdleToSprint = addIdleToSprint,
        _finishSprint = finishSprint,
        _getActiveSprint = getActiveSprint,
        super(SprintInitial()) {
    _initSprint();
  }

  void _initSprint() async {
    emit(SprintLoading());
    try {
      final activeSprint = await _getActiveSprint();
      if (activeSprint != null) {
        emit(SprintLoaded(activeSprint));
      } else {
        emit(SprintInitial());
      }
    } catch (e) {
      emit(SprintError("Failed to load active sprint"));
    }
  }

  Future<Sprint> _createNewSprint() async {
    final String sprintId = const Uuid().v4(); // Генерация ID спринта.
    final Sprint newSprint = Sprint(
      id: sprintId,
      startTime: DateTime.now(),
      isActive: true,
    );

    await _createSprint(newSprint);
    return newSprint;
  }

  void _reloadActiveSprint() async {
    try {
      final activeSprint = await _getActiveSprint();
      if (activeSprint != null) {
        emit(SprintLoaded(activeSprint));
      } else {
        emit(SprintInitial());
      }
    } catch (e) {
      emit(SprintError("Failed to reload active sprint"));
    }
  }

  void startOrAddActivity(Activity activity) async {
    if (state is SprintLoaded) {
      print('start activitty, loaded');
      await _addActivityToSprint(
          (state as SprintLoaded).sprint.id, activity.id);
      _reloadActiveSprint();
    } else {
      print('start activitty, not loaded');
      Sprint newSprint = await _createNewSprint();

      await _addActivityToSprint(newSprint.id, activity.id);
      emit(SprintLoaded(newSprint));
    }
  }

  void addIdle() async {
    if (state is SprintLoaded) {
      await _addIdleToSprint((state as SprintLoaded).sprint.id);
      // Обновление состояния может потребовать дополнительного вызова, если UI должен отразить этот факт
    }
  }

  void finishSprint() async {
    if (state is SprintLoaded) {
      await _finishSprint((state as SprintLoaded).sprint.id);
      emit(SprintInitial());
      // Возвращаем состояние в исходное, предполагая что спринт завершён
    }
  }
}
