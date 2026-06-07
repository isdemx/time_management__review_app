import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:time_tracker/domain/entities/trackable.dart';
import 'package:time_tracker/domain/entities/trackable_mode.dart';
import 'package:time_tracker/domain/repositories/trackable_repository.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/external_app_usage_day.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/installed_external_app.dart';
import 'package:time_tracker/features/social_app_tracking/domain/entities/tracked_external_app.dart';
import 'package:time_tracker/features/social_app_tracking/domain/repositories/social_app_tracking_repository.dart';
import 'package:time_tracker/features/social_app_tracking/services/external_app_monitor_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/installed_apps_service.dart';
import 'package:time_tracker/features/social_app_tracking/services/social_app_tracking_settings.dart';
import 'package:time_tracker/features/social_app_tracking/services/usage_access_permission_service.dart';

class SocialAppTrackingSettingsScreen extends StatefulWidget {
  const SocialAppTrackingSettingsScreen({super.key});

  @override
  State<SocialAppTrackingSettingsScreen> createState() =>
      _SocialAppTrackingSettingsScreenState();
}

class _SocialAppTrackingSettingsScreenState
    extends State<SocialAppTrackingSettingsScreen> {
  late final SocialAppTrackingRepository _repository;
  late final UsageAccessPermissionService _permissionService;
  late final ExternalAppMonitorService _monitorService;
  SocialAppTrackingSettings _settings = SocialAppTrackingSettings.defaults;
  bool _hasPermission = false;
  bool _loading = true;
  List<TrackedExternalApp> _apps = const [];
  List<ExternalAppUsageDay> _usage = const [];

  @override
  void initState() {
    super.initState();
    _repository = context.read<SocialAppTrackingRepository>();
    _permissionService = context.read<UsageAccessPermissionService>();
    _monitorService = context.read<ExternalAppMonitorService>();
    _load();
  }

  Future<void> _load() async {
    final settings = await SocialAppTrackingSettings.load();
    final hasPermission = await _permissionService.hasUsageAccess();
    final apps = await _repository.getTrackedApps();
    final usage = await _repository.getUsageForDate(DateTime.now());
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _hasPermission = hasPermission;
      _apps = apps;
      _usage = usage;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    final next = _settings.copyWith(enabled: value);
    setState(() => _settings = next);
    await next.save();
    if (value) {
      await _monitorService.restart();
    } else {
      _monitorService.stop();
    }
  }

  Future<void> _openUsageSettings() async {
    await _permissionService.openUsageAccessSettings();
  }

  Future<void> _addApps() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const SocialAppPickerScreen(),
      ),
    );
    if (result == true) {
      await _load();
      await _monitorService.restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const _IosSocialTrackingScreen();
    }
    return _TrackingScaffold(
      title: 'Control app time',
      subtitle:
          'Track selected apps softly and count them as part of your day.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _GoldIcon(icon: Icons.shield_outlined),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Chronika does not block apps in Android MVP. It helps you notice time in Instagram, TikTok, YouTube, Reddit and other apps.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          height: 1.32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _settings.enabled,
                  activeThumbColor: const Color(0xFFF5B84B),
                  activeTrackColor: const Color(0xFFF5B84B).withValues(
                    alpha: 0.28,
                  ),
                  title: const Text(
                    'Enable tracking',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    _hasPermission
                        ? 'Usage Access is allowed'
                        : 'Android Usage Access is required',
                    style: TextStyle(
                      color: _hasPermission
                          ? Colors.white.withValues(alpha: 0.50)
                          : const Color(0xFFF5B84B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: _loading ? null : _setEnabled,
                ),
                if (!_hasPermission) ...[
                  const SizedBox(height: 12),
                  _GoldButton(
                    label: 'Open Usage Access',
                    onPressed: _openUsageSettings,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _load,
                      child: const Text('I allowed access'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tracked apps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: Platform.isAndroid ? _addApps : null,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF5B84B),
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!Platform.isAndroid)
            const _EmptyMessage('Social app tracking is Android-only in MVP.')
          else if (_apps.isEmpty)
            const _EmptyMessage(
              'Choose apps you want Chronika to account for.',
            )
          else
            ..._apps.map(
              (app) {
                final usage = _usageFor(app.packageName);
                return _TrackedAppTile(
                  app: app,
                  usage: usage,
                  onChanged: (enabled) async {
                    await _repository.updateTrackedApp(
                      app.copyWith(
                        isEnabled: enabled,
                        updatedAt: DateTime.now(),
                      ),
                    );
                    await _load();
                    await _monitorService.restart();
                  },
                  onDelete: () async {
                    await _repository.deleteTrackedApp(app.id);
                    await _load();
                    await _monitorService.restart();
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  ExternalAppUsageDay? _usageFor(String packageName) {
    for (final item in _usage) {
      if (item.packageName == packageName) return item;
    }
    return null;
  }
}

class SocialAppPickerScreen extends StatefulWidget {
  const SocialAppPickerScreen({super.key});

  @override
  State<SocialAppPickerScreen> createState() => _SocialAppPickerScreenState();
}

class _SocialAppPickerScreenState extends State<SocialAppPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<InstalledExternalApp>> _appsFuture;
  final Set<String> _selectedPackages = {};

  @override
  void initState() {
    super.initState();
    _appsFuture = context.read<InstalledAppsService>().getInstalledApps();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _continue(List<InstalledExternalApp> apps) async {
    final selected = apps
        .where((app) => _selectedPackages.contains(app.packageName))
        .toList();
    if (selected.isEmpty) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SocialAppSetupScreen(apps: selected),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TrackingScaffold(
      title: 'Choose apps',
      subtitle: 'Select apps you want Chronika to account for.',
      child: FutureBuilder<List<InstalledExternalApp>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          final apps = snapshot.data ?? const <InstalledExternalApp>[];
          final query = _searchController.text.trim().toLowerCase();
          final filtered = apps
              .where(
                (app) =>
                    app.appName.toLowerCase().contains(query) ||
                    app.packageName.toLowerCase().contains(query),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Search apps',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Color(0xFFF5B84B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final app = filtered[index];
                    final selected =
                        _selectedPackages.contains(app.packageName);
                    return _PickerAppTile(
                      app: app,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedPackages.remove(app.packageName);
                          } else {
                            _selectedPackages.add(app.packageName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _GoldButton(
                    label: 'Continue',
                    onPressed: _selectedPackages.isEmpty
                        ? null
                        : () => _continue(apps),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SocialAppSetupScreen extends StatefulWidget {
  final List<InstalledExternalApp> apps;

  const SocialAppSetupScreen({required this.apps, super.key});

  @override
  State<SocialAppSetupScreen> createState() => _SocialAppSetupScreenState();
}

class _SocialAppSetupScreenState extends State<SocialAppSetupScreen> {
  static const _uuid = Uuid();
  final Map<String, TextEditingController> _dailyControllers = {};
  final Map<String, TextEditingController> _sessionControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final app in widget.apps) {
      _dailyControllers[app.packageName] = TextEditingController(text: '30');
      _sessionControllers[app.packageName] = TextEditingController(text: '10');
    }
  }

  @override
  void dispose() {
    for (final controller in _dailyControllers.values) {
      controller.dispose();
    }
    for (final controller in _sessionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final repository = context.read<SocialAppTrackingRepository>();
    final trackableRepository = context.read<TrackableRepository>();
    final monitorService = context.read<ExternalAppMonitorService>();
    final existingActivities = await trackableRepository.getTrackables();
    final now = DateTime.now();
    try {
      for (final app in widget.apps) {
        final activity = await _activityForApp(
          app,
          existingActivities,
          trackableRepository,
        );
        final existing = await repository.getTrackedAppByPackage(
          app.packageName,
        );
        final tracked = TrackedExternalApp(
          id: existing?.id ?? _uuid.v4(),
          packageName: app.packageName,
          appName: app.appName,
          iconPath: app.iconPath,
          linkedActivityId: activity.id,
          isEnabled: true,
          dailyLimitMinutes: _minutes(_dailyControllers[app.packageName]?.text),
          sessionLimitMinutes:
              _minutes(_sessionControllers[app.packageName]?.text),
          notifyOnOpen: true,
          notifyOnDailyLimitReached: true,
          notifyOnSessionLimitReached: true,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await repository.saveTrackedApp(tracked);
      }
      await const SocialAppTrackingSettings(enabled: true).save();
      await monitorService.restart();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Trackable> _activityForApp(
    InstalledExternalApp app,
    List<Trackable> existingActivities,
    TrackableRepository repository,
  ) async {
    final existing = existingActivities.where(
      (activity) => activity.name.toLowerCase() == app.appName.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final now = DateTime.now();
    final trackable = Trackable(
      id: _uuid.v4(),
      name: app.appName,
      color: _colorForPackage(app.packageName),
      dailyLimitMinutes: _minutes(_dailyControllers[app.packageName]?.text),
      sessionLimitMinutes: _minutes(_sessionControllers[app.packageName]?.text),
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveTrackable(trackable);
    await repository.saveMode(
      TrackableMode(
        id: _uuid.v4(),
        trackableId: trackable.id,
        name: TrackableMode.mainName,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    existingActivities.add(trackable);
    return trackable;
  }

  int? _minutes(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  String _colorForPackage(String packageName) {
    if (packageName.contains('youtube')) return '#FF4D4D';
    if (packageName.contains('instagram')) return '#C13584';
    if (packageName.contains('tiktok')) return '#19D3C5';
    if (packageName.contains('reddit')) return '#FF7A2F';
    return '#7C5CFF';
  }

  @override
  Widget build(BuildContext context) {
    return _TrackingScaffold(
      title: 'Set limits',
      subtitle: 'Choose a soft daily limit and a single-session reminder.',
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _GoldButton(
            label: _saving ? 'Saving...' : 'Save tracking',
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          for (final app in widget.apps)
            _Panel(
              margin: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chronika will create or link an activity for this app.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _dailyControllers[app.packageName],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Daily limit, minutes',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sessionControllers[app.packageName],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Single session limit, minutes',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackingScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;

  const _TrackingScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050910),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.58, -0.88),
            radius: 1.18,
            colors: [
              Color(0xFF171209),
              Color(0xFF07101F),
              Color(0xFF050910),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xCCFFFFFF),
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 16,
                        height: 1.30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: child),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottom,
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
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7C05A), Color(0xFFE3961F)],
                ),
          color: onPressed == null ? const Color(0xFF30323A) : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFF5B84B).withValues(alpha: 0.26),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
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
                      ? Colors.white.withValues(alpha: 0.34)
                      : Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldIcon extends StatelessWidget {
  final IconData icon;

  const _GoldIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF5B84B).withValues(alpha: 0.13),
        border: Border.all(
          color: const Color(0xFFF5B84B).withValues(alpha: 0.36),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5B84B).withValues(alpha: 0.14),
            blurRadius: 20,
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFFF5B84B)),
    );
  }
}

class _PickerAppTile extends StatelessWidget {
  final InstalledExternalApp app;
  final bool selected;
  final VoidCallback onTap;

  const _PickerAppTile({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? const Color(0xFFF5B84B).withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.055),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF5B84B)
                  : Colors.white.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFF5B84B)
                        : Colors.white.withValues(alpha: 0.34),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFFF5B84B),
                          size: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              const Icon(Icons.apps_rounded, color: Color(0xFF8D6BFF)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      app.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.44),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

class _TrackedAppTile extends StatelessWidget {
  final TrackedExternalApp app;
  final ExternalAppUsageDay? usage;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;

  const _TrackedAppTile({
    required this.app,
    required this.usage,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = usage?.totalSeconds ?? 0;
    final limit = app.dailyLimitMinutes;
    final limitText =
        limit == null ? 'No daily limit' : '${seconds ~/ 60} / $limit min';
    return _Panel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.apps_rounded, color: Color(0xFF8D6BFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$limitText • openings: ${usage?.openCount ?? 0}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: app.isEnabled, onChanged: onChanged),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _IosSocialTrackingScreen extends StatelessWidget {
  const _IosSocialTrackingScreen();

  @override
  Widget build(BuildContext context) {
    return _TrackingScaffold(
      title: 'Screen Time',
      subtitle:
          'iOS app control uses Apple Screen Time, not Android Usage Access.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _Panel(
            child: Row(
              children: [
                const _GoldIcon(icon: Icons.lock_outline_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Screen Time integration is configured from the Focus Apps flow. Your selected apps stay protected by Apple and remain on this device.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      height: 1.34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const _Panel({
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
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

class _EmptyMessage extends StatelessWidget {
  final String text;

  const _EmptyMessage(this.text);

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.56),
          height: 1.35,
        ),
      ),
    );
  }
}
