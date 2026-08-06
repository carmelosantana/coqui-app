/// A generic cursor-paginated envelope for CAP 0.5.0 list endpoints.
///
/// Every list endpoint now returns `{ "data": [ ... ], "next_cursor": "<opaque>" | null }`,
/// replacing the former named-key wrappers. [CursorPage] parses that shape once;
/// callers read [data] for the items and [nextCursor] where pagination is supported.
class CursorPage<T> {
  final List<T> data;
  final String? nextCursor;
  const CursorPage(this.data, this.nextCursor);

  factory CursorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) item,
  ) {
    final raw = (json['data'] as List<dynamic>?) ?? const [];
    return CursorPage(
      raw.map((e) => item(e as Map<String, dynamic>)).toList(),
      json['next_cursor'] as String?,
    );
  }
}
