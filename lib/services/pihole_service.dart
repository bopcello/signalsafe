import 'package:flutter/foundation.dart';
import '../models/admin_user.dart';
import 'database_service.dart';

/// PiHoleVpnService
/// Represents the local VPN gateway running on the admin laptop:
///   - Pi-hole (Docker, port 53): DNS sinkhole for 101k malicious domains
///   - WireGuard / wg-easy (Docker, UDP 51820): VPN server that demo devices tunnel through
///
/// On a real deployment this would hit the Pi-hole REST API and wg-easy REST API.
/// For the hackathon demo the service provides:
///   1. VPN status / client list (simulated from in-memory DatabaseService)
///   2. Block-event ingestion from Pi-hole query log format
///   3. Repeat-offender analytics
class PiHoleVpnService {
  static final PiHoleVpnService _instance = PiHoleVpnService._internal();
  factory PiHoleVpnService() => _instance;
  PiHoleVpnService._internal();

  final _db = DatabaseService();

  // VPN gateway configuration (matches wg-easy / Pi-hole Docker setup)
  String _piHoleIp = '127.0.0.1';
  final int _piHolePort = 8080;
  String _wgAdminUrl = 'http://localhost:51821';

  String get piHoleAdminUrl => 'http://$_piHoleIp:$_piHolePort/admin';
  String get wgAdminUrl => _wgAdminUrl;

  void setPiHoleIp(String ip) => _piHoleIp = ip.trim();
  void setWgAdminUrl(String url) => _wgAdminUrl = url.trim();

  // ─── Pi-hole Query Log Ingest ──────────────────────────────────────────────

  /// Parses Pi-hole query log lines (exported from Pi-hole admin → Query Log)
  /// and ingests block events into the SignalSafe database.
  ///
  /// Supported Pi-hole log line formats:
  ///   Oct 30 15:42:10 dnsmasq[123]: NXDOMAIN keraekken.godaddysites.com from 10.8.0.2
  ///   Oct 30 15:42:10 dnsmasq[123]: gravity blocked paypa1-secure.phishbait.net is 0.0.0.0
  ///   2026-10-30 15:42:10 BLOCKED (gravity) evil-actor.io from 10.8.0.3
  int ingestPiHoleQueryLog(String rawLogText) {
    if (rawLogText.trim().isEmpty) return 0;
    int count = 0;

    final lines = rawLogText.split('\n');
    for (final line in lines) {
      final parsed = _parsePiHoleLogLine(line.trim());
      if (parsed != null) {
        _db.logBlockEvent(
          parsed.domain,
          clientIp: parsed.clientIp,
          userAgent: 'Pi-hole DNS Block (gravity)',
        );
        count++;
      }
    }

    debugPrint('[PiHoleVpnService] Ingested $count Pi-hole block events.');
    return count;
  }

  _ParsedLogEvent? _parsePiHoleLogLine(String line) {
    if (line.isEmpty) return null;

    final ipRegex = RegExp(r'(10\.8\.0\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})');
    final domainRegex = RegExp(
      r'([a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}',
    );

    // Must be a block-related line
    final isBlock = line.toLowerCase().contains('blocked') ||
        line.toLowerCase().contains('nxdomain') ||
        line.toLowerCase().contains('gravity') ||
        line.toLowerCase().contains('0.0.0.0');

    if (!isBlock) return null;

    final domainMatch = domainRegex.firstMatch(line);
    if (domainMatch == null) return null;

    final domain = domainMatch.group(0)!;
    if (domain.endsWith('.local') || domain.endsWith('.arpa') ||
        domain == 'localhost' || domain == '0.0.0.0') {
      return null;
    }

    final clientIp = ipRegex.firstMatch(line)?.group(0) ?? '10.8.0.2';
    return _ParsedLogEvent(domain: domain, clientIp: clientIp);
  }

  /// Sample Pi-hole query log for demo / testing
  static const String samplePiHoleQueryLog = '''
2026-10-30 15:42:10 BLOCKED (gravity) keraekken-loagginnusa.godaddysites.com from 10.8.0.2
2026-10-30 15:43:02 BLOCKED (gravity) paypa1-secure-login.phishbait.net from 10.8.0.2
2026-10-30 15:44:18 BLOCKED (gravity) netbanking-verify.fraudster.xyz from 10.8.0.3
2026-10-30 15:45:00 BLOCKED (gravity) campus-qr-redirect.evil-actor.io from 10.8.0.2
2026-10-30 15:46:22 BLOCKED (gravity) ucgrant-form.phishing.link from 10.8.0.4
2026-10-30 15:48:05 BLOCKED (regex) djtool-for-spotify.com from 10.8.0.3
''';

  // ─── Repeat Offender Analytics ────────────────────────────────────────────

  /// Groups Pi-hole DNS block events by client VPN IP to surface repeat offenders.
  List<VpnRepeatOffender> analyzeRepeatOffenders(
    List<BlockEvent> events,
    List<DhcpClient> vpnClients,
  ) {
    final Map<String, List<BlockEvent>> grouped = {};
    for (final ev in events) {
      final ip = ev.clientIp ?? 'Unknown';
      grouped.putIfAbsent(ip, () => []).add(ev);
    }

    final List<VpnRepeatOffender> results = [];
    for (final entry in grouped.entries) {
      final ip = entry.key;
      final ipEvents = entry.value;

      final client = vpnClients.firstWhere(
        (c) => c.ip == ip,
        orElse: () => DhcpClient(
          ip: ip,
          mac: 'WireGuard Peer',
          hostName: ip.contains('10.8.0.2')
              ? 'Judge-Phone (WG Peer 1)'
              : ip.contains('10.8.0.3')
                  ? 'Student-MacBook (WG Peer 2)'
                  : ip.contains('10.8.0.4')
                      ? 'Aarav-iPhone (WG Peer 3)'
                      : 'VPN-Client-$ip',
          leaseTime: 'VPN Tunnel',
          isFlagged: ipEvents.length >= 2,
        ),
      );

      final Set<String> domains = ipEvents.map((e) => e.domain).toSet();
      final DateTime lastAttempt = ipEvents.fold(
        DateTime(2000),
        (prev, e) => e.createdAt.isAfter(prev) ? e.createdAt : prev,
      );

      results.add(VpnRepeatOffender(
        clientIp: ip,
        hostName: client.hostName,
        wgPeer: client.mac,
        blockCount: ipEvents.length,
        targetedDomains: domains.toList(),
        lastAttempt: lastAttempt,
        isFlagged: client.isFlagged || ipEvents.length >= 2,
      ));
    }

    results.sort((a, b) => b.blockCount.compareTo(a.blockCount));
    return results;
  }
}

class _ParsedLogEvent {
  final String domain;
  final String clientIp;
  _ParsedLogEvent({required this.domain, required this.clientIp});
}

class VpnRepeatOffender {
  final String clientIp;
  final String hostName;
  final String wgPeer; // WireGuard peer identifier (public key prefix or name)
  final int blockCount;
  final List<String> targetedDomains;
  final DateTime lastAttempt;
  final bool isFlagged;

  VpnRepeatOffender({
    required this.clientIp,
    required this.hostName,
    required this.wgPeer,
    required this.blockCount,
    required this.targetedDomains,
    required this.lastAttempt,
    this.isFlagged = false,
  });

  String get threatSeverity {
    if (blockCount >= 4) return 'CRITICAL REPEAT OFFENDER';
    if (blockCount >= 2) return 'FREQUENT VIOLATOR';
    return 'FIRST ATTEMPT';
  }
}
