import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/domain/entities/activity.dart';
import 'package:time_tracker/domain/entities/sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_actitivty_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/add_idle_to_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/archive_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/create_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/finish_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/get_active_sprint.dart';
import 'package:time_tracker/domain/use_cases/sprint/get_all_sprints.dart';
import 'package:uuid/uuid.dart';

part 'sprint_state.dart';

class SprintCubit extends Cubit<SprintState> {
  final CreateSprint _createSprint;
  final AddActivityToSprint _addActivityToSprint;
  final AddIdleToSprint _addIdleToSprint;
  final FinishSprint _finishSprint;
  final GetActiveSprint _getActiveSprint;
  final GetAllSprints _getAllSprints;
  final ArchiveSprint _archiveSprint;

  SprintCubit(
      {required CreateSprint createSprint,
      required AddActivityToSprint addActivityToSprint,
      required AddIdleToSprint addIdleToSprint,
      required FinishSprint finishSprint,
      required GetActiveSprint getActiveSprint,
      required GetAllSprints getAllSprints,
      required ArchiveSprint archiveSprint})
      : _createSprint = createSprint,
        _addActivityToSprint = addActivityToSprint,
        _addIdleToSprint = addIdleToSprint,
        _finishSprint = finishSprint,
        _getActiveSprint = getActiveSprint,
        _getAllSprints = getAllSprints,
        _archiveSprint = archiveSprint,
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
    print('CREATE NEW SPRINT!!!');
    final String sprintId = const Uuid().v4();
    final Sprint newSprint = Sprint(
      id: sprintId,
      startTime: DateTime.now(),
      isActive: true,
    );

    await _createSprint(newSprint);
    return newSprint;
  }

  Future<void> _reloadActiveSprint() async {
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
      await _addActivityToSprint(
          (state as SprintLoaded).sprint.id, activity.id);
      await _reloadActiveSprint();
    } else {
      var activeSprint = await _getActiveSprint();
      if (activeSprint == null) {
        Sprint newSprint = await _createNewSprint();
        await _addActivityToSprint(newSprint.id, activity.id);
      }
      await _reloadActiveSprint();
    }
  }

  void addIdle() async {
    if (state is SprintLoaded) {
      await _addIdleToSprint((state as SprintLoaded).sprint.id);
      await _reloadActiveSprint();
    }
  }

  void finishSprint() async {
    if (state is SprintLoaded) {
      await _finishSprint((state as SprintLoaded).sprint.id);
      emit(SprintInitial());
    }
  }

  Future<void> loadAllSprints() async {
    emit(SprintLoading());
    try {
      final sprints = await _getAllSprints();
      ;
      if (sprints != null && sprints.isNotEmpty) {
        emit(SprintsLoaded(sprints));
      } else {
        emit(SprintError("No sprints found"));
      }
    } catch (e) {
      emit(SprintError("Failed to load sprints"));
    }
  }

  Future<void> loadActiveSprint() async {
    await _reloadActiveSprint();
  }

  Future<void> deleteSprint(String sprintId) async {
    await _archiveSprint(sprintId);
    loadAllSprints();
  }
}
