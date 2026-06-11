// Keep compatibility with the current release Flutter toolchain.
// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:time_tracker/application/paywall/paywall_cubit.dart';
import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';
import 'package:time_tracker/presentation/onboarding/onboarding_visual_system.dart';

class PaywallPage extends StatelessWidget {
  final String source;
  final VoidCallback? onCompleted;

  const PaywallPage({
    super.key,
    required this.source,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return _PaywallAccessGate(
      onCompleted: onCompleted,
      child: BlocProvider(
        create: (context) => PaywallCubit(
          service: context.read<PaywallService>(),
          source: source,
        )..load(),
        child: _PaywallView(onCompleted: onCompleted),
      ),
    );
  }
}

class _PaywallAccessGate extends StatefulWidget {
  final Widget child;
  final VoidCallback? onCompleted;

  const _PaywallAccessGate({
    required this.child,
    this.onCompleted,
  });

  @override
  State<_PaywallAccessGate> createState() => _PaywallAccessGateState();
}

class _PaywallAccessGateState extends State<_PaywallAccessGate> {
  late final Future<bool> _premiumFuture;

  @override
  void initState() {
    super.initState();
    _premiumFuture = context.read<PaywallService>().hasPremiumAccess();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _premiumFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF070C14),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) {
              return;
            }
            widget.onCompleted?.call();
            Navigator.of(context).maybePop(true);
          });
          return const SizedBox.shrink();
        }
        return widget.child;
      },
    );
  }
}

class _PaywallView extends StatefulWidget {
  final VoidCallback? onCompleted;

  const _PaywallView({this.onCompleted});

  @override
  State<_PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<_PaywallView>
    with SingleTickerProviderStateMixin {
  String? _selectedPlanId;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  String formatPrice(String? value) {
    final parsed = _parsePrice(value);
    if (parsed == null) return value ?? '';
    return '${parsed.currency}${parsed.amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaywallCubit, PaywallState>(
      listener: (context, state) {
        if (state.completed) {
          widget.onCompleted?.call();
          Navigator.of(context).maybePop(true);
        }
      },
      builder: (context, state) {
        final plans = _plansForState(state);
        final selectedId =
            _selectedPlanId ?? state.selectedProduct?.id ?? plans.first.id;
        return Scaffold(
          body: DecoratedBox(
            decoration:
                const BoxDecoration(gradient: OnboardingGradients.background),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter: OnboardingSpectralWavePainter(
                      progress: 0.16,
                      intensity: 0.94,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 360,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, _) {
                          return CustomPaint(
                            painter: _PaywallBottomFlowPainter(
                              progress: _ambientController.value,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 760;
                      final featureWidth =
                          (constraints.maxWidth * 0.72).clamp(292.0, 370.0);
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          compact ? 12 : 28,
                          24,
                          compact ? 8 : 18,
                        ),
                        child: Column(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _GradientHeadline(compact: compact),
                                SizedBox(height: compact ? 5 : 8),
                                Text(
                                  'Take full control of your time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xB8FFFFFF),
                                    fontSize: compact ? 15 : 17,
                                    height: 1.18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 30 : 58),
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: featureWidth,
                                child: _FeatureList(compact: compact),
                              ),
                            ),
                            SizedBox(height: compact ? 34 : 58),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final plan in plans) ...[
                                  _PlanCard(
                                    plan: plan,
                                    selected: plan.id == selectedId,
                                    compact: compact,
                                    onTap: () {
                                      setState(() => _selectedPlanId = plan.id);
                                      final product = plan.product;
                                      if (product != null) {
                                        context
                                            .read<PaywallCubit>()
                                            .selectProduct(product);
                                      }
                                    },
                                  ),
                                  SizedBox(height: compact ? 8 : 10),
                                ],
                              ],
                            ),
                            SizedBox(height: compact ? 2 : 4),
                            _TrialBlock(compact: compact),
                            SizedBox(height: compact ? 9 : 12),
                            _PrimaryButton(
                              compact: compact,
                              label: state.purchasing
                                  ? 'Starting...'
                                  : 'Start Free Trial',
                              onPressed: state.purchasing
                                  ? null
                                  : () => context
                                      .read<PaywallCubit>()
                                      .purchaseSelected(),
                            ),
                            if (state.error != null) ...[
                              SizedBox(height: compact ? 6 : 8),
                              Text(
                                state.error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: compact ? 11 : 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            SizedBox(height: compact ? 5 : 8),
                            _PaywallLinks(
                              restoring: state.restoring,
                              compact: compact,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, top: 6),
                      child: _CloseButton(
                        onPressed: PaywallConfig.allowFreeVersion
                            ? () => context.read<PaywallCubit>().continueFree()
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_PlanData> _plansForState(PaywallState state) {
    final yearly = _findProduct(
      state.products,
      preferred: (item) =>
          item.recommended || _containsAny(item, const ['year', 'annual']),
      fallbackIndex: 0,
    );
    final weekly = _findProduct(
      state.products,
      preferred: (item) => _containsAny(item, const ['week']),
      fallbackIndex: state.products.length > 1 ? 1 : 0,
    );
    return [
      _PlanData(
        id: yearly?.id ?? 'yearly-placeholder',
        title: 'Yearly',
        price:
            yearly?.price.isNotEmpty == true ? formatPrice(yearly?.price) : '',
        detail: 'Best Value',
        periodDetail: _yearlyPeriodDetail(yearly?.price),
        product: yearly,
      ),
      _PlanData(
        id: weekly?.id ?? 'weekly-placeholder',
        title: 'Weekly',
        price:
            weekly?.price.isNotEmpty == true ? formatPrice(weekly?.price) : '',
        detail: '',
        periodDetail: _weeklyPeriodDetail(weekly?.price),
        product: weekly,
      ),
    ];
  }

  String _yearlyPeriodDetail(String? price) {
    final parsed = _parsePrice(price);
    if (parsed == null) return r'$4.99 / month';
    final monthly = parsed.amount / 12;
    return '${parsed.currency}${monthly.toStringAsFixed(2)} / month';
  }

  String _weeklyPeriodDetail(String? price) {
    final parsed = _parsePrice(price);
    if (parsed == null) return r'$9.99 / week';
    return '${parsed.currency}${parsed.amount.toStringAsFixed(2)} / week';
  }

  _ParsedPrice? _parsePrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.replaceAll(',', '.');
    final match = RegExp(r'([^\d]*)(\d+(?:\.\d+)?)').firstMatch(normalized);
    if (match == null) return null;
    final amount = double.tryParse(match.group(2)!);
    if (amount == null) return null;
    final currency = match.group(1)?.trim();
    return _ParsedPrice(
      amount: amount,
      currency: currency?.isNotEmpty == true ? currency! : r'$',
    );
  }

  PaywallProduct? _findProduct(
    List<PaywallProduct> products, {
    required bool Function(PaywallProduct product) preferred,
    required int fallbackIndex,
  }) {
    for (final product in products) {
      if (preferred(product)) return product;
    }
    if (products.isEmpty) return null;
    return products[fallbackIndex.clamp(0, products.length - 1)];
  }

  bool _containsAny(PaywallProduct product, List<String> values) {
    final raw = '${product.id} ${product.title}'.toLowerCase();
    return values.any(raw.contains);
  }
}

class _GradientHeadline extends StatelessWidget {
  final bool compact;

  const _GradientHeadline({required this.compact});

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 35.0 : 39.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Unlock',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            height: 0.96,
            fontWeight: FontWeight.w900,
          ),
        ),
        _GradientWord('Full Access', fontSize: fontSize),
      ],
    );
  }
}

