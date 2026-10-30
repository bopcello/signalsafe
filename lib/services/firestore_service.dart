import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_user.dart';
import '../models/audit_log.dart';
import '../models/domain_blacklist.dart';
import '../models/scan_report.dart';
import 'database_service.dart';

/// FirestoreService
/// Bridges Firestore collections → DatabaseService in-memory reactive store.
///
/// Architecture (Build Plan §4/§6):
///   block_events      → DatabaseService._blockEvents  (written by interstitial page)
///   domains_blacklist → DatabaseService._blacklist    (written by app reviewReport())
///   scan_reports      → DatabaseService._scanReports  (written by app submitScanReport())
///   audit_log         → DatabaseService._auditLogs    (written atomically with reviews)
///
/// All listeners are authenticated (admin only).
/// The block_events listener tolerates anonymous auth too, since the interstitial
/// page writes with anonymous auth.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _db = DatabaseService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription? _blockEventsSubscription;
  StreamSubscription? _blacklistSubscription;
  StreamSubscription? _reportsSubscription;
  StreamSubscription? _auditSubscription;
  StreamSubscription? _authSubscription;

  bool _isListening = false;

  /// Start all Firestore real-time listeners.
  /// Call once after app initialisation (main.dart after Firebase.initializeApp).
  void startListening() {
    if (_isListening) return;
    _isListening = true;

    // Watch auth state: spin up data listeners when user is present
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _startBlacklistListener();
        _startReportsListener();
        _startAuditListener();
      } else {
        _blacklistSubscription?.cancel();
        _reportsSubscription?.cancel();
        _auditSubscription?.cancel();
      }
    });

    // block_events are readable by anonymous auth (interstitial page writes them)
    _startBlockEventsListener();
  }

  // ─── Listeners ────────────────────────────────────────────────────────────

  void _startBlockEventsListener() {
    _blockEventsSubscription?.cancel();
    _blockEventsSubscription = _firestore
        .collection('block_events')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        final events = snapshot.docs.map((doc) {
          final data = doc.data();
          return BlockEvent(
            id: doc.id,
            domain: data['domain'] as String? ?? '',
            clientIp: data['clientIp'] as String?,
            userAgent: data['userAgent'] as String? ?? 'Campus-WiFi Client',
            createdAt: _parseTimestamp(data['createdAt']),
          );
        }).toList();
        _db.mergeBlockEvents(events);
      },
      onError: (e) => _log('block_events error (may be pre-auth): $e'),
    );
  }

  void _startBlacklistListener() {
    _blacklistSubscription?.cancel();
    _blacklistSubscription = _firestore
        .collection('domains_blacklist')
        .orderBy('firstSeen', descending: true)
        .limit(200)
        .snapshots()
        .listen(
      (snapshot) {
        final entries = snapshot.docs
            .map((doc) => DomainBlacklistEntry.fromMap(doc.id, doc.data()))
            .toList();
        _db.mergeBlacklistEntries(entries);
      },
      onError: (e) => _log('domains_blacklist error: $e'),
    );
  }

  void _startReportsListener() {
    _reportsSubscription?.cancel();
    _reportsSubscription = _firestore
        .collection('scan_reports')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final reports = snapshot.docs
            .map((doc) => ScanReport.fromMap(doc.id, doc.data()))
            .toList();
        _db.mergeScanReports(reports);
      },
      onError: (e) => _log('scan_reports error: $e'),
    );
  }

  void _startAuditListener() {
    _auditSubscription?.cancel();
    _auditSubscription = _firestore
        .collection('audit_log')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snapshot) {
        final logs = snapshot.docs
            .map((doc) => AuditLogEntry.fromMap(doc.id, doc.data()))
            .toList();
        _db.mergeAuditLogs(logs);
      },
      onError: (e) => _log('audit_log error: $e'),
    );
  }

  // ─── Write helpers ────────────────────────────────────────────────────────

  /// Atomic WriteBatch for reviewReport — matches the Build Plan §6 spec exactly:
  /// scan_reports update + domains_blacklist upsert + audit_log append, all in one.
  Future<void> commitReviewBatch({
    required ScanReport updatedReport,
    required DomainBlacklistEntry updatedBlacklist,
    required AuditLogEntry auditEntry,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('scan_reports').doc(updatedReport.id),
      updatedReport.toMap(),
    );
    batch.set(
      _firestore.collection('domains_blacklist').doc(updatedBlacklist.id),
      updatedBlacklist.toMap(),
    );
    batch.set(
      _firestore.collection('audit_log').doc(auditEntry.id),
      auditEntry.toMap(),
    );
    await batch.commit();
  }

  Future<void> persistScanReport(ScanReport report) async {
    await _firestore
        .collection('scan_reports')
        .doc(report.id)
        .set(report.toMap());
  }

  Future<void> persistBlacklistEntry(DomainBlacklistEntry entry) async {
    await _firestore
        .collection('domains_blacklist')
        .doc(entry.id)
        .set(entry.toMap());
  }

  Future<void> persistAuditLog(AuditLogEntry entry) async {
    await _firestore
        .collection('audit_log')
        .doc(entry.id)
        .set(entry.toMap());
  }

  Future<void> persistBlockEvent(BlockEvent event) async {
    await _firestore
        .collection('block_events')
        .doc(event.id)
        .set(event.toMap());
  }

  void dispose() {
    _authSubscription?.cancel();
    _blockEventsSubscription?.cancel();
    _blacklistSubscription?.cancel();
    _reportsSubscription?.cancel();
    _auditSubscription?.cancel();
    _isListening = false;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[FirestoreService] $msg');
  }
}
