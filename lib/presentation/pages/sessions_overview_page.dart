import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/blocs/session_detail/session_detail_bloc.dart';
import 'package:time_tracker/presentation/blocs/sessions/sessions_bloc.dart';
import 'package:time_tracker/presentation/pages/session_detail_page.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';

class SessionsOverviewPage extends StatelessWidget {
  const SessionsOverviewPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionsBloc(
        sessionRepository: context.read<SessionV2Repository>(),
        timelineRepository: context.read<TimelineRepository>(),
      )..add(const SessionsRequested()),
      child: const _SessionsOverviewView(),
    );
  }
}

enum _SessionsSortMode { status, recentActivity }

class _SessionsOverviewView extends StatefulWidget {
  const _SessionsOverviewView();

  @override
  State<_SessionsOverviewView> createState() => _SessionsOverviewViewState();
}

class _SessionsOverviewViewState extends State<_SessionsOverviewView> {
  _SessionsSortMode _sortMode = _SessionsSortMode.status;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionsBloc, SessionsState>(
      listener: (context, state) {
        if (state is SessionRestartReady) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SessionDetailPage(sessionId: state.sessionId),
            ),
          );
          context.read<SessionsBloc>().add(const SessionsRequested());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sessions'),
          actions: [
            IconButton(
              onPressed: () {
                setState(() => _sortMode = _SessionsSortMode.status);
              },
              isSelected: _sortMode == _SessionsSortMode.status,
              selectedIcon: const Icon(Icons.filter_list),
              icon: const Icon(Icons.filter_list_outlined),
              tooltip: 'Sort by status',
            ),
            IconButton(
              onPressed: () {
                setState(() => _sortMode = _SessionsSortMode.recentActivity);
              },
              isSelected: _sortMode == _SessionsSortMode.recentActivity,
              selectedIcon: const Icon(Icons.schedule),
              icon: const Icon(Icons.schedule_outlined),
              tooltip: 'Sort by last activity',
            ),
          ],
        ),
        body: BlocBuilder<SessionsBloc, SessionsState>(
          builder: (context, state) {
            if (state is SessionsLoading || state is SessionsInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SessionsFailure) {
              return Center(child: Text(state.message));
            }

            if (state is SessionsLoaded) {
              if (state.sessions.isEmpty) {
                return Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      context.read<SessionsBloc>().add(const SessionCreated());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Start new session'),
                  ),
                );
              }

              final sessions = _sortedSessions(state.sessions);

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: sessions.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.40),
                ),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _SessionTile(session: session);
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.read<SessionsBloc>().add(const SessionCreated());
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  List<Session> _sortedSessions(List<Session> sessions) {
    final sorted = [...sessions];
    switch (_sortMode) {
      case _SessionsSortMode.status:
        sorted.sort((a, b) {
          final statusCompare =
              _statusRank(a.status).compareTo(_statusRank(b.status));
          if (statusCompare != 0) {
            return statusCompare;
          }
          return b.updatedAt.compareTo(a.updatedAt);
        });
      case _SessionsSortMode.recentActivity:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return sorted;
  }

  int _statusRank(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return 0;
      case SessionStatus.paused:
        return 1;
      case SessionStatus.finished:
        return 2;
    }
  }
}

class _SessionTile extends StatefulWidget {
  final Session session;

  const _SessionTile({required this.session});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  late Future<List<_SessionActivityShare>> _sharesFuture;

  @override
  void initState() {
    super.initState();
    _sharesFuture = _loadShares();
  }

