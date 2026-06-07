import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

// The app still targets Flutter SDKs where withValues is not consistently
// available across every local toolchain used for release builds.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/daily_rhythm/daily_rhythm_notification_service.dart';
import 'package:time_tracker/features/ios_focus_apps/domain/ios_focus_apps_models.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_focus_apps_settings_service.dart';
import 'package:time_tracker/features/ios_focus_apps/services/ios_screen_time_service.dart';

class AppControlOnboardingStep extends StatefulWidget {
  final VoidCallback onCompleted;
  final VoidCallback onBack;

  const AppControlOnboardingStep({
    super.key,
    required this.onCompleted,
    required this.onBack,
  });

  @override
  State<AppControlOnboardingStep> createState() =>
      _AppControlOnboardingStepState();
}

class _AppControlOnboardingStepState extends State<AppControlOnboardingStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;
  AppControlMode _selectedMode = AppControlMode.notifyOnLimit;
  int _selectedDailyLimitMinutes = 15;
  int _screenIndex = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _previous();
        }
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _ambientController,
          builder: (context, _) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.18),
                  radius: 1.18,
                  colors: [
                    Color(0xFF101A18),
                    Color(0xFF060B0F),
                    Color(0xFF020407),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _AppControlAmbientPainter(
                      progress: _ambientController.value,
                      intensity: _screenIndex == 0 ? 1.0 : 0.62,
                    ),
                  ),
                  SafeArea(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 520),
                      reverseDuration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: _transition,
                      child: KeyedSubtree(
                        key: ValueKey(_screenIndex),
                        child: _screen(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _screen() {
    return switch (_screenIndex) {
      0 => _IntroScreen(
          progress: _ambientController.value,
          onNext: _next,
          onBack: _previous,
        ),
      1 => _ModeScreen(
          selectedMode: _selectedMode,
          onChanged: (mode) => setState(() => _selectedMode = mode),
          onNext: _continueFromMode,
          onBack: _previous,
        ),
      2 => _AccessExplainerScreen(
          onNext: _next,
          onBack: _previous,
        ),
      3 => _ScreenTimeAccessScreen(
          busy: _busy,
          onOpenSettings: _openScreenTimePicker,
          onBack: _previous,
        ),
      4 => _NotificationsScreen(
          busy: _busy,
          onAllow: _requestNotifications,
          onBack: _previous,
        ),
      5 => _DailyLimitScreen(
          selectedMinutes: _selectedDailyLimitMinutes,
          onChanged: (minutes) {
            setState(() => _selectedDailyLimitMinutes = minutes);
          },
          onNext: _saveDailyLimit,
          onBack: _previous,
        ),
      _ => _FinalScreen(
          progress: _ambientController.value,
          onNext: widget.onCompleted,
          onBack: _previous,
        ),
    };
  }

  Widget _transition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final value = curved.value;
        final blur = (1 - value) * 8;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset((1 - value) * 18, 0),
            child: Transform.scale(
              scale: 0.975 + value * 0.025,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blur,
                  sigmaY: blur,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  void _next() {
    setState(() => _screenIndex += 1);
  }

  void _previous() {
    if (_busy) return;
    if (_screenIndex <= 0) {
      widget.onBack();
      return;
    }
    setState(() => _screenIndex -= 1);
  }

  void _continueFromMode() {
    if (_selectedMode == AppControlMode.trackOnly) {
      widget.onCompleted();
      return;
    }
    _next();
  }

  Future<void> _openScreenTimePicker() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final screenTimeService = context.read<IOSScreenTimeService>();
      final settingsService = context.read<IOSFocusAppsSettingsService>();
      final authorized = await screenTimeService.requestAuthorization();
      final selected = authorized
          ? await screenTimeService.openFamilyActivityPicker()
          : false;
      final existing = await settingsService.load();
      final updated = existing.copyWith(
        isScreenTimeAuthorized: authorized,
        isEnabled: authorized && selected,
        hasFamilyActivitySelection: selected,
        dailyMode: _selectedMode,
        dailyLimitMinutes: _selectedDailyLimitMinutes,
        focusModeBlockingEnabled: true,
        updatedAt: DateTime.now(),
      );
      await settingsService.save(updated);
      await screenTimeService.configure(updated);
      if (!mounted) return;
      if (!selected) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authorized
                  ? 'Select apps to continue.'
                  : 'Allow Screen Time access to continue.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _busy = false;
        _screenIndex = 4;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screen Time setup is not available right now.'),
        ),
      );
    }
  }

  Future<void> _requestNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<DailyRhythmNotificationService>().requestPermissions();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (mounted) {
      _next();
    }
  }

  Future<void> _saveDailyLimit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final settingsService = context.read<IOSFocusAppsSettingsService>();
      final screenTimeService = context.read<IOSScreenTimeService>();
      final existing = await settingsService.load();
      final updated = existing.copyWith(
        isEnabled: existing.isEnabled || existing.hasFamilyActivitySelection,
        dailyMode: _selectedMode,
        dailyLimitMinutes: _selectedDailyLimitMinutes,
        updatedAt: DateTime.now(),
      );
      await settingsService.save(updated);
      await screenTimeService.configure(updated);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (mounted) {
      _next();
    }
  }
}

