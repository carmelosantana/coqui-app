import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_channel_driver.dart';
import 'package:coqui_app/Pages/channels_page/subwidgets/channel_editor_sheet.dart';
import 'package:coqui_app/Providers/channel_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class _FakeApiService extends CoquiApiService {
  final List<CoquiChannelDriver> drivers;

  _FakeApiService({required this.drivers});

  @override
  Future<List<CoquiChannelDriver>> listChannelDrivers() async {
    return List<CoquiChannelDriver>.from(drivers);
  }
}

void main() {
  Future<void> pumpEditorSheet(
    WidgetTester tester, {
    required CoquiApiService apiService,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CoquiApiService>.value(value: apiService),
          ChangeNotifierProvider<ChannelProvider>(
            create: (_) => ChannelProvider(apiService: apiService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChannelEditorSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('ChannelEditorSheet', () {
    testWidgets('shows scaffolded drivers as disabled options', (tester) async {
      final apiService = _FakeApiService(
        drivers: [
          CoquiChannelDriver(
            name: 'signal',
            displayName: 'Signal',
            capabilities: const {},
            package: 'coquibot/coqui',
          ),
          CoquiChannelDriver(
            name: 'telegram',
            displayName: 'Telegram',
            capabilities: const {},
            package: 'coquibot/coqui',
          ),
          CoquiChannelDriver(
            name: 'discord',
            displayName: 'Discord',
            capabilities: const {},
            package: 'coquibot/coqui',
          ),
        ],
      );

      await pumpEditorSheet(tester, apiService: apiService);

      expect(
        find.text(
          'Telegram and Discord are visible for roadmap clarity, but setup is disabled until their transport runtimes ship.',
        ),
        findsOneWidget,
      );

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      final items = dropdown.items!;

      expect(
          items.map((item) => item.value), ['signal', 'telegram', 'discord']);

      final telegramItem = items.firstWhere((item) => item.value == 'telegram');
      final discordItem = items.firstWhere((item) => item.value == 'discord');
      final signalItem = items.firstWhere((item) => item.value == 'signal');

      expect(signalItem.enabled, isTrue);
      expect(telegramItem.enabled, isFalse);
      expect(discordItem.enabled, isFalse);
    });
  });
}
