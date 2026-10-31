import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_report.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _db = DatabaseService();
  String _filter = 'pending'; // 'pending' | 'all' | 'malicious' | 'suspicious'

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScanReport>>(
      stream: _db.reportsStream,
      initialData: _db.pendingReports,
      builder: (context, snapshot) {
        final allReports = snapshot.data ?? [];
        final filteredReports = allReports.where((r) {
          if (_filter == 'pending') return r.isPending;
          if (_filter == 'malicious') return r.verdict == 'malicious';
          if (_filter == 'suspicious') return r.verdict == 'suspicious';
          return true;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SECOPS TRIAGE QUEUE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.cyberCyan,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Human-in-the-Loop Override & Decision Authority',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded,
                            size: 16, color: AppColors.cyberCyan),
                        const SizedBox(width: 8),
                        Text(
                          'Active Admin: ${_db.currentUser.displayName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Chips Row
              Row(
                children: [
                  _buildFilterChip('pending', 'Pending Action (${allReports.where((r) => r.isPending).length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('malicious', 'High Threat (Malicious)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('suspicious', 'Suspicious (Borderline)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('all', 'Complete History (${allReports.length})'),
                ],
              ),
              const SizedBox(height: 20),

              // Empty State or List
              if (filteredReports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.task_alt_rounded, size: 48, color: AppColors.verifiedGreen.withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        const Text(
                          'No reports matching this filter',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All submitted threats have been triaged or no new detections logged.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredReports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) => _buildReportCard(filteredReports[i]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _filter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _filter = filterKey),
      selectedColor: AppColors.cyberCyan.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected ? AppColors.cyberCyan : AppColors.border,
      ),
    );
  }

  Widget _buildReportCard(ScanReport r) {
    Color cardBorder;
    Color scoreColor;
    if (r.score >= 0.70) {
      cardBorder = AppColors.threatRed.withValues(alpha: 0.5);
      scoreColor = AppColors.threatRed;
    } else if (r.score >= 0.35) {
      cardBorder = AppColors.warningAmber.withValues(alpha: 0.5);
      scoreColor = AppColors.warningAmber;
    } else {
      cardBorder = AppColors.verifiedGreen.withValues(alpha: 0.5);
      scoreColor = AppColors.verifiedGreen;
    }

    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(r.createdAt);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type, Domain, Score & Timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    r.inputType == 'qr' ? Icons.qr_code_2_rounded : Icons.link_rounded,
                    color: AppColors.cyberCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              r.domain,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${(r.score * 100).toInt()}% RISK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scoreColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Logged: $dateStr • Input: ${r.inputType.toUpperCase()} • Status: ${r.reviewDecision.toUpperCase()}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Raw input link
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                r.input,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Plain Language Reasons
            const Text(
              'Feature Detection Reasoning:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            ...r.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.cyberCyan)),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Action Buttons (Atomic Batch Commit)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      r.isPending
                          ? 'Awaiting human authorization'
                          : 'Triaged by: ${r.reviewedBy ?? "Admin"}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                if (r.isPending)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _db.reviewReport(
                            reportId: r.id,
                            decision: 'allowed',
                            customReason: 'Admin verified benign site (allowlist override)',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.surfaceElevated,
                                content: Text('Overridden: ${r.domain} marked as ALLOWED. Audit log created.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.verifiedGreen),
                        label: const Text('ALLOW OVERRIDE', style: TextStyle(color: AppColors.verifiedGreen)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _db.reviewReport(
                            reportId: r.id,
                            decision: 'confirmed_block',
                            customReason: 'Admin confirmed phishing / scam link. Blacklist enforced.',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.threatRed,
                                content: Text('Confirmed Block: ${r.domain} added to VPN DNS blocklist. Audit log committed.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: const Text('CONFIRM BLOCK'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.threatRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: r.isBlocked
                          ? AppColors.threatRed.withValues(alpha: 0.15)
                          : AppColors.verifiedGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r.isBlocked ? 'DECISION: CONFIRMED BLOCK' : 'DECISION: OVERRIDDEN ALLOW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: r.isBlocked ? AppColors.threatRed : AppColors.verifiedGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
