// ignore_for_file: unused_element, unused_element_parameter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/blocs/session_detail/session_detail_bloc.dart';
import 'package:time_tracker/presentation/blocs/sessions/sessions_bloc.dart';
import 'package:time_tracker/presentation/pages/daily_rhythm/morning_start_page.dart';
import 'package:time_tracker/presentation/pages/new_session_draft_page.dart';
import 'package:time_tracker/presentation/pages/session_detail_page.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';
import 'package:uuid/uuid.dart';

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
  final _SessionsSortMode _sortMode = _SessionsSortMode.status;
  final Map<String, List<_SessionActivityShare>> _sessionShares = {};
  String? _sharesLoadKey;
  bool _sharesLoading = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionsBloc, SessionsState>(
      listener: (context, state) {
        if (state is SessionRestartReady) {
          Navigator.of(context)
              .push(
            MaterialPageRoute<void>(
              builder: (_) => SessionDetailPage(
                sessionId: state.sessionId,
                startEditingTitle: state.editTitle,
              ),
            ),
          )
              .then((_) {
            if (context.mounted) {
              context.read<SessionsBloc>().add(const SessionsRequested());
            }
          });
        }
      },
      child: Scaffold(
        extendBody: true,
        body: BlocBuilder<SessionsBloc, SessionsState>(
          builder: (context, state) {
            if (state is SessionsLoading || state is SessionsInitial) {
              return const _SessionsBackdrop(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (state is SessionsFailure) {
              return _SessionsBackdrop(
                child: Center(child: Text(state.message)),
              );
            }

            if (state is SessionsLoaded) {
              _ensureSessionSharesLoaded(state.sessions);

              if (state.sessions.isEmpty && state.templates.isEmpty) {
                return _SessionsBackdrop(
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: () => _openMorningStart(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Start Day'),
                    ),
                  ),
                );
              }

              final sessions = _sortedSessions(state.sessions);
              final activeSessions = sessions
                  .where(
                    (session) => session.isActive || session.isPaused,
                  )
                  .toList();
              final finishedSessions =
                  sessions.where((session) => session.isFinished).toList();

              return _SessionsBackdrop(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: _SessionsSectionTitle(
                          title: 'Current Sessions',
                          topPadding: 18,
                        ),
                      ),
                    ),
                    if (activeSessions.isEmpty)
                      SliverToBoxAdapter(
                        child: _EmptyNowCard(
                          onStart: () => _openMorningStart(context),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: activeSessions.length,
                        itemBuilder: (context, index) {
                          final session = activeSessions[index];
                          return _CurrentSessionCard(
                            key: ValueKey(session.id),
                            session: session,
                            shares: _sessionShares[session.id],
                            sharesLoading: _sharesLoading &&
                                !_sessionShares.containsKey(session.id),
                          );
                        },
                      ),
                    SliverToBoxAdapter(
                      child: _SessionsSectionTitle(
                        title: 'Quick start',
                        subtitle: state.templates.isEmpty
                            ? 'Create a session'
                            : 'Start a template',
                        topPadding: 34,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 190,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: state.templates.length + 1,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            if (index == state.templates.length) {
                              return const _QuickStartNewSessionCard();
                            }
                            return _QuickStartTemplateCard(
                              template: state.templates[index],
                              index: index,
                            );
                          },
                        ),
                      ),
                    ),
                    if (finishedSessions.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: _SessionsSectionTitle(
                          title: 'History',
                          subtitle: 'Completed sessions',
                          topPadding: 36,
                        ),
                      ),
                      SliverList.builder(
                        itemCount: finishedSessions.length,
                        itemBuilder: (context, index) {
                          final session = finishedSessions[index];
                          return _HistorySessionTile(
                            key: ValueKey(session.id),
                            session: session,
                            shares: _sessionShares[session.id],
                            sharesLoading: _sharesLoading &&
                                !_sessionShares.containsKey(session.id),
                          );
                        },
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 112)),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _ensureSessionSharesLoaded(List<Session> sessions) {
    final nextKey = sessions
        .map(
          (session) =>
              '${session.id}:${session.updatedAt.millisecondsSinceEpoch}',
        )
        .join('|');
    if (_sharesLoadKey == nextKey) {
      return;
    }

    _sharesLoadKey = nextKey;
    _sharesLoading = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadSessionShares(sessions);
    });
  }

  Future<void> _loadSessionShares(List<Session> sessions) async {
    final timelineRepository = context.read<TimelineRepository>();
    final trackableRepository = context.read<TrackableRepository>();
    final sessionRepository = context.read<SessionV2Repository>();
    final now = DateTime.now();
    final trackableShares = <String, _TrackableShareData>{};

    debugPrint('SessionsSummary: loading ${sessions.length} sessions');

    Future<_TrackableShareData> trackableShareFor(String trackableId) async {
      if (trackableId == TimeSegment.pauseTrackableId) {
        return const _TrackableShareData(
          name: 'Pause',
          color: Color(0xFFFFB020),
        );
      }
      final cached = trackableShares[trackableId];
      if (cached != null) {
        return cached;
      }
      final trackable = await trackableRepository.getTrackable(trackableId);
      final color = ColorUtils.fromHex(trackable?.color ?? '#607D8B');
      final data = _TrackableShareData(
        name: trackable?.name ?? 'Activity',
        color: color,
      );
      trackableShares[trackableId] = data;
      return data;
    }

    try {
      final entries = await Future.wait(
        sessions.map((session) async {
          final segments = await timelineRepository.getSegments(session.id);
          final totals = <String, Duration>{};
          debugPrint(
            'SessionsSummary: session=${session.id} '
            'name="${session.name}" status=${session.status.name} '
            'segments=${segments.length}',
          );

          for (final segment in segments) {
            if (segment.isPause) {
              continue;
            }
            final duration = _segmentDurationForSession(segment, session, now);
            totals[segment.trackableId] =
                (totals[segment.trackableId] ?? Duration.zero) + duration;
          }

          final shares = <_SessionActivityShare>[];
          if (totals.isEmpty) {
            final sessionTrackables = await sessionRepository
                .getSessionTrackablesIncludingArchived(session.id);
            debugPrint(
              'SessionsSummary: session=${session.id} has no segment totals, '
              'sessionTrackables=${sessionTrackables.length}',
            );
            for (final sessionTrackable in sessionTrackables) {
              final shareData =
                  await trackableShareFor(sessionTrackable.trackableId);
              shares.add(
                _SessionActivityShare(
                  name: shareData.name,
                  duration: const Duration(seconds: 1),
                  color: shareData.color,
                ),
              );
            }
          } else {
            for (final entry in totals.entries) {
              final shareData = await trackableShareFor(entry.key);
              shares.add(
                _SessionActivityShare(
                  name: shareData.name,
                  duration: entry.value,
                  color: shareData.color,
                ),
              );
            }
          }

          shares.sort((a, b) => b.duration.compareTo(a.duration));
          debugPrint(
            'SessionsSummary: session=${session.id} shares='
            '${shares.map((share) => '${ColorUtils.toHex(share.color)}:${share.duration.inSeconds}s').join(', ')}',
          );
          return MapEntry(session.id, shares);
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _sessionShares
          ..clear()
          ..addEntries(entries);
        _sharesLoading = false;
      });
      debugPrint('SessionsSummary: loaded ${entries.length} summaries');
    } catch (error, stackTrace) {
      debugPrint('SessionsSummary: failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() => _sharesLoading = false);
    }
  }

  Duration _segmentDurationForSession(
    TimeSegment segment,
    Session session,
    DateTime now,
  ) {
    final end = segment.endAt ?? session.finishedAt ?? session.pausedAt ?? now;
    return end.difference(segment.startAt);
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

  Future<void> _openMorningStart(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MorningStartPage(),
      ),
    );
    if (context.mounted) {
      context.read<SessionsBloc>().add(const SessionsRequested());
    }
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

class _SessionsBackdrop extends StatelessWidget {
  final Widget child;

  const _SessionsBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: child,
    );
  }
}

class _SessionsSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double topPadding;

  const _SessionsSectionTitle({
    required this.title,
    this.subtitle,
    this.topPadding = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 7),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyNowCard extends StatelessWidget {
  final VoidCallback onStart;

  const _EmptyNowCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B35FF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: _GlassPanel(
          borderColor: accent.withValues(alpha: 0.26),
          child: Stack(
            children: [
              const Positioned.fill(
                child: Opacity(
                  opacity: 0.58,
                  child: _FlowRibbon(accent: accent, active: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No running sessions',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start today’s rhythm when you are ready.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    _EmptyStartButton(onPressed: onStart),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmptyStartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B35FF);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [accent, Color(0xFF246BFE)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.26),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -10,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Start',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentSessionCard extends StatelessWidget {
  final Session session;
  final List<_SessionActivityShare>? shares;
  final bool sharesLoading;

  const _CurrentSessionCard({
    super.key,
    required this.session,
    required this.shares,
    required this.sharesLoading,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _dominantColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openSession(context),
          splashColor: accent.withValues(alpha: 0.10),
          highlightColor: accent.withValues(alpha: 0.06),
          child: _GlassPanel(
            borderColor: accent.withValues(alpha: 0.32),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: session.isActive ? 1 : 0.42,
                    duration: const Duration(milliseconds: 250),
                    child:
                        _FlowRibbon(accent: accent, active: session.isActive),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.52),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              session.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.90),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                          ),
                          _StatusBadge(session: session, accent: accent),
                        ],
                      ),
                      const SizedBox(height: 34),
                      _LiveSessionDuration(session: session),
                      const SizedBox(height: 4),
                      Text(
                        'Session duration',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 28),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 18,
                          child: _SessionActivityShareBar(
                            shares: shares,
                            loading: sharesLoading,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ShareDetailsGrid(shares: shares),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _openSession(context),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          label: const Text('View breakdown'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Color.lerp(accent, Colors.white, 0.22),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _dominantColor() {
    final visibleShares = shares;
    if (visibleShares != null && visibleShares.isNotEmpty) {
      return visibleShares.first.color;
    }
    return session.isPaused ? const Color(0xFFFFA22A) : const Color(0xFF8B35FF);
  }

  void _openSession(BuildContext context) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailPage(sessionId: session.id),
      ),
    )
        .then((_) {
      if (context.mounted) {
        context.read<SessionsBloc>().add(const SessionsRequested());
      }
    });
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _GlassPanel({
    required this.child,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1421).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 28,
            offset: const Offset(0, 16),
            spreadRadius: -18,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Session session;
  final Color accent;

  const _StatusBadge({
    required this.session,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final label = session.isActive ? 'Active' : 'Paused';
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

class _LiveSessionDuration extends StatelessWidget {
  final Session session;

  const _LiveSessionDuration({required this.session});

  @override
  Widget build(BuildContext context) {
    if (!session.isActive) {
      return _DurationText(duration: _durationAt(DateTime.now()));
    }
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (value) => value),
      builder: (context, _) => _DurationText(
        duration: _durationAt(DateTime.now()),
      ),
    );
  }

  Duration _durationAt(DateTime now) {
    final start = session.startedAt;
    if (start == null) {
      return Duration.zero;
    }
    final end = session.finishedAt ?? session.pausedAt ?? now;
    return end.difference(start);
  }
}

class _DurationText extends StatelessWidget {
  final Duration duration;

  const _DurationText({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Text(
      TimeFormatUtil.formatDuration(duration),
      maxLines: 1,
      style: Theme.of(context).textTheme.displayMedium?.copyWith(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 58,
        fontWeight: FontWeight.w300,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _ShareDetailsGrid extends StatelessWidget {
  final List<_SessionActivityShare>? shares;

  const _ShareDetailsGrid({required this.shares});

  @override
  Widget build(BuildContext context) {
    final visibleShares = shares ?? const <_SessionActivityShare>[];
    final total = visibleShares.fold<int>(
      0,
      (value, share) => value + math.max(1, share.duration.inSeconds),
    );
    if (visibleShares.isEmpty || total == 0) {
      return const SizedBox(height: 58);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 18) / 2;
        return Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            for (final share in visibleShares.take(4))
              SizedBox(
                width: itemWidth,
                child: _ShareDetailItem(
                  share: share,
                  percent: share.duration.inSeconds / total,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShareDetailItem extends StatelessWidget {
  final _SessionActivityShare share;
  final double percent;

  const _ShareDetailItem({
    required this.share,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(color: share.color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                share.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(percent * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: share.color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                TimeFormatUtil.formatDuration(share.duration),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickStartTemplateCard extends StatelessWidget {
  final SessionTemplate template;
  final int index;

  const _QuickStartTemplateCard({
    required this.template,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accent(index);
    return FutureBuilder<List<_TemplateTrackableViewData>>(
      future: _loadTrackables(context),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <_TemplateTrackableViewData>[];
        return SizedBox(
          width: 210,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.read<SessionsBloc>().add(
                    SessionTemplateStarted(templateId: template.id),
                  ),
              onLongPress: () => _showTemplateMenu(context),
              child: Ink(
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFF0C1420), accent, 0.13),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: -16,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        items.isEmpty
                            ? 'template'
                            : items
                                .take(4)
                                .map((item) => item.name)
                                .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.52),
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const Spacer(),
                      Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.38),
                          ),
                        ),
                        child: Text(
                          'Start',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<_TemplateTrackableViewData>> _loadTrackables(
    BuildContext context,
  ) async {
    final sessionRepository = context.read<SessionV2Repository>();
    final trackableRepository = context.read<TrackableRepository>();
    final templateTrackables =
        await sessionRepository.getSessionTemplateTrackables(template.id);
    final items = <_TemplateTrackableViewData>[];
    for (final templateTrackable in templateTrackables.take(4)) {
      final trackable =
          await trackableRepository.getTrackable(templateTrackable.trackableId);
      if (trackable == null) {
        continue;
      }
      items.add(
        _TemplateTrackableViewData(
          name: trackable.name,
          color: ColorUtils.fromHex(trackable.color),
        ),
      );
    }
    return items;
  }

  Future<void> _showTemplateMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Edit template'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename template'),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete template'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }
    if (action == 'edit') {
      await _openTemplateEditor(context);
      return;
    }
    if (action == 'delete') {
      context.read<SessionsBloc>().add(
            SessionTemplateDeleted(templateId: template.id),
          );
      return;
    }

    final bloc = context.read<SessionsBloc>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TemplateNameDialog(
        title: 'Rename template',
        initialName: template.name,
      ),
    );
    if (name == null) {
      return;
    }
    bloc.add(SessionTemplateRenamed(templateId: template.id, name: name));
  }

  Future<void> _openTemplateEditor(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => TemplateEditorPage(template: template),
      ),
    );
    if (context.mounted) {
      context.read<SessionsBloc>().add(const SessionsRequested());
    }
  }

  Color _accent(int index) {
    const colors = [
      Color(0xFF20D67B),
      Color(0xFF246BFE),
      Color(0xFFFFA22A),
      Color(0xFF21D4E8),
      Color(0xFF8B35FF),
    ];
    return colors[index % colors.length];
  }
}

class _QuickStartNewSessionCard extends StatelessWidget {
  const _QuickStartNewSessionCard();

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);
    return SizedBox(
      width: 210,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDraft(context),
          splashColor: accent.withValues(alpha: 0.10),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFF0C1420), accent, 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.36)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -16,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New session',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start from an empty session and add activities as you go.',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Text(
                      'Create',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDraft(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NewSessionDraftPage(),
      ),
    );
    if (context.mounted) {
      context.read<SessionsBloc>().add(const SessionsRequested());
    }
  }
}

class _HistorySessionTile extends StatelessWidget {
  final Session session;
  final List<_SessionActivityShare>? shares;
  final bool sharesLoading;

  const _HistorySessionTile({
    super.key,
    required this.session,
    required this.shares,
    required this.sharesLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: () => _showSessionActions(context),
          child: Ink(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1421).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showSessionActions(context),
                        icon: const Icon(Icons.more_horiz_rounded),
                        color: Colors.white.withValues(alpha: 0.62),
                        tooltip: 'Session actions',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.54),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('dd.MM.yyyy').format(
                          session.finishedAt ?? session.updatedAt,
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          TimeFormatUtil.formatDuration(_duration()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: double.infinity,
                      height: 9,
                      child: _SessionActivityShareBar(
                        shares: shares,
                        loading: sharesLoading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Duration _duration() {
    final start = session.startedAt;
    if (start == null) {
      return Duration.zero;
    }
    final end = session.finishedAt ?? session.pausedAt ?? DateTime.now();
    return end.difference(start);
  }

  Future<void> _showSessionActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Save as template'),
              onTap: () => Navigator.of(sheetContext).pop('template'),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Statistics'),
              onTap: () => Navigator.of(sheetContext).pop('stats'),
            ),
            ListTile(
              leading: const Icon(Icons.replay),
              title: const Text('Restart'),
              onTap: () => Navigator.of(sheetContext).pop('restart'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }
    switch (action) {
      case 'template':
        await _saveAsTemplate(context);
        break;
      case 'stats':
        _openStats(context);
        break;
      case 'restart':
        context
            .read<SessionsBloc>()
            .add(SessionRestarted(sessionId: session.id));
        break;
      case 'delete':
        await _confirmDeleteSession(context);
        break;
    }
  }

  Future<void> _saveAsTemplate(BuildContext context) async {
    final bloc = context.read<SessionsBloc>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TemplateNameDialog(
        title: 'Save as template',
        initialName: session.name,
      ),
    );

    if (name == null) {
      return;
    }
    bloc.add(
      SessionTemplateCreatedFromSession(sessionId: session.id, name: name),
    );
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
        )..add(SessionDetailRequested(sessionId: session.id)),
        child: const SessionEventsDialog(),
      ),
    );
  }

  Future<void> _confirmDeleteSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          'This will permanently delete "${session.name}" and all its events.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<SessionsBloc>().add(SessionDeleted(sessionId: session.id));
    }
  }
}

class _FlowRibbon extends StatefulWidget {
  final Color accent;
  final bool active;

  const _FlowRibbon({
    required this.accent,
    required this.active,
  });

  @override
  State<_FlowRibbon> createState() => _FlowRibbonState();
}

class _FlowRibbonState extends State<_FlowRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _FlowRibbonPainter(
            accent: widget.accent,
            phase: _controller.value,
            active: widget.active,
          ),
        );
      },
    );
  }
}

class _FlowRibbonPainter extends CustomPainter {
  final Color accent;
  final double phase;
  final bool active;

  const _FlowRibbonPainter({
    required this.accent,
    required this.phase,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final wash = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.18, -0.18),
        radius: 0.88,
        colors: [
          accent.withValues(alpha: active ? 0.18 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wash);

    final baseY = size.height * 0.48;
    final waveWidth = size.width / 4.3;
    for (var line = 0; line < 22; line++) {
      final t = line / 21;
      final localPhase = phase * math.pi * 2 + t * 2.6;
      final y = baseY + (t - 0.5) * size.height * 0.22;
      final amplitude = size.height * (0.055 + t * 0.028);
      final path = Path()..moveTo(-size.width * 0.16, y);
      for (var i = 0; i < 6; i++) {
        final x0 = -size.width * 0.16 + waveWidth * i;
        final x1 = x0 + waveWidth;
        path.cubicTo(
          x0 + waveWidth * 0.34,
          y + math.sin(localPhase + i * 0.88) * amplitude * 1.65,
          x0 + waveWidth * 0.68,
          y - math.cos(localPhase + i * 1.12) * amplitude * 1.45,
          x1,
          y + math.sin(localPhase + i * 0.72) * amplitude,
        );
      }

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 9 - t * 5
        ..color = accent.withValues(alpha: active ? 0.055 : 0.025)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, glowPaint);

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.05
        ..shader = LinearGradient(
          colors: [
            accent.withValues(alpha: 0.00),
            Color.lerp(accent, Colors.white, 0.20)!.withValues(
              alpha: active ? 0.30 : 0.12,
            ),
            accent.withValues(alpha: active ? 0.18 : 0.08),
            accent.withValues(alpha: 0.00),
          ],
          stops: const [0, 0.38, 0.70, 1],
        ).createShader(Offset.zero & size)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()..blendMode = BlendMode.screen;
    for (var dot = 0; dot < 26; dot++) {
      final t = (dot / 26 + phase * (active ? 0.55 : 0.18)) % 1;
      final y =
          baseY + math.sin(t * math.pi * 4.1 + dot * 0.32) * size.height * 0.10;
      final x = size.width * t;
      final focus = math.sin(t * math.pi);
      dotPaint.color = Color.lerp(accent, Colors.white, 0.20)!.withValues(
        alpha: (active ? 0.32 : 0.12) * focus,
      );
      canvas.drawCircle(Offset(x, y), 1.2 + focus * 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowRibbonPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.phase != phase ||
        oldDelegate.active != active;
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final List<_SessionActivityShare>? shares;
  final bool sharesLoading;

  const _SessionTile({
    super.key,
    required this.session,
    required this.shares,
    required this.sharesLoading,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(session.status);
    final duration = _duration();
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: session.isFinished ? null : () => _openSession(context),
        splashColor: statusColor.withValues(alpha: 0.08),
        highlightColor: statusColor.withValues(alpha: 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: colors.surface.withValues(alpha: 0.42),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SessionStatusPill(status: session.status),
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
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: colors.onSurface.withValues(alpha: 0.58),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                TimeFormatUtil.formatDuration(duration),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: colors.onSurface
                                          .withValues(alpha: 0.70),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (session.isFinished)
                      Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            onPressed: () => _saveAsTemplate(context),
                            icon: const Icon(Icons.star_border),
                            tooltip: 'Save as template',
                          ),
                          IconButton(
                            onPressed: () => _confirmDeleteSession(context),
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
                      Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: colors.onSurface.withValues(alpha: 0.36),
                      ),
                  ],
                ),
              ),
            ),
            _SessionActivityShareBar(
              shares: shares,
              loading: sharesLoading,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAsTemplate(BuildContext context) async {
    final bloc = context.read<SessionsBloc>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TemplateNameDialog(
        title: 'Save as template',
        initialName: session.name,
      ),
    );

    if (name == null) {
      return;
    }
    bloc.add(
      SessionTemplateCreatedFromSession(
        sessionId: session.id,
        name: name,
      ),
    );
  }

  Duration _duration() {
    final start = session.startedAt;
    if (start == null) {
      return Duration.zero;
    }

    final end = session.finishedAt ?? session.pausedAt ?? DateTime.now();
    return end.difference(start);
  }

  void _openSession(BuildContext context) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => SessionDetailPage(sessionId: session.id),
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
        )..add(SessionDetailRequested(sessionId: session.id)),
        child: const SessionEventsDialog(),
      ),
    );
  }

  Future<void> _confirmDeleteSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          'This will permanently delete "${session.name}" and all its events.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<SessionsBloc>().add(
            SessionDeleted(sessionId: session.id),
          );
    }
  }

  Color _statusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return const Color(0xFF21C76A);
      case SessionStatus.paused:
        return const Color(0xFFFFB020);
      case SessionStatus.finished:
        return const Color(0xFF7B8496);
    }
  }
}

