/// A server region from the Vultr API.
class Region {
  final String id;
  final String city;
  final String country;
  final String continent;

  Region({
    required this.id,
    required this.city,
    required this.country,
    required this.continent,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      city: json['city'] as String,
      country: json['country'] as String,
      continent: json['continent'] as String,
    );
  }

  /// Display label (e.g. "New York, US").
  String get displayLabel => '$city, $country';
}
