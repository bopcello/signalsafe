import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_user.dart';
import '../models/audit_log.dart';
import '../models/domain_blacklist.dart';
import '../models/scan_report.dart';
import '../scoring/feature_extractor.dart';
import '../scoring/reasoning.dart';
import 'database_service.dart';

/// SeedDataService
/// Populates realistic seed data for SignalSafe:
/// 1. Admin users & Student users
/// 2. Active Blacklist entries with full lexical feature breakdowns
/// 3. Pending & Triaged Scan Reports (SecOps Triage Queue)
/// 4. Interstitial Block Events (Tenda N301 & WiFi defense triggers)
/// 5. Immutable Audit Log entries (human IT override authority records)
/// 6. Active Campus DHCP Clients (Tenda N301 client table)
///
/// Both updates the in-memory reactive DatabaseService immediately AND
/// writes into Cloud Firestore when an authenticated or authorized session is active.
class SeedDataService {
  static final SeedDataService _instance = SeedDataService._internal();
  factory SeedDataService() => _instance;
  SeedDataService._internal();

  bool _hasSeededLocal = false;

  /// Returns true if local or Firestore data has been seeded
  bool get hasSeededLocal => _hasSeededLocal;

  /// Default predefined accounts
  static final List<AppUser> sampleUsers = [
    AppUser(
      uid: 'admin_rajesh_sharma',
      email: 'admin.rajesh@campus.edu',
      displayName: 'Dr. Rajesh Sharma (IT Head)',
      isAdmin: true,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    AppUser(
      uid: 'admin_ananya_secops',
      email: 'ananya.cyber@campus.edu',
      displayName: 'Ananya Verma (CyberSec Lead)',
      isAdmin: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    AppUser(
      uid: 'student_aarav_patel',
      email: 'aarav.patel@student.campus.edu',
      displayName: 'Aarav Patel (CS Year 3)',
      isAdmin: false,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    AppUser(
      uid: 'student_sneha_reddy',
      email: 'sneha.reddy@student.campus.edu',
      displayName: 'Sneha Reddy (ECE Year 2)',
      isAdmin: false,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    AppUser(
      uid: 'student_vikram_singh',
      email: 'vikram.singh@student.campus.edu',
      displayName: 'Vikram Singh (IT Year 4)',
      isAdmin: false,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  /// Realistic DHCP clients representing students and staff connected to Tenda N301
  static final List<DhcpClient> sampleDhcpClients = [
    DhcpClient(
      ip: '192.168.0.102',
      mac: 'F4:D1:08:92:B1:A4',
      hostName: 'Aarav-iPhone-14',
      leaseTime: '23h 48m',
      isFlagged: false,
    ),
    DhcpClient(
      ip: '192.168.0.104',
      mac: '7C:2E:BD:41:88:F9',
      hostName: 'Judge-Phone-TestDevice',
      leaseTime: '23h 59m',
      isFlagged: true, // Intercepted threat simulation device
    ),
    DhcpClient(
      ip: '192.168.0.105',
      mac: 'A0:C5:89:12:33:DE',
      hostName: 'Sneha-MacBook-Air',
      leaseTime: '21h 14m',
      isFlagged: false,
    ),
    DhcpClient(
      ip: '192.168.0.108',
      mac: 'B8:27:EB:77:4A:91',
      hostName: 'RaspberryPi-DNS-Edge',
      leaseTime: 'Static Lease',
      isFlagged: false,
    ),
    DhcpClient(
      ip: '192.168.0.112',
      mac: '44:65:0D:5F:AA:C2',
      hostName: 'Vikram-OnePlus-11',
      leaseTime: '18h 32m',
      isFlagged: false,
    ),
    DhcpClient(
      ip: '192.168.0.119',
      mac: 'E0:CB:EE:94:01:5D',
      hostName: 'Library-Kiosk-Terminal-03',
      leaseTime: 'Static Lease',
      isFlagged: false,
    ),
    DhcpClient(
      ip: '192.168.0.125',
      mac: 'D8:3B:BF:6C:54:19',
      hostName: 'Lab-Workstation-CS204',
      leaseTime: 'Static Lease',
      isFlagged: false,
    ),
  ];

  /// Raw seed definitions for threats and benign URLs
  static final List<Map<String, dynamic>> rawSeedItems = [
    {
      'id': 'rep_kraken_01',
      'url': 'http://keraekken-loagginnusa.godaddysites.com/auth/login.php',
      'domain': 'keraekken-loagginnusa.godaddysites.com',
      'inputType': 'url',
      'score': 0.96,
      'verdict': 'malicious',
      'reviewDecision': 'confirmed_block',
      'status': 'active',
      'source': 'auto',
      'reviewedBy': 'admin_rajesh_sharma',
      'auditAction': 'confirmed_block',
      'auditDetails': 'Confirmed automated block: high threat score 96.0%. Impersonates exchange login with hyphenated typosquatting.',
      'hoursAgo': 36,
    },
    {
      'id': 'rep_paypa1_02',
      'url': 'http://paypa1-secure-login.phishbait.net/verify-identity?token=77a8df',
      'domain': 'paypa1-secure-login.phishbait.net',
      'inputType': 'qr',
      'score': 0.94,
      'verdict': 'malicious',
      'reviewDecision': 'confirmed_block',
      'status': 'active',
      'source': 'auto',
      'reviewedBy': 'admin_ananya_secops',
      'auditAction': 'confirmed_block',
      'auditDetails': 'Physical QR code sticker found pasted over campus cafeteria payment kiosk. Block enforced router-wide.',
      'hoursAgo': 28,
    },
    {
      'id': 'rep_campus_qr_03',
      'url': 'http://campus-qr-redirect.evil-actor.io/auth/saml/sso-login.php?client=edu',
      'domain': 'campus-qr-redirect.evil-actor.io',
      'inputType': 'qr',
      'score': 0.91,
      'verdict': 'malicious',
      'reviewDecision': 'confirmed_block',
      'status': 'active',
      'source': 'auto',
      'reviewedBy': 'admin_rajesh_sharma',
      'auditAction': 'confirmed_block',
      'auditDetails': 'Quishing campaign targeting student portal SSO credentials. Automated router blacklist propagation.',
      'hoursAgo': 20,
    },
    {
      'id': 'rep_netbanking_04',
      'url': 'http://netbanking-verify.fraudster.xyz/account-update',
      'domain': 'netbanking-verify.fraudster.xyz',
      'inputType': 'url',
      'score': 0.89,
      'verdict': 'malicious',
      'reviewDecision': 'confirmed_block',
      'status': 'active',
      'source': 'auto',
      'reviewedBy': 'admin_ananya_secops',
      'auditAction': 'confirmed_block',
      'auditDetails': 'Credential harvesting phishing email link targeting SBI student fee payment accounts.',
      'hoursAgo': 14,
    },
    {
      'id': 'rep_ucgrant_05',
      'url': 'http://ucgrant-form.phishing.link/students/scholarship/apply.exe',
      'domain': 'ucgrant-form.phishing.link',
      'inputType': 'url',
      'score': 0.98,
      'verdict': 'malicious',
      'reviewDecision': 'confirmed_block',
      'status': 'active',
      'source': 'auto',
      'reviewedBy': 'admin_rajesh_sharma',
      'auditAction': 'confirmed_block',
      'auditDetails': 'Payload delivers suspicious executable (.exe) masquerading as scholarship application.',
      'hoursAgo': 10,
    },
    {
      'id': 'rep_overridden_ieee_06',
      'url': 'https://hackathon-review-portal.ieee-campus.org/submissions',
      'domain': 'hackathon-review-portal.ieee-campus.org',
      'inputType': 'url',
      'score': 0.58,
      'verdict': 'suspicious',
      'reviewDecision': 'allowed',
      'status': 'overridden_allow',
      'source': 'manual_override',
      'reviewedBy': 'admin_rajesh_sharma',
      'auditAction': 'allowed',
      'auditDetails': 'IT Admin Manual Override: Legitimate student hackathon portal verified by Dr. Rajesh Sharma.',
      'hoursAgo': 8,
    },
    // Pending Queue items:
    {
      'id': 'rep_pending_event_07',
      'url': 'http://event-registration-desk.online/fest2026/checkin',
      'domain': 'event-registration-desk.online',
      'inputType': 'qr',
      'score': 0.74,
      'verdict': 'malicious',
      'reviewDecision': 'pending',
      'status': 'active',
      'source': 'auto',
      'hoursAgo': 2,
    },
    {
      'id': 'rep_pending_wifi_08',
      'url': 'http://wifi-login-portal-update.top/guest-session',
      'domain': 'wifi-login-portal-update.top',
      'inputType': 'url',
      'score': 0.81,
      'verdict': 'malicious',
      'reviewDecision': 'pending',
      'status': 'active',
      'source': 'auto',
      'hoursAgo': 1,
    },
    {
      'id': 'rep_pending_eval_09',
      'url': 'https://research-survey-feedback.xyz/survey.php?id=99281',
      'domain': 'research-survey-feedback.xyz',
      'inputType': 'url',
      'score': 0.48,
      'verdict': 'suspicious',
      'reviewDecision': 'pending',
      'status': 'pending',
      'source': 'auto',
      'hoursAgo': 0,
    },
  ];

  /// Populates all sample data in-memory into DatabaseService
  void seedLocalDatabase() {
    final db = DatabaseService();

    // 1. Seed DHCP clients
    db.mergeDhcpClients(sampleDhcpClients);

    // 2. Build and seed Blacklist, ScanReports, and AuditLogs
    final List<DomainBlacklistEntry> blacklistEntries = [];
    final List<ScanReport> scanReports = [];
    final List<AuditLogEntry> auditLogs = [];
    final List<BlockEvent> blockEvents = [];

    for (final item in rawSeedItems) {
      final String id = item['id'] as String;
      final String url = item['url'] as String;
      final String domain = item['domain'] as String;
      final String inputType = item['inputType'] as String;
      final double score = (item['score'] as num).toDouble();
      final String verdict = item['verdict'] as String;
      final String reviewDecision = item['reviewDecision'] as String;
      final String status = item['status'] as String;
      final String source = item['source'] as String;
      final int hoursAgo = item['hoursAgo'] as int;
      final timestamp = DateTime.now().subtract(Duration(hours: hoursAgo, minutes: 12));

      final features = FeatureExtractor.extractFeaturesMap(url);
      final reasons = DetectionReasoning.generateReasons(features, score);

      final String? auditId = item.containsKey('auditAction') ? 'audit_$id' : null;

      // Scan Report
      final report = ScanReport(
        id: id,
        input: url,
        inputType: inputType,
        score: score,
        verdict: verdict,
        reviewDecision: reviewDecision,
        reviewedBy: item['reviewedBy'] as String?,
        lastAuditId: auditId,
        createdAt: timestamp,
        features: features,
        reasons: reasons,
      );
      scanReports.add(report);

      // Blacklist Entry (for confirmed_block or active or overridden)
      if (status == 'active' || status == 'overridden_allow') {
        blacklistEntries.add(
          DomainBlacklistEntry(
            id: domain,
            domain: domain,
            score: score,
            reasonFeatures: features,
            reasons: reasons,
            source: source,
            status: status,
            firstSeen: timestamp,
          ),
        );
      }

      // Audit Log Entry
      if (item.containsKey('auditAction')) {
        auditLogs.add(
          AuditLogEntry(
            id: auditId!,
            actorUid: item['reviewedBy'] as String? ?? 'system_scorer',
            actorRole: 'it_head',
            action: item['auditAction'] as String,
            targetDomain: domain,
            details: item['auditDetails'] as String? ?? 'Automated network block rule verified',
            timestamp: timestamp,
          ),
        );
      }
    }

    // 3. Seed Fallback Interstitial Block Events
    final now = DateTime.now();
    blockEvents.addAll([
      BlockEvent(
        id: 'evt_01',
        domain: 'keraekken-loagginnusa.godaddysites.com',
        clientIp: '192.168.0.104',
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15',
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      BlockEvent(
        id: 'evt_02',
        domain: 'paypa1-secure-login.phishbait.net',
        clientIp: '192.168.0.112',
        userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-S918B) Chrome/122.0 Mobile Safari/537.36',
        createdAt: now.subtract(const Duration(minutes: 42)),
      ),
      BlockEvent(
        id: 'evt_03',
        domain: 'campus-qr-redirect.evil-actor.io',
        clientIp: '192.168.0.104',
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      ),
      BlockEvent(
        id: 'evt_04',
        domain: 'netbanking-verify.fraudster.xyz',
        clientIp: '192.168.0.102',
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/123.0 Safari/537.36',
        createdAt: now.subtract(const Duration(hours: 4, minutes: 30)),
      ),
      BlockEvent(
        id: 'evt_05',
        domain: 'ucgrant-form.phishing.link',
        clientIp: '192.168.0.105',
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4) Safari/605.1.15',
        createdAt: now.subtract(const Duration(hours: 7)),
      ),
    ]);

    // Apply all to DatabaseService
    db.mergeBlacklistEntries(blacklistEntries);
    db.mergeScanReports(scanReports);
    db.mergeAuditLogs(auditLogs);
    db.mergeBlockEvents(blockEvents);

    _hasSeededLocal = true;
    debugPrint('[SeedDataService] Local memory successfully seeded with ${blacklistEntries.length} domains, ${scanReports.length} reports, ${blockEvents.length} events, ${sampleDhcpClients.length} clients.');
  }

  /// Syncs all seed data to Cloud Firestore collections:
  /// - `users` & `admin_users`
  /// - `domains_blacklist`
  /// - `scan_reports`
  /// - `audit_log`
  /// - `block_events`
  Future<void> seedFirestoreDatabase() async {
    final firestore = FirebaseFirestore.instance;

    try {
      final batch = firestore.batch();

      // 1. Seed Users (Admin & Students)
      for (final user in sampleUsers) {
        final userDoc = firestore.collection('users').doc(user.uid);
        batch.set(userDoc, {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'isAdmin': user.isAdmin,
          'role': user.role,
          'createdAt': user.createdAt.toIso8601String(),
          'photoUrl': user.photoUrl,
        }, SetOptions(merge: true));

        // If admin, also write to admin_users collection per Build Plan
        if (user.isAdmin) {
          final adminDoc = firestore.collection('admin_users').doc(user.uid);
          batch.set(adminDoc, {
            'role': 'it_head',
            'displayName': user.displayName,
            'email': user.email,
          }, SetOptions(merge: true));
        }
      }

      // 2. Seed Blacklist, ScanReports, and AuditLogs
      for (final item in rawSeedItems) {
        final String id = item['id'] as String;
        final String url = item['url'] as String;
        final String domain = item['domain'] as String;
        final String inputType = item['inputType'] as String;
        final double score = (item['score'] as num).toDouble();
        final String verdict = item['verdict'] as String;
        final String reviewDecision = item['reviewDecision'] as String;
        final String status = item['status'] as String;
        final String source = item['source'] as String;
        final int hoursAgo = item['hoursAgo'] as int;
        final timestamp = DateTime.now().subtract(Duration(hours: hoursAgo, minutes: 12));

        final features = FeatureExtractor.extractFeaturesMap(url);
        final reasons = DetectionReasoning.generateReasons(features, score);

        final String? auditId = item.containsKey('auditAction') ? 'audit_$id' : null;

        // Scan Report
        final reportDoc = firestore.collection('scan_reports').doc(id);
        batch.set(reportDoc, {
          'input': url,
          'inputType': inputType,
          'score': score,
          'verdict': verdict,
          'reviewDecision': reviewDecision,
          'reviewedBy': item['reviewedBy'],
          'lastAuditId': auditId,
          'createdAt': timestamp.toIso8601String(),
          'features': features,
          'reasons': reasons,
        }, SetOptions(merge: true));

        // Blacklist Entry
        if (status == 'active' || status == 'overridden_allow') {
          final blacklistDoc = firestore.collection('domains_blacklist').doc(domain);
          batch.set(blacklistDoc, {
            'domain': domain,
            'score': score,
            'reasonFeatures': features,
            'reasons': reasons,
            'source': source,
            'status': status,
            'firstSeen': timestamp.toIso8601String(),
          }, SetOptions(merge: true));
        }

        // Audit Log Entry
        if (item.containsKey('auditAction') && auditId != null) {
          final auditDoc = firestore.collection('audit_log').doc(auditId);
          batch.set(auditDoc, {
            'actorUid': item['reviewedBy'] as String? ?? 'admin_rajesh_sharma',
            'actorRole': 'it_head',
            'action': item['auditAction'] as String,
            'targetDomain': domain,
            'details': item['auditDetails'] as String? ?? 'Automated network block rule verified',
            'timestamp': timestamp.toIso8601String(),
          }, SetOptions(merge: true));
        }
      }

      // 3. Seed Block Events
      final now = DateTime.now();
      final events = [
        {
          'id': 'evt_01',
          'domain': 'keraekken-loagginnusa.godaddysites.com',
          'clientIp': '192.168.0.104',
          'userAgent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)',
          'createdAt': now.subtract(const Duration(minutes: 18)).toIso8601String(),
        },
        {
          'id': 'evt_02',
          'domain': 'paypa1-secure-login.phishbait.net',
          'clientIp': '192.168.0.112',
          'userAgent': 'Mozilla/5.0 (Linux; Android 14; SM-S918B)',
          'createdAt': now.subtract(const Duration(minutes: 42)).toIso8601String(),
        },
        {
          'id': 'evt_03',
          'domain': 'campus-qr-redirect.evil-actor.io',
          'clientIp': '192.168.0.104',
          'userAgent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)',
          'createdAt': now.subtract(const Duration(hours: 2, minutes: 15)).toIso8601String(),
        },
        {
          'id': 'evt_04',
          'domain': 'netbanking-verify.fraudster.xyz',
          'clientIp': '192.168.0.102',
          'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'createdAt': now.subtract(const Duration(hours: 4, minutes: 30)).toIso8601String(),
        },
        {
          'id': 'evt_05',
          'domain': 'ucgrant-form.phishing.link',
          'clientIp': '192.168.0.105',
          'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_4)',
          'createdAt': now.subtract(const Duration(hours: 7)).toIso8601String(),
        },
      ];

      for (final ev in events) {
        final evDoc = firestore.collection('block_events').doc(ev['id'] as String);
        batch.set(evDoc, {
          'domain': ev['domain'],
          'clientIp': ev['clientIp'],
          'userAgent': ev['userAgent'],
          'createdAt': ev['createdAt'],
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('[SeedDataService] Successfully uploaded seed data to Cloud Firestore (hf2signalsafe)!');
    } catch (e) {
      debugPrint('[SeedDataService] Firestore seed sync note: $e');
    }
  }
}
