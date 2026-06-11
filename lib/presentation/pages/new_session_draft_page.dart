import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:time_tracker/application/daily_rhythm/morning_start_service.dart';
import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_trackable.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/pages/session_detail_page.dart';
import 'package:time_tracker/presentation/utils/premium_gate.dart';

class NewSessionDraftPage extends StatefulWidget {
  const NewSessionDraftPage({super.key});

  @override
  State<NewSessionDraftPage> createState() => _NewSessionDraftPageState();
}

class _NewSessionDraftPageState extends State<NewSessionDraftPage> {
  static const _uuid = Uuid();

  late final SessionV2Repository _sessionRepository;
  late final TimelineRepository _timelineRepository;
  late final TrackableRepository _trackableRepository;
  late final MorningStartService _activityService;
  late Future<List<Trackable>> _activitiesFuture;
  final TextEditingController _searchController = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _sessionRepository = context.read<SessionV2Repository>();
    _timelineRepository = context.read<TimelineRepository>();
    _trackableRepository = context.read<TrackableRepository>();
    _activityService = MorningStartService(
      dailyRhythmRepository: context.read<DailyRhythmRepository>(),
      sessionRepository: _sessionRepository,
      trackableRepository: _trackableRepository,
      timelineRepository: _timelineRepository,
    );
    _searchController.addListener(() => setState(() {}));
    _activitiesFuture = _trackableRepository.getTrackables();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createAndStart(Trackable trackable) async {
    if (_creating) return;
    final canCreate = await _canCreateActiveSession();
    if (!canCreate) {
      return;
    }
    setState(() => _creating = true);
    try {
      final now = DateTime.now();
      final session = Session(
        id: _uuid.v4(),
        name: _defaultSessionName(now),
        status: SessionStatus.active,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await _sessionRepository.saveSession(session);
      await _sessionRepository.saveSessionTrackable(
        SessionTrackable(
          id: _uuid.v4(),
          sessionId: session.id,
          trackableId: trackable.id,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final mode = await _defaultMode(trackable.id);
      await _timelineRepository.saveSegment(
        TimeSegment(
          id: _uuid.v4(),
          sessionId: session.id,
          trackableId: trackable.id,
          modeId: mode.id,
          startAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailPage(sessionId: session.id),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Future<void> _createActivityAndStart() async {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;
    final canCreate = await _canCreateActiveSession();
    if (!canCreate) {
      return;
    }
    final activity = await _activityService.createCustomActivity(name);
    await _createAndStart(activity);
  }

  Future<bool> _canCreateActiveSession() async {
    final activeSessions = await _sessionRepository.getSessionsByStatus(
      SessionStatus.active,
    );
    final pausedSessions = await _sessionRepository.getSessionsByStatus(
      SessionStatus.paused,
    );
    if (activeSessions.isEmpty && pausedSessions.isEmpty) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    return ensurePremiumAccess(
      context,
      feature: PremiumFeature.multipleSessions,
      source: 'multiple_sessions_new_session',
    );
  }

  Future<TrackableMode> _defaultMode(String trackableId) async {
    final modes = await _trackableRepository.getModes(trackableId);
    if (modes.isNotEmpty) {
      return modes.firstWhere(
        (mode) => mode.isMain,
        orElse: () => modes.first,
      );
    }
    final now = DateTime.now();
    final mode = TrackableMode(
      id: _uuid.v4(),
      trackableId: trackableId,
      name: TrackableMode.mainName,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _trackableRepository.saveMode(mode);
    return mode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New session')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.62, -0.86),
            radius: 1.2,
            colors: [
              Color(0xFF10192A),
              Color(0xFF070C14),
              Color(0xFF050910),
            ],
            stops: [0, 0.52, 1],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<Trackable>>(
            future: _activitiesFuture,
            builder: (context, snapshot) {
              final activities = snapshot.data ?? const <Trackable>[];
              final query = _searchController.text.trim();
              final filtered = _filtered(activities, query);
              final exactExists = activities.any(
                (activity) => _normalize(activity.name) == _normalize(query),
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    'Choose the first activity',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.94),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The session will be created only after you start an activity.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: 'Find and create activity',
                      hintText: 'Work, Walk, Music',
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (query.isNotEmpty && !exactExists)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DraftCreateButton(
                        label: query,
                        busy: _creating,
                        onPressed: _createActivityAndStart,
                      ),
                    ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    for (final activity in filtered)
                      _DraftActivityTile(
                        activity: activity,
                        busy: _creating,
                        onTap: () => _createAndStart(activity),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Trackable> _filtered(List<Trackable> activities, String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) {
      return activities.take(20).toList();
    }
    return activities
        .where((activity) => _normalize(activity.name).contains(normalized))
        .take(20)
        .toList();
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _defaultSessionName(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }
}

class _DraftActivityTile extends StatelessWidget {
  final Trackable activity;
  final bool busy;
  final VoidCallback onTap;

  const _DraftActivityTile({
    required this.activity,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.fromHex(activity.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFF0D1421).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.44),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    activity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftCreateButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _DraftCreateButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);
    return Material(
      color: accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.44)),
          ),
          child: Row(
            children: [
              busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Create and start "$label"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
