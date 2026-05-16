import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';

abstract class TrackableRepository {
  Future<void> saveTrackable(Trackable trackable);
  Future<void> updateTrackable(Trackable trackable);
  Future<Trackable?> getTrackable(String id);
  Future<List<Trackable>> getTrackables({bool includeArchived = false});

  Future<void> saveMode(TrackableMode mode);
  Future<void> updateMode(TrackableMode mode);
  Future<List<TrackableMode>> getModes(
    String trackableId, {
    bool includeArchived = false,
  });
}
