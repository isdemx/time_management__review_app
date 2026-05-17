import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/session.dart';
import 'package:time_tracker/domain/entities/session_template.dart';
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
  final Map<String, List<_SessionActivityShare>> _sessionShares = {};
  String? _sharesLoadKey;
  bool _sharesLoading = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionsBloc, SessionsState>(
      listener: (context, state) {
        if (state is SessionRestartReady) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SessionDetailPage(
                sessionId: state.sessionId,
                startEditingTitle: state.editTitle,
              ),
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
              _ensureSessionSharesLoaded(state.sessions);

              if (state.sessions.isEmpty && state.templates.isEmpty) {
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
              final activeSessions = sessions
                  .where(
                    (session) => session.isActive || session.isPaused,
                  )
                  .toList();
              final finishedSessions =
                  sessions.where((session) => session.isFinished).toList();

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (activeSessions.isNotEmpty) ...[
                    const _SessionsSectionHeader(title: 'Active'),
                    for (final session in activeSessions)
                      _SessionTile(
                        key: ValueKey(session.id),
                        session: session,
                        shares: _sessionShares[session.id],
                        sharesLoading: _sharesLoading &&
                            !_sessionShares.containsKey(session.id),
                      ),
                  ],
                  if (state.templates.isNotEmpty) ...[
                    const _SessionsSectionHeader(title: 'Templates'),
                    for (final template in state.templates)
                      _SessionTemplateTile(template: template),
                  ],
                  if (finishedSessions.isNotEmpty) ...[
                    const _SessionsSectionHeader(title: 'Finished'),
                    for (final session in finishedSessions)
                      _SessionTile(
                        key: ValueKey(session.id),
                        session: session,
                        shares: _sessionShares[session.id],
                        sharesLoading: _sharesLoading &&
                            !_sessionShares.containsKey(session.id),
                      ),
                  ],
                ],
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
    final trackableColors = <String, Color>{};

    debugPrint('SessionsSummary: loading ${sessions.length} sessions');

    Future<Color> colorFor(String trackableId) async {
      if (trackableId == TimeSegment.pauseTrackableId) {
        return const Color(0xFFFFB020);
      }
      final cached = trackableColors[trackableId];
      if (cached != null) {
        return cached;
      }
      final trackable = await trackableRepository.getTrackable(trackableId);
      final color = ColorUtils.fromHex(trackable?.color ?? '#607D8B');
      trackableColors[trackableId] = color;
      return color;
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
              shares.add(
                _SessionActivityShare(
                  duration: const Duration(seconds: 1),
                  color: await colorFor(sessionTrackable.trackableId),
                ),
              );
            }
          } else {
            for (final entry in totals.entries) {
              shares.add(
                _SessionActivityShare(
                  duration: entry.value,
                  color: await colorFor(entry.key),
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
  final Duration duration;
  final Color color;

  const _SessionActivityShare({
    required this.duration,
    required this.color,
  });
}
