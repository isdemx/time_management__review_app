// activity_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

// activity_state.dart
class ActivityStateOld {
  final int? activeId;
  ActivityStateOld({this.activeId});
}


class ActivityCubit extends Cubit<ActivityStateOld> {
  ActivityCubit() : super(ActivityStateOld());

  void setActive(int id) {
    emit(ActivityStateOld(activeId: id));
  }

  void clearActive() {
    emit(ActivityStateOld());
  }
}
