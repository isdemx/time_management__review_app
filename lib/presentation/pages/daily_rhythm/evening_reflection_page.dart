import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/domain/entities/day_session.dart';
import 'package:time_tracker/domain/entities/evening_reflection.dart';
import 'package:time_tracker/domain/repositories/daily_rhythm_repository.dart';

class EveningReflectionPage extends StatefulWidget {
  final DaySession daySession;

  const EveningReflectionPage({
    super.key,
    required this.daySession,
  });

  @override
  State<EveningReflectionPage> createState() => _EveningReflectionPageState();
}

class _EveningReflectionPageState extends State<EveningReflectionPage> {
  static const _uuid = Uuid();

  final TextEditingController _commentController = TextEditingController();
  String _completionFeeling = 'Balanced';
  String _energyLevel = 'Medium';
  String _mood = 'Calm';
  bool _saving = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _closeDay() async {
    setState(() => _saving = true);
    final repository = context.read<DailyRhythmRepository>();
    final notificationService = context.read<DailyRhythmNotificationService>();
    final now = DateTime.now();
    final reflection = EveningReflection(
      id: _uuid.v4(),
      daySessionId: widget.daySession.id,
      date: DateTime(now.year, now.month, now.day),
      completionFeeling: _completionFeeling,
      energyLevel: _energyLevel,
      mood: _mood,
      comment: _commentController.text.trim(),
      createdAt: now,
    );
    await repository.saveEveningReflection(reflection);
    await repository.closeOpenActivityEntries(widget.daySession.id, now);
    await repository.updateDaySession(
      widget.daySession.copyWith(
        endedAt: now,
        status: DaySessionStatus.completed,
        reflectionId: reflection.id,
      ),
    );
    await notificationService.refreshDailyNudges();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reflection')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              'How was today?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'A short note for your rhythm, not a scorecard.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.66),
                  ),
            ),
            const SizedBox(height: 28),
            _ChoiceSection(
              title: 'Did today feel right?',
              value: _completionFeeling,
              values: const [
                'Productive',
                'Balanced',
                'Chaotic',
                'Exhausting',
                'Calm',
              ],
              onChanged: (value) => setState(() => _completionFeeling = value),
            ),
            const SizedBox(height: 22),
            _ChoiceSection(
              title: 'Energy',
              value: _energyLevel,
              values: const ['Low', 'Medium', 'High'],
              onChanged: (value) => setState(() => _energyLevel = value),
            ),
            const SizedBox(height: 22),
            _ChoiceSection(
              title: 'Mood',
              value: _mood,
              values: const ['Calm', 'Focused', 'Tired', 'Social', 'Scattered'],
              onChanged: (value) => setState(() => _mood = value),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Want to add a note?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _closeDay,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Close Day'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  final String title;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _ChoiceSection({
    required this.title,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in values)
              ChoiceChip(
                label: Text(item),
                selected: value == item,
                onSelected: (_) => onChanged(item),
              ),
          ],
        ),
      ],
    );
  }
}
