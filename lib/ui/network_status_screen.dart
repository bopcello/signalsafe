import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/admin_user.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/tenda_service.dart';
import '../theme/app_theme.dart';

class NetworkStatusScreen extends StatefulWidget {
  const NetworkStatusScreen({super.key});

  @override
  State<NetworkStatusScreen> createState() => _NetworkStatusScreenState();
}

class _NetworkStatusScreenState extends State<NetworkStatusScreen> {
  final _db = DatabaseService();
  final _tenda = TendaRouterService();
  DateTime _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 42));

  // Demo: pre-canned domain victims for the simulate button
  static const _demoBlockDomains = [
    'keraekken-loagginnusa.godaddysites.com',
    'paypa1-secure-login.phishbait.net',
    'campus-qr-redirect.evil-actor.io',
    'netbanking-verify.fraudster.xyz',
    'ucgrant-form.phishing.link',
  ];
  int _demoIdx = 0;

  void _showExportDialog() {
    final text = ExportService.generateTendaBlacklistText();

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
            Text('EXPORT ROUTER BLACKLIST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy and paste these active blocked domains into your Tenda N301 router: Parental Control → Website Filter → Blacklist.',
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
                    '${_db.activeBlacklist.length} active domains ready for sync',
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
                      'Blacklist copied to clipboard! Paste into Tenda Website Filter.',
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
            Text('TENDA N301 DEMO RUNBOOK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical Network Live Setup Steps (Section 8 Runbook):',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                SizedBox(height: 12),
                _RunbookStep(
                  step: '1',
                  title: 'WISP Client Mode',
                  body: 'Configure Tenda N301 in WISP Client Mode, wirelessly uplinked to a dedicated 4G/5G mobile hotspot.',
                ),
                _RunbookStep(
                  step: '2',
                  title: 'Sync Blacklist',
                  body: 'Open 192.168.0.1 in browser → Parental Control → Website Filter. Click "Export Blacklist" here and paste the domains.',
                ),
                _RunbookStep(
                  step: '3',
                  title: 'Judge Connects to WiFi',
                  body: 'Judge joins SignalSafe-WiFi (no software/profile required on phone). Phone appears live in Connected Devices table.',
                ),
                _RunbookStep(
                  step: '4',
                  title: 'Live Block Trigger',
                  body: 'Judge scans QR or opens demo link. Router immediately blocks request; fallback interstitial logs block event into dashboard.',
                ),
                _RunbookStep(
                  step: '5',
                  title: 'Human Override Demonstration',
                  body: 'Navigate to Review Queue → tap "Allow Override" → router permits domain, proving IT human authority.',
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

  /// Ingest Tenda N301 Parental Control & Syslog block data directly into database
  void _showIngestRouterLogsDialog() {
    final logController = TextEditingController();
    final routerIpController = TextEditingController(text: _tenda.routerIp);

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
                Icon(Icons.router_rounded, color: AppColors.cyberCyan),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'TENDA ROUTER PARENTAL CONTROL LOG INGEST',
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
                                'How Tenda Router Interception Works',
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
                            'When students on campus WiFi attempt to visit malicious domains filtered by Tenda Parental Controls or Website Filter, the router blocks the TCP connection and logs the event (Client IP, timestamp, and target domain).\nIngesting these logs records the events into Cloud Firestore, enabling live Repeat Offender Analytics to identify students repeatedly visiting phishing or malicious sites.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: routerIpController,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        labelText: 'Tenda Gateway IP',
                        prefixIcon: Icon(Icons.settings_ethernet, size: 18),
                        hintText: '192.168.0.1',
                      ),
                      onChanged: (val) => _tenda.setRouterIp(val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Router Syslog / Parental Control Log Lines:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            logController.text = TendaRouterService.sampleTendaRouterSyslog;
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.auto_fix_high, size: 14, color: AppColors.cyberCyan),
                          label: const Text(
                            'LOAD SAMPLE ROUTER LOGS',
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
                      decoration: InputDecoration(
                        hintText: 'Paste Tenda N301 System Log or Parental Control drop records here...\n\nExample:\n2026-10-30 15:42:10 [Parental Control] Drop HTTP packet from 192.168.0.104 to phishbait.net',
                        hintStyle: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
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
                        content: Text('Please enter or load router log text to ingest.'),
                        backgroundColor: AppColors.threatRed,
                      ),
                    );
                    return;
                  }

                  final count = _tenda.ingestRouterLogText(text);
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
                              'Successfully ingested $count router block events into Cloud Firestore & Analytics!',
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

  /// Demo helper: simulates a block event as if the interstitial page fired
  /// on a judge's phone. Writes to in-memory store (and optionally Firestore).
  void _simulateBlockEvent() async {
    final domain = _demoBlockDomains[_demoIdx % _demoBlockDomains.length];
    _demoIdx++;
    final ip = '192.168.0.${100 + (_demoIdx % 50)}';

    // In-memory update (instant — Firestore will sync later)
    await _db.logBlockEvent(domain, clientIp: ip);

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
                  'Block event fired: $domain ($ip)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStr = DateFormat('HH:mm:ss').format(_lastSyncTime);

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
                    'CAMPUS NETWORK GATEWAY & ROUTER SYNC',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.cyberCyan,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tenda N301 WISP Telemetry & DHCP Clients',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showRunbookDialog,
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('DEMO RUNBOOK'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showExportDialog,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('EXPORT BLACKLIST'),
                  ),
                  const SizedBox(width: 12),
                  // Ingest logs button
                  OutlinedButton.icon(
                    onPressed: _showIngestRouterLogsDialog,
                    icon: const Icon(Icons.input_rounded, size: 16, color: AppColors.cyberCyan),
                    label: const Text(
                      'INGEST ROUTER LOGS',
                      style: TextStyle(color: AppColors.cyberCyan),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cyberCyan),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Demo trigger: simulate a block event for judges
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

          // Tenda N301 WISP Status Cards Grid
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
                    title: 'ROUTER OPERATING MODE',
                    value: 'WISP Client Mode',
                    status: 'Tenda N301 v2',
                    icon: Icons.router_rounded,
                    color: AppColors.cyberCyan,
                  ),
                  _buildStatusCard(
                    title: 'WIRELESS UPLINK',
                    value: 'SignalSafe-MiFi-5G',
                    status: 'Dedicated Hotspot',
                    icon: Icons.wifi_rounded,
                    color: AppColors.verifiedGreen,
                  ),
                  _buildStatusCard(
                    title: 'GATEWAY IP / SUBNET',
                    value: '192.168.0.1',
                    status: '255.255.255.0',
                    icon: Icons.dns_rounded,
                    color: AppColors.cyberCyan,
                  ),
                  _buildStatusCard(
                    title: 'LAST BLACKLIST SYNC',
                    value: syncStr,
                    status: 'Synced & Enforced',
                    icon: Icons.sync_rounded,
                    color: AppColors.verifiedGreen,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Connected DHCP Clients List (from Tenda N301)
          Card(
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
                          Icon(Icons.devices_rounded, color: AppColors.cyberCyan, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Connected DHCP Client Devices (Tenda N301 Table)',
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
                        child: Text(
                          '${_db.dhcpClients.length} Active Leases',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.cyberCyan),
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
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: clients.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, i) {
                          final c = clients[i];
                          return Row(
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
                                  c.hostName.toLowerCase().contains('phone')
                                      ? Icons.phone_iphone_rounded
                                      : Icons.laptop_mac_rounded,
                                  color: c.isFlagged ? AppColors.threatRed : AppColors.verifiedGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.hostName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'MAC: ${c.mac}',
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  c.ip,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.cyberCyan),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Lease: ${c.leaseTime}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.isFlagged
                                      ? AppColors.threatRed.withValues(alpha: 0.15)
                                      : AppColors.verifiedGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.isFlagged ? 'THREAT INTERCEPTED' : 'SECURE',
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
          ),
          const SizedBox(height: 24),

          // ────────────────────────────────────────────────────
          // Repeat Offender Analysis (Student Threat Frequency)
          // ────────────────────────────────────────────────────
          _buildRepeatOffendersAnalysis(),

          const SizedBox(height: 24),

          // ────────────────────────────────────────────────────
          // Block Events Feed (what the router + interstitial page actually blocked)
          // ────────────────────────────────────────────────────
          _buildBlockEventsFeed(),
        ],
      ),
    );
  }

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

  /// Visual analytics to identify students repeatedly visiting blocked malicious domains
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
            final offenders = _tenda.analyzeRepeatOffenders(events, clients);
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STUDENT REPEAT OFFENDER ANALYTICS',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tracks student devices repeatedly attempting to bypass Tenda Parental Controls to visit malicious URLs',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                                : 'ALL CAMPUS DEVICES COMPLIANT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: repeatOffenders.isNotEmpty
                                  ? AppColors.threatRed
                                  : AppColors.verifiedGreen,
                            ),
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
                            Icon(Icons.shield_outlined, color: AppColors.textMuted.withValues(alpha: 0.4), size: 36),
                            const SizedBox(height: 10),
                            const Text(
                              'No Student Threat Activity Recorded',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use "INGEST ROUTER LOGS" above to parse Tenda router drops or click "SIMULATE BLOCK".',
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
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        o.hostName.toLowerCase().contains('phone')
                                            ? Icons.phone_android_rounded
                                            : Icons.laptop_chromebook_rounded,
                                        color: badgeColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                o.hostName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  o.threatSeverity,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Text(
                                                'IP: ${o.clientIp}',
                                                style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12,
                                                  color: AppColors.cyberCyan,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Text(
                                                'MAC: ${o.mac}',
                                                style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Text(
                                                'Last Hit: ${DateFormat('HH:mm:ss · dd MMM').format(o.lastAttempt)}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.block_rounded, size: 14, color: badgeColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${o.blockCount} Attempt${o.blockCount == 1 ? '' : 's'} Blocked',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: o.mac));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: AppColors.threatRed,
                                            content: Text(
                                              'Copied MAC ${o.mac} for Tenda MAC Filter Isolation.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.security, size: 14, color: AppColors.threatRed),
                                      label: const Text(
                                        'QUARANTINE MAC',
                                        style: TextStyle(fontSize: 11, color: AppColors.threatRed),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.threatRed),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Targeted Malicious Sites: ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: o.targetedDomains.map((dom) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              dom,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: AppColors.threatRed,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
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

  /// Live block events feed — driven by DatabaseService.eventsStream (Firestore-backed).
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
                // Card header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.crisis_alert_rounded,
                            color: AppColors.threatRed, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Router Block Events Feed',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
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
                              color: events.isEmpty
                                  ? AppColors.textMuted
                                  : AppColors.threatRed,
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
                                  color: AppColors.threatRed
                                      .withValues(alpha: 0.5),
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
                  'Every interstitial page hit from a blocked device on campus WiFi appears here in real time via Firestore.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),

                // Empty state
                if (events.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: AppColors.textMuted.withValues(alpha: 0.4),
                          size: 36,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No block events yet',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Events appear here when a device on campus WiFi hits a blocked domain.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _simulateBlockEvent,
                          icon: const Icon(Icons.bolt_rounded,
                              size: 14, color: AppColors.threatRed),
                          label: const Text(
                            'Simulate Demo Block Event',
                            style: TextStyle(
                                color: AppColors.threatRed, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.threatRed, width: 1),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      // Column header row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: const [
                            SizedBox(width: 18), // dot spacer
                            Expanded(
                              flex: 3,
                              child: Text(
                                'BLOCKED DOMAIN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'CLIENT IP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'TIMESTAMP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                'SOURCE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const Divider(height: 14),
                        itemBuilder: (context, i) {
                          final event = events[i];
                          final timeStr = DateFormat('HH:mm:ss · dd MMM')
                              .format(event.createdAt);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                // Pulsing threat dot
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: const BoxDecoration(
                                    color: AppColors.threatRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                // Domain + user agent
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (event.userAgent.isNotEmpty &&
                                          event.userAgent !=
                                              'Campus-WiFi Client')
                                        Text(
                                          event.userAgent,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Client IP
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    event.clientIp ?? '—',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: AppColors.cyberCyan,
                                    ),
                                  ),
                                ),
                                // Timestamp
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                // Source badge
                                SizedBox(
                                  width: 90,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.threatRed
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.threatRed
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: const Text(
                                      'INTERSTITIAL',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.threatRed,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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
