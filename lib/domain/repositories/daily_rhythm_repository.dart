import 'package:time_tracker/domain/entities/day_session.dart';
import 'package:time_tracker/domain/entities/evening_reflection.dart';
import 'package:time_tracker/domain/entities/focus_session.dart';

abstract class DailyRhythmRepository {
  Future<DaySession?> getDaySessionByDate(DateTime date);
  Future<DaySession?> getDaySession(String id);
  Future<void> saveDaySession(DaySession daySession);
  Future<void> updateDaySession(DaySession daySession);

  Future<void> saveActivityEntry(ActivityEntry entry);
  Future<void> closeOpenActivityEntries(String daySessionId, DateTime endedAt);
  Future<List<ActivityEntry>> getActivityEntries(String daySessionId);

  Future<void> saveFocusSession(FocusSession focusSession);
  Future<void> updateFocusSession(FocusSession focusSession);
  Future<FocusSession?> getActiveFocusSession({
    String? daySessionId,
    required String activityId,
  });
  Future<bool> hasActiveFocusSession();

  Future<void> saveEveningReflection(EveningReflection reflection);
}
