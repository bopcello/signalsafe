import 'package:flutter/services.dart';
import 'database_service.dart';

class ExportService {
  /// Generates plain text format for Tenda N301 Website Filter
  static String generateTendaBlacklistText() {
    final domains = DatabaseService().activeBlacklist.map((e) => e.domain).toList()..sort();
    final buffer = StringBuffer();
    buffer.writeln('# SignalSafe Export for Tenda N301 Website Filter');
    buffer.writeln('# Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Total Active Blocked Domains: ${domains.length}');
    buffer.writeln('');
    for (final d in domains) {
      buffer.writeln(d);
    }
    return buffer.toString();
  }

  /// Generates standard dnsmasq format for OpenWrt or campus edge gateways
  static String generateDnsmasqFormat() {
    final domains = DatabaseService().activeBlacklist.map((e) => e.domain).toList()..sort();
    final buffer = StringBuffer();
    buffer.writeln('# SignalSafe Dnsmasq Blocklist');
    for (final d in domains) {
      buffer.writeln('address=/$d/0.0.0.0');
    }
    return buffer.toString();
  }

  /// Copies Tenda blacklist to system clipboard
  static Future<void> copyToClipboard() async {
    final text = DatabaseService().exportBlacklistAsText();
    await Clipboard.setData(ClipboardData(text: text));
  }
}
