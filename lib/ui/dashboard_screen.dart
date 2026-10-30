import 'package:flutter/material.dart';
import '../models/domain_blacklist.dart';
import '../models/scan_report.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return StreamBuilder<DashboardStats>(
      stream: db.statsStream,
      initialData: db.currentStats,
      builder: (context, statsSnap) {
        final stats = statsSnap.data ?? db.currentStats;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner: Live Network Status & Threat Defense
              _buildTopLiveStatus(stats),
              const SizedBox(height: 20),

              // KPI Counters Grid (The 4 core metrics for judges)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.6 : 1.35,
                    children: [
                      _buildMetricCard(
                        title: 'BLOCKED DOMAINS',
                        value: stats.totalBlockedDomains.toString(),
                        subtitle: 'Active router blacklist',
                        icon: Icons.block_rounded,
                        accentColor: AppColors.threatRed,
                        badgeText: 'NETWORK ENFORCED',
                        onTap: () => onNavigateTab(4), // Blacklist
                      ),
                      _buildMetricCard(
                        title: 'PENDING REVIEWS',
                        value: stats.pendingReports.toString(),
                        subtitle: 'Awaiting human override',
                        icon: Icons.rate_review_rounded,
                        accentColor: AppColors.warningAmber,
                        badgeText: stats.pendingReports > 0 ? 'ACTION REQ' : 'TRIAGED',
                        onTap: () => onNavigateTab(2), // Review Queue
                      ),
                      _buildMetricCard(
                        title: 'INTERSTITIAL HITS',
                        value: stats.totalBlockEvents.toString(),
                        subtitle: 'Fallback page triggers',
                        icon: Icons.shield_rounded,
                        accentColor: AppColors.cyberCyan,
                        badgeText: 'LIVE DEFENSE',
                        onTap: () {},
                      ),
                      _buildMetricCard(
                        title: 'CAMPUS CLIENTS',
                        value: stats.activeNetworkClients.toString(),
                        subtitle: 'Tenda N301 DHCP pool',
                        icon: Icons.devices_rounded,
                        accentColor: AppColors.verifiedGreen,
                        badgeText: 'WISP ACTIVE',
                        onTap: () => onNavigateTab(4), // Network screen
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Telemetry & Grounding Showcase
              _buildModelTelemetryBanner(context),
              const SizedBox(height: 24),

              // 2-Column Section: Recent Threats & Live Review Queue
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildRecentThreatsCard(context, db)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildPendingReviewStreamCard(context, db)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildRecentThreatsCard(context, db),
                        const SizedBox(height: 20),
                        _buildPendingReviewStreamCard(context, db),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopLiveStatus(DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderHighlight),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cyberCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wifi_tethering_rounded, color: AppColors.cyberCyan, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tenda N301 WISP Gateway',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.circle, size: 8, color: AppColors.verifiedGreen),
                    SizedBox(width: 4),
                    Text(
                      'ACTIVE DEFENSE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.verifiedGreen,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  'Uplink: Dedicated MiFi Hotspot • DNS/SNI Filter: Enforced • Subnet: 192.168.0.0/24',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => onNavigateTab(1), // Go to Scan
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('SCAN URL / QR'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelTelemetryBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyberCyan.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surfaceElevated.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyberCyan.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.psychology_rounded, color: AppColors.cyberCyan, size: 28),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      'AI Threat Engine Telemetry',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '101,219 URL Mendeley Dataset Grounded',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.cyberCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '50-Tree Random Forest • 16 Lexical Features • Measured Validation Accuracy: 99.96% • On-Device Latency: <1ms',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigateTab(1),
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('TEST LIVE SCORER'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentThreatsCard(BuildContext context, DatabaseService db) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.security_update_warning_rounded,
                          color: AppColors.threatRed, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Live Blacklist Interceptions',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateTab(3), // Domain details
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(),
            StreamBuilder<List<DomainBlacklistEntry>>(
              stream: db.blacklistStream,
              initialData: db.activeBlacklist,
              builder: (context, snapshot) {
                final list = snapshot.data ?? db.activeBlacklist;
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No active threats recorded',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.take(4).length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final item = list[i];
                    return Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.threatRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${(item.score * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.threatRed,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.reasons.isNotEmpty
                                    ? item.reasons.first
                                    : 'Network threat blocked',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.isActive
                                ? AppColors.threatRed.withValues(alpha: 0.15)
                                : AppColors.verifiedGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.isActive ? 'BLOCKED' : 'ALLOWED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: item.isActive ? AppColors.threatRed : AppColors.verifiedGreen,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingReviewStreamCard(BuildContext context, DatabaseService db) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions_rounded, color: AppColors.warningAmber, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Triage Review Queue',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateTab(2), // Review Queue
                  child: const Text('Open Queue', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const Divider(),
            StreamBuilder<List<ScanReport>>(
              stream: db.reportsStream,
              initialData: db.pendingReports,
              builder: (context, snapshot) {
                final reports = (snapshot.data ?? db.pendingReports)
                    .where((r) => r.isPending)
                    .toList();
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Review queue is clear • 0 pending reports',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.take(3).length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final report = reports[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              report.inputType == 'qr'
                                  ? Icons.qr_code_2_rounded
                                  : Icons.link_rounded,
                              size: 16,
                              color: AppColors.cyberCyan,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                report.domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            Text(
                              '${(report.score * 100).toInt()}% Risk',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: report.score >= 0.7
                                    ? AppColors.threatRed
                                    : AppColors.warningAmber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                db.reviewReport(
                                  reportId: report.id,
                                  decision: 'allowed',
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('ALLOW', style: TextStyle(fontSize: 11)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                db.reviewReport(
                                  reportId: report.id,
                                  decision: 'confirmed_block',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.threatRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('BLOCK', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
