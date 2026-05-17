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
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
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
            const SizedBox(height: 16),
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
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'New activity',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createTrackable(),
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
            const SizedBox(height: 16),
            _StartTimeSelector(
              selected: _startOption,
              customStartAt: _customStartAt,
              disabledOptions: disabledStartOptions,
              onSelected: _selectStartOption,
            ),
            const SizedBox(height: 12),
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
      final picked =
          await _pickDateTime(context, _customStartAt ?? DateTime.now());
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _startOption = option;
        _customStartAt = picked;
      });
      return;
    }

    setState(() {
      _startOption = option;
      _customStartAt = null;
    });
  }

  Future<DateTime?> _pickDateTime(
      BuildContext context, DateTime initial) async {
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
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return picked.isAfter(now) ? now : picked;
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
    context.read<SessionDetailBloc>().add(
          SessionDetailTrackableAdded(
            trackableId: trackableId,
            modeId: modeId,
            startAt: _selectedStartAt,
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
  final ValueChanged<_PickerStartOption> onSelected;

  const _StartTimeSelector({
    required this.selected,
    required this.customStartAt,
    required this.disabledOptions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _PickerStartOption.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
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

class _TrackablePickerData {
  final List<Trackable> trackables;
  final Map<String, List<TrackableMode>> modesByTrackable;

  const _TrackablePickerData({
    required this.trackables,
    required this.modesByTrackable,
  });
}
