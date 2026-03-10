/// A hosting plan from the CoquiBot SaaS API.
class Plan {
  final int id;
  final String name;
  final String displayName;
  final int priceInCents;
  final int? iapPriceInCents;
  final String? stripePriceId;
  final String? iapAppleProductId;
  final String? iapGoogleProductId;
  final int vcpuCount;
  final int ramMb;
  final int diskGb;
  final int bandwidth;
  final String vultrPlan;
  final int maxInstances;
  final bool isActive;

  Plan({
    required this.id,
    required this.name,
    required this.displayName,
    required this.priceInCents,
    this.iapPriceInCents,
    this.stripePriceId,
    this.iapAppleProductId,
    this.iapGoogleProductId,
    required this.vcpuCount,
    required this.ramMb,
    required this.diskGb,
    required this.bandwidth,
    required this.vultrPlan,
    required this.maxInstances,
    required this.isActive,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'] as int,
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      priceInCents: json['priceInCents'] as int,
      iapPriceInCents: json['iapPriceInCents'] as int?,
      stripePriceId: json['stripePriceId'] as String?,
      iapAppleProductId: json['iapAppleProductId'] as String?,
      iapGoogleProductId: json['iapGoogleProductId'] as String?,
      vcpuCount: json['vcpuCount'] as int,
      ramMb: json['ramMb'] as int,
      diskGb: json['diskGb'] as int,
      bandwidth: json['bandwidth'] as int,
      vultrPlan: json['vultrPlan'] as String,
      maxInstances: json['maxInstances'] as int,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// Formatted web price (e.g. "\$15.00/mo").
  String get formattedPrice {
    final dollars = priceInCents / 100;
    return '\$${dollars.toStringAsFixed(2)}/mo';
  }

  /// Formatted IAP price (e.g. "\$19.99/mo") or null if no IAP price.
  String? get formattedIapPrice {
    if (iapPriceInCents == null) return null;
    final dollars = iapPriceInCents! / 100;
    return '\$${dollars.toStringAsFixed(2)}/mo';
  }

  /// Human-readable RAM (e.g., "2 GB").
  String get formattedRam {
    if (ramMb >= 1024) {
      final gb = ramMb / 1024;
      return '${gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1)} GB';
    }
    return '$ramMb MB';
  }

  /// Feature summary for plan cards.
  List<String> get features => [
        '$vcpuCount vCPU${vcpuCount > 1 ? 's' : ''}',
        formattedRam,
        '$diskGb GB SSD',
        '$bandwidth TB bandwidth',
        '$maxInstances instance${maxInstances > 1 ? 's' : ''}',
      ];
}
