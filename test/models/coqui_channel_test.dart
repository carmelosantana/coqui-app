import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Models/coqui_channel_delivery.dart';
import 'package:coqui_app/Models/coqui_channel_driver.dart';
import 'package:coqui_app/Models/coqui_channel_event.dart';
import 'package:coqui_app/Models/coqui_channel_link.dart';
import 'package:coqui_app/Models/coqui_channel_stats.dart';

void main() {
  group('CoquiChannel models', () {
    test('parses channel payload and helper flags', () {
      final channel = CoquiChannel.fromJson({
        'id': 'channel-1',
        'name': 'signal-primary',
        'driver': 'signal',
        'display_name': 'Signal Primary',
        'enabled': true,
        'default_profile': 'caelum',
        'bound_session_id': 'session-123',
        'settings': {
          'account': '+15551234567',
          'binary': 'signal-cli',
          'ignoreAttachments': true,
          'sendReadReceipts': false,
        },
        'allowed_scopes': ['group-1'],
        'security': {'linkRequired': true},
        'capabilities': {'direct_messages': true, 'groups': true},
        'worker_status': 'running',
        'ready': true,
        'summary': 'Signal runtime ready.',
        'last_heartbeat_at': '2026-04-21T10:30:00Z',
        'last_receive_at': '2026-04-21T10:25:00Z',
        'last_send_at': '2026-04-21T10:26:00Z',
        'inbound_backlog': 1,
        'outbound_backlog': 2,
        'consecutive_failures': 0,
      });

      expect(channel.displayName, 'Signal Primary');
      expect(channel.driverLabel, 'Signal');
      expect(channel.isHealthy, isTrue);
      expect(channel.hasIssues, isFalse);
      expect(channel.allowedScopes, ['group-1']);
      expect(channel.boundSessionId, 'session-123');
      expect(channel.isSessionBound, isTrue);
      expect(channel.inboundBacklog, 1);
      expect(channel.outboundBacklog, 2);
      expect(channel.statusLabel, 'Healthy');
    });

    test('parses live channel payloads that use numeric booleans', () {
      final channel = CoquiChannel.fromJson({
        'id': '5e3f60345738867c97308122e63397ca',
        'name': 'gvoice2',
        'driver': 'signal',
        'source': 'config',
        'enabled': 1,
        'display_name': 'gvoice2',
        'default_profile': null,
        'bound_session_id': null,
        'worker_status': 'running',
        'ready': 1,
        'summary': 'Signal JSON-RPC runtime active for gvoice2.',
        'last_heartbeat_at': '2026-04-23T03:40:03Z',
        'last_receive_at': null,
        'last_send_at': null,
        'inbound_backlog': 0,
        'outbound_backlog': 0,
        'consecutive_failures': 0,
        'last_error': null,
        'created_at': '2026-04-22T20:31:00Z',
        'updated_at': '2026-04-23T03:40:03Z',
        'settings': {
          'account': '+12013380755',
        },
        'allowed_scopes': [],
        'security': [],
        'capabilities': {
          'direct_messages': true,
          'groups': true,
        },
      });

      expect(channel.enabled, isTrue);
      expect(channel.ready, isTrue);
      expect(channel.isHealthy, isTrue);
      expect(channel.displayName, 'gvoice2');
    });

    test('treats placeholder driver state as scaffolded', () {
      final channel = CoquiChannel.fromJson({
        'id': 'channel-2',
        'name': 'discord-primary',
        'driver': 'discord',
        'display_name': 'Discord Primary',
        'enabled': true,
        'worker_status': 'placeholder',
        'ready': false,
      });

      expect(channel.isPlaceholder, isTrue);
      expect(channel.statusLabel, 'Scaffolded');
      expect(channel.hasIssues, isTrue);
    });

    test('parses driver metadata', () {
      final driver = CoquiChannelDriver.fromJson({
        'name': 'telegram',
        'display_name': 'Telegram',
        'capabilities': {'direct_messages': true},
        'package': 'coquibot/coqui',
      });

      expect(driver.name, 'telegram');
      expect(driver.isSignal, isFalse);
      expect(driver.isScaffolded, isTrue);
    });

    test('parses links, events, deliveries, and stats', () {
      final link = CoquiChannelLink.fromJson({
        'id': 'link-1',
        'channel_instance_id': 'channel-1',
        'remote_user_key': '+15557654321',
        'profile': 'caelum',
        'trust_level': 'linked',
        'metadata': {'source': 'manual'},
      });
      final event = CoquiChannelEvent.fromJson({
        'id': 'event-1',
        'channel_instance_id': 'channel-1',
        'conversation_id': 'conversation-1',
        'dedupe_key': 'dedupe-1',
        'event_type': 'message',
        'remote_user_key': '+15557654321',
        'payload': {'message': 'hello'},
        'normalized': {'text': 'hello'},
        'status': 'processed',
        'received_at': '2026-04-21T10:25:00Z',
      });
      final delivery = CoquiChannelDelivery.fromJson({
        'id': 'delivery-1',
        'channel_instance_id': 'channel-1',
        'idempotency_key': 'delivery-key',
        'payload': {'message': 'hi'},
        'status': 'sent',
        'attempt_count': 1,
        'queued_at': '2026-04-21T10:25:00Z',
      });
      final stats = CoquiChannelStats.fromJson({
        'total': 4,
        'enabled': 3,
        'ready': 1,
        'errors': 2,
        'active_runtimes': 1,
        'registered_drivers': 3,
      });

      expect(link.profile, 'caelum');
      expect(event.isProcessed, isTrue);
      expect(delivery.isFailed, isFalse);
      expect(stats.total, 4);
      expect(stats.registeredDrivers, 3);
    });
  });
}
