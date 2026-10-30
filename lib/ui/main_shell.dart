import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/admin_user.dart';
import '../models/scan_report.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'dashboard_screen.dart';
import 'domain_detail_screen.dart';
import 'network_status_screen.dart';
import 'review_queue_screen.dart';
import 'scan_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _db = DatabaseService();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _auth.authStateChanges,
      initialData: _auth.currentUser,
      builder: (context, userSnapshot) {
        final user = userSnapshot.data ?? _auth.currentUser;

        // If not authenticated, show AuthScreen
        if (user == null) {
          return AuthScreen(onAuthenticated: () => setState(() {}));
        }

        final bool isAdmin = user.isAdmin;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return Scaffold(
              appBar: _buildTopBar(context, user, isAdmin),
              body: isDesktop
                  ? Row(
                      children: [
                        _buildNavRail(isAdmin),
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                        Expanded(child: _buildBody(isAdmin)),
                      ],
                    )
                  : _buildBody(isAdmin),
              bottomNavigationBar: isDesktop ? null : _buildBottomNav(isAdmin),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildTopBar(
    BuildContext context,
    AppUser user,
    bool isAdmin,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AppBar(
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyberCyan.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.cyberCyan),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.cyberCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'SIGNALSAFE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          // Role Badge: Student vs Admin (Interactive Tap to toggle!)
          Tooltip(
            message: 'Click to switch between Student and IT Admin mode',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final newStatus = !isAdmin;
                await _auth.setAdminStatusInDatabase(user.uid, newStatus);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: newStatus ? AppColors.cyberCyan : AppColors.surfaceElevated,
                      duration: const Duration(seconds: 3),
                      content: Row(
                        children: [
                          Icon(
                            newStatus ? Icons.admin_panel_settings_rounded : Icons.school_rounded,
                            color: newStatus ? Colors.black : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              newStatus
                                  ? 'Unlocked IT ADMIN Mode! "Router Gateway" & "Review Queue" now visible in sidebar.'
                                  : 'Switched to STUDENT mode.',
                              style: TextStyle(
                                color: newStatus ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin
                      ? AppColors.cyberCyan.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isAdmin ? AppColors.cyberCyan : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.school_rounded,
                      size: 13,
                      color: isAdmin
                          ? AppColors.cyberCyan
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAdmin ? 'IT ADMIN (CLICK TO SWITCH)' : 'STUDENT (CLICK FOR ADMIN)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isAdmin
                          ? AppColors.cyberCyan
                          : AppColors.cyberCyan,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Live Router Status Pill (Visible on Desktop)
        if (screenWidth >= 760)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderHighlight),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.verifiedGreen),
                SizedBox(width: 6),
                Text(
                  'Tenda N301 WISP Active',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        const SizedBox(width: 8),

        // Quick Export Blacklist (Only enabled for Admins)
        if (isAdmin)
          IconButton(
            tooltip: 'Quick Copy Router Blacklist',
            icon: const Icon(
              Icons.file_upload_outlined,
              color: AppColors.cyberCyan,
            ),
            onPressed: () async {
              await ExportService.copyToClipboard();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.verifiedGreen,
                    content: Text(
                      'Router Blacklist copied to clipboard!',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        const SizedBox(width: 8),

        // User Account & Database Boolean Flip Inspector
        InkWell(
          onTap: () => _showUserRoleModal(context, user, isAdmin),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAdmin ? AppColors.cyberCyan : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAdmin
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  size: 16,
                  color: isAdmin
                      ? AppColors.cyberCyan
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  user.displayName.split(' ').first,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  void _showUserRoleModal(BuildContext context, AppUser user, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE USER PROFILE & DATABASE CLEARANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.cyberCyan,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // User Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAdmin
                              ? AppColors.cyberCyan.withValues(alpha: 0.15)
                              : AppColors.surfaceHighlight,
                        ),
                        child: Icon(
                          isAdmin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.school_rounded,
                          color: isAdmin
                              ? AppColors.cyberCyan
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? AppColors.cyberCyan.withValues(alpha: 0.15)
                              : AppColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAdmin
                                ? AppColors.cyberCyan
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          isAdmin ? 'IT ADMIN' : 'STUDENT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isAdmin
                                ? AppColors.cyberCyan
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // UID with 1-Tap Copy for Firestore Console
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Database User UID (users/{uid}):',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            SelectableText(
                              user.uid,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.cyberCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: user.uid));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'UID copied! Locate in Firestore users/{uid}',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text(
                          'Copy UID',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // One-Tap Admin Flip for Hackathon Testing / Demo
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'IT Admin Clearance (isAdmin)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                isAdmin
                    ? 'Full authority: review queue, manual allow/block, router sync'
                    : 'Restricted student view: threat scanning and personal submissions',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              value: isAdmin,
              activeThumbColor: AppColors.cyberCyan,
              onChanged: (val) async {
                await _auth.setAdminStatusInDatabase(user.uid, val);
                _db.toggleCurrentAdminStatus(val);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: val ? AppColors.cyberCyan : AppColors.warningAmber,
                      content: Text(
                        val
                            ? 'Flipped database clearance: You are now IT ADMIN!'
                            : 'Flipped database clearance: Role set to STUDENT',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),

            // Sign Out Button
            OutlinedButton.icon(
              onPressed: () async {
                await _auth.signOut();
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _currentIndex = 0);
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign Out of SignalSafe'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.threatRed,
                side: const BorderSide(color: AppColors.threatRed),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavRail(bool isAdmin) {
    return StreamBuilder<DashboardStats>(
      stream: _db.statsStream,
      initialData: _db.currentStats,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.pendingReports ?? 0;

        if (isAdmin) {
          // Full Admin Navigation
          return NavigationRail(
            backgroundColor: AppColors.background,
            selectedIndex: _currentIndex,
            onDestinationSelected: (val) => setState(() => _currentIndex = val),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(
              color: AppColors.cyberCyan,
              size: 24,
            ),
            unselectedIconTheme: const IconThemeData(
              color: AppColors.textMuted,
              size: 22,
            ),
            selectedLabelTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.cyberCyan,
              letterSpacing: 0.5,
            ),
            unselectedLabelTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('NetWatch'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                label: Text('Scan & Score'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(pendingCount.toString()),
                  backgroundColor: AppColors.warningAmber,
                  child: const Icon(Icons.rate_review_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text(pendingCount.toString()),
                  backgroundColor: AppColors.warningAmber,
                  child: const Icon(Icons.rate_review_rounded),
                ),
                label: const Text('Review Queue'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.security_outlined),
                selectedIcon: Icon(Icons.security_rounded),
                label: Text('Governance'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.router_outlined),
                selectedIcon: Icon(Icons.router_rounded),
                label: Text('Router Gateway'),
              ),
            ],
          );
        } else {
          // Student Navigation (Simplified, Student Security Focused)
          return NavigationRail(
            backgroundColor: AppColors.background,
            selectedIndex: _currentIndex.clamp(0, 2),
            onDestinationSelected: (val) => setState(() => _currentIndex = val),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(
              color: AppColors.cyberCyan,
              size: 24,
            ),
            unselectedIconTheme: const IconThemeData(
              color: AppColors.textMuted,
              size: 22,
            ),
            selectedLabelTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.cyberCyan,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                label: Text('Threat Scanner'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: Text('Campus Shield'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: Text('My Submissions'),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildBottomNav(bool isAdmin) {
    if (isAdmin) {
      return NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: _currentIndex,
        onDestinationSelected: (val) => setState(() => _currentIndex = val),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(
              Icons.dashboard_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'NetWatch',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(
              Icons.rate_review_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(
              Icons.security_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Domains',
          ),
          NavigationDestination(
            icon: Icon(Icons.router_outlined),
            selectedIcon: Icon(
              Icons.router_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Router Gateway',
          ),
        ],
      );
    } else {
      return NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: _currentIndex.clamp(0, 2),
        onDestinationSelected: (val) => setState(() => _currentIndex = val),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Scan & Check',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(
              Icons.shield_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Campus Shield',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(
              Icons.history_rounded,
              color: AppColors.cyberCyan,
            ),
            label: 'Submissions',
          ),
        ],
      );
    }
  }

  Widget _buildBody(bool isAdmin) {
    if (isAdmin) {
      // Full Admin View
      switch (_currentIndex) {
        case 0:
          return DashboardScreen(
            onNavigateTab: (tab) => setState(() => _currentIndex = tab),
          );
        case 1:
          return const ScanScreen();
        case 2:
          return const ReviewQueueScreen();
        case 3:
          return const DomainDetailScreen();
        case 4:
          return const NetworkStatusScreen();
        default:
          return DashboardScreen(
            onNavigateTab: (tab) => setState(() => _currentIndex = tab),
          );
      }
    } else {
      // Student View
      switch (_currentIndex) {
        case 0:
          return const ScanScreen();
        case 1:
          return _buildStudentCampusShieldView();
        case 2:
          return _buildStudentSubmissionsView();
        default:
          return const ScanScreen();
      }
    }
  }

  /// Student View: Campus Shield Advisory
  Widget _buildStudentCampusShieldView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.cyberCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyberCyan.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.cyberCyan,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to SignalSafe Protected WiFi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your device is shielded by Tenda N301 hardware filtering. Known phishing domains, credential harvesters, and malicious QR links are blocked automatically at the router gateway.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Student Guidance Cards
          const Text(
            'CAMPUS DIGITAL SAFETY PROTOCOLS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.cyberCyan,
            ),
          ),
          const SizedBox(height: 12),
          _buildStudentTip(
            icon: Icons.qr_code_2_rounded,
            title: 'Verify Physical QR Codes (Quishing Defense)',
            body:
                'Attackers paste fraudulent stickers over campus library and cafeteria signs. Use the Threat Scanner to inspect links before signing in.',
          ),
          const SizedBox(height: 10),
          _buildStudentTip(
            icon: Icons.lock_open_rounded,
            title: 'Never Input Credentials on Unencrypted HTTP',
            body:
                'SignalSafe automatically blocks plaintext HTTP sites soliciting passwords. Look for SSL encryption verified by campus IT.',
          ),
          const SizedBox(height: 10),
          _buildStudentTip(
            icon: Icons.report_problem_rounded,
            title: 'Report Suspicious Sites to IT Head',
            body:
                'Found a deceptive email link? Scan it and tap "Report to IT Head" to flag it for the campus-wide router blacklist.',
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTip({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.cyberCyan, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Student View: My Submissions History
  Widget _buildStudentSubmissionsView() {
    return StreamBuilder<List<ScanReport>>(
      stream: _db.reportsStream,
      initialData: _db.pendingReports,
      builder: (context, snapshot) {
        final reports = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR SUBMITTED THREAT REPORTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.cyberCyan,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Submissions Flagged for IT SecOps Triage',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No reports submitted yet. Use the Threat Scanner to inspect links.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final r = reports[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              r.inputType == 'qr'
                                  ? Icons.qr_code_2_rounded
                                  : Icons.link_rounded,
                              color: AppColors.cyberCyan,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.domain,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Status: ${r.reviewDecision.toUpperCase()} • ${(r.score * 100).toInt()}% Risk',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: r.isPending
                                    ? AppColors.warningAmber.withValues(
                                        alpha: 0.15,
                                      )
                                    : (r.isBlocked
                                          ? AppColors.threatRed.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.verifiedGreen.withValues(
                                              alpha: 0.15,
                                            )),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.reviewDecision.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: r.isPending
                                      ? AppColors.warningAmber
                                      : (r.isBlocked
                                            ? AppColors.threatRed
                                            : AppColors.verifiedGreen),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
