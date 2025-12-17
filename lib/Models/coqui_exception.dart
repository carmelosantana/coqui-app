/// Exception thrown when a Coqui API request fails.
class CoquiException implements Exception {
  final String message;
  final int? statusCode;

  CoquiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