class _SessionsSectionHeader extends StatelessWidget {
  final String title;

  const _SessionsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.72),
            ),
      ),
    );
  }
}

class _SessionTemplateTile extends StatelessWidget {
  final SessionTemplate template;

  const _SessionTemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_TemplateTrackableViewData>>(
      future: _loadTrackables(context),
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <_TemplateTrackableViewData>[];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => _showTemplateMenu(context),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withValues(
                    alpha: 0.36,
                  ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HorizontalScrollText(
                            text: template.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final item in items.take(6))
                                _TemplateTrackableChip(item: item),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        context.read<SessionsBloc>().add(
                              SessionTemplateStarted(
                                templateId: template.id,
                              ),
                            );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Create'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<_TemplateTrackableViewData>> _loadTrackables(
    BuildContext context,
  ) async {
    final sessionRepository = context.read<SessionV2Repository>();
    final trackableRepository = context.read<TrackableRepository>();
    final templateTrackables =
        await sessionRepository.getSessionTemplateTrackables(template.id);
    final items = <_TemplateTrackableViewData>[];
    for (final templateTrackable in templateTrackables) {
      final trackable =
          await trackableRepository.getTrackable(templateTrackable.trackableId);
      if (trackable == null) {
        continue;
      }
      items.add(
        _TemplateTrackableViewData(
          name: trackable.name,
          color: ColorUtils.fromHex(trackable.color),
        ),
      );
    }
    return items;
  }

  Future<void> _showTemplateMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Edit template'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename template'),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete template'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }
    if (action == 'edit') {
      await _openTemplateEditor(context);
      return;
    }
    if (action == 'delete') {
      context.read<SessionsBloc>().add(
            SessionTemplateDeleted(templateId: template.id),
          );
      return;
    }

