import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';

abstract class SessionV2Repository {
  Future<void> saveSession(Session session);
  Future<void> updateSession(Session session);
  Future<void> deleteSession(String id);
  Future<Session?> getSession(String id);
  Future<List<Session>> getSessions();
  Future<List<Session>> getSessionsByStatus(SessionStatus status);

  Future<void> saveSessionTrackable(SessionTrackable sessionTrackable);
  Future<void> updateSessionTrackable(SessionTrackable sessionTrackable);
  Future<List<SessionTrackable>> getSessionTrackables(String sessionId);
  Future<List<SessionTrackable>> getSessionTrackablesIncludingArchived(
    String sessionId,
  );

  Future<void> saveSessionTemplate(SessionTemplate template);
  Future<void> updateSessionTemplate(SessionTemplate template);
  Future<void> deleteSessionTemplate(String id);
  Future<List<SessionTemplate>> getSessionTemplates();
  Future<void> saveSessionTemplateTrackable(SessionTemplateTrackable item);
  Future<List<SessionTemplateTrackable>> getSessionTemplateTrackables(
    String templateId,
  );
}
