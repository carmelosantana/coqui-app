/// A billing event from the CoquiBot SaaS API.
class BillingEvent {
  final int id;
  final String type;
  final int amountInCents;
  final String currency;
  final String? description;
  final String? stripeInvoiceId;
  final DateTime createdAt;

  BillingEvent({
    required this.id,
    required this.type,
    required this.amountInCents,
    required this.currency,
    this.description,
    this.stripeInvoiceId,
    required this.createdAt,
  });

  factory BillingEvent.fromJson(Map<String, dynamic> json) {
    return BillingEvent(
      id: json['id'] as int,
      type: json['type'] as String,
      amountInCents: json['amountInCents'] as int,
      currency: json['currency'] as String? ?? 'usd',
      description: json['description'] as String?,
      stripeInvoiceId: json['stripeInvoiceId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Formatted amount (e.g. "\$15.00").
  String get formattedAmount {
    final dollars = amountInCents / 100;
    return '\$${dollars.toStringAsFixed(2)}';
  }

  /// Display-friendly type.
  String get displayType => switch (type) {
        'charge' => 'Payment',
        'refund' => 'Refund',
        'credit' => 'Credit',
        _ => type,
      };
}