class _IntroScreen extends StatelessWidget {
  final double progress;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _IntroScreen({
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      showBack: false,
      title: 'Ready to take\ncontrol?',
      subtitle: 'You decide what gets\nyour attention.',
      body: Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(250),
                    painter: _ShieldGlowPainter(progress: progress),
                  ),
                  Image.asset(
                    'assets/shield.png',
                    width: 154,
                    height: 154,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Want to control\nyour apps?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFEDE8DD),
                fontSize: 20,
                height: 1.28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      button: _GoldButton(
        label: 'Yes, I want to',
        onPressed: onNext,
      ),
    );
  }
}

class _ModeScreen extends StatelessWidget {
  final AppControlMode selectedMode;
  final ValueChanged<AppControlMode> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _ModeScreen({
    required this.selectedMode,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      title: 'How would you like\nto handle your apps?',
      subtitle: 'You can always change\nthis later.',
      body: Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ModeCard(
                mode: AppControlMode.trackOnly,
                selectedMode: selectedMode,
                icon: Icons.event_note_rounded,
                title: "Don't handle",
                subtitle: 'Skip app control\nfor now.',
                onTap: onChanged,
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: AppControlMode.notifyOnLimit,
                selectedMode: selectedMode,
                icon: Icons.notifications_active_rounded,
                title: 'Track & notify',
                subtitle: "Notify me when I'm\nspending too much time.",
                onTap: onChanged,
              ),
              const SizedBox(height: 12),
              _ModeCard(
                mode: AppControlMode.blockAfterLimit,
                selectedMode: selectedMode,
                icon: Icons.lock_rounded,
                title: 'Full control',
                subtitle: 'Block distractions and\nstay in control.',
                onTap: onChanged,
              ),
            ],
          ),
        ),
      ),
      button: _GoldButton(
        label: 'Continue',
        onPressed: onNext,
      ),
    );
  }
}

class _AccessExplainerScreen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _AccessExplainerScreen({
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      title: 'To control your apps,\nwe need access.',
      subtitle: "We'll guide you through\nthe setup.",
      body: const Expanded(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BellGlow(),
              SizedBox(width: 24),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccessItem(
                      icon: Icons.shield_rounded,
                      title: 'Screen Time\nAccess',
                      subtitle: 'Required to limit\napps & time',
                    ),
                    SizedBox(height: 28),
                    _AccessItem(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      subtitle: 'Optional to send\ntimely reminders',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      button: _GoldButton(
        label: 'Continue',
        onPressed: onNext,
      ),
    );
  }
}

class _ScreenTimeAccessScreen extends StatelessWidget {
  final bool busy;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  const _ScreenTimeAccessScreen({
    required this.busy,
    required this.onOpenSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      title: 'First, allow\nScreen Time access.',
      subtitle: 'It lets Chronika limit apps\nand track your time.',
      body: Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SystemPromptMock(
                title: 'Screen Time',
                body:
                    'Chronika will be able to\nview and limit your\nScreen Time.',
                left: 'Cancel',
                right: 'Continue',
                onTap: busy ? null : onOpenSettings,
              ),
              const SizedBox(height: 28),
              const Text(
                "You'll be taken to iOS settings.",
                style: TextStyle(
                  color: Color(0xFF7E858B),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      button: _GoldButton(
        label: busy ? 'Opening...' : 'Open Settings',
        onPressed: busy ? null : onOpenSettings,
      ),
    );
  }
}

class _NotificationsScreen extends StatelessWidget {
  final bool busy;
  final VoidCallback onAllow;
  final VoidCallback onBack;

  const _NotificationsScreen({
    required this.busy,
    required this.onAllow,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      title: 'Next, allow\nnotifications.',
      subtitle: 'So we can remind you\nwhen it matters.',
      body: Expanded(
        child: Center(
          child: _SystemPromptMock(
            title: '"Chronika" Would Like\nto Send You\nNotifications',
            body:
                'Notifications may include alerts,\nsounds, and icon badges. These\ncan be configured in Settings.',
            left: "Don't Allow",
            right: 'Allow',
            large: true,
            onTap: busy ? null : onAllow,
          ),
        ),
      ),
      button: _GoldButton(
        label: busy ? 'Opening...' : 'Allow Notifications',
        onPressed: busy ? null : onAllow,
      ),
    );
  }
}

class _DailyLimitScreen extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _DailyLimitScreen({
    required this.selectedMinutes,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      title: 'Choose your\ndaily limit',
      subtitle: 'How much time should these apps\nget each day?',
      body: Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LimitOption(
                minutes: 15,
                selectedMinutes: selectedMinutes,
                onTap: onChanged,
              ),
              const SizedBox(height: 18),
              _LimitOption(
                minutes: 25,
                selectedMinutes: selectedMinutes,
                onTap: onChanged,
              ),
              const SizedBox(height: 18),
              _LimitOption(
                minutes: 35,
                selectedMinutes: selectedMinutes,
                onTap: onChanged,
              ),
            ],
          ),
        ),
      ),
      button: _GoldButton(
        label: 'Continue',
        onPressed: onNext,
      ),
    );
  }
}

