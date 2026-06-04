import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:time_tracker/features/ios_focus_apps/domain/ios_focus_apps_models.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_focus_apps_settings_service.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_screen_time_service.dart';

class BlockedAppsScreen extends StatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  State<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends State<BlockedAppsScreen> {
  late final IOSScreenTimeService _screenTimeService;
  late final IOSFocusAppsSettingsService _settingsService;
  IOSFocusAppsBlockingState _state = IOSFocusAppsBlockingState.inactive;
  IOSFocusAppsSettings? _settings;
  Timer? _ticker;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _screenTimeService = context.read<IOSScreenTimeService>();
    _settingsService = context.read<IOSFocusAppsSettingsService>();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshCountdown();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _settingsService.load();
    final state = await _screenTimeService.getBlockingState();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _state = state;
      _loading = false;
    });
  }

  Future<void> _refreshCountdown() async {
    final unlockEndsAt = _state.temporaryUnlockEndsAt;
    if (unlockEndsAt == null) return;
    if (unlockEndsAt.isBefore(DateTime.now())) {
      await _load();
      return;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _unlock() async {
    if (!_state.areAppsCurrentlyBlocked) {
      return;
    }
    final settings = _settings ?? IOSFocusAppsSettings.defaults(DateTime.now());
    final breathed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _BreathingUnlockScreen(
          seconds: settings.breathingPauseSeconds,
        ),
      ),
    );
    if (breathed != true || !mounted) return;
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _UnlockDurationSheet(),
    );
    if (minutes == null) return;
    await _screenTimeService.temporaryUnlock(Duration(minutes: minutes));
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Apps unlocked for $minutes minutes')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: const Text('Blocked apps')),
        body: const Center(child: Text('Blocked apps are iOS-only.')),
      );
    }
    final settings = _settings;
    final hasActiveUnlock = _hasActiveUnlock(_state);
    final canUnlock = _state.areAppsCurrentlyBlocked && !hasActiveUnlock;
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked apps')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.58, -0.85),
            radius: 1.2,
            colors: [Color(0xFF142135), Color(0xFF07111E), Color(0xFF030812)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
                children: [
                  _HeroPanel(
                    blocked: _state.areAppsCurrentlyBlocked,
                    reason: _reasonLabel(_state.blockingReason),
                    unlockEndsAt: _state.temporaryUnlockEndsAt,
                    appName: _state.lastBlockedAppName,
                  ),
                  const SizedBox(height: 18),
                  _InfoPanel(
                    title: 'Current status',
                    body: _statusDescription(
                      state: _state,
                      hasActiveUnlock: hasActiveUnlock,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (settings != null)
                    _InfoPanel(
                      title: 'Current setup',
                      body:
                          'Daily mode: ${_modeLabel(settings.dailyMode)}\nDaily limit: ${settings.dailyLimitMinutes ?? 30} min\nFocus Mode blocking: ${settings.focusModeBlockingEnabled ? 'On' : 'Off'}',
                    ),
                  const SizedBox(height: 18),
                  const _InfoPanel(
                    title: 'Daily app time',
                    body:
                        'Chronika can block or notify after the Screen Time limit, but iOS does not expose a live per-app minute counter here. Use this screen to see protection status and temporary unlock time.',
                  ),
                  const SizedBox(height: 24),
                  if (canUnlock) ...[
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.self_improvement_rounded),
                      label: const Text('Unlock for a short break'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Sync protection status'),
                  ),
                ],
              ),
      ),
    );
  }

  String _reasonLabel(BlockingReason reason) {
    return switch (reason) {
      BlockingReason.focusMode => 'Focus Mode',
      BlockingReason.dailyLimitReached => 'Daily limit',
      BlockingReason.manual => 'Manual protection',
      BlockingReason.none => 'No active block',
    };
  }

  String _modeLabel(AppControlMode mode) {
    return switch (mode) {
      AppControlMode.trackOnly => 'Track only',
      AppControlMode.notifyOnLimit => 'Notify on limit',
      AppControlMode.blockAfterLimit => 'Block after limit',
    };
  }

  bool _hasActiveUnlock(IOSFocusAppsBlockingState state) {
    final unlockEndsAt = state.temporaryUnlockEndsAt;
    return unlockEndsAt != null && unlockEndsAt.isAfter(DateTime.now());
  }

  String _statusDescription({
    required IOSFocusAppsBlockingState state,
    required bool hasActiveUnlock,
  }) {
    if (hasActiveUnlock) {
      return 'Selected apps are temporarily available. Protection will return automatically when the short break ends.';
    }
    if (state.areAppsCurrentlyBlocked) {
      return 'Selected apps are currently blocked by ${_reasonLabel(state.blockingReason)}. You can unlock them after a short breathing pause.';
    }
    return 'Selected apps are currently available. Unlock is only shown when Chronika is actively blocking apps.';
  }
}

class _HeroPanel extends StatelessWidget {
  final bool blocked;
  final String reason;
  final DateTime? unlockEndsAt;
  final String? appName;

  const _HeroPanel({
    required this.blocked,
    required this.reason,
    required this.unlockEndsAt,
    required this.appName,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = unlockEndsAt?.difference(DateTime.now());
    final hasActiveUnlock = remaining != null && !remaining.isNegative;
    final target = appName ?? 'Selected apps';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101827).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            blocked ? Icons.shield_rounded : Icons.lock_open_rounded,
            color: blocked ? const Color(0xFF66D9FF) : const Color(0xFF86EFAC),
            size: 42,
          ),
          const SizedBox(height: 20),
          Text(
            hasActiveUnlock
                ? '$target unlocked'
                : blocked
                    ? '$target protected'
                    : '$target available',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (hasActiveUnlock) ...[
            Text(
              _formatRemaining(remaining),
              style: const TextStyle(
                color: Color(0xFF86EFAC),
                fontSize: 46,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            hasActiveUnlock
                ? 'Protection turns back on at ${TimeOfDay.fromDateTime(unlockEndsAt!).format(context)}.'
                : 'Reason: $reason',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final String body;

  const _InfoPanel({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.36,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockDurationSheet extends StatelessWidget {
  const _UnlockDurationSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Allow apps for',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            for (final minutes in [5, 10, 15, 20])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(minutes),
                  child: Text('$minutes minutes'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BreathingUnlockScreen extends StatefulWidget {
  final int seconds;

  const _BreathingUnlockScreen({required this.seconds});

  @override
  State<_BreathingUnlockScreen> createState() => _BreathingUnlockScreenState();
}

class _BreathingUnlockScreenState extends State<_BreathingUnlockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.40, -0.75),
            radius: 1.25,
            colors: [Color(0xFF173247), Color(0xFF07111E), Color(0xFF030812)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final scale = 0.72 + _controller.value * 0.28;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 172,
                        height: 172,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFF66D9FF).withValues(alpha: 0.14),
                          border: Border.all(
                            color:
                                const Color(0xFF66D9FF).withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 38),
                    const Text(
                      'Pause for a breath',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _controller.value < 0.5 ? 'Inhale...' : 'Exhale...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$_remaining seconds',
                      style: const TextStyle(
                        color: Color(0xFF66D9FF),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
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
