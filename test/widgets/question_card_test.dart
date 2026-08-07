import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/chat_page/subwidgets/question_card.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';

/// Records the arguments of every [answerQuestion] call so tests can assert
/// the question-scoped answer route was invoked with the CAP payload.
class _RecordingApiService extends CoquiApiService {
  final List<Map<String, dynamic>> answerQuestionCalls = [];
  bool shouldThrow = false;

  @override
  Future<void> answerQuestion(
    String sessionId,
    String questionId, {
    List<String> selected = const [],
    String? text,
  }) async {
    answerQuestionCalls.add({
      'sessionId': sessionId,
      'questionId': questionId,
      'selected': selected,
      'text': text,
    });
    if (shouldThrow) {
      throw Exception('boom');
    }
  }
}

class _NoopDatabaseService extends DatabaseService {
  @override
  Future<void> open(String databaseFile) async {}

  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async => const [];

  @override
  Future<List<CoquiMessage>> getMessages(String sessionId) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingApiService apiService;
  late ChatProvider chatProvider;

  setUp(() {
    apiService = _RecordingApiService();
    chatProvider = ChatProvider(
      apiService: apiService,
      databaseService: _NoopDatabaseService(),
    );
  });

  tearDown(() {
    chatProvider.dispose();
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Map<String, dynamic> question,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CoquiApiService>.value(value: apiService),
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: QuestionCard(question: question, sessionId: 'sess1'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders one choice chip per option', (tester) async {
    await pumpCard(tester, {
      'question_id': 'q1',
      'prompt': 'Which environment?',
      'options': ['staging', 'production'],
    });

    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.text('staging'), findsOneWidget);
    expect(find.text('production'), findsOneWidget);
  });

  testWidgets('selecting a chip and submitting posts the label', (
    tester,
  ) async {
    await pumpCard(tester, {
      'question_id': 'q1',
      'prompt': 'Which environment?',
      'options': ['staging', 'production'],
    });

    await tester.tap(find.text('staging'));
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(apiService.answerQuestionCalls, hasLength(1));
    final call = apiService.answerQuestionCalls.single;
    expect(call['sessionId'], 'sess1');
    expect(call['questionId'], 'q1');
    expect(call['selected'], ['staging']);
    expect(call['text'], isNull);
  });

  testWidgets('free-text question submits text with empty selected', (
    tester,
  ) async {
    await pumpCard(tester, {
      'question_id': 'q2',
      'prompt': 'Describe the issue',
    });

    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'it broke');
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(apiService.answerQuestionCalls, hasLength(1));
    final call = apiService.answerQuestionCalls.single;
    expect(call['sessionId'], 'sess1');
    expect(call['questionId'], 'q2');
    expect(call['selected'], isEmpty);
    expect(call['text'], 'it broke');
  });

  testWidgets('submit is disabled until an answer is valid', (tester) async {
    await pumpCard(tester, {
      'question_id': 'q2',
      'prompt': 'Describe the issue',
    });

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit'),
    );
    expect(submitButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'answer');
    await tester.pump();

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('pre-selects the suggested option when it matches', (
    tester,
  ) async {
    await pumpCard(tester, {
      'question_id': 'q1',
      'prompt': 'Which environment?',
      'options': ['staging', 'production'],
      'suggested': 'production',
    });

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'production'),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(apiService.answerQuestionCalls.single['selected'], ['production']);
  });
}
