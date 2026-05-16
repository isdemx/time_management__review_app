import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/time_segment.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/blocs/session_detail/session_detail_bloc.dart';
import 'package:time_tracker/presentation/utils/time_format_util.dart';
import 'package:time_tracker/presentation/widgets/trackable_button.dart';
import 'package:time_tracker/presentation/widgets/trackable_picker_sheet.dart';
import 'package:uuid/uuid.dart';

class SessionDetailPage extends StatelessWidget {
  final String sessionId;

  const SessionDetailPage({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionDetailBloc(
        sessionRepository: context.read<SessionV2Repository>(),
        trackableRepository: context.read<TrackableRepository>(),
        timelineRepository: context.read<TimelineRepository>(),
      )..add(SessionDetailRequested(sessionId: sessionId)),
      child: const _SessionDetailView(),
    );
  }
}

class _SessionDetailView extends StatefulWidget {
  const _SessionDetailView();

  @override
  State<_SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<_SessionDetailView> {
  static const double _trackableSliderHeight = 92;
  static const double _trackableSliderFingerGap = 12;

  Timer? _ticker;
  late final ValueNotifier<DateTime> _clock;
  _TrackableSliderAction? _sliderAction;
  _LongPressTrackableTarget? _longPressTarget;
  double? _sliderTop;
  final GlobalKey _bodyStackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _clock = ValueNotifier<DateTime>(DateTime.now());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _clock.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionDetailBloc, SessionDetailState>(
      buildWhen: _shouldRebuildSessionDetail,
      builder: (context, state) {
        if (state is SessionDetailLoading || state is SessionDetailInitial) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is SessionDetailFailure) {
          return Scaffold(
            appBar: AppBar(title: const Text('Session')),
            body: Center(child: Text(state.message)),
          );
        }

        if (state is SessionDetailLoaded) {
          final isFinished = state.session.isFinished;
          return Scaffold(
            appBar: AppBar(
              title: _EditableSessionTitle(sessionName: state.session.name),
              actions: [
                IconButton(
                  onPressed: () => _showSessionEvents(context, state),
                  icon: const Icon(Icons.history),
                  tooltip: 'Session events',
                ),
              ],
            ),
            body: Stack(
              key: _bodyStackKey,
              children: [
                Column(
                  children: [
                    _SessionHeader(state: state, clock: _clock),
                    Expanded(
                      child: _SessionTrackablesList(
                        state: state,
                        clock: _clock,
                        onLongPressStart: _startTrackableSlider,
                        onLongPressMove: (position) => _moveTrackableSlider(
                          position,
                          state,
                        ),
                        onLongPressEnd: (position) =>
                            _endTrackableSlider(context, state, position),
                      ),
                    ),
                  ],
                ),
                if (_longPressTarget != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _sliderTop ?? 120,
                    child: IgnorePointer(
                      child: _TrackableActionSliderOverlay(
                        selectedAction: _sliderAction,
                        disabledActions: _disabledSliderActions(state),
                      ),
                    ),
                  ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed:
                  isFinished ? null : () => _showTrackablePicker(context),
              child: const Icon(Icons.add),
            ),
          );
        }

        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }

  bool _shouldRebuildSessionDetail(
    SessionDetailState previous,
    SessionDetailState current,
  ) {
    if (previous is SessionDetailLoaded && current is SessionDetailLoaded) {
      return previous.session != current.session ||
          previous.sessionTrackables != current.sessionTrackables ||
          previous.trackables != current.trackables ||
          previous.modesByTrackable != current.modesByTrackable ||
          previous.segments != current.segments;
    }
    return previous.runtimeType != current.runtimeType;
  }

  void _showTrackablePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SessionDetailBloc>(),
        child: const TrackablePickerSheet(),
      ),
    );
  }

  void _startTrackableSlider(
    String trackableId,
    String modeId,
    Offset globalPosition,
  ) {
    final localPosition = _globalToBodyLocal(globalPosition);
    if (localPosition == null) {
      return;
    }

    setState(() {
      _longPressTarget = _LongPressTrackableTarget(
        trackableId: trackableId,
        modeId: modeId,
      );
      _sliderTop = (localPosition.dy -
              _trackableSliderHeight -
              _trackableSliderFingerGap)
          .clamp(8.0, double.infinity);
      _sliderAction = null;
    });
  }

  void _moveTrackableSlider(
    Offset globalPosition,
    SessionDetailLoaded state,
  ) {
    setState(() {
      _sliderAction = _actionFromGlobalPosition(globalPosition, state);
    });
  }

