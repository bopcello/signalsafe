import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/models/admin_user.dart';
import 'package:signalsafe/services/tenda_service.dart';

void main() {
  group('TendaRouterService Log Parser & Repeat Offender Tests', () {
    final tenda = TendaRouterService();

    test('Parses raw router syslog and parental control drop records', () {
      const rawLog = '''
2026-10-30 15:42:10 [Parental Control] Drop HTTP packet from 192.168.0.104 to keraekken-loagginnusa.godaddysites.com (Blacklist match)
2026-10-30 15:43:02 [Parental Control] Drop HTTP packet from 192.168.0.104 to paypa1-secure-login.phishbait.net (Rule: Malicious Domain)
2026-10-30 15:45:00 [Website Filter] Intercepted DNS query from 192.168.0.102 for netbanking-verify.fraudster.xyz (MAC: 48:2C:6A:19:B3:01)
''';

      final ingested = tenda.ingestRouterLogText(rawLog);
      expect(ingested, equals(3));
    });

    test('Identifies repeat student offenders visiting malicious sites', () {
      final now = DateTime.now();
      final events = [
        BlockEvent(
          id: 'ev-1',
          domain: 'phishbait.net',
          clientIp: '192.168.0.104',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        BlockEvent(
          id: 'ev-2',
          domain: 'evil-portal.io',
          clientIp: '192.168.0.104',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        BlockEvent(
          id: 'ev-3',
          domain: 'bad-site.com',
          clientIp: '192.168.0.104',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
        BlockEvent(
          id: 'ev-4',
          domain: 'one-time-hit.org',
          clientIp: '192.168.0.102',
          createdAt: now,
        ),
      ];

      final clients = [
        DhcpClient(
          ip: '192.168.0.104',
          mac: 'F4:D1:08:92:B1:A4',
          hostName: 'Aarav-iPhone-14',
          leaseTime: '23h 12m',
        ),
        DhcpClient(
          ip: '192.168.0.102',
          mac: '48:2C:6A:19:B3:01',
          hostName: 'Student-MacBook',
          leaseTime: '12h 40m',
        ),
      ];

      final offenders = tenda.analyzeRepeatOffenders(events, clients);

      expect(offenders.length, equals(2));
      // First one is the highest repeat violator (192.168.0.104 with 3 attempts)
      final topOffender = offenders.first;
      expect(topOffender.clientIp, equals('192.168.0.104'));
      expect(topOffender.hostName, equals('Aarav-iPhone-14'));
      expect(topOffender.blockCount, equals(3));
      expect(topOffender.targetedDomains.length, equals(3));
      expect(topOffender.threatSeverity, equals('FREQUENT VIOLATOR'));
      expect(topOffender.isFlagged, isTrue);

      final secondOffender = offenders[1];
      expect(secondOffender.clientIp, equals('192.168.0.102'));
      expect(secondOffender.blockCount, equals(1));
      expect(secondOffender.threatSeverity, equals('FIRST ATTEMPT'));
    });
  });
}
