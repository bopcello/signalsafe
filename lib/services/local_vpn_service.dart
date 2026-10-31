import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'database_service.dart';

class VpnDnsLogEvent {
  final String domain;
  final String clientIp;
  final bool isBlocked;
  final int qType;
  final DateTime timestamp;

  VpnDnsLogEvent({
    required this.domain,
    required this.clientIp,
    required this.isBlocked,
    required this.qType,
    required this.timestamp,
  });
}

/// LocalVpnService
///
/// Controls the native Android AdGuard-style Local VPN DNS sinkhole:
///  - Prepares and starts the Android VpnService via MethodChannel
///  - Syncs the active SignalSafe domain blocklist to native memory
///  - Listens to real-time DNS queries and sinkholed blocks via EventChannel
///  - Automatically records live blocks into DatabaseService for telemetry & dashboards
class LocalVpnService extends ChangeNotifier {
  static final LocalVpnService _instance = LocalVpnService._internal();
  factory LocalVpnService() => _instance;
  LocalVpnService._internal() {
    _initEventChannel();
  }

  static const _methodChannel = MethodChannel('com.example.signalsafe/vpn');
  static const _eventChannel = EventChannel(
    'com.example.signalsafe/vpn_events',
  );

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  int _totalQueries = 0;
  int get totalQueries => _totalQueries;

  int _totalBlocked = 0;
  int get totalBlocked => _totalBlocked;

  final List<VpnDnsLogEvent> _recentLogs = [];
  List<VpnDnsLogEvent> get recentLogs => List.unmodifiable(_recentLogs);

  StreamSubscription? _eventSubscription;

  void _initEventChannel() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (data) {
        if (data is Map) {
          final type = data['type']?.toString();
          if (type == 'status') {
            _isRunning = data['isRunning'] == true;
            notifyListeners();
          } else if (type == 'blocked') {
            final domain = data['domain']?.toString() ?? 'unknown';
            final clientIp = data['clientIp']?.toString() ?? '10.240.0.1';
            final qType = (data['qType'] as num?)?.toInt() ?? 1;
            final ts = data['timestamp'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (data['timestamp'] as num).toInt(),
                  )
                : DateTime.now();

            _totalQueries++;
            _totalBlocked++;

            final log = VpnDnsLogEvent(
              domain: domain,
              clientIp: clientIp,
              isBlocked: true,
              qType: qType,
              timestamp: ts,
            );
            _recentLogs.insert(0, log);
            if (_recentLogs.length > 50) _recentLogs.removeLast();

            // Feed directly into SignalSafe database & telemetry
            DatabaseService().logBlockEvent(
              domain,
              clientIp: clientIp,
              userAgent: 'SignalSafe Local VPN',
            );

            notifyListeners();
          } else if (type == 'resolved') {
            final domain = data['domain']?.toString() ?? 'unknown';
            final clientIp = data['clientIp']?.toString() ?? '10.240.0.1';
            final qType = (data['qType'] as num?)?.toInt() ?? 1;
            final ts = data['timestamp'] != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    (data['timestamp'] as num).toInt(),
                  )
                : DateTime.now();

            _totalQueries++;
            final log = VpnDnsLogEvent(
              domain: domain,
              clientIp: clientIp,
              isBlocked: false,
              qType: qType,
              timestamp: ts,
            );
            _recentLogs.insert(0, log);
            if (_recentLogs.length > 50) _recentLogs.removeLast();

            notifyListeners();
          }
        }
      },
      onError: (err) {
        debugPrint('[LocalVpnService] Event channel error: $err');
      },
    );

    // Initial check
    checkVpnRunning();
  }

  /// Check whether the native VPN service is already active
  Future<bool> checkVpnRunning() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final running =
          await _methodChannel.invokeMethod<bool>('isVpnRunning') ?? false;
      if (_isRunning != running) {
        _isRunning = running;
        notifyListeners();
      }
      return running;
    } catch (e) {
      debugPrint('[LocalVpnService] checkVpnRunning error: $e');
      return false;
    }
  }

  /// Request system VPN permission from Android OS
  Future<bool> prepareVpn() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final granted =
          await _methodChannel.invokeMethod<bool>('prepareVpn') ?? false;
      return granted;
    } catch (e) {
      debugPrint('[LocalVpnService] prepareVpn error: $e');
      return false;
    }
  }

  /// Collects all active malicious domains and starts the local VPN
  Future<bool> startVpn() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('[LocalVpnService] VPN is only supported on Android devices.');
      return false;
    }

    try {
      // 1. Prepare VPN permission
      final prepared = await prepareVpn();
      if (!prepared) {
        debugPrint('[LocalVpnService] VPN permission was denied by the user.');
        return false;
      }

      // 2. Gather active blocklist domains
      final db = DatabaseService();
      final Set<String> domains = db.activeBlacklist
          .map((e) => e.domain.trim().toLowerCase())
          .toSet();

      // Ensure standard demo / known phishing test domains are included
      domains.addAll([
        'keraekken-loagginnusa.godaddysites.com',
        'paypa1-secure-login.phishbait.net',
        'netbanking-verify.fraudster.xyz',
        'campus-qr-redirect.evil-actor.io',
        'ucgrant-form.phishing.link',
        'djtool-for-spotify.com',
        'evil-actor.io',
        'phishbait.net',
      ]);

      // 3. Start native VPN service
      final success =
          await _methodChannel.invokeMethod<bool>('startVpn', {
            'blockedDomains': domains.toList(),
          }) ??
          false;

      if (success) {
        _isRunning = true;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[LocalVpnService] startVpn error: $e');
      return false;
    }
  }

  /// Stops the local VPN
  Future<bool> stopVpn() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final success =
          await _methodChannel.invokeMethod<bool>('stopVpn') ?? false;
      if (success) {
        _isRunning = false;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[LocalVpnService] stopVpn error: $e');
      return false;
    }
  }

  /// Syncs the latest blocklist from DatabaseService into the active native VPN
  Future<void> syncBlocklist() async {
    if (!_isRunning ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      final db = DatabaseService();
      final domains = db.activeBlacklist
          .map((e) => e.domain.trim().toLowerCase())
          .toSet();
      domains.addAll([
        'keraekken-loagginnusa.godaddysites.com',
        'paypa1-secure-login.phishbait.net',
        'netbanking-verify.fraudster.xyz',
        'campus-qr-redirect.evil-actor.io',
        'ucgrant-form.phishing.link',
        'djtool-for-spotify.com',
      ]);

      await _methodChannel.invokeMethod('updateBlocklist', {
        'blockedDomains': domains.toList(),
      });
      debugPrint(
        '[LocalVpnService] Pushed ${domains.length} blocked domains to native VPN.',
      );
    } catch (e) {
      debugPrint('[LocalVpnService] syncBlocklist error: $e');
    }
  }

  void clearLogs() {
    _recentLogs.clear();
    _totalQueries = 0;
    _totalBlocked = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