class _FinalScreen extends StatelessWidget {
  final double progress;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _FinalScreen({
    required this.progress,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _FrameScaffold(
      onBack: onBack,
      title: "That's it!",
      subtitle: "You're all set to take\ncontrol of your time.",
      body: Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(220),
                      painter: _ShieldGlowPainter(progress: progress),
                    ),
                    Image.asset(
                      'assets/shield.png',
                      width: 126,
                      height: 126,
                      fit: BoxFit.contain,
                    ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFC25D),
                            Color(0xFFE1972F),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE8A638).withOpacity(0.34),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF2B1808),
                        size: 36,
                        weight: 900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const _FinalPoint(
                text: 'Apps will be limited\nautomatically',
              ),
              const SizedBox(height: 18),
              const _FinalPoint(
                text: "You'll get notified when\nyou reach your limit",
              ),
            ],
          ),
        ),
      ),
      button: _GoldButton(
        label: 'Next',
        onPressed: onNext,
      ),
    );
  }
}

class _FrameScaffold extends StatelessWidget {
  final VoidCallback? onBack;
  final bool showBack;
  final String title;
  final String subtitle;
  final Widget body;
  final Widget button;

  const _FrameScaffold({
    required this.onBack,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.button,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: showBack
                ? _BackCircle(onPressed: onBack)
                : const SizedBox(width: 36, height: 36),
          ),
          const SizedBox(height: 26),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.18,
              letterSpacing: 0,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFA6A9AE),
              fontSize: 16,
              height: 1.38,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ),
          body,
          button,
        ],
      ),
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback? onPressed;

  const _BackCircle({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      onPressed: onPressed,
      icon: const Icon(
        Icons.chevron_left_rounded,
        color: Color(0xCCFFFFFF),
        size: 28,
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GoldButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFC25D),
                    Color(0xFFE1972F),
                    Color(0xFFC87716),
                  ],
                ),
          color: onPressed == null ? const Color(0xFF262626) : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFE49A2F).withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: onPressed == null
                      ? const Color(0xFF8D8D8D)
                      : const Color(0xFF18110A),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final AppControlMode mode;
  final AppControlMode selectedMode;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<AppControlMode> onTap;

  const _ModeCard({
    required this.mode,
    required this.selectedMode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == selectedMode;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2B2116).withOpacity(0.88)
              : const Color(0xFF0C1418).withOpacity(0.80),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFE7A43C)
                : Colors.white.withOpacity(0.06),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE6A039).withOpacity(0.16),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE9A63D).withOpacity(0.18),
              ),
              child: Icon(icon, color: const Color(0xFFE8A638), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFEDEAE4),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9EA2A6),
                      fontSize: 14,
                      height: 1.22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFE8A638),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitOption extends StatelessWidget {
  final int minutes;
  final int selectedMinutes;
  final ValueChanged<int> onTap;

  const _LimitOption({
    required this.minutes,
    required this.selectedMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = minutes == selectedMinutes;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(minutes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2B2116).withOpacity(0.86)
              : const Color(0xFF0C1418).withOpacity(0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFD43F)
                : Colors.white.withOpacity(0.11),
            width: selected ? 1.45 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE8A638).withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFD43F)
                      : const Color(0xFFA4A4A4),
                  width: selected ? 2.2 : 1.7,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE8A638).withOpacity(0.30),
                          blurRadius: 18,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      selected ? const Color(0xFFFFC253) : Colors.transparent,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$minutes min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),
      ),
    );
  }
}

