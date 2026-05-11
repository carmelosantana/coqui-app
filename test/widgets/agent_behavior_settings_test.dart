import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_context_settings.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Pages/settings_page/subwidgets/agent_behavior_settings.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

class _FakeContextApiService extends CoquiApiService {
  Map<String, dynamic>? lastValues;
  List<String>? lastReset;
  bool restartRequired = false;

  final CoquiContextSettingsValues _defaults =
      CoquiContextSettingsValues.fromJson(const {
    'conversationHistoryInSystemPrompt': false,
    'autoSummarizeMode': 'token',
    'autoSummarizeThreshold': 64,
    'autoSummarizeTurnThreshold': 32,
    'autoSummarizeKeepRecent': 15,
  });

  late CoquiContextSettingsValues _current;

  _FakeContextApiService() {
    _current = _defaults;
  }

  @override
  Future<Map<String, dynamic>> healthCheck() async => {
        'status': 'ok',
        'restart': {
          'required': restartRequired,
          'supported': true,
          'managed_by_launcher': true,
          'reason': restartRequired
              ? 'Agent context configuration changed. Restart the API server to apply the new behavior cleanly.'
              : null,
          'source': restartRequired ? 'api.config.context.update' : null,
        },
      };

  @override
  Future<CoquiContextSettings> getContextSettings() async =>
      CoquiContextSettings.fromJson({
        'context': {
          'conversationHistoryInSystemPrompt':
              _current.conversationHistoryInSystemPrompt,
          'autoSummarizeMode': _current.autoSummarizeMode,
          'autoSummarizeThreshold': _current.autoSummarizeThreshold,
          'autoSummarizeTurnThreshold': _current.autoSummarizeTurnThreshold,
          'autoSummarizeKeepRecent': _current.autoSummarizeKeepRecent,
        },
        'defaults': {
          'conversationHistoryInSystemPrompt':
              _defaults.conversationHistoryInSystemPrompt,
          'autoSummarizeMode': _defaults.autoSummarizeMode,
          'autoSummarizeThreshold': _defaults.autoSummarizeThreshold,
          'autoSummarizeTurnThreshold': _defaults.autoSummarizeTurnThreshold,
          'autoSummarizeKeepRecent': _defaults.autoSummarizeKeepRecent,
        },
        'fields': {
          'conversationHistoryInSystemPrompt': {
            'key': 'conversationHistoryInSystemPrompt',
            'dot_key':
                'agents.defaults.context.conversationHistoryInSystemPrompt',
            'label': 'Conversation History In System Prompt',
            'description':
                'Render prior active messages into a compact Conversation History system-prompt block in addition to normal message replay.',
            'type': 'boolean',
            'resettable': true,
            'restart_required': true,
            'configured': false,
            'default': false,
            'value': _current.conversationHistoryInSystemPrompt,
          },
          'autoSummarizeMode': {
            'key': 'autoSummarizeMode',
            'dot_key': 'agents.defaults.context.autoSummarizeMode',
            'label': 'Auto-Summarize Mode',
            'description':
                'Choose whether Coqui summarizes based on token budget, turn count, or only when you request it manually.',
            'type': 'enum',
            'resettable': true,
            'restart_required': true,
            'configured': false,
            'default': 'token',
            'value': _current.autoSummarizeMode,
            'options': ['token', 'turn', 'manual'],
          },
          'autoSummarizeThreshold': {
            'key': 'autoSummarizeThreshold',
            'dot_key': 'agents.defaults.context.autoSummarizeThreshold',
            'label': 'Auto-Summarize Threshold',
            'description':
                'Token usage percentage that triggers auto-summarization when Auto-Summarize Mode is set to token.',
            'type': 'number',
            'resettable': true,
            'restart_required': true,
            'configured': false,
            'default': 64,
            'value': _current.autoSummarizeThreshold,
            'minimum': 0,
            'maximum': 100,
            'presentation': 'percent',
          },
          'autoSummarizeTurnThreshold': {
            'key': 'autoSummarizeTurnThreshold',
            'dot_key': 'agents.defaults.context.autoSummarizeTurnThreshold',
            'label': 'Auto-Summarize Turn Threshold',
            'description':
                'Number of user turns that triggers auto-summarization when Auto-Summarize Mode is set to turn.',
            'type': 'integer',
            'resettable': true,
            'restart_required': true,
            'configured': false,
            'default': 32,
            'value': _current.autoSummarizeTurnThreshold,
            'minimum': 1,
          },
          'autoSummarizeKeepRecent': {
            'key': 'autoSummarizeKeepRecent',
            'dot_key': 'agents.defaults.context.autoSummarizeKeepRecent',
            'label': 'Auto-Summarize Keep Recent',
            'description':
                'How many recent turns are preserved when Coqui auto-summarizes a conversation.',
            'type': 'integer',
            'resettable': true,
            'restart_required': true,
            'configured': false,
            'default': 15,
            'value': _current.autoSummarizeKeepRecent,
            'minimum': 1,
            'maximum': 20,
          },
        },
        'restart': {
          'required': restartRequired,
          'supported': true,
          'managed_by_launcher': true,
          'reason': restartRequired
              ? 'Agent context configuration changed. Restart the API server to apply the new behavior cleanly.'
              : null,
          'source': restartRequired ? 'api.config.context.update' : null,
        },
      });

