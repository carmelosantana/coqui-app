import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:coqui_app/Constants/constants.dart';

void main() {
  group('App smoke tests', () {
    test('AppConstants has valid app name', () {
      expect(AppConstants.appName, isNotEmpty);
    });

    test('Hive can be initialized for testing', () async {
      Hive.init('/tmp/coqui_test_hive');
      final box = await Hive.openBox('test_settings');
      expect(box.isOpen, isTrue);

      box.put('brightness', null);
      expect(box.get('brightness'), isNull);

      await box.close();
      await Hive.close();
    });

    testWidgets('MaterialApp renders with default theme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          title: 'Coqui',
          home: Scaffold(
            body: Center(child: Text('Coqui')),
          ),
        ),
      );

      expect(find.text('Coqui'), findsOneWidget);
    });
  });
}
