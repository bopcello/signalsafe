import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/database_service.dart';
import '../services/scoring_service.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _urlController = TextEditingController();
  final _scoring = ScoringService();
  final _db = DatabaseService();

  bool _isAnalyzing = false;
  ScanResult? _latestResult;
  String _activeInputType = 'url';
  bool _showQrDisplay = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis(String input, {String type = 'url'}) async {
    final clean = input.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _activeInputType = type;
      _showQrDisplay = (type == 'qr');
    });

    try {
      final result = await _scoring.scoreURL(clean, inputType: type);
      setState(() {
        _latestResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Inference error: $e')),
        );
      }
    }
  }

  Future<void> _submitToQueue() async {
    if (_latestResult == null) return;
    final r = _latestResult!;

    await _db.submitScanReport(
      input: r.rawInput,
      inputType: r.inputType,
      score: r.score,
      verdict: r.verdict,
      features: r.features,
      reasons: r.reasons,
      autoBlockIfMalicious: false,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            'Submitted ${r.domain} to Review Queue for SecOps audit.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  Future<void> _immediateBlock() async {
    if (_latestResult == null) return;
    final r = _latestResult!;

    await _db.submitScanReport(
      input: r.rawInput,
      inputType: r.inputType,
      score: r.score,
      verdict: r.verdict,
      features: r.features,
      reasons: r.reasons,
      autoBlockIfMalicious: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.threatRed,
          content: Text(
            'Enforced DNS block on ${r.domain}! Added to active blocklist.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          const Text(
            'AI THREAT DETECTOR & QR ANALYZER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.cyberCyan,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'On-Device Lexical & Structural Threat Scoring',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Presets Row for Instant Hackathon Judging Demos
          _buildPresetsBar(),
          const SizedBox(height: 20),

          // Main Input Box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              _activeInputType == 'qr'
                                  ? Icons.qr_code_2_rounded
                                  : Icons.language_rounded,
                              color: AppColors.cyberCyan,
                            ),
                            hintText: 'Enter domain or paste raw URL / decoded QR payload...',
                            suffixIcon: _urlController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      _urlController.clear();
                                      setState(() {
                                        _latestResult = null;
                                        _showQrDisplay = false;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onSubmitted: (val) => _runAnalysis(val, type: _activeInputType),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isAnalyzing
                            ? null
                            : () => _runAnalysis(_urlController.text, type: _activeInputType),
                        icon: _isAnalyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.shield_rounded, size: 18),
                        label: Text(_isAnalyzing ? 'SCORING...' : 'ANALYZE'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Web Link (URL)'),
                            selected: _activeInputType == 'url',
                            onSelected: (val) => setState(() => _activeInputType = 'url'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('QR Code (Quishing)'),
                            selected: _activeInputType == 'qr',
                            onSelected: (val) {
                              setState(() {
                                _activeInputType = 'qr';
                                _showQrDisplay = true;
                              });
                            },
                          ),
                        ],
                      ),
                      const Text(
                        'Offline Inference • Zero Network Fetch • <1ms',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Analysis Output (Score + Reasoning + Feature Grid)
          if (_latestResult != null) _buildResultSection(_latestResult!),
        ],
      ),
    );
  }

  Widget _buildPresetsBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'HACKATHON DEMO PRESETS (1-TAP AUDIT):',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ScoringService.demoSamples.map((sample) {
            return OutlinedButton(
              onPressed: () {
                _urlController.text = sample['url']!;
                _runAnalysis(sample['url']!, type: sample['type']!);
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                backgroundColor: AppColors.surface,
              ),
              child: Text(
                sample['label']!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultSection(ScanResult r) {
    Color verdictColor;
    String verdictLabel;
    IconData verdictIcon;

    if (r.isMalicious) {
      verdictColor = AppColors.threatRed;
      verdictLabel = 'MALICIOUS THREAT DETECTED';
      verdictIcon = Icons.dangerous_rounded;
    } else if (r.isSuspicious) {
      verdictColor = AppColors.warningAmber;
      verdictLabel = 'SUSPICIOUS (HUMAN REVIEW REQUIRED)';
      verdictIcon = Icons.warning_amber_rounded;
    } else {
      verdictColor = AppColors.verifiedGreen;
      verdictLabel = 'CLEAN / BENIGN DOMAIN';
      verdictIcon = Icons.check_circle_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live QR Code Generator Card (for physical judge phone testing)
        if (_showQrDisplay) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.cyberCyan, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: r.rawInput,
                      version: QrVersions.auto,
                      size: 110.0,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.cyberCyan),
                            SizedBox(width: 6),
                            Text(
                              'LIVE JUDGE SCAN BENCHMARK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.cyberCyan,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Point your phone camera at this QR code with the SignalSafe VPN active to test DNS-level blocking in real time.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          r.rawInput,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Verdict & Score Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: verdictColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: verdictColor.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Radial / Score Dial
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: r.score,
                      strokeWidth: 8,
                      backgroundColor: verdictColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(verdictColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(r.score * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: verdictColor,
                        ),
                      ),
                      const Text(
                        'RISK',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(verdictIcon, color: verdictColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          verdictLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: verdictColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      r.domain,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Input Type: ${r.inputType.toUpperCase()} • Inference: ${r.inferenceTimeMs}ms • Grounding: Mendeley LegitPhish',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Action Buttons (Role-Gated for Student vs Admin)
              Column(
                children: [
                  if (_db.currentUser.isAdmin) ...[
                    ElevatedButton.icon(
                      onPressed: _immediateBlock,
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text('ENFORCE BLOCK'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.threatRed,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (r.isMalicious) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _db.manuallyAllowDomain(
                            r.domain,
                            reason: 'Admin manual override from scanner despite high threat score',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.verifiedGreen,
                                content: Text(
                                  'Domain Overridden: ${r.domain} allowed by ${_db.currentUser.displayName}.',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
                        label: const Text('ALLOW OVERRIDE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.verifiedGreen,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: _submitToQueue,
                      icon: const Icon(Icons.rate_review_rounded, size: 16),
                      label: const Text('SEND TO QUEUE'),
                    ),
                  ] else ...[
                    // Student Action
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _db.submitScanReport(
                          input: r.rawInput,
                          inputType: r.inputType,
                          score: r.score,
                          verdict: r.verdict,
                          features: r.features,
                          reasons: r.reasons,
                          autoBlockIfMalicious: false,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.verifiedGreen,
                              content: Text(
                                'Report Submitted! Campus IT SecOps will review this link.',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                      label: const Text('REPORT TO IT HEAD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyberCyan,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Plain Language Reasoning Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_rounded, color: AppColors.cyberCyan, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Plain-Language Detection Reasoning (IT Explanations)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...r.reasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: AppColors.cyberCyan, fontSize: 16)),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 16-Feature Inspector Table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '16-Feature Lexical Vector (Mendeley LegitPhish Grounded)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Direct Parity Extraction',
                      style: TextStyle(fontSize: 11, color: AppColors.cyberCyan),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: r.features.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.value % 1 != 0
                                ? e.value.toStringAsFixed(3)
                                : e.value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
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
    );
  }
}
