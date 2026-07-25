import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Pages/shell/persona_rail/persona_orb.dart';
import 'package:coqui_app/Pages/shell/persona_rail/persona_rail.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class _FakeProfileProvider extends ProfileProvider {
  _FakeProfileProvider(this._list)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final List<CoquiProfile> _list;
  @override
  List<CoquiProfile> get profiles => _list;
  @override
  Future<void> fetchProfiles() async {}
}

Widget _wrap({
  required List<CoquiProfile> profiles,
  ShellController? controller,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProfileProvider>.value(
        value: _FakeProfileProvider(profiles),
      ),
      ChangeNotifierProvider<ShellController>.value(
        value: controller ?? ShellController(),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: PersonaRail())),
  );
}

const _orchestrator = CoquiProfile(
  name: 'orchestrator',
  displayName: 'Home',
  isDefault: true,
);
const _caelum = CoquiProfile(name: 'caelum', displayName: 'Caelum');
const _nova = CoquiProfile(name: 'nova', displayName: 'Nova');

void main() {
  testWidgets('renders one orb per profile plus the add button', (t) async {
    await t.pumpWidget(_wrap(profiles: const [_orchestrator, _caelum]));
    await t.pump();

    expect(find.byType(PersonaOrb), findsNWidgets(2));
    expect(find.byKey(const ValueKey('add-persona')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-orb')), findsOneWidget);
  });

  testWidgets('tapping a persona orb selects it on the controller',
      (t) async {
    final controller = ShellController();
    await t.pumpWidget(
      _wrap(profiles: const [_orchestrator, _caelum], controller: controller),
    );
    await t.pump();

    expect(controller.activePersona, isNull);

    // Tap the non-orchestrator persona (Caelum).
    final caelumOrb = find.byWidgetPredicate(
      (w) => w is PersonaOrb && w.profile.name == 'caelum',
    );
    expect(caelumOrb, findsOneWidget);
    await t.tap(caelumOrb);
    await t.pump();

    expect(controller.activePersona, 'caelum');
  });

  testWidgets('active orb reflects the controller state', (t) async {
    final controller = ShellController()..selectPersona('nova');
    await t.pumpWidget(
      _wrap(
        profiles: const [_orchestrator, _caelum, _nova],
        controller: controller,
      ),
    );
    await t.pump();

    final novaOrb = t.widget<PersonaOrb>(
      find.byWidgetPredicate(
        (w) => w is PersonaOrb && w.profile.name == 'nova',
      ),
    );
    final caelumOrb = t.widget<PersonaOrb>(
      find.byWidgetPredicate(
        (w) => w is PersonaOrb && w.profile.name == 'caelum',
      ),
    );

    expect(novaOrb.active, isTrue);
    expect(caelumOrb.active, isFalse);
  });

  testWidgets('orchestrator is rendered from the isDefault profile',
      (t) async {
    await t.pumpWidget(_wrap(profiles: const [_orchestrator, _caelum]));
    await t.pump();

    final orchestratorOrb = t.widget<PersonaOrb>(
      find.byWidgetPredicate(
        (w) => w is PersonaOrb && w.profile.name == 'orchestrator',
      ),
    );
    expect(orchestratorOrb.profile.isDefault, isTrue);
  });
}
