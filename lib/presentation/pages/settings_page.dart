import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:time_tracker/application/active_session_bar/active_session_bar_service.dart';
import 'package:time_tracker/application/active_session_bar/active_session_visibility_settings.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ActiveSessionVisibilitySettings _settings =
      const ActiveSessionVisibilitySettings.defaults();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ActiveSessionVisibilitySettings.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _loaded = true;
    });
  }

  Future<void> _applySettings(ActiveSessionVisibilitySettings settings) async {
    setState(() => _settings = settings);
    await context.read<ActiveSessionBarService>().applyVisibilitySettings(
          settings,
        );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.60, -0.92),
          radius: 1.16,
          colors: [
            Color(0xFF10192A),
            Color(0xFF070C14),
            Color(0xFF050910),
          ],
          stops: [0, 0.54, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 104),
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 34),
            const _SettingsSectionLabel('Session Visibility'),
            const SizedBox(height: 10),
            _GlassSettingsPanel(
              children: [
                _VisibilitySettingTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Lock Screen',
                  subtitle: 'Show active session and timer on lock screen',
                  value: _settings.lockScreen,
                  enabled: _loaded,
                  onChanged: (value) {
                    _applySettings(_settings.copyWith(lockScreen: value));
                  },
                ),
                _SettingsDivider(),
                _VisibilitySettingTile(
                  icon: Icons.smartphone_rounded,
                  title: 'Dynamic Island',
                  subtitle: 'Display live session in Dynamic Island',
                  value: _settings.dynamicIsland,
                  enabled: _loaded,
                  onChanged: (value) {
                    _applySettings(_settings.copyWith(dynamicIsland: value));
                  },
                ),
                _SettingsDivider(),
                _VisibilitySettingTile(
                  icon: Icons.crop_16_9_rounded,
                  title: 'Compact Island mode',
                  subtitle: 'Show minimal timer only to save space',
                  value: _settings.compactIsland,
                  enabled: _loaded,
                  onChanged: (value) {
                    _applySettings(_settings.copyWith(compactIsland: value));
                  },
                ),
                _SettingsDivider(),
                _VisibilitySettingTile(
                  icon: Icons.radio_button_checked_rounded,
                  title: 'Background tracking indicator',
                  subtitle: 'Show a subtle indicator in background',
                  value: _settings.backgroundIndicator,
                  enabled: _loaded,
                  onChanged: (value) {
                    _applySettings(
                      _settings.copyWith(backgroundIndicator: value),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Lock Screen and Dynamic Island control whether Chronika keeps a live session indicator running.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.36),
                      height: 1.32,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 34),
            const _SettingsSectionLabel('About'),
            const SizedBox(height: 10),
            _GlassSettingsPanel(
              children: [
                _AboutSettingTile(
                  icon: Icons.send_rounded,
                  iconColor: const Color(0xFF4E8DFF),
                  title: 'Developer Telegram',
                  subtitle: 'Open Telegram',
                  onTap: _openTelegram,
                ),
                _SettingsDivider(),
                _AboutSettingTile(
                  icon: Icons.star_border_rounded,
                  iconColor: const Color(0xFFFFB020),
                  title: 'Rate Chronika',
                  subtitle: 'If you enjoy using the app',
                  onTap: _rateApp,
                ),
              ],
            ),
            const SizedBox(height: 34),
            Text(
              'Made with focus.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.34),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFA579FF).withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse('https://t.me/isdemx');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Telegram')),
      );
    }
  }

  Future<void> _rateApp() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating is not available yet')),
      );
    }
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  final String title;

  const _SettingsSectionLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.9,
            ),
      ),
    );
  }
}

class _GlassSettingsPanel extends StatelessWidget {
  final List<Widget> children;

  const _GlassSettingsPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1421).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 14),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _VisibilitySettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _VisibilitySettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
      child: Row(
        children: [
          _SettingsIconBubble(icon: icon, color: const Color(0xFF9C5CFF)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.55),
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Transform.scale(
            scale: 0.86,
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF7C3CFF),
              inactiveThumbColor: Colors.white.withValues(alpha: 0.92),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AboutSettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
          child: Row(
            children: [
              _SettingsIconBubble(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.52),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsIconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIconBubble({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 28),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