    final bloc = context.read<SessionsBloc>();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _TemplateNameDialog(
        title: 'Rename template',
        initialName: template.name,
      ),
    );
    if (name == null) {
      return;
    }
    bloc.add(
      SessionTemplateRenamed(templateId: template.id, name: name),
    );
  }

  Future<void> _openTemplateEditor(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => TemplateEditorPage(template: template),
      ),
    );
    if (context.mounted) {
      context.read<SessionsBloc>().add(const SessionsRequested());
    }
  }
}

class TemplateEditorPage extends StatefulWidget {
  final SessionTemplate template;

  const TemplateEditorPage({Key? key, required this.template})
      : super(key: key);

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  final TextEditingController _nameController = TextEditingController();
  late Future<void> _loadFuture;
  final List<_EditableTemplateActivity> _activities = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.template.name;
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _SessionsBackdrop(
        child: SafeArea(
          child: FutureBuilder<void>(
            future: _loadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      children: [
                        _TemplateIconButton(
                          icon: Icons.chevron_left,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        Text(
                          'Edit template',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7136D7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      children: [
                        Text(
                          'Template name',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        _TemplateNameField(controller: _nameController),
                        const SizedBox(height: 24),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Activities',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.94,
                                          ),
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Drag to reorder',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.60,
                                          ),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _addActivity,
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7136D7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _activities.length,
                          onReorder: _reorder,
                          itemBuilder: (context, index) {
                            final activity = _activities[index];
                            return Padding(
                              key: ValueKey(activity.localId),
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TemplateActivityCard(
                                activity: activity,
                                index: index,
                                onEdit: () => _editActivity(index),
                                onDelete: () => _deleteActivity(index),
                              ),
                            );
                          },
                        ),
                        if (_activities.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'No activities yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.52),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        const SizedBox(height: 22),
                        _TemplateStatsPanel(
                          activityCount: _activities.length,
                          contextCount: _activities.fold<int>(
                            0,
                            (sum, item) => sum + item.modes.length,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    final sessionRepository = context.read<SessionV2Repository>();
    final trackableRepository = context.read<TrackableRepository>();
    final templateTrackables = await sessionRepository
        .getSessionTemplateTrackables(widget.template.id);
    final loaded = <_EditableTemplateActivity>[];
    for (final templateTrackable in templateTrackables) {
      final trackable =
          await trackableRepository.getTrackable(templateTrackable.trackableId);
      if (trackable == null || trackable.isArchived) {
        continue;
      }
      final modes = await trackableRepository.getModes(trackable.id);
      loaded.add(
        _EditableTemplateActivity(
          localId: templateTrackable.id,
          templateTrackableId: templateTrackable.id,
          trackable: trackable,
          modes: modes,
        ),
      );
    }
    _activities
      ..clear()
      ..addAll(loaded);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _activities.removeAt(oldIndex);
      _activities.insert(newIndex, item);
    });
  }

  Future<void> _addActivity() async {
    final picked = await showModalBottomSheet<Trackable>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateActivityPickerSheet(
        excludedTrackableIds: Set.unmodifiable(
          _activities.map((activity) => activity.trackable.id),
        ),
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    final modes = await context.read<TrackableRepository>().getModes(picked.id);
    setState(() {
      _activities.add(
        _EditableTemplateActivity(
          localId: const Uuid().v4(),
          trackable: picked,
          modes: modes,
        ),
      );
    });
  }

  Future<void> _editActivity(int index) async {
    final activity = _activities[index];
    final result = await showDialog<_TemplateActivityEditResult>(
      context: context,
      builder: (_) => _TemplateActivityEditDialog(activity: activity),
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.removeFromTemplate) {
      setState(() => _activities.removeAt(index));
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    final updatedTrackable = activity.trackable.copyWith(
      name: result.name,
      color: result.color,
      updatedAt: now,
    );
    await repository.updateTrackable(updatedTrackable);

    final keptModeIds = result.modes
        .where((mode) => mode.existing != null)
        .map((mode) => mode.existing!.id)
        .toSet();
    for (final mode in activity.modes) {
      if (!keptModeIds.contains(mode.id) && !mode.isMain) {
        await repository.updateMode(
          mode.copyWith(archivedAt: now, updatedAt: now),
        );
      }
    }
    for (var i = 0; i < result.modes.length; i += 1) {
      final mode = result.modes[i];
      if (mode.existing == null) {
        await repository.saveMode(
          TrackableMode(
            id: const Uuid().v4(),
            trackableId: updatedTrackable.id,
            name: mode.name,
            sortOrder: i,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await repository.updateMode(
          mode.existing!.copyWith(
            name: mode.name,
            sortOrder: i,
            updatedAt: now,
          ),
        );
      }
    }

    final modes = await repository.getModes(updatedTrackable.id);
    setState(() {
      _activities[index] = activity.copyWith(
        trackable: updatedTrackable,
        modes: modes,
      );
    });
  }

  void _deleteActivity(int index) {
    setState(() => _activities.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template name is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = context.read<SessionV2Repository>();
      final now = DateTime.now();
      await repository.updateSessionTemplate(
        widget.template.copyWith(name: name, updatedAt: now),
      );
      await repository.replaceSessionTemplateTrackables(
        widget.template.id,
        [
          for (var i = 0; i < _activities.length; i += 1)
            SessionTemplateTrackable(
              id: _activities[i].templateTrackableId ?? const Uuid().v4(),
              templateId: widget.template.id,
              trackableId: _activities[i].trackable.id,
              sortOrder: i,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }
}

class _TemplateNameField extends StatelessWidget {
  final TextEditingController controller;

  const _TemplateNameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 40,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.94),
            fontWeight: FontWeight.w800,
          ),
      decoration: InputDecoration(
        counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.48)),
        suffixIcon: IconButton(
          onPressed: controller.clear,
          icon: Icon(
            Icons.cancel,
            color: Colors.white.withValues(alpha: 0.54),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFF101826).withValues(alpha: 0.74),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7D42F5)),
        ),
      ),
    );
  }
}

class _TemplateActivityCard extends StatelessWidget {
  final _EditableTemplateActivity activity;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateActivityCard({
    required this.activity,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.fromHex(activity.trackable.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0xFF0D1420), accent, 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: accent),
              ReorderableDragStartListener(
                index: index,
                child: SizedBox(
                  width: 48,
                  child: Icon(
                    Icons.drag_indicator,
                    color: Colors.white.withValues(alpha: 0.36),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.trackable.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.94),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final mode in activity.modes)
                            _TemplateModeChip(name: mode.name, color: accent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TemplateIconButton(icon: Icons.edit_outlined, onTap: onEdit),
              const SizedBox(width: 8),
              _TemplateIconButton(
                icon: Icons.delete_outline,
                color: const Color(0xFFFF584D),
                onTap: onDelete,
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateModeChip extends StatelessWidget {
  final String name;
  final Color color;

  const _TemplateModeChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          name,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _TemplateIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _TemplateIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF182131).withValues(alpha: 0.80),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: color ?? Colors.white.withValues(alpha: 0.86),
          ),
        ),
      ),
    );
  }
}

class _TemplateStatsPanel extends StatelessWidget {
  final int activityCount;
  final int contextCount;

  const _TemplateStatsPanel({
    required this.activityCount,
    required this.contextCount,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101826).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Expanded(
              child: _TemplateStat(
                icon: Icons.grid_view_rounded,
                value: activityCount,
                label: 'Activities',
              ),
            ),
            Container(
              width: 1,
              height: 44,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Expanded(
              child: _TemplateStat(
                icon: Icons.blur_circular,
                value: contextCount,
                label: 'Contexts',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _TemplateStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2233).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.70)),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TemplateActivityPickerSheet extends StatefulWidget {
  final Set<String> excludedTrackableIds;

  const _TemplateActivityPickerSheet({required this.excludedTrackableIds});

  @override
  State<_TemplateActivityPickerSheet> createState() =>
      _TemplateActivityPickerSheetState();
}

class _TemplateActivityPickerSheetState
    extends State<_TemplateActivityPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  late Future<List<Trackable>> _trackablesFuture;

  @override
  void initState() {
    super.initState();
    _trackablesFuture = _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF08111E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'New activity',
                  suffixIcon: IconButton(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                  ),
                ),
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: FutureBuilder<List<Trackable>>(
                  future: _trackablesFuture,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <Trackable>[];
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No available activities'),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final color = ColorUtils.fromHex(item.color);
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: color),
                          title: Text(item.name),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Trackable>> _load() async {
    final repository = context.read<TrackableRepository>();
    final items = await repository.getTrackables();
    return items
        .where((item) => !widget.excludedTrackableIds.contains(item.id))
        .toList();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    final trackable = Trackable(
      id: const Uuid().v4(),
      name: name,
      color: ColorUtils.toHex(ColorUtils.generateRandomLightColor()),
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveTrackable(trackable);
    await repository.saveMode(
      TrackableMode(
        id: const Uuid().v4(),
        trackableId: trackable.id,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop(trackable);
    }
  }
}

class _TemplateActivityEditDialog extends StatefulWidget {
  final _EditableTemplateActivity activity;

  const _TemplateActivityEditDialog({required this.activity});

  @override
  State<_TemplateActivityEditDialog> createState() =>
      _TemplateActivityEditDialogState();
}

class _TemplateActivityEditDialogState
    extends State<_TemplateActivityEditDialog> {
  late final TextEditingController _nameController;
  final TextEditingController _modeController = TextEditingController();
  late String _selectedColor;
  late final List<String> _suggestedColors;
  late final List<_EditableTemplateMode> _modes;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.activity.trackable.name);
    _selectedColor = ColorUtils.normalizeHex(widget.activity.trackable.color);
    _suggestedColors = ColorUtils.suggestedColorHexes(
      currentHex: widget.activity.trackable.color,
    );
    _modes = widget.activity.modes
        .map((mode) => _EditableTemplateMode(existing: mode, name: mode.name))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.fromHex(_selectedColor);
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF050B14),
      child: _SessionsBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    _TemplateIconButton(
                      icon: Icons.close,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      'Edit activity',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7136D7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  children: [
                    Text(
                      'Activity name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _TemplateNameField(controller: _nameController),
                    const SizedBox(height: 20),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF101826).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Color',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                for (final color in _colorChoices)
                                  _TemplateColorChoice(
                                    color: ColorUtils.fromHex(color),
                                    selected: color == _selectedColor,
                                    onTap: () =>
                                        setState(() => _selectedColor = color),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'QUICK STATES (CONTEXTS)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.66),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddModeDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add quick state'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC159FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF101826).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Column(
                        children: [
                          for (final mode in _modes)
                            _TemplateModeEditRow(
                              mode: mode,
                              color: accent,
                              canDelete: _modes.length > 1 &&
                                  mode.existing?.isMain != true,
                              onRename: () => _renameMode(mode),
                              onDelete: () =>
                                  setState(() => _modes.remove(mode)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        _TemplateActivityEditResult(
                          name: _nameController.text.trim(),
                          color: _selectedColor,
                          modes: const [],
                          removeFromTemplate: true,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete activity'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF584D),
                        side: const BorderSide(color: Color(0xFFFF3B30)),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _colorChoices {
    return {_selectedColor, ..._suggestedColors}.take(4).toList();
  }

  void _addMode() {
    final name = _modeController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _modes.add(_EditableTemplateMode(name: name));
      _modeController.clear();
    });
  }

  Future<void> _showAddModeDialog() async {
    _modeController.clear();
    final name = await _modeNameDialog('Add quick state', _modeController);
    if (name == null) {
      return;
    }
    _modeController.text = name;
    _addMode();
  }

  Future<void> _renameMode(_EditableTemplateMode mode) async {
    final controller = TextEditingController(text: mode.name);
    final name = await _modeNameDialog('Rename quick state', controller);
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) {
      return;
    }
    setState(() {
      final index = _modes.indexOf(mode);
      if (index != -1) {
        _modes[index] = _EditableTemplateMode(
          existing: mode.existing,
          name: trimmed,
        );
      }
    });
  }

  Future<String?> _modeNameDialog(
    String title,
    TextEditingController controller,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Quick state name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _TemplateActivityEditResult(
        name: name,
        color: _selectedColor,
        modes: List.of(_modes),
      ),
    );
  }
}

class _EditableTemplateActivity {
  final String localId;
  final String? templateTrackableId;
  final Trackable trackable;
  final List<TrackableMode> modes;

  const _EditableTemplateActivity({
    required this.localId,
    required this.trackable,
    required this.modes,
    this.templateTrackableId,
  });

  _EditableTemplateActivity copyWith({
    Trackable? trackable,
    List<TrackableMode>? modes,
  }) {
    return _EditableTemplateActivity(
      localId: localId,
      templateTrackableId: templateTrackableId,
      trackable: trackable ?? this.trackable,
      modes: modes ?? this.modes,
    );
  }
}

class _EditableTemplateMode {
  final TrackableMode? existing;
  final String name;

  const _EditableTemplateMode({required this.name, this.existing});
}

class _TemplateColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFFC159FF) : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.34),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _TemplateModeEditRow extends StatelessWidget {
  final _EditableTemplateMode mode;
  final Color color;
  final bool canDelete;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TemplateModeEditRow({
    required this.mode,
    required this.color,
    required this.canDelete,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              color: Colors.white.withValues(alpha: 0.34),
            ),
            const SizedBox(width: 14),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                mode.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _TemplateIconButton(icon: Icons.edit_outlined, onTap: onRename),
            const SizedBox(width: 10),
            _TemplateIconButton(
              icon: Icons.delete_outline,
              color: canDelete
                  ? const Color(0xFFFF584D)
                  : Colors.white.withValues(alpha: 0.22),
              onTap: canDelete ? onDelete : () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateActivityEditResult {
  final String name;
  final String color;
  final List<_EditableTemplateMode> modes;
  final bool removeFromTemplate;

  const _TemplateActivityEditResult({
    required this.name,
    required this.color,
    required this.modes,
    this.removeFromTemplate = false,
  });
}

class _TemplateNameDialog extends StatefulWidget {
  final String title;
  final String initialName;

  const _TemplateNameDialog({
    required this.title,
    required this.initialName,
  });

  @override
  State<_TemplateNameDialog> createState() => _TemplateNameDialogState();
}

class _TemplateNameDialogState extends State<_TemplateNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Template name'),
        textInputAction: TextInputAction.done,
        onSubmitted: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }
}

class _HorizontalScrollText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _HorizontalScrollText({
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}

class _TemplateTrackableChip extends StatelessWidget {
  final _TemplateTrackableViewData item;

  const _TemplateTrackableChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final base = item.color;
    final textColor =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
            ? Colors.white
            : const Color(0xFF121722);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ColorUtils.lighten(base, 0.16),
            base,
            ColorUtils.darken(base, 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          item.name,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _TemplateTrackableViewData {
  final String name;
  final Color color;

  const _TemplateTrackableViewData({
    required this.name,
    required this.color,
  });
}

class _SessionStatusPill extends StatelessWidget {
  final SessionStatus status;

  const _SessionStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _color(status);
    return Container(
      width: 74,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon(status), color: color, size: 15),
          const SizedBox(width: 4),
          Text(
            _label(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return Icons.play_arrow_rounded;
      case SessionStatus.paused:
        return Icons.pause_rounded;
      case SessionStatus.finished:
        return Icons.check_rounded;
    }
  }

  String _label(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.paused:
        return 'Paused';
      case SessionStatus.finished:
        return 'Done';
    }
  }

  Color _color(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return const Color(0xFF21C76A);
      case SessionStatus.paused:
        return const Color(0xFFFFB020);
      case SessionStatus.finished:
        return const Color(0xFF7B8496);
    }
  }
}

class _SessionActivityShareBar extends StatefulWidget {
  final List<_SessionActivityShare>? shares;
  final bool loading;

  const _SessionActivityShareBar({
    required this.shares,
    required this.loading,
  });

  @override
  State<_SessionActivityShareBar> createState() =>
      _SessionActivityShareBarState();
}

class _SessionActivityShareBarState extends State<_SessionActivityShareBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.28,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
    if (_hasShares(widget.shares)) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _SessionActivityShareBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasSameShares(oldWidget.shares, widget.shares)) {
      if (_hasShares(widget.shares)) {
        _controller
          ..reset()
          ..forward();
      } else {
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleShares = widget.shares;
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = widget.loading
        ? colors.primary.withValues(alpha: 0.10)
        : colors.outlineVariant.withValues(alpha: 0.16);
    final separatorColor =
        Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.78);

    if (visibleShares == null || visibleShares.isEmpty) {
      return SizedBox(
        height: 8,
        width: double.infinity,
        child: ColoredBox(color: backgroundColor),
      );
    }

    return SizedBox(
      height: 8,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CustomPaint(
            painter: _SessionActivitySharePainter(
              shares: visibleShares,
              progress: _progress.value,
              backgroundColor: backgroundColor,
              separatorColor: separatorColor,
            ),
          );
        },
      ),
    );
  }

  bool _hasShares(List<_SessionActivityShare>? shares) {
    return shares != null && shares.isNotEmpty;
  }

  bool _hasSameShares(
    List<_SessionActivityShare>? previous,
    List<_SessionActivityShare>? next,
  ) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous == null || next == null || previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      if (previous[index].duration != next[index].duration ||
          previous[index].name != next[index].name ||
          previous[index].color != next[index].color) {
        return false;
      }
    }
    return true;
  }
}

class _SessionActivitySharePainter extends CustomPainter {
  final List<_SessionActivityShare> shares;
  final double progress;
  final Color backgroundColor;
  final Color separatorColor;

  const _SessionActivitySharePainter({
    required this.shares,
    required this.progress,
    required this.backgroundColor,
    required this.separatorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    if (shares.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final totalSeconds = shares.fold<int>(
      0,
      (value, item) => value + math.max(1, item.duration.inSeconds),
    );
    if (totalSeconds <= 0) {
      return;
    }

    final normalizedProgress = progress.clamp(0.0, 1.0);
    final colorPaint = Paint();
    final separatorPaint = Paint()
      ..color = separatorColor
      ..strokeWidth = 1;
    var left = 0.0;
    var revealedRight = 0.0;

    for (var index = 0; index < shares.length; index++) {
      final share = shares[index];
      final ratio = math.max(1, share.duration.inSeconds) / totalSeconds;
      final right = index == shares.length - 1
          ? size.width
          : math.min(size.width, left + size.width * ratio);
      final segmentDelay = math.min(0.42, index * 0.055);
      final segmentProgress = ((normalizedProgress - segmentDelay) /
              math.max(0.01, 1 - segmentDelay))
          .clamp(0.0, 1.0);
      final easedSegmentProgress = Curves.easeOutQuart.transform(
        segmentProgress,
      );
      final clippedRight = left + (right - left) * easedSegmentProgress;

      if (clippedRight > left) {
        colorPaint.color = share.color;
        canvas.drawRect(
          Rect.fromLTRB(left, 0, clippedRight, size.height),
          colorPaint,
        );
        revealedRight = math.max(revealedRight, clippedRight);
      }

      if (clippedRight >= right - 0.5 && index < shares.length - 1) {
        canvas.drawLine(
          Offset(right, 0),
          Offset(right, size.height),
          separatorPaint,
        );
      }

      left = right;
      if (left > revealedRight && segmentProgress <= 0) {
        break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SessionActivitySharePainter oldDelegate) {
    return oldDelegate.shares != shares ||
        oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.separatorColor != separatorColor;
  }
}

class _SessionActivityShare {
  final String name;
  final Duration duration;
  final Color color;

  const _SessionActivityShare({
    this.name = 'Activity',
    required this.duration,
    required this.color,
  });
}

class _TrackableShareData {
  final String name;
  final Color color;

  const _TrackableShareData({
    required this.name,
    required this.color,
  });
}
