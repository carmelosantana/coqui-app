import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Models/cursor_page.dart';

void main() {
  test('CursorPage.fromJson parses data + next_cursor', () {
    final page = CursorPage<Map<String, dynamic>>.fromJson(
      {'data': [{'x': 1}, {'x': 2}], 'next_cursor': 'c_abc'},
      (m) => m,
    );
    expect(page.data.length, 2);
    expect(page.data.first['x'], 1);
    expect(page.nextCursor, 'c_abc');
  });

  test('CursorPage.fromJson tolerates null next_cursor and missing data', () {
    final page = CursorPage<Map<String, dynamic>>.fromJson(
      {'data': [], 'next_cursor': null},
      (m) => m,
    );
    expect(page.data, isEmpty);
    expect(page.nextCursor, isNull);
  });
}
