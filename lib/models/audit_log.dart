class AuditLogEntry {
  final String id;
  final String actorUid;
  final String actorRole;
  final String action; // "confirmed_block" | "allowed" | "manual_add" | "sync_vpn"
  final String targetDomain;
  final String details;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.actorUid,
    this.actorRole = 'it_head',
    required this.action,
    required this.targetDomain,
    this.details = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'actorUid': actorUid,
      'actorRole': actorRole,
      'action': action,
      'targetDomain': targetDomain,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLogEntry.fromMap(String id, Map<String, dynamic> map) {
    return AuditLogEntry(
      id: id,
      actorUid: map['actorUid'] as String? ?? 'unknown',
      actorRole: map['actorRole'] as String? ?? 'it_head',
      action: map['action'] as String? ?? '',
      targetDomain: map['targetDomain'] as String? ?? '',
      details: map['details'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
