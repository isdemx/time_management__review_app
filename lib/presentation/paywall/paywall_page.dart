import 'dart:math' as math;
import 'dart:ui' as ui;

// Keep compatibility with the current release Flutter toolchain.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:time_tracker/application/paywall/paywall_cubit.dart';
import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';

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
    return BlocProvider(
      create: (context) => PaywallCubit(
        service: context.read<PaywallService>(),
        source: source,
      )..load(),
      child: _PaywallView(onCompleted: onCompleted),
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
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4700),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF02081A),
                  Color(0xFF07132D),
                  Color(0xFF02081A),
                ],
              ),
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _orbitController,
                _pulseController,
              ]),
              builder: (context, _) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PaywallOrbitPainter(
                          progress: _orbitController.value,
                          breath: _breath,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _CloseButton(
                              onPressed: PaywallConfig.allowFreeVersion
                                  ? () => context
                                      .read<PaywallCubit>()
                                      .continueFree()
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _GradientHeadline(),
                          const SizedBox(height: 10),
                          const Text(
                            'Upgrade to Premium and take full control of your time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 16,
                              height: 1.28,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const _FeatureList(),
                          const SizedBox(height: 14),
                          for (final plan in plans) ...[
                            _PlanCard(
                              plan: plan,
                              selected: plan.id == selectedId,
                              pulse: _planPulse,
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
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 6),
                          const _TrialBlock(),
                          const SizedBox(height: 14),
                          _PrimaryButton(
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
                            const SizedBox(height: 12),
                            Text(
                              state.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _PaywallLinks(restoring: state.restoring),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  double get _breath {
    return 0.8 +
        Curves.easeInOut.transform(
              (math.sin(_pulseController.value * math.pi * 2) + 1) / 2,
            ) *
            0.2;
  }

  double get _planPulse {
    final phase = math.sin(_pulseController.value * math.pi * 2);
    return 1 + math.max(0, phase) * 0.018;
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
        price: yearly?.price.isNotEmpty == true ? yearly!.price : r'$49.99',
        detail: r'$4.99 / month',
        badge: 'BEST VALUE',
        product: yearly,
      ),
      _PlanData(
        id: weekly?.id ?? 'weekly-placeholder',
        title: 'Weekly',
        price: weekly?.price.isNotEmpty == true ? weekly!.price : r'$9.99',
        detail: r'$9.99 / week',
        product: weekly,
      ),
    ];
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
  const _GradientHeadline();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w900,
        ),
        children: [
          TextSpan(text: 'Unlock your '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _GradientWord('potential.'),
          ),
        ],
      ),
    );
  }
}

class _GradientWord extends StatelessWidget {
  final String text;

