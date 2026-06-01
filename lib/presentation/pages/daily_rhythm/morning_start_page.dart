import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/daily_rhythm/morning_start_service.dart';
import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';
import 'package:time_tracker/domain/repositories/session_v2_repository.dart';
import 'package:time_tracker/domain/repositories/timeline_repository.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/pages/session_detail_page.dart';
import 'package:time_tracker/presentation/widgets/trackable_button.dart';
import 'package:uuid/uuid.dart';

class MorningStartPage extends StatefulWidget {
  const MorningStartPage({super.key});

  @override
  State<MorningStartPage> createState() => _MorningStartPageState();
}

class _MorningStartPageState extends State<MorningStartPage>
    with SingleTickerProviderStateMixin {
  late final MorningStartService _service;
  late final TrackableRepository _trackableRepository;
  late final AnimationController _flowController;
  late Future<_MorningStartData> _dataFuture;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String? _firstActivityId;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _trackableRepository = context.read<TrackableRepository>();
    _service = MorningStartService(
      dailyRhythmRepository: context.read<DailyRhythmRepository>(),
      sessionRepository: context.read<SessionV2Repository>(),
      trackableRepository: _trackableRepository,
      timelineRepository: context.read<TimelineRepository>(),
    );
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
    )..repeat();
    _searchController.addListener(() => setState(() {}));
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _flowController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<_MorningStartData> _loadData() async {
    final existingDay = await _service.getTodayDaySession();
    if (existingDay != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionDetailPage(sessionId: existingDay.id),
          ),
        );
      });
      return const _MorningStartData.empty();
    }

    final suggested = await _service.suggestedActivitiesForMorningStart();
    final allActivities = await _trackableRepository.getTrackables();
    final merged = _mergeActivities(suggested, allActivities);
    _selectedIds
      ..clear()
      ..addAll(suggested.map((activity) => activity.id));
    _firstActivityId = suggested.isNotEmpty ? suggested.first.id : null;
    return _MorningStartData(suggested: suggested, allActivities: merged);
  }

  Future<void> _addOrSelectActivity(_MorningStartData data) async {
    final name = _searchController.text.trim();
    if (name.isEmpty) return;

    final exact = data.allActivities
        .where((activity) => _normalize(activity.name) == _normalize(name))
        .firstOrNull;
    final activity = exact ?? await _createActivityLikeSession(name);
    if (activity == null) {
      return;
    }
    _searchController.clear();
    setState(() {
      _selectedIds.add(activity.id);
      _firstActivityId ??= activity.id;
      _dataFuture = _dataFuture.then((current) {
        return current.copyWith(
          allActivities: _mergeActivities([activity], current.allActivities),
        );
      });
    });
  }

  Future<void> _startDay(_MorningStartData data) async {
    final selected = data.allActivities
        .where((activity) => _selectedIds.contains(activity.id))
        .map((activity) => activity.id)
        .toList();
    final firstActivityId = _firstActivityId;
    if (selected.isEmpty || firstActivityId == null) return;

    setState(() => _starting = true);
    final notificationService = context.read<DailyRhythmNotificationService>();
    try {
      final sessionId = await _service.startDay(
        selectedActivityIds: selected,
        firstActivityId: firstActivityId,
      );
      await notificationService.refreshDailyNudges();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionDetailPage(sessionId: sessionId),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Start Day'),
        backgroundColor: Colors.transparent,
      ),
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
        child: FutureBuilder<_MorningStartData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? const _MorningStartData.empty();
            if (data.allActivities.isEmpty) {
              return const SizedBox.shrink();
            }

            final selectedActivities = data.allActivities
                .where((activity) => _selectedIds.contains(activity.id))
                .toList();
            final query = _searchController.text.trim();
            final filteredActivities = _filteredActivities(data, query);
            final exactExists = data.allActivities.any(
              (activity) => _normalize(activity.name) == _normalize(query),
            );

            return SafeArea(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _MorningHero(
                    controller: _flowController,
                    selectedCount: selectedActivities.length,
                  ),
                  const SizedBox(height: 18),
                  _GlassPanel(
                    borderColor:
                        const Color(0xFF8B35FF).withValues(alpha: 0.34),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today activities',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Search from your activities. Create a new one only when it is not there yet.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.58),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addOrSelectActivity(data),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              labelText: 'Find activity',
                              hintText: 'Work, Walk, Music',
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (query.isNotEmpty && !exactExists)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CreateActivityButton(
                                label: query,
                                onPressed: () => _addOrSelectActivity(data),
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Column(
                              key: ValueKey(query),
                              children: [
                                for (final activity in filteredActivities)
                                  _ActivityChoiceTile(
                                    activity: activity,
                                    selected:
                                        _selectedIds.contains(activity.id),
                                    suggested: data.suggested.any(
                                      (item) => item.id == activity.id,
                                    ),
                                    onChanged: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedIds.add(activity.id);
                                          _firstActivityId ??= activity.id;
                                        } else {
                                          _selectedIds.remove(activity.id);
                                          if (_firstActivityId == activity.id) {
                                            _firstActivityId =
                                                _selectedIds.isEmpty
                                                    ? null
                                                    : _selectedIds.first;
                                          }
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _GlassPanel(
                    borderColor:
                        const Color(0xFF14B8A6).withValues(alpha: 0.26),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start with',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (selectedActivities.isEmpty)
                            Text(
                              'Pick at least one activity for today.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.56),
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final activity in selectedActivities)
                                  _StartWithChip(
                                    activity: activity,
                                    selected: _firstActivityId == activity.id,
                                    onTap: () {
                                      setState(
                                        () => _firstActivityId = activity.id,
                                      );
                                    },
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _StartDayButton(
                    starting: _starting,
                    enabled: selectedActivities.isNotEmpty &&
                        _firstActivityId != null,
                    onPressed: () => _startDay(data),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Trackable> _filteredActivities(_MorningStartData data, String query) {
    final normalized = _normalize(query);
    final source = normalized.isEmpty
        ? _mergeActivities(data.suggested, data.allActivities)
        : data.allActivities
            .where((activity) => _normalize(activity.name).contains(normalized))
            .toList();
    return source.take(normalized.isEmpty ? 12 : 20).toList();
  }

  List<Trackable> _mergeActivities(
    List<Trackable> primary,
    List<Trackable> secondary,
  ) {
    final byId = <String, Trackable>{};
    for (final activity in [...primary, ...secondary]) {
      byId[activity.id] = activity;
    }
    return byId.values.toList();
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  Future<Trackable?> _createActivityLikeSession(String initialName) async {
    final result = await showDialog<_MorningActivityCreateResult>(
      context: context,
      builder: (_) => _MorningActivityCreateDialog(initialName: initialName),
    );
    if (result == null) {
      return null;
    }

    final now = DateTime.now();
    final trackable = Trackable(
      id: const Uuid().v4(),
      name: result.name,
      color: result.colorHex,
      createdAt: now,
      updatedAt: now,
    );
    await _trackableRepository.saveTrackable(trackable);
    final modes =
        result.modes.isEmpty ? [TrackableMode.mainName] : result.modes;
    for (var index = 0; index < modes.length; index += 1) {
      await _trackableRepository.saveMode(
        TrackableMode(
          id: const Uuid().v4(),
          trackableId: trackable.id,
          name: modes[index],
          sortOrder: index,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return trackable;
  }
}

class _MorningActivityCreateResult {
  final String name;
  final String colorHex;
  final List<String> modes;

  const _MorningActivityCreateResult({
    required this.name,
    required this.colorHex,
    required this.modes,
  });
}

class _MorningActivityCreateDialog extends StatefulWidget {
  final String initialName;

  const _MorningActivityCreateDialog({required this.initialName});

  @override
  State<_MorningActivityCreateDialog> createState() =>
      _MorningActivityCreateDialogState();
}

class _MorningActivityCreateDialogState
    extends State<_MorningActivityCreateDialog> {
  late final TextEditingController _nameController;
  final TextEditingController _modeController = TextEditingController();
  String _colorHex = ColorUtils.toHex(ColorUtils.generateRandomLightColor());
  final List<String> _modes = [TrackableMode.mainName];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.fromHex(_colorHex);
    final colorOptions = [
      _colorHex,
      ...ColorUtils.suggestedColorHexes(currentHex: _colorHex, count: 5),
    ];
    return AlertDialog(
      title: const Text('Create activity'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Activity name'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final hex in colorOptions)
                  InkWell(
                    onTap: () => setState(() => _colorHex = hex),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: ColorUtils.fromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hex == _colorHex
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _modeController,
                    decoration: const InputDecoration(
                      labelText: 'Quick state',
                      hintText: 'coding, meeting, walk',
                    ),
                    onSubmitted: (_) => _addMode(),
                  ),
                ),
                IconButton(
                  onPressed: _addMode,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in _modes)
                  Chip(
                    backgroundColor: color.withValues(alpha: 0.18),
                    label: Text(mode),
                    deleteIcon: mode == TrackableMode.mainName
                        ? null
                        : const Icon(Icons.close),
                    onDeleted: mode == TrackableMode.mainName
                        ? null
                        : () => setState(() => _modes.remove(mode)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _addMode() {
    final mode = _modeController.text.trim();
    if (mode.isEmpty ||
        _modes.any((item) => item.toLowerCase() == mode.toLowerCase())) {
      return;
    }
    setState(() {
      _modes.add(mode);
      _modeController.clear();
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _MorningActivityCreateResult(
        name: name,
        colorHex: _colorHex,
        modes: List.unmodifiable(_modes),
      ),
    );
  }
}

class _MorningStartData {
  final List<Trackable> suggested;
  final List<Trackable> allActivities;

  const _MorningStartData({
    required this.suggested,
    required this.allActivities,
  });

  const _MorningStartData.empty()
      : suggested = const [],
        allActivities = const [];

  _MorningStartData copyWith({
    List<Trackable>? suggested,
    List<Trackable>? allActivities,
  }) {
    return _MorningStartData(
      suggested: suggested ?? this.suggested,
      allActivities: allActivities ?? this.allActivities,
    );
  }
}

class _MorningHero extends StatelessWidget {
  final AnimationController controller;
  final int selectedCount;

  const _MorningHero({
    required this.controller,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B35FF);
    return SizedBox(
      height: 184,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1421).withValues(alpha: 0.88),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 36,
                offset: const Offset(0, 18),
                spreadRadius: -20,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: ActivityFlowPainter(
                        accentColor: accent,
                        phase: controller.value,
                        isActive: true,
                        intensity: 0.72,
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.16),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start your day',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.94),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Build today from states you may actually enter.',
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _HeroMetric(value: '$selectedCount', label: 'selected'),
                        const SizedBox(width: 10),
                        const _HeroMetric(value: 'Today', label: 'rhythm'),
                      ],
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
}

class _HeroMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeroMetric({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
        color: const Color(0xFF0D1421).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
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

class _ActivityChoiceTile extends StatelessWidget {
  final Trackable activity;
  final bool selected;
  final bool suggested;
  final ValueChanged<bool> onChanged;

  const _ActivityChoiceTile({
    required this.activity,
    required this.selected,
    required this.suggested,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.fromHex(activity.color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!selected),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.52)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.46),
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
                          color: Colors.white.withValues(alpha: 0.90),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (suggested) ...[
                  const SizedBox(width: 8),
                  Text(
                    'suggested',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.46),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color:
                      selected ? color : Colors.white.withValues(alpha: 0.34),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateActivityButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _CreateActivityButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF3B82F6);
    return Material(
      color: accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: accent.withValues(alpha: 0.42)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Create "$label"',
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

class _StartWithChip extends StatelessWidget {
  final Trackable activity;
  final bool selected;
  final VoidCallback onTap;

  const _StartWithChip({
    required this.activity,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ColorUtils.fromHex(activity.color);
    return ActionChip(
      onPressed: onTap,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(activity.name),
      backgroundColor: selected
          ? color.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.06),
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: 0.66)
            : Colors.white.withValues(alpha: 0.10),
      ),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: selected ? 0.96 : 0.72),
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _StartDayButton extends StatelessWidget {
  final bool starting;
  final bool enabled;
  final VoidCallback onPressed;

  const _StartDayButton({
    required this.starting,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B35FF);
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: enabled ? 0.98 : 0.28),
              const Color(0xFF246BFE).withValues(alpha: enabled ? 0.86 : 0.18),
            ],
          ),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: accent.withValues(alpha: 0.24),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -10,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled && !starting ? onPressed : null,
            child: Center(
              child: starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Start Day',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
