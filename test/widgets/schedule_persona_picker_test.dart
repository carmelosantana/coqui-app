import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Pages/tasks_page/subwidgets/schedule_editor_sheet.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Providers/schedule_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// Captures the persona id passed to schedule create/update calls and serves a
/// fixed pair of personas for the picker.
class _FakeApiService extends CoquiApiService {
  _FakeApiService({required this.profiles});

  final List<CoquiProfile> profiles;
  String? capturedCreatePersonaId;
  String? capturedUpdatePersonaId;

  @override
  Future<List<CoquiProfile>> getProfiles() async {
    return List<CoquiProfile>.from(profiles);
  }

  @override
  Future<CoquiSchedule> createSchedule({
    required String name,
    required String cron,
    required String personaId,
    required ScheduleAction action,
  }) async {
    capturedCreatePersonaId = personaId;
    return CoquiSchedule(
      id: 'sched-1',
      name: name,
      cron: cron,
      personaId: personaId,
      action: action,
      status: 'enabled',
    );
  }

  @override
  Future<CoquiSchedule> updateSchedule(
    String id, {
    String? name,
    String? cron,
    String? personaId,
    ScheduleAction? action,
    String? status,
  }) async {
    capturedUpdatePersonaId = personaId;
    return CoquiSchedule(
      id: id,
      name: name ?? '',
      cron: cron ?? '',
      personaId: personaId ?? '',
      action: action ?? const ScheduleAction(kind: 'turn', prompt: ''),
      status: status ?? 'enabled',
    );
  }
}

void main() {
  const profiles = [
    CoquiProfile(
      name: 'analyst',
      displayName: 'Analyst',
      description: 'Deep research persona.',
    ),
    CoquiProfile(
      name: 'builder',
      displayName: 'Builder',
      description: 'Ships code fast.',
    ),
  ];

  Future<void> pumpEditor(
    WidgetTester tester, {
    required _FakeApiService apiService,
    CoquiSchedule? schedule,
  }) async {
    final profileProvider = ProfileProvider(apiService: apiService);
    final scheduleProvider = ScheduleProvider(apiService: apiService);

    await tester.binding.setSurfaceSize(const Size(900, 2000));

    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      profileProvider.dispose();
      scheduleProvider.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ChangeNotifierProvider<ScheduleProvider>.value(
            value: scheduleProvider,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ScheduleEditorSheet(schedule: schedule),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('picker stores the selected persona name as persona_id',
      (tester) async {
    final apiService = _FakeApiService(profiles: profiles);

    await pumpEditor(tester, apiService: apiService);

    await tester.enterText(find.byType(TextField).at(0), 'daily-review');
    await tester.enterText(find.byType(TextField).at(1), '0 9 * * 1-5');
    await tester.enterText(find.byType(TextField).at(2), 'Run the review.');

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Builder'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Select'));
    await tester.pumpAndSettle();

    expect(find.text('builder'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(apiService.capturedCreatePersonaId, 'builder');
  });

  testWidgets('existing schedule prefills its persona id', (tester) async {
    final apiService = _FakeApiService(profiles: profiles);
    const schedule = CoquiSchedule(
      id: 'sched-42',
      name: 'existing',
      cron: '0 9 * * *',
      personaId: 'foo',
      action: ScheduleAction(kind: 'turn', prompt: 'Do it.'),
      status: 'enabled',
    );

    await pumpEditor(tester, apiService: apiService, schedule: schedule);

    expect(find.text('foo'), findsOneWidget);
  });
}
