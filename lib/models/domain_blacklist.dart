class DomainBlacklistEntry {
  final String id;
  final String domain;
  final double score;
  final Map<String, double> reasonFeatures;
  final List<String> reasons;
  final String source; // "auto" | "manual_block"
  final String status; // "active" | "overridden_allow"
  final DateTime firstSeen;

  DomainBlacklistEntry({
    required this.id,
    required this.domain,
    required this.score,
    required this.reasonFeatures,
    required this.reasons,
    required this.source,
    required this.status,
    required this.firstSeen,
  });

  bool get isActive => status == 'active';

  DomainBlacklistEntry copyWith({
    String? id,
    String? domain,
    double? score,
    Map<String, double>? reasonFeatures,
    List<String>? reasons,
    String? source,
    String? status,
    DateTime? firstSeen,
  }) {
    return DomainBlacklistEntry(
      id: id ?? this.id,
      domain: domain ?? this.domain,
      score: score ?? this.score,
      reasonFeatures: reasonFeatures ?? this.reasonFeatures,
      reasons: reasons ?? this.reasons,
      source: source ?? this.source,
      status: status ?? this.status,
      firstSeen: firstSeen ?? this.firstSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'domain': domain,
      'score': score,
      'reasonFeatures': reasonFeatures,
      'reasons': reasons,
      'source': source,
      'status': status,
      'firstSeen': firstSeen.toIso8601String(),
    };
  }

  factory DomainBlacklistEntry.fromMap(String id, Map<String, dynamic> map) {
    return DomainBlacklistEntry(
      id: id,
      domain: map['domain'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      reasonFeatures: (map['reasonFeatures'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      reasons: (map['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      source: map['source'] as String? ?? 'auto',
      status: map['status'] as String? ?? 'active',
      firstSeen: map['firstSeen'] != null
          ? DateTime.tryParse(map['firstSeen'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
