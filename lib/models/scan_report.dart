class ScanReport {
  final String id;
  final String input; // URL or decoded QR content
  final String inputType; // "url" | "qr"
  final double score; // 0.0 - 1.0
  final String verdict; // "malicious" | "suspicious" | "clean"
  final String? reviewedBy; // uid or null
  final String reviewDecision; // "pending" | "confirmed_block" | "allowed"
  final String? lastAuditId;
  final DateTime createdAt;
  final Map<String, double> features;
  final List<String> reasons;

  ScanReport({
    required this.id,
    required this.input,
    required this.inputType,
    required this.score,
    required this.verdict,
    this.reviewedBy,
    required this.reviewDecision,
    this.lastAuditId,
    required this.createdAt,
    required this.features,
    required this.reasons,
  });

  bool get isPending => reviewDecision == 'pending';
  bool get isBlocked => reviewDecision == 'confirmed_block';
  bool get isAllowed => reviewDecision == 'allowed';

  String get domain {
    final clean = input.trim();
    final full = clean.contains('://') ? clean : 'http://$clean';
    try {
      final uri = Uri.parse(full);
      final host = uri.host.split(':').first;
      return host.isNotEmpty ? host : clean;
    } catch (_) {
      return clean;
    }
  }

  ScanReport copyWith({
    String? id,
    String? input,
    String? inputType,
    double? score,
    String? verdict,
    String? reviewedBy,
    String? reviewDecision,
    String? lastAuditId,
    DateTime? createdAt,
    Map<String, double>? features,
    List<String>? reasons,
  }) {
    return ScanReport(
      id: id ?? this.id,
      input: input ?? this.input,
      inputType: inputType ?? this.inputType,
      score: score ?? this.score,
      verdict: verdict ?? this.verdict,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewDecision: reviewDecision ?? this.reviewDecision,
      lastAuditId: lastAuditId ?? this.lastAuditId,
      createdAt: createdAt ?? this.createdAt,
      features: features ?? this.features,
      reasons: reasons ?? this.reasons,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'input': input,
      'inputType': inputType,
      'score': score,
      'verdict': verdict,
      'reviewedBy': reviewedBy,
      'reviewDecision': reviewDecision,
      'lastAuditId': lastAuditId,
      'createdAt': createdAt.toIso8601String(),
      'features': features,
      'reasons': reasons,
    };
  }

  factory ScanReport.fromMap(String id, Map<String, dynamic> map) {
    return ScanReport(
      id: id,
      input: map['input'] as String? ?? '',
      inputType: map['inputType'] as String? ?? 'url',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      verdict: map['verdict'] as String? ?? 'clean',
      reviewedBy: map['reviewedBy'] as String?,
      reviewDecision: map['reviewDecision'] as String? ?? 'pending',
      lastAuditId: map['lastAuditId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      features: (map['features'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      reasons: (map['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
