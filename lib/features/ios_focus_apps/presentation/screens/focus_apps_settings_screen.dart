import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/core/analytics/analytics_events.dart';
import 'package:time_tracker/core/analytics/analytics_service.dart';
import 'package:time_tracker/features/ios_focus_apps/domain/ios_focus_apps_models.dart';
import 'package:time_tracker/features/ios_focus_apps/presentation/screens/blocked_apps_screen.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_focus_apps_settings_service.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_screen_time_service.dart';

class FocusAppsSettingsScreen extends StatefulWidget {
  const FocusAppsSettingsScreen({super.key});

  @override
  State<FocusAppsSettingsScreen> createState() =>
      _FocusAppsSettingsScreenState();
}

class _FocusAppsSettingsScreenState extends State<FocusAppsSettingsScreen> {
  late final IOSScreenTimeService _screenTimeService;
  late final IOSFocusAppsSettingsService _settingsService;
  late final AnalyticsService _analyticsService;
  IOSFocusAppsSettings? _settings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _screenTimeService = context.read<IOSScreenTimeService>();
    _settingsService = context.read<IOSFocusAppsSettingsService>();
    _analyticsService = context.read<AnalyticsService>();
    _load();
  }

  Future<void> _load() async {
    final settings = await _settingsService.load();
    final authorized = await _screenTimeService.isAuthorized();
    final hasSelection = await _screenTimeService.hasSelection();
    final next = settings.copyWith(
      isScreenTimeAuthorized: authorized,
      hasFamilyActivitySelection: hasSelection,
      updatedAt: DateTime.now(),
    );
    await _settingsService.save(next);
    await _screenTimeService.configure(next);
    if (next.isEnabled) {
      await _screenTimeService.startDailyMonitoring();
    }
    if (!mounted) return;
    setState(() {
      _settings = next;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _requestAccess() async {
    setState(() => _error = null);
    try {
      final authorized = await _screenTimeService.requestAuthorization();
      final current =
          _settings ?? IOSFocusAppsSettings.defaults(DateTime.now());
      final next = current.copyWith(
        isScreenTimeAuthorized: authorized,
        isEnabled: authorized ? true : current.isEnabled,
        updatedAt: DateTime.now(),
      );
      await _settingsService.save(next);
      await _screenTimeService.configure(next);
      if (!mounted) return;
      setState(() => _settings = next);
      if (authorized) {
        await _chooseApps();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _chooseApps() async {
    final selected = await _screenTimeService.openFamilyActivityPicker();
    final hasSelection = selected || await _screenTimeService.hasSelection();
    final current = _settings ?? IOSFocusAppsSettings.defaults(DateTime.now());
    final next = current.copyWith(
      hasFamilyActivitySelection: hasSelection,
      isEnabled: hasSelection ? true : current.isEnabled,
      updatedAt: DateTime.now(),
    );
    await _settingsService.save(next);
    await _screenTimeService.configure(next);
    if (next.isEnabled) {
      await _screenTimeService.startDailyMonitoring();
      await _trackSetupCompleted(next);
    }
    if (!mounted) return;
    setState(() => _settings = next);
  }

  Future<void> _update(IOSFocusAppsSettings settings) async {
    final next = settings.copyWith(updatedAt: DateTime.now());
    await _settingsService.save(next);
    await _screenTimeService.configure(next);
    if (!mounted) return;
    setState(() => _settings = next);
    if (!next.isEnabled) {
      await _screenTimeService.clearShield();
      await _screenTimeService.stopDailyMonitoring();
    } else {
      await _screenTimeService.startDailyMonitoring();
      await _trackSetupCompleted(next);
    }
    await _analyticsService.setUserProperties(
      {
        AnalyticsUserProperties.trackingEnabled: next.isEnabled,
        AnalyticsUserProperties.focusEnabled: next.focusModeBlockingEnabled,
      },
    );
  }

  Future<void> _trackSetupCompleted(IOSFocusAppsSettings settings) {
    return _analyticsService.track(
      AnalyticsEvent.trackingSetupCompleted,
      properties: {AnalyticsProperties.mode: _modeAnalyticsValue(settings)},
    );
  }

  String _modeAnalyticsValue(IOSFocusAppsSettings settings) {
    return switch (settings.dailyMode) {
      AppControlMode.trackOnly => 'track_only',
      AppControlMode.notifyOnLimit => 'notify',
      AppControlMode.blockAfterLimit => 'block',
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (!Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Control')),
        body: const Center(
          child: Text('App Control uses Apple Screen Time and is iOS-only.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('App Control')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.65, -0.95),
            radius: 1.15,
            colors: [Color(0xFF10192A), Color(0xFF070C14), Color(0xFF050910)],
          ),
        ),
        child: _loading || settings == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                children: [
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Control',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Track selected apps, get limit notifications and block distractions when you want stronger boundaries. Screen Time data stays protected by Apple and remains on your device.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFFFF8F8F)),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _StatusRow(
                          label: 'Screen Time Access',
                          value: settings.isScreenTimeAuthorized
                              ? 'Connected'
                              : 'Not connected',
                        ),
                        _StatusRow(
                          label: 'Selected apps',
                          value: settings.hasFamilyActivitySelection
                              ? 'Configured'
                              : 'Not selected',
                        ),
                        const SizedBox(height: 14),
                        if (!settings.isScreenTimeAuthorized)
                          FilledButton(
                            onPressed: _requestAccess,
                            child: const Text('Continue'),
                          )
                        else
                          FilledButton.tonal(
                            onPressed: _chooseApps,
                            child: const Text('Change selected apps'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Daily app rules'),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: settings.isEnabled,
                          title: const Text('Enable App Control'),
                          onChanged: (value) {
                            _update(settings.copyWith(isEnabled: value));
                          },
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final mode in AppControlMode.values)
                              ChoiceChip(
                                label: Text(_modeLabel(mode)),
                                selected: settings.dailyMode == mode,
                                onSelected: settings.isEnabled
                                    ? (_) {
                                        _update(
                                          settings.copyWith(dailyMode: mode),
                                        );
                                      }
                                    : null,
                              ),
                          ],
                        ),
                        if (settings.dailyMode != AppControlMode.trackOnly)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final minutes in [15, 30, 45, 60])
                                ChoiceChip(
                                  label: Text('$minutes min'),
                                  selected:
                                      settings.dailyLimitMinutes == minutes,
                                  onSelected: (_) {
                                    _update(
                                      settings.copyWith(
                                        dailyLimitMinutes: minutes,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('Focus Mode'),
                        const SizedBox(height: 8),
                        Text(
                          'During Focus Mode, Chronika blocks selected distracting apps. To unlock them, open Chronika, pause for a breath, then choose a short break.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            height: 1.32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: settings.focusModeBlockingEnabled,
                          title: const Text('Block selected apps in Focus'),
                          onChanged: (value) {
                            _update(
                              settings.copyWith(
                                focusModeBlockingEnabled: value,
                              ),
                            );
                          },
                        ),
                        _ValueStepper(
                          label: 'Breathing pause',
                          value: settings.breathingPauseSeconds,
                          suffix: 'sec',
                          values: const [5, 10, 15, 20],
                          onChanged: (value) {
                            _update(
                              settings.copyWith(breathingPauseSeconds: value),
                            );
                          },
                        ),
                        _ValueStepper(
                          label: 'Temporary unlock',
                          value: settings.temporaryUnlockMinutes,
                          suffix: 'min',
                          values: const [5, 10, 15, 20],
                          onChanged: (value) {
                            _update(
                              settings.copyWith(temporaryUnlockMinutes: value),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _openBlockedApps,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Status and short breaks'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _modeLabel(AppControlMode mode) {
    return switch (mode) {
      AppControlMode.trackOnly => 'Only track time',
      AppControlMode.notifyOnLimit => 'Notify when limit is reached',
      AppControlMode.blockAfterLimit => 'Block after daily limit',
    };
  }

  Future<void> _openBlockedApps() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BlockedAppsScreen(),
      ),
    );
    await _load();
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: child,
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF8C6BFF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 21,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ValueStepper extends StatelessWidget {
  final String label;
  final int value;
  final String suffix;
  final List<int> values;
  final ValueChanged<int> onChanged;

  const _ValueStepper({
    required this.label,
    required this.value,
    required this.suffix,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: $value $suffix',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final item in values)
                ChoiceChip(
                  label: Text('$item $suffix'),
                  selected: value == item,
                  onSelected: (_) => onChanged(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
