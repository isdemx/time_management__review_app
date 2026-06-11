import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:time_tracker/application/paywall/paywall_models.dart';
import 'package:time_tracker/application/paywall/paywall_service.dart';
import 'package:time_tracker/presentation/paywall/paywall_page.dart';

Future<bool> hasPremiumAccess(BuildContext context) {
  return context.read<PaywallService>().hasPremiumAccess();
}

Future<bool> openPaywallIfNeeded(
  BuildContext context, {
  required String source,
  VoidCallback? onCompleted,
}) async {
  final paywallService = context.read<PaywallService>();
  if (await paywallService.hasPremiumAccess()) {
    onCompleted?.call();
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PaywallPage(
        source: source,
        onCompleted: onCompleted,
      ),
    ),
  );
  if (!context.mounted) {
    return false;
  }
  return paywallService.hasPremiumAccess();
}

Future<bool> ensurePremiumAccess(
  BuildContext context, {
  required PremiumFeature feature,
  required String source,
}) async {
  final paywallService = context.read<PaywallService>();
  final canUse = await paywallService.canUse(feature);
  if (canUse) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final unlocked = await openPaywallIfNeeded(
    context,
    source: source,
  );
  if (!unlocked || !context.mounted) {
    return false;
  }
  return paywallService.canUse(feature);
}
