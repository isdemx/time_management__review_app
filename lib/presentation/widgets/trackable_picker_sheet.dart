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

  void _select(String trackableId, String modeId) {
    context.read<SessionDetailBloc>().add(
          SessionDetailTrackableAdded(
            trackableId: trackableId,
            modeId: modeId,
          ),
        );
    Navigator.of(context).pop();
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
