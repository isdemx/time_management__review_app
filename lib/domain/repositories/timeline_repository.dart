import 'package:time_tracker/domain/entities/time_segment.dart';

abstract class TimelineRepository {
  Future<void> saveSegment(TimeSegment segment);
  Future<void> updateSegment(TimeSegment segment);
  Future<void> deleteSegment(String id);
  Future<void> deleteSegmentsForSession(String sessionId);
  Future<TimeSegment?> getOpenSegment(String sessionId);
  Future<List<TimeSegment>> getSegments(String sessionId);
  Future<List<TimeSegment>> getSegmentsInRange({
    required String sessionId,
    required DateTime startAt,
    required DateTime endAt,
  });
}