  void _endTrackableSlider(
    BuildContext context,
    SessionDetailLoaded state,
    Offset globalPosition,
  ) {
    final target = _longPressTarget;
    final action = _actionFromGlobalPosition(globalPosition, state);
    setState(() {
      _longPressTarget = null;
      _sliderAction = null;
      _sliderTop = null;
    });

    if (target == null || action == null) {
      return;
    }

    switch (action.kind) {
      case _TrackableSliderActionKind.backdate:
        final offset = action.backdateOffset;
        if (offset == null) {
          return;
        }
        context.read<SessionDetailBloc>().add(
              SessionDetailTrackableSelected(
                trackableId: target.trackableId,
                modeId: target.modeId,
                startAt: DateTime.now().subtract(offset),
              ),
            );
        return;
      case _TrackableSliderActionKind.startNow:
        context.read<SessionDetailBloc>().add(
              SessionDetailTrackableSelected(
                trackableId: target.trackableId,
                modeId: target.modeId,
              ),
            );
        return;
      case _TrackableSliderActionKind.customTime:
        _showCustomTimeDialog(context, state, target);
        return;
      case _TrackableSliderActionKind.edit:
        _showTrackableEditor(context, state, target.trackableId);
        return;
      case _TrackableSliderActionKind.archive:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${action.label} is next')),
        );
        return;
    }
  }

  Set<_TrackableSliderAction> _disabledSliderActions(
    SessionDetailLoaded state,
  ) {
    final openSegment = state.openSegment;
    if (openSegment == null) {
      return const {};
    }

    final now = DateTime.now();
    return {
      for (final action in _TrackableSliderAction.leftActions)
        if (action.backdateOffset != null &&
            now.subtract(action.backdateOffset!).isBefore(openSegment.startAt))
          action,
    };
  }

  Future<void> _showSessionEvents(
    BuildContext context,
    SessionDetailLoaded state,
  ) {
    final bloc = context.read<SessionDetailBloc>();
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const SessionEventsDialog(),
      ),
    );
  }

  _TrackableSliderAction? _actionFromGlobalPosition(
    Offset globalPosition,
    SessionDetailLoaded state,
  ) {
    final sliderTop = _sliderTop;
    final localPosition = _globalToBodyLocal(globalPosition);
    final width = _bodyWidth;
    if (sliderTop == null || localPosition == null || width == null) {
      return null;
    }

    return _TrackableSliderAction.fromLocalPosition(
      localPosition: localPosition,
      width: width,
      sliderTop: sliderTop,
      disabledActions: _disabledSliderActions(state),
    );
  }

  Offset? _globalToBodyLocal(Offset globalPosition) {
    final box = _bodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(globalPosition);
  }

  double? get _bodyWidth {
    final box = _bodyStackKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width;
  }

  Future<void> _showCustomTimeDialog(
    BuildContext context,
    SessionDetailLoaded state,
    _LongPressTrackableTarget target,
  ) async {
    final result = await showDialog<_CustomTimeResult>(
      context: context,
      builder: (_) => _CustomTimeDialog(state: state),
    );

    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailCustomSegmentInserted(
            trackableId: target.trackableId,
            modeId: target.modeId,
            startAt: result.startAt,
            endAt: result.endAt,
          ),
        );
  }

  Future<void> _showTrackableEditor(
    BuildContext context,
    SessionDetailLoaded state,
    String trackableId,
  ) async {
    final trackable = state.trackables
        .where((item) => item.id == trackableId)
        .cast<Trackable?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (trackable == null) {
      return;
    }

    final modes = state.modesByTrackable[trackable.id] ?? const [];
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TrackableEditorDialog(
        trackable: trackable,
        modes: modes,
      ),
    );

    if (saved == true && context.mounted) {
      context
          .read<SessionDetailBloc>()
          .add(SessionDetailRequested(sessionId: state.session.id));
    }
  }
}

class _SessionHeader extends StatelessWidget {
  final SessionDetailLoaded state;
  final ValueListenable<DateTime> clock;

  const _SessionHeader({
    required this.state,
    required this.clock,
  });

  @override
  Widget build(BuildContext context) {
    final isFinished = state.session.isFinished;
    final isActive = state.session.isActive;
    final statusColor = _statusColor(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      _statusLabel(state),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.06),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: clock,
                      builder: (context, now, _) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            TimeFormatUtil.formatDuration(
                              _sessionDurationAt(state, now),
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 0,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 82,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton.filledTonal(
                      padding: EdgeInsets.zero,
                      onPressed: isActive
                          ? () {
                              context
                                  .read<SessionDetailBloc>()
                                  .add(const SessionDetailPaused());
                            }
                          : null,
                      icon: const Icon(Icons.pause),
                      tooltip: 'Pause',
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton.filledTonal(
                      padding: EdgeInsets.zero,
                      onPressed:
                          isFinished ? null : () => _confirmFinish(context),
                      icon: const Icon(Icons.stop),
                      tooltip: 'Finish',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmFinish(BuildContext context) async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Finish session?'),
          content: const Text('The current activity will be stopped.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Finish'),
            ),
          ],
        );
      },
    );

    if (shouldFinish == true && context.mounted) {
      context.read<SessionDetailBloc>().add(const SessionDetailFinished());
    }
  }

  String _statusLabel(SessionDetailLoaded state) {
    if (state.session.isActive) {
      return 'Active';
    }
    if (state.session.isPaused) {
      return 'Paused';
    }
    return 'Finished';
  }

  Color _statusColor(SessionDetailLoaded state) {
    if (state.session.isActive) {
      return Colors.green;
    }
    if (state.session.isPaused) {
      return Colors.orange;
    }
    return Colors.grey;
  }
}

class _EditableSessionTitle extends StatefulWidget {
  final String sessionName;

  const _EditableSessionTitle({required this.sessionName});

  @override
  State<_EditableSessionTitle> createState() => _EditableSessionTitleState();
}

class _EditableSessionTitleState extends State<_EditableSessionTitle> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.sessionName;
  }

  @override
  void didUpdateWidget(covariant _EditableSessionTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.sessionName != _controller.text) {
      _controller.text = widget.sessionName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(),
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              onSubmitted: (_) => _submit(context),
            ),
          ),
          IconButton(
            onPressed: () => _submit(context),
            icon: const Icon(Icons.check),
            tooltip: 'Save session name',
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            widget.sessionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        IconButton(
          onPressed: _startEditing,
          icon: const Icon(Icons.edit),
          tooltip: 'Edit session name',
        ),
      ],
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.sessionName;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _submit(BuildContext context) {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      _controller.text = widget.sessionName;
      setState(() => _isEditing = false);
      return;
    }

    context.read<SessionDetailBloc>().add(SessionDetailRenamed(name: name));
    setState(() => _isEditing = false);
  }
}

