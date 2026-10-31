import 'package:flutter/services.dart';
import 'database_service.dart';

/// ExportService — generates Pi-hole / dnsmasq blocklist formats
/// for the SignalSafe VPN gateway architecture.
class ExportService {
  /// Generates Pi-hole gravity-compatible dnsmasq format.
  /// Each line: `address=/<domain>/0.0.0.0`
  /// This file can be dropped into /etc/pihole/custom_blocklist.txt
  static String generatePiHoleDnsmasqFormat() {
    final domains = DatabaseService().activeBlacklist.map((e) => e.domain).toList()..sort();
    final buffer = StringBuffer();
    buffer.writeln('# SignalSafe Pi-hole Blocklist Export');
    buffer.writeln('# Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Total Active Blocked Domains: ${domains.length}');
    buffer.writeln('# Usage: copy to /etc/pihole/custom_blocklist.txt, then run: pihole -g');
    buffer.writeln('');
    for (final d in domains) {
      buffer.writeln('address=/$d/0.0.0.0');
    }
    return buffer.toString();
  }

  /// Generates a plain one-domain-per-line format
  /// (compatible with Pi-hole adlist / hosts file format)
  static String generatePlainDomainList() {
    final domains = DatabaseService().activeBlacklist.map((e) => e.domain).toList()..sort();
    final buffer = StringBuffer();
    buffer.writeln('# SignalSafe Domain Blocklist');
    buffer.writeln('# ${domains.length} active malicious domains');
    buffer.writeln('');
    for (final d in domains) {
      buffer.writeln(d);
    }
    return buffer.toString();
  }

  /// Copies Pi-hole dnsmasq blocklist to system clipboard
  static Future<void> copyToClipboard() async {
    final text = DatabaseService().exportBlacklistAsText();
    await Clipboard.setData(ClipboardData(text: text));
  }
}
