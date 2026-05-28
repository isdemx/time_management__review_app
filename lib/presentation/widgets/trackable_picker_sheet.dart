import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/data/utils/color_utils.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/presentation/blocs/session_detail/session_detail_bloc.dart';
import 'package:time_tracker/presentation/widgets/trackable_button.dart';
import 'package:uuid/uuid.dart';

class TrackablePickerSheet extends StatefulWidget {
  const TrackablePickerSheet({Key? key}) : super(key: key);

  @override
  State<TrackablePickerSheet> createState() => _TrackablePickerSheetState();
}

class _TrackablePickerSheetState extends State<TrackablePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  late Future<_TrackablePickerData> _dataFuture;
  _PickerStartOption _startOption = _PickerStartOption.now;
  DateTime? _customStartAt;
  DateTime? _customEndAt;
  bool _doNotActivate = false;
  bool _hasEndAt = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabledStartOptions = _disabledStartOptions(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          top: 10,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.42),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _controller,
                          autofocus: false,
                          decoration: const InputDecoration(
                            hintText: 'Create activity',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _createTrackable(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _createTrackable,
                      icon: const Icon(Icons.add),
                      tooltip: 'Create',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _StartTimeSelector(
              selected: _startOption,
              customStartAt: _customStartAt,
              disabledOptions: disabledStartOptions,
              hasEndAt: _hasEndAt,
              onSelected: _selectStartOption,
              onHasEndAtChanged: _setHasEndAt,
            ),
            const SizedBox(height: 8),
            _PickerOptionsPanel(
              doNotActivate: _doNotActivate,
              hasEndAt: _hasEndAt,
              startAt: _selectedStartAt,
              endAt: _customEndAt,
              onDoNotActivateChanged: (value) {
                setState(() => _doNotActivate = value);
              },
              onPickStartTime: _pickCustomStartTime,
              onPickStartDate: _pickCustomStartDate,
              onPickEndTime: _pickCustomEndTime,
              onPickEndDate: _pickCustomEndDate,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<_TrackablePickerData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  if (data.trackables.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No saved activities yet'),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: data.trackables.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      final trackable = data.trackables[index];
                      final modes = data.modesByTrackable[trackable.id] ?? [];

                      return TrackableButton(
                        trackable: trackable,
                        modes: modes,
                        duration: Duration.zero,
                        isActive: false,
                        showTimer: false,
                        animated: false,
                        activeModeId: null,
                        onModeTap: (modeId) => _select(trackable.id, modeId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_TrackablePickerData> _load() async {
    final repository = context.read<TrackableRepository>();
    final trackables = await repository.getTrackables();
    final modesByTrackable = <String, List<TrackableMode>>{};

    for (final trackable in trackables) {
      modesByTrackable[trackable.id] = await repository.getModes(trackable.id);
    }

    return _TrackablePickerData(
      trackables: trackables,
      modesByTrackable: modesByTrackable,
    );
  }

  Future<void> _createTrackable() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }

    final repository = context.read<TrackableRepository>();
    final now = DateTime.now();
    final trackableId = const Uuid().v4();
    final modeId = const Uuid().v4();
    final trackable = Trackable(
      id: trackableId,
      name: name,
      color: ColorUtils.toHex(ColorUtils.generateRandomLightColor()),
      createdAt: now,
      updatedAt: now,
    );
    final mode = TrackableMode(
      id: modeId,
      trackableId: trackableId,
      name: TrackableMode.mainName,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveTrackable(trackable);
    await repository.saveMode(mode);

    if (!mounted) {
      return;
    }

    _select(trackableId, modeId);
  }

  Future<void> _selectStartOption(_PickerStartOption option) async {
    if (_disabledStartOptions(context).contains(option)) {
      return;
    }

    if (option == _PickerStartOption.custom) {
      final picked = await _pickTime(context, _customStartAt ?? DateTime.now());
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _startOption = option;
        _customStartAt = picked;
        _syncEndAfterStart();
      });
      return;
    }

    setState(() {
      _startOption = option;
      _customStartAt = null;
      _syncEndAfterStart();
    });
  }

  void _setHasEndAt(bool value) {
    final now = DateTime.now();
    setState(() {
      _hasEndAt = value;
      if (value) {
        _customEndAt ??= now;
        if (_startOption == _PickerStartOption.now) {
          _startOption = _PickerStartOption.custom;
          _customStartAt = now.subtract(const Duration(minutes: 10));
        }
        _syncEndAfterStart();
      }
    });
  }

  Future<void> _pickCustomStartTime() async {
    final picked = await _pickTime(context, _selectedStartAt ?? DateTime.now());
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startOption = _PickerStartOption.custom;
      _customStartAt = picked;
      _syncEndAfterStart();
    });
  }

  Future<void> _pickCustomStartDate() async {
    final picked = await _pickDate(context, _selectedStartAt ?? DateTime.now());
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _startOption = _PickerStartOption.custom;
      _customStartAt = picked;
      _syncEndAfterStart();
    });
  }

  Future<void> _pickCustomEndTime() async {
    final picked = await _pickTime(context, _customEndAt ?? DateTime.now());
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _customEndAt = _clampToNow(picked));
  }

  Future<void> _pickCustomEndDate() async {
    final picked = await _pickDate(context, _customEndAt ?? DateTime.now());
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _customEndAt = _clampToNow(picked));
  }

  Future<DateTime?> _pickTime(BuildContext context, DateTime initial) async {
    final now = DateTime.now();
    final base = initial.isAfter(now) ? now : initial;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) {
      return null;
    }
    return _clampToNow(DateTime(
      base.year,
      base.month,
      base.day,
      time.hour,
      time.minute,
    ));
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime initial) async {
    final now = DateTime.now();
    final base = initial.isAfter(now) ? now : initial;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDate: base,
    );
    if (date == null) {
      return null;
    }
    return _clampToNow(DateTime(
      date.year,
      date.month,
      date.day,
      base.hour,
      base.minute,
    ));
  }

  DateTime _clampToNow(DateTime value) {
    final now = DateTime.now();
    return value.isAfter(now) ? now : value;
  }

  void _syncEndAfterStart() {
    final start = _selectedStartAt;
    if (!_hasEndAt || start == null) {
      return;
    }
    final now = DateTime.now();
    if (_customEndAt == null || !_customEndAt!.isAfter(start)) {
      _customEndAt = start.add(const Duration(minutes: 1));
    }
    if (_customEndAt!.isAfter(now)) {
      _customEndAt = now;
    }
  }

  DateTime? get _selectedStartAt {
    if (_startOption == _PickerStartOption.now) {
      return null;
    }
    if (_startOption == _PickerStartOption.custom) {
      return _customStartAt;
    }
    return DateTime.now().subtract(_startOption.offset!);
  }

  Set<_PickerStartOption> _disabledStartOptions(BuildContext context) {
    final state = context.read<SessionDetailBloc>().state;
    if (state is! SessionDetailLoaded || state.openSegment == null) {
      return const {};
    }

    final now = DateTime.now();
    final openStart = state.openSegment!.startAt;
    return {
      for (final option in _PickerStartOption.values)
        if (option.offset != null &&
            now.subtract(option.offset!).isBefore(openStart))
          option,
    };
  }

  void _select(String trackableId, String modeId) {
    final startAt = _selectedStartAt;
    final endAt = _hasEndAt ? _customEndAt : null;
    if (_hasEndAt && (startAt == null || endAt == null)) {
      return;
    }
    if (_hasEndAt && !endAt!.isAfter(startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }
    context.read<SessionDetailBloc>().add(
          SessionDetailTrackableAdded(
            trackableId: trackableId,
            modeId: modeId,
            startAt: startAt,
            endAt: endAt,
            activate: !_doNotActivate || _hasEndAt,
          ),
        );
    Navigator.of(context).pop();
  }
}

