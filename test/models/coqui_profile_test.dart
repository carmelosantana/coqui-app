import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/coqui_profile.dart';

void main() {
  group('CoquiProfile', () {
    test('parses CAP persona.json id, version, and avatar object', () {
      final profile = CoquiProfile.fromJson({
        'id': 'p_1',
        'version': 1,
        'name': 'caelum',
        'avatar': {'tint': '#2b3a52', 'image_ref': null},
        'model': 'anthropic/claude-sonnet-4',
        'allowed_roles': ['orchestrator'],
        'soul': '# Caelum',
        'created_at': '2026-08-04T00:00:00Z',
        'updated_at': '2026-08-04T00:00:00Z',
      });

      expect(profile.id, 'p_1');
      expect(profile.version, 1);
      expect(profile.avatar, {'tint': '#2b3a52', 'image_ref': null});
      expect(profile.name, 'caelum');
      expect(profile.model, 'anthropic/claude-sonnet-4');
      expect(profile.allowedRoles, ['orchestrator']);
      expect(profile.soul, '# Caelum');
    });

    test('tolerates a lighter list-summary that omits id and avatar', () {
      final profile = CoquiProfile.fromJson({
        'name': 'caelum',
        'display_name': 'Caelum',
        'description': 'A calm companion.',
        'version': 3,
        'model': 'anthropic/claude-sonnet-4',
        'allowed_roles': ['orchestrator', 'analyst'],
      });

      expect(profile.id, isNull);
      expect(profile.avatar, isNull);
      expect(profile.version, 3);
      expect(profile.name, 'caelum');
      expect(profile.allowedRoles, ['orchestrator', 'analyst']);
    });
  });
}