class _GradientWord extends StatelessWidget {
  final String text;
  final double fontSize;

  const _GradientWord(this.text, {required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          Color(0xFF7A4DFF),
          Color(0xFFFF4CCB),
          Color(0xFFF5B84B),
        ],
      ).createShader(rect),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 0.98,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  final bool compact;

  const _FeatureList({required this.compact});

  static const _features = [
    _FeatureData(
      asset: 'assets/lock.png',
      title: 'App Blocking & Tracking',
      glow: OnboardingPalette.violet,
    ),
    _FeatureData(
      asset: 'assets/crown.png',
      title: 'Unlimited Tracking Sessions',
      glow: OnboardingPalette.purple,
    ),
    _FeatureData(
      asset: 'assets/charts.png',
      title: 'Focus Mode',
      glow: OnboardingPalette.indigo,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final feature in _features)
          _FeatureRow(feature: feature, compact: compact),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _FeatureData feature;
  final bool compact;

  const _FeatureRow({required this.feature, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 4),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            padding: EdgeInsets.all(compact ? 8 : 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: feature.glow.withOpacity(0.12),
              border: Border.all(color: feature.glow.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: feature.glow.withOpacity(0.18),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Image.asset(feature.asset, fit: BoxFit.contain),
          ),
          SizedBox(width: compact ? 11 : 13),
          Expanded(
            child: Text(
              feature.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanData plan;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        height: compact ? 68 : 74,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xB3071028),
          border: Border.all(
            color: selected
                ? OnboardingPalette.purple.withOpacity(0.95)
                : Colors.white.withOpacity(0.12),
            width: selected ? 1.25 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: OnboardingPalette.purple.withOpacity(0.23),
                    blurRadius: 28,
                  ),
                  BoxShadow(
                    color: OnboardingPalette.pink.withOpacity(0.12),
                    blurRadius: 36,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 18 : 20,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (plan.detail.isNotEmpty) ...[
                    SizedBox(height: compact ? 5 : 7),
                    Text(
                      plan.detail,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected
                            ? OnboardingPalette.pink
                            : const Color(0x99FFFFFF),
                        fontSize: compact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      plan.price,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 23 : 25,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 5),
                    Text(
                      plan.periodDetail,
                      maxLines: 1,
                      style: TextStyle(
                        color: const Color(0x99FFFFFF),
                        fontSize: compact ? 10 : 11,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrialBlock extends StatelessWidget {
  final bool compact;

  const _TrialBlock({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          color: OnboardingPalette.purple.withOpacity(0.92),
          size: compact ? 20 : 22,
        ),
        SizedBox(width: compact ? 8 : 10),
        Flexible(
          child: Text(
            '7-day free trial. Cancel anytime.\nNo commitment. No risk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xA8FFFFFF),
              fontSize: compact ? 11 : 12,
              height: 1.22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool compact;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.compact,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 52 : 56,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: onPressed == null
              ? null
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    OnboardingPalette.electricBlue,
                    OnboardingPalette.indigo,
                    OnboardingPalette.purple,
                    OnboardingPalette.pink,
                  ],
                ),
          color: onPressed == null ? const Color(0xFF20263A) : null,
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: OnboardingPalette.indigo.withOpacity(0.34),
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
                      ? const Color(0xFF8C93A8)
                      : Colors.white,
                  fontSize: compact ? 18 : 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaywallLinks extends StatelessWidget {
  final bool restoring;
  final bool compact;

  const _PaywallLinks({required this.restoring, required this.compact});

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: Colors.white.withOpacity(0.50),
      textStyle: TextStyle(
        fontSize: compact ? 10.5 : 11.5,
        fontWeight: FontWeight.w700,
      ),
      padding: EdgeInsets.zero,
      minimumSize: Size(0, compact ? 24 : 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          style: style,
          onPressed:
              restoring ? null : () => context.read<PaywallCubit>().restore(),
          child: Text(restoring ? 'Restoring...' : 'Restore Purchase'),
        ),
        const _LinkDot(),
        TextButton(
          style: style,
          onPressed: () => _openLink(
            'https://github.com/isdemx/time_management__review_app/blob/main/TERMS.md',
          ),
          child: const Text('Terms of Service'),
        ),
        const _LinkDot(),
        TextButton(
          style: style,
          onPressed: () => _openLink(
            'https://github.com/isdemx/time_management__review_app/blob/main/PRIVACY.md',
          ),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _LinkDot extends StatelessWidget {
  const _LinkDot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '·',
        style: TextStyle(color: Color(0x80FFFFFF), fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _CloseButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      onPressed: onPressed,
      icon: Icon(
        Icons.close_rounded,
        color: Colors.white.withOpacity(0.52),
        size: 24,
      ),
    );
  }
}

class _PaywallBottomFlowPainter extends CustomPainter {
  final double progress;

  const _PaywallBottomFlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          OnboardingPalette.indigo.withOpacity(0.18),
          OnboardingPalette.purple.withOpacity(0.10),
          Colors.transparent,
        ],
        stops: const [0, 0.46, 1],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.52, size.height * 0.92),
          radius: size.width * 0.72,
        ),
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final baseY = size.height * 0.78;
    for (var i = 0; i < 7; i++) {
      final t = (progress + i * 0.075) % 1;
      final opacity = (0.055 - i * 0.004).clamp(0.020, 0.055);
      final stroke = 1.0 + i * 0.18;
      final amplitude = 22.0 + i * 5.0;
      final yOffset = (i - 3) * 11.0;
      final phase = t * math.pi * 2 + i * 0.62;
      final path = Path();

      for (var step = 0; step <= 80; step++) {
        final x = size.width * step / 80;
        final normalized = step / 80;
        final wave = math.sin(normalized * math.pi * 2.25 + phase) +
            math.sin(normalized * math.pi * 4.7 - phase * 0.62) * 0.26;
        final y = baseY + yOffset + wave * amplitude;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final color = Color.lerp(
            OnboardingPalette.electricBlue,
            i.isEven ? OnboardingPalette.purple : OnboardingPalette.pink,
            0.58,
          ) ??
          OnboardingPalette.purple;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8)
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            OnboardingPalette.electricBlue.withOpacity(opacity),
            color.withOpacity(opacity * 1.25),
            OnboardingPalette.pink.withOpacity(opacity * 0.75),
            Colors.transparent,
          ],
          stops: const [0, 0.18, 0.54, 0.82, 1],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(path, paint);
    }

    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 16; i++) {
      final t = (progress * (0.42 + i * 0.013) + i * 0.071) % 1;
      final x = size.width * ((i * 0.173 + t * 0.18) % 1);
      final y = size.height * (0.55 + ((i * 0.137 + t * 0.38) % 0.43));
      final pulse = 0.5 + 0.5 * math.sin(progress * math.pi * 2 + i);
      particlePaint.color = Color.lerp(
        OnboardingPalette.indigo,
        OnboardingPalette.pink,
        pulse,
      )!
          .withOpacity(0.035 + pulse * 0.025);
      canvas.drawCircle(Offset(x, y), 1.4 + pulse * 1.8, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaywallBottomFlowPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FeatureData {
  final String asset;
  final String title;
  final Color glow;

  const _FeatureData({
    required this.asset,
    required this.title,
    required this.glow,
  });
}

class _PlanData {
  final String id;
  final String title;
  final String price;
  final String detail;
  final String periodDetail;
  final PaywallProduct? product;

  const _PlanData({
    required this.id,
    required this.title,
    required this.price,
    required this.detail,
    required this.periodDetail,
    this.product,
  });
}

class _ParsedPrice {
  final double amount;
  final String currency;

  const _ParsedPrice({
    required this.amount,
    required this.currency,
  });
}
