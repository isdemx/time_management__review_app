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

class _PaywallView extends StatelessWidget {
  final VoidCallback? onCompleted;

  const _PaywallView({this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaywallCubit, PaywallState>(
      listener: (context, state) {
        if (state.completed) {
          onCompleted?.call();
          Navigator.of(context).maybePop(true);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chronika Premium'),
            leading: IconButton(
              onPressed: PaywallConfig.allowFreeVersion
                  ? () => context.read<PaywallCubit>().continueFree()
                  : null,
              icon: const Icon(Icons.close),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Start understanding your days.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock the full Chronika experience.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                for (final benefit in const [
                  'Unlimited History',
                  'Focus Sessions',
                  'Daily Reflections',
                  'Weekly Insights',
                  'Mood & Energy Tracking',
                  'Smart Suggestions',
                ])
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(benefit),
                  ),
                const SizedBox(height: 16),
                if (state.loading)
                  const Center(child: CircularProgressIndicator())
                else if (state.products.isEmpty)
                  const _PaywallMessage(
                    title: 'Products are not available',
                    body:
                        'Connect Apphud API key and products to enable purchases.',
                  )
                else
                  for (final product in state.products)
                    _ProductTile(
                      product: product,
                      selected: state.selectedProduct?.id == product.id,
                      onTap: () {
                        context.read<PaywallCubit>().selectProduct(product);
                      },
                    ),
                const SizedBox(height: 18),
                const Text('3-day free trial'),
                const Text('Cancel anytime'),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: state.purchasing
                      ? null
                      : () => context.read<PaywallCubit>().purchaseSelected(),
                  child: Text(
                    state.purchasing ? 'Starting...' : 'Start Free Trial',
                  ),
                ),
                TextButton(
                  onPressed: state.restoring
                      ? null
                      : () => context.read<PaywallCubit>().restore(),
                  child: Text(
                    state.restoring ? 'Restoring...' : 'Restore Purchases',
                  ),
                ),
                if (PaywallConfig.allowFreeVersion)
                  TextButton(
                    onPressed: () =>
                        context.read<PaywallCubit>().continueFree(),
                    child: const Text('Continue with Free Version'),
                  ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => _openLink('https://chronika.app/terms'),
                      child: const Text('Terms of Use'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _openLink('https://chronika.app/privacy'),
                      child: const Text('Privacy Policy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ProductTile extends StatelessWidget {
  final PaywallProduct product;
  final bool selected;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
        title: Row(
          children: [
            Flexible(child: Text(product.title)),
            if (product.recommended) ...[
              const SizedBox(width: 8),
              const Chip(label: Text('Recommended')),
            ],
          ],
        ),
        subtitle:
            Text(product.price.isEmpty ? 'Price from Apphud' : product.price),
      ),
    );
  }
}

class _PaywallMessage extends StatelessWidget {
  final String title;
  final String body;

  const _PaywallMessage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    );
  }
}