class _FinalPoint extends StatelessWidget {
  final String text;

  const _FinalPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE9A63D).withOpacity(0.15),
          ),
          child: const Icon(
            Icons.notifications_rounded,
            color: Color(0xFFE8A638),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 220,
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFE8E3DA),
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BellGlow extends StatefulWidget {
  const _BellGlow();

  @override
  State<_BellGlow> createState() => _BellGlowState();
}

class _BellGlowState extends State<_BellGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = Curves.easeInOut.transform(_controller.value);
        return Transform.rotate(
          angle: math.sin(value * math.pi * 2) * 0.035,
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(0xFFEAA13A).withOpacity(0.22 + value * 0.16),
                  blurRadius: 34 + value * 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_rounded,
              size: 92,
              color: Color(0xFFF1A83C),
            ),
          ),
        );
      },
    );
  }
}

class _AccessItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AccessItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE9A63D).withOpacity(0.16),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFFE8A638)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFEFEDE9),
                  fontSize: 15,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8B9094),
                  fontSize: 13,
                  height: 1.24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SystemPromptMock extends StatelessWidget {
  final String title;
  final String body;
  final String left;
  final String right;
  final bool large;
  final VoidCallback? onTap;

  const _SystemPromptMock({
    required this.title,
    required this.body,
    required this.left,
    required this.right,
    this.large = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: large ? 286 : 246,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2022).withOpacity(0.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.32),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(18, large ? 24 : 22, 18, 16),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: large ? 18 : 17,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFB7B7B7),
                            fontSize: large ? 13 : 14,
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: Colors.white.withOpacity(0.07)),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Text(
                              left,
                              style: const TextStyle(
                                color: Color(0xFF58A4FF),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          color: Colors.white.withOpacity(0.07),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              right,
                              style: const TextStyle(
                                color: Color(0xFF58A4FF),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _AppControlAmbientPainter extends CustomPainter {
  final double progress;
  final double intensity;

  const _AppControlAmbientPainter({
    required this.progress,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.52);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFE59B2D).withOpacity(0.08 * intensity);

    for (var i = 0; i < 7; i++) {
      final radius = size.width * (0.28 + i * 0.09);
      final wobble = math.sin(progress * math.pi * 2 + i) * 14;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(wobble, i * 18.0 - 50),
          width: radius * 1.7,
          height: radius * 0.42,
        ),
        paint,
      );
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 42; i++) {
      final seed = i * 19.73;
      final angle = seed + progress * math.pi * 2 * (0.25 + (i % 4) * 0.08);
      final rx = size.width * (0.16 + (i % 9) * 0.035);
      final ry = size.height * (0.07 + (i % 7) * 0.014);
      final pos = Offset(
        center.dx + math.cos(angle) * rx,
        center.dy + math.sin(angle * 1.4) * ry - 48 + (i % 5) * 18,
      );
      final pulse = 0.35 + 0.65 * math.sin(angle * 1.7).abs();
      dotPaint.color =
          const Color(0xFFFFB23D).withOpacity(0.05 * intensity + pulse * 0.11);
      canvas.drawCircle(pos, 1.2 + pulse * 2.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppControlAmbientPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}

class _ShieldGlowPainter extends CustomPainter {
  final double progress;

  const _ShieldGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFBE4F).withOpacity(0.38),
          const Color(0xFFE79325).withOpacity(0.13),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.5));
    canvas.drawCircle(center, size.width * 0.43, glowPaint);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFE89F33).withOpacity(0.20);
    for (var i = 0; i < 4; i++) {
      final wobble = math.sin(progress * math.pi * 2 + i) * 10;
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(wobble, i * 7.0),
          width: size.width * (0.78 + i * 0.08),
          height: size.height * (0.18 + i * 0.03),
        ),
        orbitPaint,
      );
    }

    final sparkPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 28; i++) {
      final angle = i * 0.88 + progress * math.pi * 2 * (0.7 + (i % 3) * 0.1);
      final radius = size.width * (0.18 + (i % 8) * 0.035);
      final pos = center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.5);
      final alpha = 0.20 + 0.42 * math.sin(angle * 1.9).abs();
      sparkPaint.color = const Color(0xFFFFC05A).withOpacity(alpha);
      canvas.drawCircle(pos, 1.2 + alpha * 3.0, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShieldGlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
