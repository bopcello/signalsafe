import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain_blacklist.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class DomainDetailScreen extends StatefulWidget {
  const DomainDetailScreen({super.key});

  @override
  State<DomainDetailScreen> createState() => _DomainDetailScreenState();
}

class _DomainDetailScreenState extends State<DomainDetailScreen> {
  final _db = DatabaseService();
  String? _selectedDomain;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DomainBlacklistEntry>>(
      stream: _db.blacklistStream,
      initialData: _db.activeBlacklist,
      builder: (context, snapshot) {
        final allDomains = snapshot.data ?? [];
        final query = _searchController.text.trim().toLowerCase();
        final filtered = allDomains
            .where((d) => d.domain.toLowerCase().contains(query))
            .toList()
          ..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));

        final selected = filtered.isNotEmpty
            ? filtered.firstWhere(
                (d) => d.domain == _selectedDomain,
                orElse: () => filtered.first,
              )
            : null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'DOMAIN GOVERNANCE & AUDIT TRAIL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.cyberCyan,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Feature Analysis & Immutable Decision History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.cyberCyan),
                  hintText: 'Search domain name or filter blacklist database...',
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Split View (List on left, Details on right)
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No matching domains found',
                            style: TextStyle(color: AppColors.textMuted)),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 340,
                                  child: _buildDomainList(filtered, selected),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: selected != null
                                      ? _buildDomainInspector(selected)
                                      : const SizedBox(),
                                ),
                              ],
                            );
                          } else {
                            return _buildDomainList(filtered, selected);
                          }
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDomainList(
      List<DomainBlacklistEntry> domains, DomainBlacklistEntry? selected) {
    return Card(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: domains.length,
        separatorBuilder: (_, __) => const Divider(height: 8),
        itemBuilder: (context, i) {
          final item = domains[i];
          final isSelected = item.domain == selected?.domain;
          return ListTile(
            selected: isSelected,
            selectedTileColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: Icon(
              item.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
              color: item.isActive ? AppColors.threatRed : AppColors.verifiedGreen,
              size: 20,
            ),
            title: Text(
              item.domain,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? AppColors.cyberCyan : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${(item.score * 100).toInt()}% Risk • ${item.status.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            onTap: () => setState(() => _selectedDomain = item.domain),
          );
        },
      ),
    );
  }

  Widget _buildDomainInspector(DomainBlacklistEntry domain) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(domain.firstSeen);
    final auditLogs = _db.auditLogs
        .where((l) => l.targetDomain.toLowerCase() == domain.domain.toLowerCase())
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Domain Header Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: domain.isActive ? AppColors.threatRed : AppColors.verifiedGreen,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: domain.isActive
                              ? AppColors.threatRed.withValues(alpha: 0.15)
                              : AppColors.verifiedGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          domain.isActive ? 'ROUTER BLACKLIST: ENFORCED' : 'OVERRIDDEN ALLOWLIST',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: domain.isActive ? AppColors.threatRed : AppColors.verifiedGreen,
                          ),
                        ),
                      ),
                      Text(
                        'First Observed: $dateStr',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    domain.domain,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Threat Score: ${(domain.score * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: domain.score >= 0.7 ? AppColors.threatRed : AppColors.warningAmber,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Source: ${domain.source.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text(
                    'Detection Reasoning Summary:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  ...domain.reasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $r', style: const TextStyle(fontSize: 13, height: 1.4)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Admin Manual Override Control
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _db.currentUser.isAdmin ? Icons.shield_rounded : Icons.lock_outline_rounded,
                            size: 16,
                            color: _db.currentUser.isAdmin ? AppColors.cyberCyan : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _db.currentUser.isAdmin
                                ? 'Admin Override Authority Active'
                                : 'Student Mode: IT Admin required for overrides',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _db.currentUser.isAdmin ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (_db.currentUser.isAdmin)
                        domain.isActive
                            ? ElevatedButton.icon(
                                onPressed: () async {
                                  await _db.manuallyAllowDomain(
                                    domain.domain,
                                    reason: 'IT Admin override: domain explicitly permitted despite ${(domain.score * 100).toInt()}% threat score',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.verifiedGreen,
                                        content: Text(
                                          'Domain Overridden: ${domain.domain} is now ALLOWED.',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.black),
                                label: const Text('ALLOW DOMAIN (OVERRIDE)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.verifiedGreen,
                                  foregroundColor: Colors.black,
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed: () async {
                                  await _db.addManualDomainBlock(
                                    domain.domain,
                                    reason: 'IT Admin manual policy block enforced',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.threatRed,
                                        content: Text(
                                          'Domain Blocked: ${domain.domain} added to active router blacklist.',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.block_rounded, size: 16, color: AppColors.threatRed),
                                label: const Text('RE-ENFORCE BLOCK', style: TextStyle(color: AppColors.threatRed)),
                              ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Immutable Audit Trail Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, size: 20, color: AppColors.cyberCyan),
                      SizedBox(width: 8),
                      Text(
                        'Immutable Audit Trail (Section 6 Security Rules Compliance)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (auditLogs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No direct override history logged for this domain',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: auditLogs.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final log = auditLogs[idx];
                        final logDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_outlined, size: 14, color: AppColors.cyberCyan),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Action: ${log.action.toUpperCase()} by ${log.actorUid}',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      Text(logDate, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(log.details, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Features Breakdown Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LegitPhish 16-Feature Baseline Vector',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: domain.reasonFeatures.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              e.value.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppColors.cyberCyan,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
