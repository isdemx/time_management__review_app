enum AnalyticsEvent {
  appOpened,
  onboardingStepCompleted,
  paywallShown,
  paywallClosed,
  paywallPurchaseTapped,
  trialStarted,
  purchaseCompleted,
  purchaseFailed,
  restoreStarted,
  restoreCompleted,
  restoreFailed,
  sessionStarted,
  sessionCompleted,
  activitySwitched,
  focusStarted,
  focusCompleted,
  focusCancelled,
  trackingSetupCompleted,
  trackedAppAdded,
  trackedAppRemoved,
  appLimitReached,
  appBlockTriggered,
  temporaryUnlockRequested,
  temporaryUnlockCompleted,
}

extension AnalyticsEventName on AnalyticsEvent {
  String get eventName {
    return switch (this) {
      AnalyticsEvent.appOpened => 'app_opened',
      AnalyticsEvent.onboardingStepCompleted => 'onboarding_step_completed',
      AnalyticsEvent.paywallShown => 'paywall_shown',
      AnalyticsEvent.paywallClosed => 'paywall_closed',
      AnalyticsEvent.paywallPurchaseTapped => 'paywall_purchase_tapped',
      AnalyticsEvent.trialStarted => 'trial_started',
      AnalyticsEvent.purchaseCompleted => 'purchase_completed',
      AnalyticsEvent.purchaseFailed => 'purchase_failed',
      AnalyticsEvent.restoreStarted => 'restore_started',
      AnalyticsEvent.restoreCompleted => 'restore_completed',
      AnalyticsEvent.restoreFailed => 'restore_failed',
      AnalyticsEvent.sessionStarted => 'session_started',
      AnalyticsEvent.sessionCompleted => 'session_completed',
      AnalyticsEvent.activitySwitched => 'activity_switched',
      AnalyticsEvent.focusStarted => 'focus_started',
      AnalyticsEvent.focusCompleted => 'focus_completed',
      AnalyticsEvent.focusCancelled => 'focus_cancelled',
      AnalyticsEvent.trackingSetupCompleted => 'tracking_setup_completed',
      AnalyticsEvent.trackedAppAdded => 'tracked_app_added',
      AnalyticsEvent.trackedAppRemoved => 'tracked_app_removed',
      AnalyticsEvent.appLimitReached => 'app_limit_reached',
      AnalyticsEvent.appBlockTriggered => 'app_block_triggered',
      AnalyticsEvent.temporaryUnlockRequested => 'temporary_unlock_requested',
      AnalyticsEvent.temporaryUnlockCompleted => 'temporary_unlock_completed',
    };
  }
}

class AnalyticsProperties {
  const AnalyticsProperties._();

  static const source = 'source';
  static const placement = 'placement';
  static const closeMethod = 'close_method';
  static const step = 'step';
  static const selectedOption = 'selected_option';
  static const stepIndex = 'step_index';
  static const product = 'product';
  static const productId = 'product_id';
  static const productType = 'product_type';
  static const paywallId = 'paywall_id';
  static const price = 'price';
  static const error = 'error';
  static const activityId = 'activity_id';
  static const activityName = 'activity_name';
  static const durationSeconds = 'duration_seconds';
  static const fromActivity = 'from_activity';
  static const toActivity = 'to_activity';
  static const mode = 'mode';
  static const appName = 'app_name';
  static const limitMinutes = 'limit_minutes';
  static const unlockMinutes = 'unlock_minutes';
}

class AnalyticsUserProperties {
  const AnalyticsUserProperties._();

  static const premium = 'premium';
  static const subscriptionType = 'subscription_type';
  static const onboardingCompleted = 'onboarding_completed';
  static const focusEnabled = 'focus_enabled';
  static const trackingEnabled = 'tracking_enabled';
}
