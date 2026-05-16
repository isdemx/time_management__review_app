import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/presentation/widgets/trackable_button.dart';

void main() {
  testWidgets('TrackableButton renders modes and handles mode taps',
      (WidgetTester tester) async {
    final now = DateTime(2026, 1, 1);
    String? selectedModeId;
    final trackable = Trackable(
      id: 'trackable-1',
      name: 'Work',
      color: '#a8d8ff',
      createdAt: now,
      updatedAt: now,
    );
    final modes = [
      TrackableMode(
        id: 'mode-1',
        trackableId: trackable.id,
        name: 'Coding',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      TrackableMode(
        id: 'mode-2',
        trackableId: trackable.id,
        name: 'Review',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackableButton(
            trackable: trackable,
            modes: modes,
            duration: const Duration(minutes: 12),
            isActive: true,
            activeModeId: 'mode-1',
            onModeTap: (modeId) => selectedModeId = modeId,
          ),
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Coding'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('0:12:00'), findsOneWidget);

    await tester.tap(find.text('Review'));
    expect(selectedModeId, 'mode-2');
  });

  testWidgets('TrackableButton starts long press from title text',
      (WidgetTester tester) async {
    final now = DateTime(2026, 1, 1);
    String? longPressedModeId;
    final trackable = Trackable(
      id: 'trackable-1',
      name: 'Work',
      color: '#a8d8ff',
      createdAt: now,
      updatedAt: now,
    );
    final modes = [
      TrackableMode(
        id: 'mode-1',
        trackableId: trackable.id,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TrackableButton(
              trackable: trackable,
              modes: modes,
              duration: Duration.zero,
              isActive: false,
              activeModeId: null,
              onModeTap: (_) {},
              onModeLongPressStart: (modeId, _) {
                longPressedModeId = modeId;
              },
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Work'), warnIfMissed: false);

    expect(longPressedModeId, 'mode-1');
  });
}
