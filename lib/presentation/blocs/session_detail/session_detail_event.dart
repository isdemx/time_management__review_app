part of 'session_detail_bloc.dart';

abstract class SessionDetailEvent {
  const SessionDetailEvent();
}

class SessionDetailRequested extends SessionDetailEvent {
  final String sessionId;

  const SessionDetailRequested({required this.sessionId});
}

class SessionDetailTrackableAdded extends SessionDetailEvent {
  final String trackableId;
  final String? modeId;
  final DateTime? startAt;

  const SessionDetailTrackableAdded({
    required this.trackableId,
    this.modeId,
    this.startAt,
  });
}

class SessionDetailTrackableSelected extends SessionDetailEvent {
  final String trackableId;
  final String modeId;
  final DateTime? startAt;

  const SessionDetailTrackableSelected({
    required this.trackableId,
    required this.modeId,
    this.startAt,
  });
}

class SessionDetailCustomSegmentInserted extends SessionDetailEvent {
  final String trackableId;
  final String modeId;
  final DateTime startAt;
  final DateTime? endAt;

  const SessionDetailCustomSegmentInserted({
    required this.trackableId,
    required this.modeId,
    required this.startAt,
    this.endAt,
  });
}

class SessionDetailPaused extends SessionDetailEvent {
  final DateTime? startAt;
  final DateTime? endAt;

  const SessionDetailPaused({this.startAt, this.endAt});
}

class SessionDetailFinished extends SessionDetailEvent {
  final DateTime? finishedAt;

  const SessionDetailFinished({this.finishedAt});
}

class SessionDetailRenamed extends SessionDetailEvent {
  final String name;

  const SessionDetailRenamed({required this.name});
}

class SessionDetailSegmentUpdated extends SessionDetailEvent {
  final String segmentId;
  final DateTime startAt;
  final DateTime? endAt;

  const SessionDetailSegmentUpdated({
    required this.segmentId,
    required this.startAt,
    required this.endAt,
  });
}

class SessionDetailSegmentDeleted extends SessionDetailEvent {
  final String segmentId;

  const SessionDetailSegmentDeleted({required this.segmentId});
}

class SessionDetailSegmentBoundaryMoved extends SessionDetailEvent {
  final String previousSegmentId;
  final String nextSegmentId;
  final DateTime boundaryAt;

  const SessionDetailSegmentBoundaryMoved({
    required this.previousSegmentId,
    required this.nextSegmentId,
    required this.boundaryAt,
  });
}

class SessionDetailRetrospectiveSegmentInserted extends SessionDetailEvent {
  final String trackableId;
  final String modeId;
  final DateTime startAt;

  const SessionDetailRetrospectiveSegmentInserted({
    required this.trackableId,
    required this.modeId,
    required this.startAt,
  });
}

class SessionDetailNowChanged extends SessionDetailEvent {
  final DateTime now;

  const SessionDetailNowChanged({required this.now});
}
