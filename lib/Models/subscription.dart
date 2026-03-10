/// A subscription from the CoquiBot SaaS API.
class Subscription {
  final int id;
  final String status;
  final String? stripeSubscriptionId;
  final String purchaseSource;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime createdAt;
  final SubscriptionPlan? plan;

  Subscription({
    required this.id,
    required this.status,
    this.stripeSubscriptionId,
    required this.purchaseSource,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.createdAt,
    this.plan,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as int,
      status: json['status'] as String,
      stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
      purchaseSource: json['purchaseSource'] as String? ?? 'stripe',
      currentPeriodStart: json['currentPeriodStart'] != null
          ? DateTime.parse(json['currentPeriodStart'] as String)
          : null,
      currentPeriodEnd: json['currentPeriodEnd'] != null
          ? DateTime.parse(json['currentPeriodEnd'] as String)
          : null,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      plan: json['plan'] != null
          ? SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isCanceled => status == 'canceled';
  bool get isPastDue => status == 'past_due';
  bool get isIap => purchaseSource == 'apple' || purchaseSource == 'google';
  bool get isStripe => purchaseSource == 'stripe';

  /// Formatted status for display.
  String get displayStatus {
    if (cancelAtPeriodEnd && isActive) return 'Cancels at period end';
    return switch (status) {
      'active' => 'Active',
      'canceled' => 'Canceled',
      'past_due' => 'Past Due',
      'incomplete' => 'Incomplete',
      _ => status,
    };
  }
}

/// Subset of plan info returned with a subscription.
class SubscriptionPlan {
  final int id;
  final String name;
  final String displayName;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
    );
  }
}
