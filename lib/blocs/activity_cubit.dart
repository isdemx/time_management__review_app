// activity_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

// activity_state.dart
class ActivityState {
  final int? activeId;
  ActivityState({this.activeId});
}


class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit() : super(ActivityState());

  void setActive(int id) {
    emit(ActivityState(activeId: id));
  }

  void clearActive() {
    emit(ActivityState());
  }
}
