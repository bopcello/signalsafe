import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/models/admin_user.dart';
import 'package:signalsafe/services/pihole_service.dart';

void main() {
  group('PiHoleVpnService Log Parser & Repeat Offender Tests', () {
    final vpnService = PiHoleVpnService();

    test('Parses Pi-hole DNS query log lines into block events', () {
      const rawLog = '''
2026-10-30 15:42:10 BLOCKED (gravity) keraekken-loagginnusa.godaddysites.com from 10.8.0.2
2026-10-30 15:43:02 BLOCKED (gravity) paypa1-secure-login.phishbait.net from 10.8.0.2
2026-10-30 15:45:00 BLOCKED (regex) campus-qr-redirect.evil-actor.io from 10.8.0.3
''';

      final ingested = vpnService.ingestPiHoleQueryLog(rawLog);
      expect(ingested, equals(3));
    });

    test('Identifies repeat student offenders across VPN client tunnels', () {
      final now = DateTime.now();
      final events = [
        BlockEvent(
          id: 'ev-1',
          domain: 'phishbait.net',
          clientIp: '10.8.0.2',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        BlockEvent(
          id: 'ev-2',
          domain: 'evil-portal.io',
          clientIp: '10.8.0.2',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        BlockEvent(
          id: 'ev-3',
          domain: 'bad-site.com',
          clientIp: '10.8.0.2',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        BlockEvent(
          id: 'ev-4',
          domain: 'one-time-hit.org',
          clientIp: '10.8.0.3',
          createdAt: now,
        ),
      ];

      final clients = [
        DhcpClient(
          ip: '10.8.0.2',
          mac: 'WG-PEER-01',
          hostName: 'Judge-Phone (WG Peer 1)',
          leaseTime: 'VPN Tunnel',
        ),
        DhcpClient(
          ip: '10.8.0.3',
          mac: 'WG-PEER-02',
          hostName: 'Student-MacBook (WG Peer 2)',
          leaseTime: 'VPN Tunnel',
        ),
      ];

      final offenders = vpnService.analyzeRepeatOffenders(events, clients);

      expect(offenders.length, equals(2));
      // First one is the highest repeat violator (10.8.0.2 with 3 attempts)
      final topOffender = offenders.first;
      expect(topOffender.clientIp, equals('10.8.0.2'));
      expect(topOffender.hostName, equals('Judge-Phone (WG Peer 1)'));
      expect(topOffender.blockCount, equals(3));
      expect(topOffender.targetedDomains.length, equals(3));
      expect(topOffender.threatSeverity, equals('FREQUENT VIOLATOR'));
      expect(topOffender.isFlagged, isTrue);

      final secondOffender = offenders[1];
      expect(secondOffender.clientIp, equals('10.8.0.3'));
      expect(secondOffender.blockCount, equals(1));
      expect(secondOffender.threatSeverity, equals('FIRST ATTEMPT'));
    });
  });
}