enum _PickerStartOption {
  now(null, 'Now'),
  oneMinute(Duration(minutes: 1), '1m ago'),
  twoMinutes(Duration(minutes: 2), '2m ago'),
  threeMinutes(Duration(minutes: 3), '3m ago'),
  fiveMinutes(Duration(minutes: 5), '5m ago'),
  tenMinutes(Duration(minutes: 10), '10m ago'),
  twentyMinutes(Duration(minutes: 20), '20m ago'),
  fortyMinutes(Duration(minutes: 40), '40m ago'),
  oneHour(Duration(hours: 1), '1h ago'),
  twoHours(Duration(hours: 2), '2h ago'),
  custom(null, 'Custom');

  final Duration? offset;
  final String label;

  const _PickerStartOption(this.offset, this.label);
}

class _StartTimeSelector extends StatelessWidget {
  final _PickerStartOption selected;
  final DateTime? customStartAt;
  final Set<_PickerStartOption> disabledOptions;
  final bool hasEndAt;
  final ValueChanged<_PickerStartOption> onSelected;
  final ValueChanged<bool> onHasEndAtChanged;

  const _StartTimeSelector({
    required this.selected,
    required this.customStartAt,
    required this.disabledOptions,
    required this.hasEndAt,
    required this.onSelected,
    required this.onHasEndAtChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _PickerStartOption.values.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _PickerStartOption.values.length) {
            return FilterChip(
              selected: hasEndAt,
              avatar: Icon(
                Icons.task_alt_rounded,
                size: 18,
                color: hasEndAt
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.58),
              ),
              label: const Text('Ended'),
              onSelected: onHasEndAtChanged,
            );
          }
          final option = _PickerStartOption.values[index];
          final isSelected = option == selected;
          final isDisabled = disabledOptions.contains(option);
          final label = option == _PickerStartOption.custom &&
                  isSelected &&
                  customStartAt != null
              ? _formatPickedTime(customStartAt!)
              : option.label;
          return ChoiceChip(
            selected: isSelected,
            label: Text(label),
            onSelected: isDisabled ? null : (_) => onSelected(option),
            labelStyle: isDisabled
                ? TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.32),
                  )
                : null,
          );
        },
      ),
    );
  }

  String _formatPickedTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _PickerOptionsPanel extends StatelessWidget {
  final bool doNotActivate;
  final bool hasEndAt;
  final DateTime? startAt;
  final DateTime? endAt;
  final ValueChanged<bool> onDoNotActivateChanged;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndTime;
  final VoidCallback onPickEndDate;

  const _PickerOptionsPanel({
    required this.doNotActivate,
    required this.hasEndAt,
    required this.startAt,
    required this.endAt,
    required this.onDoNotActivateChanged,
    required this.onPickStartTime,
    required this.onPickStartDate,
    required this.onPickEndTime,
    required this.onPickEndDate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1421).withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PickerSwitchRow(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Do not activate',
                subtitle: 'Add without starting the timer',
                value: doNotActivate,
                onChanged: onDoNotActivateChanged,
              ),
              if (startAt != null || hasEndAt) ...[
                const SizedBox(height: 6),
                _PickerTimeRow(
                  title: 'Start',
                  value:
                      startAt == null ? 'Now' : _formatPickedDateTime(startAt!),
                  color: scheme.primary,
                  onPickTime: onPickStartTime,
                  onPickDate: onPickStartDate,
                ),
              ],
              if (hasEndAt) ...[
                const SizedBox(height: 6),
                _PickerTimeRow(
                  title: 'End',
                  value: endAt == null
                      ? 'Choose time'
                      : _formatPickedDateTime(endAt!),
                  color: const Color(0xFFFFB020),
                  onPickTime: onPickEndTime,
                  onPickDate: onPickEndDate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPickedDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}.${twoDigits(value.month)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }
}

class _PickerSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PickerSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: value ? 0.22 : 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: value ? 0.42 : 0.16),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: value
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _PickerTimeRow extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final VoidCallback onPickTime;
  final VoidCallback onPickDate;

  const _PickerTimeRow({
    required this.title,
    required this.value,
    required this.color,
    required this.onPickTime,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.64),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            onPressed: onPickTime,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            tooltip: 'Change time',
          ),
          IconButton(
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            tooltip: 'Change date',
          ),
        ],
      ),
    );
  }
}

class _TrackablePickerData {
  final List<Trackable> trackables;
  final Map<String, List<TrackableMode>> modesByTrackable;

  const _TrackablePickerData({
    required this.trackables,
    required this.modesByTrackable,
  });
}