  @override
  void didUpdateWidget(covariant _SessionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.id != widget.session.id ||
        oldWidget.session.updatedAt != widget.session.updatedAt) {
      _sharesFuture = _loadShares();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final statusColor = _statusColor(session.status);
    final duration = _duration();

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.54),
      child: InkWell(
        onTap: session.isFinished ? null : () => _openSession(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.circle, color: statusColor, size: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(TimeFormatUtil.formatDuration(duration)),
                      ],
                    ),
                  ),
                  if (session.isFinished)
                    Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          onPressed: () {
                            context.read<SessionsBloc>().add(
                                  SessionDeleted(sessionId: session.id),
                                );
                          },
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                        ),
                        IconButton(
                          onPressed: () => _openStats(context),
                          icon: const Icon(Icons.bar_chart),
                          tooltip: 'Statistics',
                        ),
                        IconButton(
                          onPressed: () {
                            context.read<SessionsBloc>().add(
                                  SessionRestarted(sessionId: session.id),
                                );
                          },
                          icon: const Icon(Icons.replay),
                          tooltip: 'Restart',
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_statusLabel(session.status)),
                        const SizedBox(height: 3),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                ],
              ),
            ),
            FutureBuilder<List<_SessionActivityShare>>(
              future: _sharesFuture,
              builder: (context, snapshot) {
                final List<_SessionActivityShare>? shares =
                    snapshot.hasError ? const [] : snapshot.data;
                return _SessionActivityShareBar(shares: shares);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_SessionActivityShare>> _loadShares() async {
    final timelineRepository = context.read<TimelineRepository>();
    final trackableRepository = context.read<TrackableRepository>();
    final sessionRepository = context.read<SessionV2Repository>();
    final segments = await timelineRepository.getSegments(widget.session.id);

    final totals = <String, Duration>{};
    for (final segment in segments) {
      totals[segment.trackableId] =
          (totals[segment.trackableId] ?? Duration.zero) +
              _segmentDuration(segment);
    }

    final shares = <_SessionActivityShare>[];
    if (totals.isEmpty) {
      final sessionTrackables = await sessionRepository
          .getSessionTrackablesIncludingArchived(widget.session.id);
      for (final sessionTrackable in sessionTrackables) {
        final trackable = await trackableRepository
            .getTrackable(sessionTrackable.trackableId);
        shares.add(
          _SessionActivityShare(
            duration: const Duration(seconds: 1),
            color: ColorUtils.fromHex(trackable?.color ?? '#607D8B'),
          ),
        );
      }
      return shares;
    }

    for (final entry in totals.entries) {
      final trackable = await trackableRepository.getTrackable(entry.key);
      shares.add(
        _SessionActivityShare(
          duration: entry.value,
          color: ColorUtils.fromHex(trackable?.color ?? '#607D8B'),
        ),
      );
    }
    shares.sort((a, b) => b.duration.compareTo(a.duration));
    return shares;
  }

  Duration _segmentDuration(TimeSegment segment) {
    final end = segment.endAt ??
        widget.session.finishedAt ??
        widget.session.pausedAt ??
        DateTime.now();
    return end.difference(segment.startAt);
  }

  Duration _duration() {
    final start = widget.session.startedAt;
    if (start == null) {
      return Duration.zero;
    }

    final end =
        widget.session.finishedAt ?? widget.session.pausedAt ?? DateTime.now();
    return end.difference(start);
  }

  void _openSession(BuildContext context) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailPage(sessionId: widget.session.id),
      ),
    )
        .then((_) {
      if (context.mounted) {
        context.read<SessionsBloc>().add(const SessionsRequested());
      }
    });
  }

  void _openStats(BuildContext context) {
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => BlocProvider(
        create: (_) => SessionDetailBloc(
          sessionRepository: context.read<SessionV2Repository>(),
          trackableRepository: context.read<TrackableRepository>(),
          timelineRepository: context.read<TimelineRepository>(),
        )..add(SessionDetailRequested(sessionId: widget.session.id)),
        child: const SessionEventsDialog(),
      ),
    );
  }

  String _statusLabel(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.finished:
        return 'Finished';
    }
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return Colors.green;
      case SessionStatus.paused:
        return Colors.orange;
      case SessionStatus.finished:
        return Colors.grey;
    }
  }
}

class _SessionActivityShareBar extends StatelessWidget {
  final List<_SessionActivityShare>? shares;

  const _SessionActivityShareBar({required this.shares});

  @override
  Widget build(BuildContext context) {
    final visibleShares = shares;
    if (visibleShares == null || visibleShares.isEmpty) {
      return SizedBox(
        height: 18,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.18),
          ),
        ),
      );
    }

    return SizedBox(
      height: 18,
      width: double.infinity,
      child: Row(
        children: [
          for (final share in visibleShares)
            Expanded(
              flex: _shareFlex(share, visibleShares),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ColorUtils.lighten(share.color, 0.08),
                      share.color,
                      ColorUtils.darken(share.color, 0.08),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _shareFlex(
    _SessionActivityShare share,
    List<_SessionActivityShare> shares,
  ) {
    final total = shares.fold<int>(
      0,
      (value, item) => value + math.max(1, item.duration.inSeconds),
    );
    return math.max(
      1,
      (math.max(1, share.duration.inSeconds) / total * 1000).round(),
    );
  }
}

class _SessionActivityShare {
  final Duration duration;
  final Color color;

  const _SessionActivityShare({
    required this.duration,
    required this.color,
  });
}
