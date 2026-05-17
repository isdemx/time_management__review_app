part of 'session_detail_bloc.dart';

abstract class SessionDetailState {
  const SessionDetailState();
}

class SessionDetailInitial extends SessionDetailState {
  const SessionDetailInitial();
}

class SessionDetailLoading extends SessionDetailState {
  const SessionDetailLoading();
}

class SessionDetailLoaded extends SessionDetailState {
  final Session session;
  final List<SessionTrackable> sessionTrackables;
  final List<Trackable> trackables;
  final Map<String, List<TrackableMode>> modesByTrackable;
  final List<TimeSegment> segments;
  final DateTime now;

  const SessionDetailLoaded({
    required this.session,
    required this.sessionTrackables,
    required this.trackables,
    required this.modesByTrackable,
    required this.segments,
    required this.now,
  });

  TimeSegment? get openSegment {
    for (final segment in segments.reversed) {
      if (segment.isOpen) {
        return segment;
      }
    }
    return null;
  }

  String? get activeTrackableId => openSegment?.trackableId;
  String? get activeModeId => openSegment?.modeId;

  Duration durationForTrackable(String trackableId) {
    return segments
        .where(
          (segment) => !segment.isPause && segment.trackableId == trackableId,
        )
        .fold<Duration>(
          Duration.zero,
          (duration, segment) => duration + segment.durationUntil(now),
        );
  }

  Duration get sessionDuration {
    return segments.where((segment) => !segment.isPause).fold<Duration>(
          Duration.zero,
          (duration, segment) => duration + segment.durationUntil(now),
        );
  }

  SessionDetailLoaded copyWith({
    Session? session,
    List<SessionTrackable>? sessionTrackables,
    List<Trackable>? trackables,
    Map<String, List<TrackableMode>>? modesByTrackable,
    List<TimeSegment>? segments,
    DateTime? now,
  }) {
    return SessionDetailLoaded(
      session: session ?? this.session,
      sessionTrackables: sessionTrackables ?? this.sessionTrackables,
      trackables: trackables ?? this.trackables,
      modesByTrackable: modesByTrackable ?? this.modesByTrackable,
      segments: segments ?? this.segments,
      now: now ?? this.now,
    );
  }
}

class SessionDetailFailure extends SessionDetailState {
  final String message;

  const SessionDetailFailure({required this.message});
}