  const _GradientWord(this.text);

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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _features = [
    _FeatureData(
      asset: 'assets/crown.png',
      title: 'Unlimited Focus Sessions',
      body: 'Track without limits. Stay in the flow.',
      glow: Color(0xFFF5B84B),
    ),
    _FeatureData(
      asset: 'assets/charts.png',
      title: 'Advanced Analytics',
      body: 'Deep insights. Real progress.',
      glow: Color(0xFF7A4DFF),
    ),
    _FeatureData(
      asset: 'assets/lock.png',
      title: 'Focus Mode',
      body: 'Block distractions. Protect your focus.',
      glow: Color(0xFF198DFF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final feature in _features) _FeatureRow(feature: feature),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final _FeatureData feature;

  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: feature.glow.withOpacity(0.09),
              border: Border.all(color: feature.glow.withOpacity(0.24)),
              boxShadow: [
                BoxShadow(
                  color: feature.glow.withOpacity(0.10),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Image.asset(feature.asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.body,
                  style: const TextStyle(
                    color: Color(0xA8FFFFFF),
                    fontSize: 13,
                    height: 1.16,
                    fontWeight: FontWeight.w600,
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

class _PlanCard extends StatelessWidget {
  final _PlanData plan;
  final bool selected;
  final double pulse;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scale = selected && plan.badge != null ? pulse : 1.0;
    return Transform.scale(
      scale: scale,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? const Color(0xFF19110A).withOpacity(0.72)
                : const Color(0xFF071024).withOpacity(0.72),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF5B84B)
                  : Colors.white.withOpacity(0.12),
              width: selected ? 1.25 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFF5B84B).withOpacity(0.26),
                      blurRadius: 26,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _RadioDot(selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (plan.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFF5B84B).withOpacity(0.14),
                            ),
                            child: Text(
                              plan.badge!,
                              style: const TextStyle(
                                color: Color(0xFFF5B84B),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.title == 'Yearly'
                          ? 'Billed yearly'
                          : 'Billed weekly',
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFFF5B84B)
                            : const Color(0x9AFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        plan.price,
                        maxLines: 1,
                        style: TextStyle(
                          color:
                              selected ? const Color(0xFFF5B84B) : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        plan.detail,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0x99FFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 26,
      height: 26,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFFF5B84B) : const Color(0xFF6C7380),
          width: 2,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? const Color(0xFFF5B84B) : Colors.transparent,
        ),
      ),
    );
  }
}

class _TrialBlock extends StatelessWidget {
  const _TrialBlock();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, color: Color(0xFF8E4DFF), size: 27),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            '7-day free trial. Cancel anytime.\nNo commitment. No risk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xA8FFFFFF),
              fontSize: 14,
              height: 1.35,
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
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: onPressed == null
              ? const Color(0xFF3B3D42)
              : const Color(0xFFF5B84B),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFF5B84B).withOpacity(0.34),
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
                      ? const Color(0xFF9B9CA1)
                      : Colors.black,
                  fontSize: 18,
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

class _PaywallLinks extends StatelessWidget {
  final bool restoring;

  const _PaywallLinks({required this.restoring});

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: Colors.white.withOpacity(0.50),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
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
          onPressed: () => _openLink('https://chronika.app/terms'),
          child: const Text('Terms of Use'),
        ),
        const _LinkDot(),
        TextButton(
          style: style,
          onPressed: () => _openLink('https://chronika.app/privacy'),
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
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onPressed,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaywallOrbitPainter extends CustomPainter {
  final double progress;
  final double breath;

  const _PaywallOrbitPainter({
    required this.progress,
    required this.breath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.18);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF1A7DFF).withOpacity(0.14 * breath),
          const Color(0xFFFF4CCB).withOpacity(0.08 * breath),
          Colors.transparent,
        ],
      ).createShader(
          Rect.fromCircle(center: center, radius: size.width * 0.55));
    canvas.drawCircle(center, size.width * 0.55, glow);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 14; i++) {
      final angle = progress * math.pi * 2 * (0.35 + i % 4 * 0.05) + i * 1.7;
      final radius = size.width * (0.22 + (i % 5) * 0.04);
      final pos = center +
          Offset(
            math.cos(angle) * radius,
            math.sin(angle) * radius * 0.45,
          );
      dotPaint.color = Color.lerp(
        const Color(0xFF198DFF),
        const Color(0xFFF5B84B),
        (i % 5) / 4,
      )!
          .withOpacity(0.18);
      canvas.drawCircle(pos, 1.2 + (i % 4) * 0.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaywallOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.breath != breath;
  }
}

class _FeatureData {
  final String asset;
  final String title;
  final String body;
  final Color glow;

  const _FeatureData({
    required this.asset,
    required this.title,
    required this.body,
    required this.glow,
  });
}

class _PlanData {
  final String id;
  final String title;
  final String price;
  final String detail;
  final String? badge;
  final PaywallProduct? product;

  const _PlanData({
    required this.id,
    required this.title,
    required this.price,
    required this.detail,
    this.badge,
    this.product,
  });
}