  @override
  Future<CoquiContextSettingsUpdateResult> updateContextSettings({
    Map<String, dynamic> values = const <String, dynamic>{},
    List<String> reset = const <String>[],
  }) async {
    lastValues = Map<String, dynamic>.from(values);
    lastReset = List<String>.from(reset);

    final next = <String, dynamic>{
      'conversationHistoryInSystemPrompt':
          _current.conversationHistoryInSystemPrompt,
      'autoSummarizeMode': _current.autoSummarizeMode,
      'autoSummarizeThreshold': _current.autoSummarizeThreshold,
      'autoSummarizeTurnThreshold': _current.autoSummarizeTurnThreshold,
      'autoSummarizeKeepRecent': _current.autoSummarizeKeepRecent,
    };

    for (final key in reset) {
      switch (key) {
        case 'conversationHistoryInSystemPrompt':
          next[key] = _defaults.conversationHistoryInSystemPrompt;
        case 'autoSummarizeMode':
          next[key] = _defaults.autoSummarizeMode;
        case 'autoSummarizeThreshold':
          next[key] = _defaults.autoSummarizeThreshold;
        case 'autoSummarizeTurnThreshold':
          next[key] = _defaults.autoSummarizeTurnThreshold;
        case 'autoSummarizeKeepRecent':
          next[key] = _defaults.autoSummarizeKeepRecent;
      }
    }

    values.forEach((key, value) {
      next[key] = value;
    });

    _current = CoquiContextSettingsValues.fromJson(next);
    restartRequired = true;

    return CoquiContextSettingsUpdateResult.fromJson({
      'context': next,
      'updated': values.keys.toList(growable: false),
      'reset': reset,
      'restart_required': true,
      'restart': {
        'required': true,
        'supported': true,
        'managed_by_launcher': true,
        'reason':
            'Agent context configuration changed. Restart the API server to apply the new behavior cleanly.',
        'source': 'api.config.context.update',
      },
    });
  }
}

class _FakeInstanceService extends InstanceService {
  final CoquiInstance _instance;

  _FakeInstanceService(this._instance);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureDefaultInstance() async {}

  @override
  List<CoquiInstance> getInstances() => [_instance];

  @override
  CoquiInstance? getActiveInstance() => _instance;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    required InstanceProvider instanceProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InstanceProvider>.value(value: instanceProvider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AgentBehaviorSettings(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows token mode fields and switches to turn mode fields',
      (tester) async {
    final apiService = _FakeContextApiService();
    final instanceProvider = InstanceProvider(
      instanceService: _FakeInstanceService(
        CoquiInstance(
          id: 'instance-1',
          name: 'Local',
          baseUrl: 'http://localhost:3300',
          apiKey: '',
          isActive: true,
        ),
      ),
      apiService: apiService,
    );

    addTearDown(instanceProvider.dispose);

    await tester.pumpWidget(buildSubject(instanceProvider: instanceProvider));
    await tester.pumpAndSettle();
    instanceProvider.pauseForDestructiveReset();

    expect(find.text('Agent Behavior'), findsOneWidget);
    expect(find.text('Auto-Summarize Threshold'), findsOneWidget);
    expect(find.text('Auto-Summarize Turn Threshold'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('turn').last);
    await tester.pumpAndSettle();

    expect(find.text('Auto-Summarize Threshold'), findsNothing);
    expect(find.text('Auto-Summarize Turn Threshold'), findsOneWidget);
  });

  testWidgets('saves changes and prompts for restart when required',
      (tester) async {
    final apiService = _FakeContextApiService();
    final instanceProvider = InstanceProvider(
      instanceService: _FakeInstanceService(
        CoquiInstance(
          id: 'instance-1',
          name: 'Local',
          baseUrl: 'http://localhost:3300',
          apiKey: '',
          isActive: true,
        ),
      ),
      apiService: apiService,
    );

    addTearDown(instanceProvider.dispose);

    await tester.pumpWidget(buildSubject(instanceProvider: instanceProvider));
    await tester.pumpAndSettle();
    instanceProvider.pauseForDestructiveReset();

    await tester.enterText(
      find.byType(TextField).at(1),
      '12',
    );
    await tester.pump();

    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(apiService.lastValues?['autoSummarizeKeepRecent'], 12);
    expect(find.text('Restart API server?'), findsOneWidget);
  });
}