class SessionEventsDialog extends StatelessWidget {
  const SessionEventsDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Session events'),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Timeline'),
                Tab(text: 'List'),
                Tab(text: 'Analytics'),
              ],
            ),
          ),
          body: BlocBuilder<SessionDetailBloc, SessionDetailState>(
            builder: (context, state) {
              if (state is! SessionDetailLoaded) {
                return const Center(child: CircularProgressIndicator());
              }

              final segments = _sortedSegments(state.segments);
              if (segments.isEmpty) {
                return const Center(child: Text('No events yet'));
              }

              return TabBarView(
                children: [
                  _VisualSessionTimeline(state: state, segments: segments),
                  _SessionEventsList(state: state, segments: segments),
                  _SessionAnalytics(state: state, segments: segments),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionEventsList extends StatelessWidget {
  final SessionDetailLoaded state;
  final List<TimeSegment> segments;

  const _SessionEventsList({
    required this.state,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final segment = segments[index];
        final endAt = segment.endAt;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _EventColorMark(
            color: _trackableColor(state, segment.trackableId),
          ),
          title: Text(_segmentTitle(state, segment)),
          subtitle: Text(
            '${_formatDateTime(segment.startAt)} - '
            '${endAt == null ? 'now' : _formatDateTime(endAt)}',
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                onPressed: () => _editSegment(context, state, segment),
                icon: const Icon(Icons.edit),
                tooltip: 'Edit event',
              ),
              IconButton(
                onPressed: () => _deleteSegment(context, segment),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete event',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSegment(
    BuildContext context,
    SessionDetailLoaded state,
    TimeSegment segment,
  ) async {
    final result = await showDialog<_SegmentTimeEditResult>(
      context: context,
      builder: (_) => _SegmentTimeEditDialog(
        segment: segment,
        now: state.now,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailSegmentUpdated(
            segmentId: segment.id,
            startAt: result.startAt,
            endAt: result.endAt,
          ),
        );
  }

  Future<void> _deleteSegment(
    BuildContext context,
    TimeSegment segment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: const Text('The previous event will fill this time.'),
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
        );
      },
    );

    if (shouldDelete == true && context.mounted) {
      context
          .read<SessionDetailBloc>()
          .add(SessionDetailSegmentDeleted(segmentId: segment.id));
    }
  }
}

class _VisualSessionTimeline extends StatefulWidget {
  final SessionDetailLoaded state;
  final List<TimeSegment> segments;

  const _VisualSessionTimeline({
    required this.state,
    required this.segments,
  });

  @override
  State<_VisualSessionTimeline> createState() => _VisualSessionTimelineState();
}

class _VisualSessionTimelineState extends State<_VisualSessionTimeline> {
  int? _draggingBoundaryIndex;
  DateTime? _pendingBoundaryAt;
  double _zoom = 1;
  double _baseZoom = 1;
  bool _isScaling = false;

  @override
  void didUpdateWidget(covariant _VisualSessionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_draggingBoundaryIndex != null &&
        _draggingBoundaryIndex! >= widget.segments.length - 1) {
      _draggingBoundaryIndex = null;
      _pendingBoundaryAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.segments.first.startAt;
    final end = widget.segments.last.endAt ?? widget.state.now;
    final total = math.max(1, end.difference(start).inSeconds);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(constraints.maxHeight * 1.9 * _zoom, 720.0);
        final pixelsPerSecond = height / total;

        return GestureDetector(
          onScaleStart: (details) {
            _baseZoom = _zoom;
            _isScaling = details.pointerCount > 1;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount < 2) {
              return;
            }
            setState(() {
              _isScaling = true;
              _zoom = (_baseZoom * details.scale).clamp(0.72, 4.0);
            });
          },
          onScaleEnd: (_) {
            Future<void>.delayed(const Duration(milliseconds: 80), () {
              if (mounted) {
                _isScaling = false;
              }
            });
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: SizedBox(
              height: height + 24,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) {
                        if (_isScaling) {
                          return;
                        }
                        final seconds =
                            (details.localPosition.dy / pixelsPerSecond)
                                .round()
                                .clamp(0, total);
                        _addRetrospectiveEvent(
                          context,
                          start.add(Duration(seconds: seconds)),
                        );
                      },
                    ),
                  ),
                  _TimelineScaleRuler(
                    start: start,
                    height: height,
                    totalSeconds: total,
                    pixelsPerSecond: pixelsPerSecond,
                  ),
                  Positioned(
                    left: 112,
                    right: 0,
                    top: 0,
                    child: Text(
                      'Tap empty timeline space to add a past event',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                  for (int i = 0; i < widget.segments.length; i++)
                    _TimelineEventBlock(
                      state: widget.state,
                      segment: widget.segments[i],
                      top: widget.segments[i].startAt
                              .difference(start)
                              .inSeconds *
                          pixelsPerSecond,
                      height: math.max(
                        34,
                        (widget.segments[i].endAt ?? widget.state.now)
                                .difference(widget.segments[i].startAt)
                                .inSeconds *
                            pixelsPerSecond,
                      ),
                      onDeleteRequested: () => _confirmDeleteEvent(
                        context,
                        widget.segments[i],
                      ),
                    ),
                  for (int i = 0; i < widget.segments.length - 1; i++)
                    _TimelineBoundaryHandle(
                      top: ((_pendingBoundaryAt != null &&
                                      _draggingBoundaryIndex == i
                                  ? _pendingBoundaryAt!
                                  : widget.segments[i].endAt ??
                                      widget.segments[i + 1].startAt)
                              .difference(start)
                              .inSeconds *
                          pixelsPerSecond),
                      label: _formatTime(
                        _pendingBoundaryAt != null &&
                                _draggingBoundaryIndex == i
                            ? _pendingBoundaryAt!
                            : widget.segments[i].endAt ??
                                widget.segments[i + 1].startAt,
                      ),
                      onDragStart: () {
                        setState(() {
                          _draggingBoundaryIndex = i;
                          _pendingBoundaryAt = widget.segments[i].endAt ??
                              widget.segments[i + 1].startAt;
                        });
                      },
                      onDragUpdate: (details) {
                        final current = _pendingBoundaryAt ??
                            widget.segments[i].endAt ??
                            widget.segments[i + 1].startAt;
                        final secondsDelta =
                            (details.delta.dy / pixelsPerSecond).round();
                        final raw =
                            current.add(Duration(seconds: secondsDelta));
                        final min = widget.segments[i].startAt
                            .add(const Duration(minutes: 1));
                        final max =
                            (widget.segments[i + 1].endAt ?? widget.state.now)
                                .subtract(const Duration(minutes: 1));
                        setState(() {
                          _pendingBoundaryAt = _clampDateTime(raw, min, max);
                        });
                      },
                      onDragEnd: () {
                        final boundaryAt = _pendingBoundaryAt;
                        setState(() {
                          _draggingBoundaryIndex = null;
                          _pendingBoundaryAt = null;
                        });
                        if (boundaryAt == null) {
                          return;
                        }
                        context.read<SessionDetailBloc>().add(
                              SessionDetailSegmentBoundaryMoved(
                                previousSegmentId: widget.segments[i].id,
                                nextSegmentId: widget.segments[i + 1].id,
                                boundaryAt: boundaryAt,
                              ),
                            );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addRetrospectiveEvent(
    BuildContext context,
    DateTime startAt,
  ) async {
    final result = await showDialog<_RetrospectiveEventResult>(
      context: context,
      builder: (_) => _RetrospectiveEventDialog(
        startAt: startAt,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }

    context.read<SessionDetailBloc>().add(
          SessionDetailRetrospectiveSegmentInserted(
            trackableId: result.trackableId,
            modeId: result.modeId,
            startAt: startAt,
          ),
        );
  }

  Future<void> _confirmDeleteEvent(
    BuildContext context,
    TimeSegment segment,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: Text(_segmentTitle(widget.state, segment)),
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
        );
      },
    );
    if (shouldDelete == true && context.mounted) {
      context
          .read<SessionDetailBloc>()
          .add(SessionDetailSegmentDeleted(segmentId: segment.id));
    }
  }
}

class _TimelineEventBlock extends StatelessWidget {
  final SessionDetailLoaded state;
  final TimeSegment segment;
  final double top;
  final double height;
  final VoidCallback onDeleteRequested;

  const _TimelineEventBlock({
    required this.state,
    required this.segment,
    required this.top,
    required this.height,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = _trackableColor(state, segment.trackableId);
    final foreground =
        ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark
            ? Colors.white
            : Colors.black.withValues(alpha: 0.82);

    return Positioned(
      left: 112,
      right: 0,
      top: top,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        onLongPress: onDeleteRequested,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ColorUtils.lighten(baseColor, 0.12),
                baseColor,
                ColorUtils.darken(baseColor, 0.16),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 48;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _segmentTitle(state, segment),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: compact ? 13 : null,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!compact)
                      Text(
                        '${_formatTime(segment.startAt)} - '
                        '${segment.endAt == null ? 'now' : _formatTime(segment.endAt!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.74),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineScaleRuler extends StatelessWidget {
  final DateTime start;
  final double height;
  final int totalSeconds;
  final double pixelsPerSecond;

  const _TimelineScaleRuler({
    required this.start,
    required this.height,
    required this.totalSeconds,
    required this.pixelsPerSecond,
  });

  @override
  Widget build(BuildContext context) {
    final interval = _intervalForScale(pixelsPerSecond);
    final tickCount = (totalSeconds / interval.inSeconds).ceil();

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 104,
      child: Stack(
        children: [
          Positioned(
            left: 88,
            top: 0,
            bottom: 0,
            child: Container(
              width: 2,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.38),
            ),
          ),
          for (int i = 0; i <= tickCount; i++)
            _TimelineScaleTick(
              top: math.min(height, i * interval.inSeconds * pixelsPerSecond),
              label: _formatTime(start.add(interval * i)),
              isMajor: i.isEven,
            ),
        ],
      ),
    );
  }

  Duration _intervalForScale(double pixelsPerSecond) {
    final pixelsPerMinute = pixelsPerSecond * 60;
    if (pixelsPerMinute >= 24) {
      return const Duration(minutes: 5);
    }
    if (pixelsPerMinute >= 10) {
      return const Duration(minutes: 15);
    }
    if (pixelsPerMinute >= 4) {
      return const Duration(minutes: 30);
    }
    return const Duration(hours: 1);
  }
}

class _TimelineScaleTick extends StatelessWidget {
  final double top;
  final String label;
  final bool isMajor;

  const _TimelineScaleTick({
    required this.top,
    required this.label,
    required this.isMajor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top - 10,
      height: 20,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: isMajor
                ? Text(
                    label,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelMedium,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Container(
            width: isMajor ? 18 : 10,
            height: 2,
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: isMajor ? 0.74 : 0.32),
          ),
        ],
      ),
    );
  }
}

class _EventColorMark extends StatelessWidget {
  final Color color;

  const _EventColorMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorUtils.lighten(color, 0.10),
            color,
            ColorUtils.darken(color, 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TimelineBoundaryHandle extends StatelessWidget {
  final double top;
  final String label;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  const _TimelineBoundaryHandle({
    required this.top,
    required this.label,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top - 16,
      height: 32,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => onDragStart(),
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: (_) => onDragEnd(),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionAnalytics extends StatelessWidget {
  final SessionDetailLoaded state;
  final List<TimeSegment> segments;

  const _SessionAnalytics({
    required this.state,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final totals = <String, _AnalyticsRow>{};
    for (final segment in segments) {
      final key = segment.trackableId;
      final existing = totals[key];
      final duration = segment.durationUntil(state.now);
      totals[key] = _AnalyticsRow(
        title: _trackableName(state, segment.trackableId),
        color: _trackableColor(state, segment.trackableId),
        duration: (existing?.duration ?? Duration.zero) + duration,
      );
    }
    final rows = totals.values.toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
    final totalDuration = rows.fold<Duration>(
      Duration.zero,
      (total, row) => total + row.duration,
    );
    final totalSeconds = math.max(1, totalDuration.inSeconds);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in rows) ...[
          _AnalyticsActivityRow(
            row: row,
            percent: row.duration.inSeconds / totalSeconds,
          ),
          const Divider(height: 1),
        ],
        const SizedBox(height: 24),
        _AnalyticsPieChart(rows: rows),
      ],
    );
  }
}

class _AnalyticsRow {
  final String title;
  final Color color;
  final Duration duration;

  const _AnalyticsRow({
    required this.title,
    required this.color,
    required this.duration,
  });
}

class _AnalyticsActivityRow extends StatelessWidget {
  final _AnalyticsRow row;
  final double percent;

  const _AnalyticsActivityRow({
    required this.row,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(percent * 100).round()}%';

    return SizedBox(
      height: 58,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                width: constraints.maxWidth * percent.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        row.color.withValues(alpha: 0.28),
                        row.color.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _EventColorMark(color: row.color),
                title: Text(row.title),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      percentLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      TimeFormatUtil.formatDuration(row.duration),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsPieChart extends StatelessWidget {
  final List<_AnalyticsRow> rows;

  const _AnalyticsPieChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 220,
      child: Center(
        child: CustomPaint(
          size: const Size.square(180),
          painter: _AnalyticsPiePainter(rows: rows),
        ),
      ),
    );
  }
}

class _AnalyticsPiePainter extends CustomPainter {
  final List<_AnalyticsRow> rows;

  const _AnalyticsPiePainter({required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final totalSeconds = math.max(
      1,
      rows.fold<int>(0, (total, row) => total + row.duration.inSeconds),
    );
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    var startAngle = -math.pi / 2;

    for (final row in rows) {
      final sweep = row.duration.inSeconds / totalSeconds * math.pi * 2;
      paint.shader = RadialGradient(
        colors: [
          ColorUtils.lighten(row.color, 0.12),
          row.color,
          ColorUtils.darken(row.color, 0.12),
        ],
      ).createShader(rect);
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }

    final holePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(
        size.center(Offset.zero), size.shortestSide * 0.24, holePaint);
  }

  @override
  bool shouldRepaint(covariant _AnalyticsPiePainter oldDelegate) {
    return oldDelegate.rows != rows;
  }
}

class _RetrospectiveEventDialog extends StatefulWidget {
  final DateTime startAt;

  const _RetrospectiveEventDialog({
    required this.startAt,
  });

  @override
  State<_RetrospectiveEventDialog> createState() =>
      _RetrospectiveEventDialogState();
}

class _RetrospectiveEventDialogState extends State<_RetrospectiveEventDialog> {
  final TextEditingController _newTrackableController = TextEditingController();
  late Future<_RetrospectivePickerData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _newTrackableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add event at ${_formatDateTime(widget.startAt)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTrackableController,
                      decoration: const InputDecoration(
                        labelText: 'New activity',
                      ),
                      onSubmitted: (_) => _createNewTrackable(context),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _createNewTrackable(context),
                    icon: const Icon(Icons.add),
                    tooltip: 'Create activity',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<_RetrospectivePickerData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final data = snapshot.data!;
                  if (data.trackables.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No saved activities yet'),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final trackable in data.trackables) ...[
                        TrackableButton(
                          trackable: trackable,
                          modes: data.modesByTrackable[trackable.id] ?? [],
                          duration: Duration.zero,
                          isActive: false,
                          showTimer: false,
                          animated: false,
                          activeModeId: null,
                          onModeTap: (modeId) => Navigator.of(context).pop(
                            _RetrospectiveEventResult(
                              trackableId: trackable.id,
                              modeId: modeId,
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.08),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<_RetrospectivePickerData> _load() async {
    final repository = context.read<TrackableRepository>();
    final trackables = await repository.getTrackables();
    final modesByTrackable = <String, List<TrackableMode>>{};

    for (final trackable in trackables) {
      modesByTrackable[trackable.id] = await repository.getModes(trackable.id);
    }

    return _RetrospectivePickerData(
      trackables: trackables,
      modesByTrackable: modesByTrackable,
    );
  }

  Future<void> _createNewTrackable(BuildContext context) async {
    final name = _newTrackableController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    final trackableId = const Uuid().v4();
    final modeId = const Uuid().v4();
    await repository.saveTrackable(
      Trackable(
        id: trackableId,
        name: name,
        color: ColorUtils.toHex(ColorUtils.generateRandomLightColor()),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveMode(
      TrackableMode(
        id: modeId,
        trackableId: trackableId,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (context.mounted) {
      Navigator.of(context).pop(
        _RetrospectiveEventResult(
          trackableId: trackableId,
          modeId: modeId,
        ),
      );
    }
  }
}

class _RetrospectiveEventResult {
  final String trackableId;
  final String modeId;

  const _RetrospectiveEventResult({
    required this.trackableId,
    required this.modeId,
  });
}

class _RetrospectivePickerData {
  final List<Trackable> trackables;
  final Map<String, List<TrackableMode>> modesByTrackable;

  const _RetrospectivePickerData({
    required this.trackables,
    required this.modesByTrackable,
  });
}

class _SegmentTimeEditDialog extends StatefulWidget {
  final TimeSegment segment;
  final DateTime now;

  const _SegmentTimeEditDialog({
    required this.segment,
    required this.now,
  });

  @override
  State<_SegmentTimeEditDialog> createState() => _SegmentTimeEditDialogState();
}

class _SegmentTimeEditDialogState extends State<_SegmentTimeEditDialog> {
  late DateTime _startAt;
  late DateTime _endAt;
  late bool _isOpen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startAt = widget.segment.startAt;
    _endAt = widget.segment.endAt ?? widget.now;
    _isOpen = widget.segment.endAt == null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit event'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(_formatDateTime(_startAt)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickStart(context),
          ),
          if (!_isOpen)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(_formatDateTime(_endAt)),
              trailing: const Icon(Icons.event_available),
              onTap: () => _pickEnd(context),
            ),
          if (widget.segment.endAt == null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isOpen,
              onChanged: (value) => setState(() => _isOpen = value ?? true),
              title: const Text('Still running'),
            ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked = await _pickDateTime(context, _startAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _startAt = picked;
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 1));
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await _pickDateTime(context, _endAt);
    if (picked == null) {
      return;
    }
    setState(() => _endAt = picked);
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(widget.now.year - 5),
      lastDate: widget.now,
      initialDate: initial.isAfter(widget.now) ? widget.now : initial,
    );
    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  void _submit() {
    final endAt = _isOpen ? null : _endAt;
    if (_startAt.isAfter(widget.now) ||
        (endAt != null && endAt.isAfter(widget.now))) {
      setState(() => _error = 'Time cannot be in the future');
      return;
    }
    if (endAt != null && !endAt.isAfter(_startAt)) {
      setState(() => _error = 'End must be after start');
      return;
    }

    Navigator.of(context).pop(
      _SegmentTimeEditResult(startAt: _startAt, endAt: endAt),
    );
  }
}

class _SegmentTimeEditResult {
  final DateTime startAt;
  final DateTime? endAt;

  const _SegmentTimeEditResult({
    required this.startAt,
    required this.endAt,
  });
}

List<TimeSegment> _sortedSegments(List<TimeSegment> segments) {
  return [...segments]..sort((a, b) => a.startAt.compareTo(b.startAt));
}

Duration _durationForTrackableAt(
  SessionDetailLoaded state,
  String trackableId,
  DateTime now,
) {
  return state.segments
      .where((segment) => segment.trackableId == trackableId)
      .fold<Duration>(
        Duration.zero,
        (duration, segment) => duration + segment.durationUntil(now),
      );
}

Duration _sessionDurationAt(SessionDetailLoaded state, DateTime now) {
  return state.segments.fold<Duration>(
    Duration.zero,
    (duration, segment) => duration + segment.durationUntil(now),
  );
}

String _segmentTitle(SessionDetailLoaded state, TimeSegment segment) {
  final trackableName = _trackableName(state, segment.trackableId);
  final modeName = _modeName(state, segment.trackableId, segment.modeId);
  return modeName == TrackableMode.mainName
      ? trackableName
      : '$trackableName / $modeName';
}

String _trackableName(SessionDetailLoaded state, String trackableId) {
  for (final trackable in state.trackables) {
    if (trackable.id == trackableId) {
      return trackable.name;
    }
  }
  return 'Removed activity';
}

Color _trackableColor(SessionDetailLoaded state, String trackableId) {
  for (final trackable in state.trackables) {
    if (trackable.id == trackableId) {
      return ColorUtils.fromHex(trackable.color);
    }
  }
  return Colors.blueGrey;
}

String _modeName(
  SessionDetailLoaded state,
  String trackableId,
  String modeId,
) {
  final modes = state.modesByTrackable[trackableId] ?? const [];
  for (final mode in modes) {
    if (mode.id == modeId) {
      return mode.name;
    }
  }
  return TrackableMode.mainName;
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _formatTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

DateTime _clampDateTime(DateTime value, DateTime min, DateTime max) {
  if (max.isBefore(min)) {
    return min;
  }
  if (value.isBefore(min)) {
    return min;
  }
  if (value.isAfter(max)) {
    return max;
  }
  return value;
}

class _SessionTrackablesList extends StatelessWidget {
  final SessionDetailLoaded state;
  final ValueListenable<DateTime> clock;
  final void Function(
    String trackableId,
    String modeId,
    Offset globalPosition,
  ) onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final ValueChanged<Offset> onLongPressEnd;

  const _SessionTrackablesList({
    required this.state,
    required this.clock,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (state.trackables.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Choose an activity to start this session'),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: state.trackables.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, index) {
        final trackable = state.trackables[index];
        final isActive = state.activeTrackableId == trackable.id;
        return _TrackableButtonWithLiveTimer(
          key: ValueKey(trackable.id),
          clock: clock,
          state: state,
          trackable: trackable,
          isActive: isActive,
          onModeTap: (modeId) {
            context.read<SessionDetailBloc>().add(
                  SessionDetailTrackableSelected(
                    trackableId: trackable.id,
                    modeId: modeId,
                  ),
                );
          },
          onLongPressStart: (modeId, globalPosition) {
            onLongPressStart(trackable.id, modeId, globalPosition);
          },
          onLongPressMove: (globalPosition) {
            onLongPressMove(globalPosition);
          },
          onLongPressEnd: (globalPosition) {
            onLongPressEnd(globalPosition);
          },
        );
      },
    );
  }
}

class _TrackableButtonWithLiveTimer extends StatefulWidget {
  final ValueListenable<DateTime> clock;
  final SessionDetailLoaded state;
  final Trackable trackable;
  final bool isActive;
  final ValueChanged<String> onModeTap;
  final void Function(String modeId, Offset globalPosition) onLongPressStart;
  final ValueChanged<Offset> onLongPressMove;
  final ValueChanged<Offset> onLongPressEnd;

  const _TrackableButtonWithLiveTimer({
    super.key,
    required this.clock,
    required this.state,
    required this.trackable,
    required this.isActive,
    required this.onModeTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
  });

  @override
  State<_TrackableButtonWithLiveTimer> createState() =>
      _TrackableButtonWithLiveTimerState();
}

class _TrackableButtonWithLiveTimerState
    extends State<_TrackableButtonWithLiveTimer> {
  late _ComputedDurationListenable _durationListenable;

  @override
  void initState() {
    super.initState();
    _durationListenable = _createDurationListenable();
  }

  @override
  void didUpdateWidget(covariant _TrackableButtonWithLiveTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock ||
        oldWidget.state.segments != widget.state.segments ||
        oldWidget.trackable.id != widget.trackable.id) {
      _durationListenable.dispose();
      _durationListenable = _createDurationListenable();
    }
  }

  @override
  void dispose() {
    _durationListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TrackableButton(
      trackable: widget.trackable,
      modes: widget.state.modesByTrackable[widget.trackable.id] ?? const [],
      duration: _durationForTrackableAt(
        widget.state,
        widget.trackable.id,
        widget.clock.value,
      ),
      durationListenable: _durationListenable,
      isActive: widget.isActive,
      enabled: !widget.state.session.isFinished,
      activeModeId: widget.state.activeModeId,
      onModeTap: widget.onModeTap,
      onModeLongPressStart: widget.onLongPressStart,
      onModeLongPressMove: (_, globalPosition) {
        widget.onLongPressMove(globalPosition);
      },
      onModeLongPressEnd: (_, globalPosition) {
        widget.onLongPressEnd(globalPosition);
      },
    );
  }

  _ComputedDurationListenable _createDurationListenable() {
    return _ComputedDurationListenable(
      clock: widget.clock,
      compute: (now) => _durationForTrackableAt(
        widget.state,
        widget.trackable.id,
        now,
      ),
    );
  }
}

class _ComputedDurationListenable extends ChangeNotifier
    implements ValueListenable<Duration> {
  final ValueListenable<DateTime> clock;
  final Duration Function(DateTime now) compute;

  _ComputedDurationListenable({
    required this.clock,
    required this.compute,
  }) {
    clock.addListener(_notify);
  }

  @override
  Duration get value => compute(clock.value);

  void _notify() => notifyListeners();

  @override
  void dispose() {
    clock.removeListener(_notify);
    super.dispose();
  }
}

class _CustomTimeDialog extends StatefulWidget {
  final SessionDetailLoaded state;

  const _CustomTimeDialog({required this.state});

  @override
  State<_CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<_CustomTimeDialog> {
  late DateTime _startAt;
  late DateTime _endAt;
  bool _wasFinished = false;
  String? _startError;
  String? _endError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startAt = now.subtract(const Duration(minutes: 10));
    _endAt = now;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(_formatDateTime(_startAt)),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickStart(context),
          ),
          if (_startError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _startError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _wasFinished,
            onChanged: (value) {
              setState(() {
                _wasFinished = value ?? false;
                if (_endAt.isBefore(_startAt)) {
                  _endAt = _startAt.add(const Duration(minutes: 1));
                }
              });
            },
            title: const Text('Was finished'),
          ),
          if (_wasFinished)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(_formatDateTime(_endAt)),
              trailing: const Icon(Icons.event_available),
              onTap: () => _pickEnd(context),
            ),
          if (_endError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _endError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  bool _validate() {
    _startError = null;
    _endError = null;
    final now = DateTime.now();
    if (_startAt.isAfter(now)) {
      _startError = 'Start time cannot be in the future';
      return false;
    }
    if (!_wasFinished) {
      return true;
    }
    if (!_endAt.isAfter(_startAt)) {
      _endError = 'End time must be after start time';
      return false;
    }
    if (_endAt.isAfter(now)) {
      _endError = 'End time cannot be in the future';
      return false;
    }
    final intersections = widget.state.segments.where((segment) {
      final segmentEnd = segment.endAt ?? now;
      return segment.startAt.isBefore(_endAt) && segmentEnd.isAfter(_startAt);
    }).length;
    if (intersections != 1) {
      _startError = 'Range must be inside one tracked interval';
      _endError = 'Adjust the end time to fit one interval';
      return false;
    }
    return true;
  }

  void _submit() {
    setState(() {});
    if (!_validate()) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      _CustomTimeResult(
        startAt: _startAt,
        endAt: _wasFinished ? _endAt : null,
      ),
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked = await _pickDateTime(context, _startAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _startAt = picked;
      if (_endAt.isBefore(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 1));
      }
      final now = DateTime.now();
      if (_endAt.isAfter(now)) {
        _endAt = now;
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await _pickDateTime(context, _endAt);
    if (picked == null) {
      return;
    }
    setState(() {
      _endAt = picked;
    });
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDate: initial.isAfter(now) ? now : initial,
    );
    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    final date =
        '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year}';
    final time = '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
    return '$date $time';
  }
}

class _CustomTimeResult {
  final DateTime startAt;
  final DateTime? endAt;

  const _CustomTimeResult({
    required this.startAt,
    this.endAt,
  });
}

class _TrackableEditorDialog extends StatefulWidget {
  final Trackable trackable;
  final List<TrackableMode> modes;

  const _TrackableEditorDialog({
    required this.trackable,
    required this.modes,
  });

  @override
  State<_TrackableEditorDialog> createState() => _TrackableEditorDialogState();
}

class _TrackableEditorDialogState extends State<_TrackableEditorDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newModeController = TextEditingController();
  final ScrollController _modesScrollController = ScrollController();
  late String _selectedColor;
  late List<String> _suggestedColors;
  late List<_EditableMode> _modes;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.trackable.name;
    _selectedColor = widget.trackable.color;
    _suggestedColors = [
      widget.trackable.color,
      for (int i = 0; i < 3; i++)
        ColorUtils.toHex(ColorUtils.generateRandomLightColor()),
    ];
    _modes = widget.modes
        .map((mode) => _EditableMode.fromExisting(mode))
        .toList(growable: true);
    if (_modes.isEmpty) {
      _modes.add(_EditableMode.newMode(TrackableMode.mainName));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newModeController.dispose();
    _modesScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit activity'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in _suggestedColors)
                    _ColorChoice(
                      color: ColorUtils.fromHex(color),
                      isSelected: color == _selectedColor,
                      onTap: () => setState(() => _selectedColor = color),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: ReorderableListView.builder(
                  scrollController: _modesScrollController,
                  buildDefaultDragHandles: false,
                  itemCount: _modes.length,
                  onReorder: _reorderMode,
                  itemBuilder: (context, index) {
                    final mode = _modes[index];
                    return ListTile(
                      key: ValueKey(mode.localId),
                      contentPadding: EdgeInsets.zero,
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: TextFormField(
                        initialValue: mode.name,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => mode.name = value,
                      ),
                      trailing: IconButton(
                        onPressed: _modes.length <= 1
                            ? null
                            : () => setState(() => _modes.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newModeController,
                      decoration: const InputDecoration(labelText: 'New mode'),
                      onSubmitted: (_) => _addMode(),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _addMode,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _addMode() {
    final name = _newModeController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() {
      _modes.add(_EditableMode.newMode(name));
      _newModeController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_modesScrollController.hasClients) {
        return;
      }
      _modesScrollController.animateTo(
        _modesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _reorderMode(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final mode = _modes.removeAt(oldIndex);
      _modes.insert(newIndex, mode);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final activeModes =
        _modes.where((mode) => mode.name.trim().isNotEmpty).toList();
    if (name.isEmpty || activeModes.isEmpty) {
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    await repository.updateTrackable(
      Trackable(
        id: widget.trackable.id,
        name: name,
        color: _selectedColor,
        archivedAt: widget.trackable.archivedAt,
        createdAt: widget.trackable.createdAt,
        updatedAt: now,
      ),
    );

    final activeExistingIds = activeModes
        .where((mode) => mode.existing != null)
        .map((mode) => mode.existing!.id)
        .toSet();
    for (final existing in widget.modes) {
      if (!activeExistingIds.contains(existing.id)) {
        await repository.updateMode(existing.copyWith(archivedAt: now));
      }
    }

    for (int index = 0; index < activeModes.length; index++) {
      final editable = activeModes[index];
      final existing = editable.existing;
      if (existing == null) {
        await repository.saveMode(
          TrackableMode(
            id: const Uuid().v4(),
            trackableId: widget.trackable.id,
            name: editable.name.trim(),
            sortOrder: index,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await repository.updateMode(
          TrackableMode(
            id: existing.id,
            trackableId: existing.trackableId,
            name: editable.name.trim(),
            sortOrder: index,
            archivedAt: existing.archivedAt,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _EditableMode {
  final String localId;
  final TrackableMode? existing;
  String name;

  _EditableMode({
    required this.localId,
    required this.name,
    this.existing,
  });

  factory _EditableMode.fromExisting(TrackableMode mode) {
    return _EditableMode(
      localId: mode.id,
      existing: mode,
      name: mode.name,
    );
  }

  factory _EditableMode.newMode(String name) {
    return _EditableMode(
      localId: const Uuid().v4(),
      name: name,
    );
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}

class _TrackableActionSliderOverlay extends StatelessWidget {
  final _TrackableSliderAction? selectedAction;
  final Set<_TrackableSliderAction> disabledActions;

  const _TrackableActionSliderOverlay({
    required this.selectedAction,
    required this.disabledActions,
  });

  @override
  Widget build(BuildContext context) {
    const leftActions = _TrackableSliderAction.leftActions;
    const rightActions = _TrackableSliderAction.rightActions;

    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: double.infinity,
        height: 92,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              selectedAction?.description ?? 'Start now',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        for (final action in leftActions)
                          Expanded(
                            child: _TrackableActionSliderCell(
                              action: action,
                              isSelected: action == selectedAction,
                              isDisabled: disabledActions.contains(action),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: _TrackableActionSliderCell(
                      action: _TrackableSliderAction.startNow,
                      isSelected:
                          selectedAction == _TrackableSliderAction.startNow,
                      isDisabled: disabledActions.contains(
                        _TrackableSliderAction.startNow,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        for (final action in rightActions)
                          Expanded(
                            child: _TrackableActionSliderCell(
                              action: action,
                              isSelected: action == selectedAction,
                              isDisabled: disabledActions.contains(action),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackableActionSliderCell extends StatelessWidget {
  final _TrackableSliderAction action;
  final bool isSelected;
  final bool isDisabled;

  const _TrackableActionSliderCell({
    required this.action,
    required this.isSelected,
    required this.isDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isDisabled
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.46)
        : isSelected
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest;
    final foreground = isDisabled
        ? colorScheme.onSurface.withValues(alpha: 0.34)
        : isSelected
            ? colorScheme.onPrimary
            : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          action.label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _LongPressTrackableTarget {
  final String trackableId;
  final String modeId;

  const _LongPressTrackableTarget({
    required this.trackableId,
    required this.modeId,
  });
}

enum _TrackableSliderActionKind {
  backdate,
  startNow,
  customTime,
  edit,
  archive,
}

class _TrackableSliderAction {
  final String label;
  final String description;
  final _TrackableSliderActionKind kind;
  final Duration? backdateOffset;

  const _TrackableSliderAction._({
    required this.label,
    required this.description,
    required this.kind,
    this.backdateOffset,
  });

  static const twoHours = _TrackableSliderAction._(
    label: '2h',
    description: 'Start 2 hours ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(hours: 2),
  );
  static const oneHour = _TrackableSliderAction._(
    label: '1h',
    description: 'Start 1 hour ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(hours: 1),
  );
  static const fortyMinutes = _TrackableSliderAction._(
    label: '40m',
    description: 'Start 40 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 40),
  );
  static const twentyMinutes = _TrackableSliderAction._(
    label: '20m',
    description: 'Start 20 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 20),
  );
  static const tenMinutes = _TrackableSliderAction._(
    label: '10m',
    description: 'Start 10 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 10),
  );
  static const fiveMinutes = _TrackableSliderAction._(
    label: '5m',
    description: 'Start 5 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 5),
  );
  static const threeMinutes = _TrackableSliderAction._(
    label: '3m',
    description: 'Start 3 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 3),
  );
  static const twoMinutes = _TrackableSliderAction._(
    label: '2m',
    description: 'Start 2 minutes ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 2),
  );
  static const oneMinute = _TrackableSliderAction._(
    label: '1m',
    description: 'Start 1 minute ago',
    kind: _TrackableSliderActionKind.backdate,
    backdateOffset: Duration(minutes: 1),
  );
  static const customTime = _TrackableSliderAction._(
    label: 'Time',
    description: 'Choose custom time',
    kind: _TrackableSliderActionKind.customTime,
  );
  static const startNow = _TrackableSliderAction._(
    label: 'Now',
    description: 'Start now',
    kind: _TrackableSliderActionKind.startNow,
  );
  static const edit = _TrackableSliderAction._(
    label: 'Edit',
    description: 'Edit activity',
    kind: _TrackableSliderActionKind.edit,
  );
  static const archive = _TrackableSliderAction._(
    label: 'Archive',
    description: 'Archive activity',
    kind: _TrackableSliderActionKind.archive,
  );

  static const leftActions = [
    customTime,
    twoHours,
    oneHour,
    fortyMinutes,
    twentyMinutes,
    tenMinutes,
    fiveMinutes,
    threeMinutes,
    twoMinutes,
    oneMinute,
  ];

  static const rightActions = [
    edit,
    archive,
  ];

  static _TrackableSliderAction? fromLocalPosition({
    required Offset localPosition,
    required double width,
    required double sliderTop,
    required Set<_TrackableSliderAction> disabledActions,
  }) {
    const sliderHeight = 92.0;
    const actionTop = 36.0;
    if (localPosition.dy < sliderTop + actionTop ||
        localPosition.dy > sliderTop + sliderHeight) {
      return null;
    }

    const centerWidth = 72.0;
    final centerStart = (width - centerWidth) / 2;
    final centerEnd = centerStart + centerWidth;
    final clampedDx = localPosition.dx;

    if (clampedDx < 0 || clampedDx > width) {
      return null;
    }

    if (clampedDx >= centerStart && clampedDx <= centerEnd) {
      return disabledActions.contains(startNow) ? null : startNow;
    }

    if (clampedDx < centerStart) {
      final index = (clampedDx / centerStart * leftActions.length)
          .floor()
          .clamp(0, leftActions.length - 1);
      final action = leftActions[index];
      return disabledActions.contains(action) ? null : action;
    }

    final rightWidth = width - centerEnd;
    final index = ((clampedDx - centerEnd) / rightWidth * rightActions.length)
        .floor()
        .clamp(0, rightActions.length - 1);
    final action = rightActions[index];
    return disabledActions.contains(action) ? null : action;
  }
}
