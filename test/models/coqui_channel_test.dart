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
      expect(channel.inboundBacklog, 1);
      expect(channel.outboundBacklog, 2);
      expect(channel.statusLabel, 'Healthy');
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