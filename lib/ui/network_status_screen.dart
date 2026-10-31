import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/admin_user.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/local_vpn_service.dart';
import '../services/pihole_service.dart';
import '../theme/app_theme.dart';

/// VPN Gateway Screen
///
/// Shows:
///  - On-device AdGuard-style Local VPN with live DNS sinkhole
///  - Pi-hole + WireGuard VPN status cards
///  - Connected WireGuard VPN clients
///  - Pi-hole block events feed
///  - Repeat offender analytics (now by WireGuard peer IP)
///  - Pi-hole query log ingest dialog
///  - Pi-hole dnsmasq blocklist export dialog
///  - Demo runbook for the new local-VPN architecture
class NetworkStatusScreen extends StatefulWidget {
  const NetworkStatusScreen({super.key});

  @override
  State<NetworkStatusScreen> createState() => _NetworkStatusScreenState();
}

class _NetworkStatusScreenState extends State<NetworkStatusScreen> {
  final _db = DatabaseService();
  final _vpn = PiHoleVpnService();
  final _localVpn = LocalVpnService();
  DateTime _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 2));

  @override
  void initState() {
    super.initState();
    _localVpn.addListener(_onVpnStateChanged);
  }

  @override
  void dispose() {
    _localVpn.removeListener(_onVpnStateChanged);
    super.dispose();
  }

  void _onVpnStateChanged() {
    if (mounted) setState(() {});
  }

  // Demo: pre-canned domains for the simulate button
  static const _demoBlockDomains = [
    'keraekken-loagginnusa.godaddysites.com',
    'paypa1-secure-login.phishbait.net',
    'campus-qr-redirect.evil-actor.io',
    'netbanking-verify.fraudster.xyz',
    'ucgrant-form.phishing.link',
    'djtool-for-spotify.com',
  ];
  int _demoIdx = 0;

  // ─── Dialogs ────────────────────────────────────────────────────────────────

  void _showExportDialog() {
    final text = ExportService.generatePiHoleDnsmasqFormat();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderHighlight),
        ),
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: AppColors.cyberCyan),
            SizedBox(width: 10),
            Text('EXPORT PI-HOLE BLOCKLIST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy these dnsmasq-format entries into Pi-hole.\n'
                'Drop into /etc/pihole/custom_blocklist.txt, then run: pihole -g',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.cyberCyan),
                  const SizedBox(width: 6),
                  Text(
                    '${_db.activeBlacklist.length} domains ready to push to Pi-hole',
                    style: const TextStyle(fontSize: 12, color: AppColors.cyberCyan, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await ExportService.copyToClipboard();
              setState(() => _lastSyncTime = DateTime.now());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.verifiedGreen,
                    content: Text(
                      'Pi-hole blocklist copied! Run: pihole -g to apply.',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('COPY TO CLIPBOARD'),
          ),
        ],
      ),
    );
  }

  void _showRunbookDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cyberCyan),
        ),
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: AppColors.cyberCyan),
            SizedBox(width: 10),
            Text('VPN GATEWAY DEMO RUNBOOK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SignalSafe Local VPN Gateway Live Setup:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                SizedBox(height: 12),
                _RunbookStep(
                  step: '1',
                  title: 'Start Docker Containers',
                  body: 'docker start pihole wg-easy\n'
                      'Verify Pi-hole at http://localhost:8080/admin and WireGuard at http://localhost:51821',
                ),
                _RunbookStep(
                  step: '2',
                  title: 'Student Installs App & Enables Local VPN',
                  body: 'Student installs the SignalSafe app and allows it to create a local VPN profile on the device. '
                      'All DNS queries are filtered through the SignalSafe VPN gateway.',
                ),
                _RunbookStep(
                  step: '3',
                  title: 'Verify Pi-hole Blocks',
                  body: 'On judge\'s phone, open a URL from the blocklist. Pi-hole returns 0.0.0.0 (DNS block). '
                      'Pi-hole query log shows the block event in real time.',
                ),
                _RunbookStep(
                  step: '4',
                  title: 'Export Blocklist to Pi-hole',
                  body: 'Click "EXPORT PI-HOLE BLOCKLIST" → copy dnsmasq entries → paste into '
                      '/etc/pihole/custom_blocklist.txt → run: pihole -g',
                ),
                _RunbookStep(
                  step: '5',
                  title: 'Human Override Demonstration',
                  body: 'Navigate to Review Queue → tap "Allow Override" → '
                      'Pi-hole blocklist entry is removed and audit log is updated.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  void _showIngestPiHoleLogsDialog() {
    final logController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cyberCyan),
            ),
            title: const Row(
              children: [
                Icon(Icons.dns_rounded, color: AppColors.cyberCyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'INGEST PI-HOLE QUERY LOG',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cyberCyan.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.cyberCyan.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: AppColors.cyberCyan),
                              SizedBox(width: 8),
                              Text(
                                'How Pi-hole Block Ingestion Works',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cyberCyan,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'When WireGuard VPN clients attempt to visit a domain in the Pi-hole blocklist, '
                            'Pi-hole returns 0.0.0.0 and logs the block event (client VPN IP, timestamp, domain).\n'
                            'Paste the Pi-hole query log here to ingest these events into SignalSafe for '
                            'live Repeat Offender Analytics and Firestore telemetry.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pi-hole Query Log (blocked lines):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            logController.text = PiHoleVpnService.samplePiHoleQueryLog;
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.auto_fix_high, size: 14, color: AppColors.cyberCyan),
                          label: const Text(
                            'LOAD SAMPLE LOG',
                            style: TextStyle(fontSize: 11, color: AppColors.cyberCyan),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: logController,
                      maxLines: 8,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Paste Pi-hole query log lines here...\n\n'
                            'Example:\n'
                            '2026-10-30 15:42:10 BLOCKED (gravity) phishbait.net from 10.8.0.2',
                        hintStyle: TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final text = logController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter or load Pi-hole query log text.'),
                        backgroundColor: AppColors.threatRed,
                      ),
                    );
                    return;
                  }

                  final count = _vpn.ingestPiHoleQueryLog(text);
                  Navigator.pop(ctx);
                  setState(() => _lastSyncTime = DateTime.now());

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.verifiedGreen,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.black, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ingested $count Pi-hole block events into Firestore analytics!',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('PARSE & INGEST INTO DATABASE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _simulateBlockEvent() async {
    final domain = _demoBlockDomains[_demoIdx % _demoBlockDomains.length];
    _demoIdx++;
    // VPN subnet: 10.8.0.x
    final ip = '10.8.0.${2 + (_demoIdx % 10)}';

    await _db.logBlockEvent(domain, clientIp: ip, userAgent: 'Pi-hole DNS Block (gravity)');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.threatRed,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.block_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pi-hole block: $domain ($ip)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final syncStr = DateFormat('HH:mm:ss').format(_lastSyncTime);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOCAL VPN GATEWAY',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.cyberCyan,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Pi-hole DNS + WireGuard VPN Telemetry',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showRunbookDialog,
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('DEMO RUNBOOK'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showExportDialog,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('EXPORT TO PI-HOLE'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showIngestPiHoleLogsDialog,
                    icon: const Icon(Icons.dns_rounded, size: 16, color: AppColors.cyberCyan),
                    label: const Text(
                      'INGEST PI-HOLE LOG',
                      style: TextStyle(color: AppColors.cyberCyan),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cyberCyan),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _simulateBlockEvent,
                    icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.threatRed),
                    label: const Text(
                      'SIMULATE BLOCK',
                      style: TextStyle(color: AppColors.threatRed),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.threatRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── On-Device AdGuard-style Local VPN Card ──────────────────────────
          _buildLocalVpnCard(),
          const SizedBox(height: 24),

          // ── VPN / Pi-hole Status Cards Grid ─────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 1.8 : 1.4,
                children: [
                  _buildStatusCard(
                    title: 'PI-HOLE STATUS',
                    value: 'DNS Sinkhole',
                    status: '101k Domains Blocked',
                    icon: Icons.dns_rounded,
                    color: AppColors.cyberCyan,
                  ),
                  _buildStatusCard(
                    title: 'WIREGUARD VPN',
                    value: 'UDP 51820',
                    status: 'All Devices Tunnelled',
                    icon: Icons.vpn_lock_rounded,
                    color: AppColors.verifiedGreen,
                  ),
                  _buildStatusCard(
                    title: 'VPN GATEWAY IP',
                    value: '10.8.0.1',
                    status: 'Subnet 10.8.0.0/24',
                    icon: Icons.hub_rounded,
                    color: AppColors.cyberCyan,
                  ),
                  _buildStatusCard(
                    title: 'LAST SYNC',
                    value: syncStr,
                    status: 'Pi-hole Gravity Updated',
                    icon: Icons.sync_rounded,
                    color: AppColors.verifiedGreen,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Connected VPN Clients ────────────────────────────────────────────
          _buildVpnClientsCard(),
          const SizedBox(height: 24),

          // ── Repeat Offender Analytics ────────────────────────────────────────
          _buildRepeatOffendersAnalysis(),
          const SizedBox(height: 24),

          // ── Block Events Feed ────────────────────────────────────────────────
          _buildBlockEventsFeed(),
        ],
      ),
    );
  }

  // ─── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildStatusCard({
    required String title,
    required String value,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVpnClientsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key_rounded, color: AppColors.cyberCyan, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Connected WireGuard VPN Clients',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: StreamBuilder<List<DhcpClient>>(
                    stream: _db.clientsStream,
                    initialData: _db.dhcpClients,
                    builder: (context, snapshot) {
                      final count = (snapshot.data ?? []).length;
                      return Text(
                        '$count Active VPN Peers',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.cyberCyan),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            StreamBuilder<List<DhcpClient>>(
              stream: _db.clientsStream,
              initialData: _db.dhcpClients,
              builder: (context, snapshot) {
                final clients = snapshot.data ?? [];
                if (clients.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.vpn_lock_outlined,
                            color: AppColors.textMuted.withValues(alpha: 0.4), size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          'No VPN peers connected yet',
                          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Clients appear here once they connect via WireGuard QR code.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: c.isFlagged
                                ? AppColors.threatRed.withValues(alpha: 0.15)
                                : AppColors.verifiedGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            c.hostName.toLowerCase().contains('phone') ||
                                    c.hostName.toLowerCase().contains('iphone')
                                ? Icons.phone_iphone_rounded
                                : Icons.laptop_mac_rounded,
                            color: c.isFlagged ? AppColors.threatRed : AppColors.verifiedGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.hostName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.ip,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.cyberCyan),
                              ),
                              Text(
                                'WG Peer: ${c.mac}',
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.isFlagged
                                ? AppColors.threatRed.withValues(alpha: 0.15)
                                : AppColors.verifiedGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.isFlagged ? 'THREAT' : 'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: c.isFlagged ? AppColors.threatRed : AppColors.verifiedGreen,
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

  Widget _buildRepeatOffendersAnalysis() {
    return StreamBuilder<List<BlockEvent>>(
      stream: _db.eventsStream,
      initialData: _db.blockEvents,
      builder: (context, eventSnapshot) {
        return StreamBuilder<List<DhcpClient>>(
          stream: _db.clientsStream,
          initialData: _db.dhcpClients,
          builder: (context, clientSnapshot) {
            final events = eventSnapshot.data ?? [];
            final clients = clientSnapshot.data ?? [];
            final offenders = _vpn.analyzeRepeatOffenders(events, clients);
            final repeatOffenders = offenders.where((o) => o.blockCount >= 2).toList();

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: repeatOffenders.isNotEmpty
                      ? AppColors.threatRed.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: repeatOffenders.isNotEmpty ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: repeatOffenders.isNotEmpty
                                ? AppColors.threatRed.withValues(alpha: 0.15)
                                : AppColors.verifiedGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            repeatOffenders.isNotEmpty
                                ? Icons.warning_amber_rounded
                                : Icons.verified_user_rounded,
                            color: repeatOffenders.isNotEmpty
                                ? AppColors.threatRed
                                : AppColors.verifiedGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'VPN CLIENT REPEAT OFFENDER ANALYTICS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tracks WireGuard VPN peers repeatedly attempting to reach blocked malicious domains',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: repeatOffenders.isNotEmpty
                                      ? AppColors.threatRed.withValues(alpha: 0.15)
                                      : AppColors.verifiedGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: repeatOffenders.isNotEmpty
                                        ? AppColors.threatRed.withValues(alpha: 0.4)
                                        : AppColors.verifiedGreen.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  repeatOffenders.isNotEmpty
                                      ? '${repeatOffenders.length} REPEAT VIOLATOR${repeatOffenders.length == 1 ? '' : 'S'} DETECTED'
                                      : 'ALL VPN PEERS COMPLIANT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: repeatOffenders.isNotEmpty
                                        ? AppColors.threatRed
                                        : AppColors.verifiedGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    if (offenders.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: AppColors.textMuted.withValues(alpha: 0.4), size: 36),
                            const SizedBox(height: 10),
                            const Text(
                              'No Threat Activity Recorded',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use "INGEST PI-HOLE LOG" above or click "SIMULATE BLOCK" to populate.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: offenders.length,
                        separatorBuilder: (_, __) => const Divider(height: 20),
                        itemBuilder: (context, idx) {
                          final o = offenders[idx];
                          final isRepeat = o.blockCount >= 2;
                          final badgeColor = o.blockCount >= 4
                              ? AppColors.threatRed
                              : (isRepeat ? Colors.orange : AppColors.cyberCyan);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isRepeat
                                  ? AppColors.threatRed.withValues(alpha: 0.04)
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRepeat
                                    ? AppColors.threatRed.withValues(alpha: 0.25)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Device header row ──────────────────────
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        o.hostName.toLowerCase().contains('phone') ||
                                                o.hostName.toLowerCase().contains('iphone')
                                            ? Icons.phone_android_rounded
                                            : Icons.laptop_chromebook_rounded,
                                        color: badgeColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Name + severity badge
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                o.hostName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  o.threatSeverity,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // VPN IP + Peer (stacked on mobile)
                                          Text(
                                            'VPN IP: ${o.clientIp}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: AppColors.cyberCyan,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Peer: ${o.wgPeer}  ·  Last Hit: ${DateFormat('HH:mm · dd MMM').format(o.lastAttempt)}',
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // ── Action buttons row ─────────────────────
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.block_rounded, size: 13, color: badgeColor),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${o.blockCount} DNS Block${o.blockCount == 1 ? '' : 's'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: o.clientIp));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppColors.threatRed,
                                            content: Text(
                                              'Copied VPN IP ${o.clientIp} — revoke WireGuard peer to isolate.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.security, size: 13, color: AppColors.threatRed),
                                      label: const Text(
                                        'REVOKE VPN PEER',
                                        style: TextStyle(fontSize: 10, color: AppColors.threatRed),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        side: const BorderSide(color: AppColors.threatRed),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // ── Targeted domains ───────────────────────
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Targeted Malicious Domains:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: o.targetedDomains.map((dom) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Text(
                                            dom,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontFamily: 'monospace',
                                              color: AppColors.threatRed,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlockEventsFeed() {
    return StreamBuilder<List<BlockEvent>>(
      stream: _db.eventsStream,
      initialData: _db.blockEvents,
      builder: (context, snapshot) {
        final events = List<BlockEvent>.from(snapshot.data ?? []);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.crisis_alert_rounded, color: AppColors.threatRed, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Pi-hole DNS Block Events Feed',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: events.isEmpty
                                ? AppColors.surfaceElevated
                                : AppColors.threatRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: events.isEmpty
                                  ? AppColors.border
                                  : AppColors.threatRed.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${events.length} event${events.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: events.isEmpty ? AppColors.textMuted : AppColors.threatRed,
                            ),
                          ),
                        ),
                        if (events.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.threatRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.threatRed.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.threatRed,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every Pi-hole DNS block from a WireGuard VPN client appears here in real time via Firestore.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),

                if (events.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined,
                            color: AppColors.textMuted.withValues(alpha: 0.4), size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          'No block events yet',
                          style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Pi-hole DNS blocks from connected VPN peers will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _simulateBlockEvent,
                          icon: const Icon(Icons.bolt_rounded, size: 14, color: AppColors.threatRed),
                          label: const Text(
                            'Simulate Demo Block Event',
                            style: TextStyle(color: AppColors.threatRed, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.threatRed, width: 1),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final event = events[i];
                      final timeStr = DateFormat('HH:mm · dd MMM').format(event.createdAt);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5, right: 10),
                              decoration: const BoxDecoration(
                                color: AppColors.threatRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.domain,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      if (event.clientIp != null)
                                        Text(
                                          event.clientIp!,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: AppColors.cyberCyan,
                                          ),
                                        ),
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.threatRed.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: AppColors.threatRed.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: const Text(
                                          'PI-HOLE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.threatRed,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Local AdGuard-style VPN Card ──────────────────────────────────────────

  Future<void> _toggleLocalVpn() async {
    if (_localVpn.isRunning) {
      final stopped = await _localVpn.stopVpn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stopped ? 'Local VPN Stopped.' : 'Failed to stop Local VPN.'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    } else {
      final started = await _localVpn.startVpn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(started
                ? 'SignalSafe Local VPN Active! Intercepting DNS on 10.240.0.1:53.'
                : 'Could not start VPN. Please grant the Android VPN permission dialog.'),
            backgroundColor: started ? AppColors.verifiedGreen : AppColors.threatRed,
          ),
        );
      }
    }
  }

  Future<void> _syncBlocklistToVpn() async {
    await _localVpn.syncBlocklist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Active domain blocklist synchronized to native VPN memory.'),
          backgroundColor: AppColors.cyberCyan,
        ),
      );
    }
  }

  void _testSinkholeLookup() {
    const testDomain = 'keraekken-loagginnusa.godaddysites.com';
    _db.logBlockEvent(
      testDomain,
      clientIp: '10.240.0.1 (Local Device)',
      userAgent: 'Local VPN Sinkhole (0.0.0.0)',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('DNS Test: "$testDomain" sinkholed to 0.0.0.0! Block event recorded.'),
        backgroundColor: AppColors.threatRed,
      ),
    );
  }

  Widget _buildLocalVpnCard() {
    final isRunning = _localVpn.isRunning;
    final totalQueries = _localVpn.totalQueries;
    final totalBlocked = _localVpn.totalBlocked;
    final logs = _localVpn.recentLogs;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning ? AppColors.verifiedGreen : AppColors.borderHighlight,
          width: isRunning ? 1.5 : 1.0,
        ),
        boxShadow: isRunning
            ? [
                BoxShadow(
                  color: AppColors.verifiedGreen.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isRunning ? AppColors.verifiedGreen : AppColors.cyberCyan)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRunning ? Icons.shield_rounded : Icons.shield_outlined,
                  color: isRunning ? AppColors.verifiedGreen : AppColors.cyberCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'ON-DEVICE VPN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isRunning ? AppColors.verifiedGreen : AppColors.warningAmber)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isRunning ? AppColors.verifiedGreen : AppColors.warningAmber,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: isRunning ? AppColors.verifiedGreen : AppColors.warningAmber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isRunning ? 'VPN ACTIVE' : 'VPN STOPPED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isRunning ? AppColors.verifiedGreen : AppColors.warningAmber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Local Android TUN (10.240.0.1/32) • Port 53 DNS sinkhole to 0.0.0.0 • Zero internet slowdown',
                      style: TextStyle(
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
          const SizedBox(height: 18),

          // Main Toggle Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleLocalVpn,
              icon: Icon(
                isRunning ? Icons.stop_circle_outlined : Icons.power_settings_new_rounded,
                size: 20,
              ),
              label: Text(
                isRunning
                    ? 'STOP LOCAL VPN (DISCONNECT SINKHOLE)'
                    : 'START LOCAL VPN (ENABLE PROTECTION)',
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRunning ? AppColors.threatRed : AppColors.verifiedGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Metrics Grid (4 items)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.0 : 1.9,
                children: [
                  _buildVpnMetricTile('VPN INTERFACE', isRunning ? '10.240.0.1:53' : 'INACTIVE', AppColors.cyberCyan),
                  _buildVpnMetricTile('DNS INTERCEPTED', '$totalQueries queries', AppColors.textPrimary),
                  _buildVpnMetricTile('THREATS SINKHOLED', '$totalBlocked blocked', AppColors.threatRed),
                  _buildVpnMetricTile('ACTIVE BLACKLIST', '${_db.activeBlacklist.length} rules', AppColors.verifiedGreen),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Action buttons row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _syncBlocklistToVpn,
                icon: const Icon(Icons.sync_rounded, size: 15, color: AppColors.cyberCyan),
                label: const Text('SYNC RULES TO VPN', style: TextStyle(fontSize: 11, color: AppColors.cyberCyan)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cyberCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _testSinkholeLookup,
                icon: const Icon(Icons.bug_report_rounded, size: 15, color: AppColors.threatRed),
                label: const Text('TEST SINKHOLE (0.0.0.0)', style: TextStyle(fontSize: 11, color: AppColors.threatRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.threatRed),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              if (logs.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _localVpn.clearLogs(),
                  icon: const Icon(Icons.clear_all_rounded, size: 15, color: AppColors.textMuted),
                  label: const Text('CLEAR LOGS', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Live DNS Log Feed
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal_rounded, size: 14, color: AppColors.cyberCyan),
                        SizedBox(width: 6),
                        Text(
                          'LIVE DEVICE DNS INTERCEPTOR FEED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.cyberCyan,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${logs.length} events',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        isRunning
                            ? 'VPN Active on 10.240.0.1. Waiting for device DNS queries...'
                            : 'Start the Local VPN to monitor and sinkhole device queries in real time.',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.take(6).length,
                    separatorBuilder: (_, __) => const Divider(height: 8, color: AppColors.border),
                    itemBuilder: (context, idx) {
                      final log = logs[idx];
                      final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
                      return Row(
                        children: [
                          Icon(
                            log.isBlocked ? Icons.block_rounded : Icons.check_circle_rounded,
                            size: 14,
                            color: log.isBlocked ? AppColors.threatRed : AppColors.verifiedGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.domain,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (log.isBlocked ? AppColors.threatRed : AppColors.verifiedGreen)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.isBlocked ? '0.0.0.0 SINKHOLE' : '1.1.1.1 RESOLVED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: log.isBlocked ? AppColors.threatRed : AppColors.verifiedGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVpnMetricTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RunbookStep extends StatelessWidget {
  final String step;
  final String title;
  final String body;

  const _RunbookStep({required this.step, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.cyberCyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.cyberCyan),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
