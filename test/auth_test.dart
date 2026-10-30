import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/models/admin_user.dart';
import 'package:signalsafe/services/database_service.dart';
import 'package:signalsafe/services/seed_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignalSafe Auth & Role Gating Tests', () {
    late DatabaseService db;

    setUp(() {
      db = DatabaseService();
      SeedDataService().seedLocalDatabase();
    });

    test('By default all users have student credentials (isAdmin = false)', () {
      final user = AppUser(
        uid: 'student_123',
        email: 'test.student@campus.edu',
        displayName: 'Test Student',
        createdAt: DateTime.now(),
      );

      // Verify default is student
      expect(user.isAdmin, isFalse);
      expect(user.isStudent, isTrue);
      expect(user.role, equals('student'));

      // From Map check
      final parsed = AppUser.fromMap('student_123', {
        'email': 'test.student@campus.edu',
        'displayName': 'Test Student',
        'isAdmin': false,
      });
      expect(parsed.isAdmin, isFalse);
    });

    test('Student accounts cannot manually override or review domains', () async {
      db.toggleCurrentAdminStatus(false);
      expect(db.currentUser.isAdmin, isFalse);

      // Student attempt to manually allow domain must throw
      expect(
        () => db.manuallyAllowDomain('keraekken-loagginnusa.godaddysites.com'),
        throwsA(isA<StateError>()),
      );
    });

    test('Flipping the isAdmin boolean promotes user to Admin with manual allow override authority', () async {
      // Flip the boolean to true
      db.toggleCurrentAdminStatus(true);
      expect(db.currentUser.isAdmin, isTrue);
      expect(db.currentUser.role, equals('it_head'));

      const testDomain = 'keraekken-loagginnusa.godaddysites.com';
      // The domain was previously scored 99.8% malicious
      final beforeEntry = db.activeBlacklist.firstWhere((d) => d.domain == testDomain);
      expect(beforeEntry.isActive, isTrue);

      // Admin manually allows domain even though it is malicious
      await db.manuallyAllowDomain(
        testDomain,
        reason: 'IT Admin manual research clearance override',
      );

      // Verify domain is now allowed
      final afterEntry = db.activeBlacklist.where((d) => d.domain == testDomain);
      expect(afterEntry.isEmpty, isTrue, reason: 'Overridden domain should no longer be active in router blacklist');

      // Verify audit log has recorded the action
      final audit = db.auditLogs.firstWhere((a) => a.targetDomain == testDomain);
      expect(audit.action, equals('allowed'));
      expect(audit.details, contains('override'));
    });
  });
}
