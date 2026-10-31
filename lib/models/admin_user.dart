/// SignalSafe User Model
/// By default, all registered users are Students (isAdmin = false).
/// Flipping `isAdmin: true` in the database grants full IT Admin authority
/// to manually allow or block any domain, review triage queues, and sync VPN gateway policies.
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final bool isAdmin; // By default FALSE (Student). User flips this boolean in DB to make Admin!
  final DateTime createdAt;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isAdmin = false,
    required this.createdAt,
    this.photoUrl,
  });

  bool get isStudent => !isAdmin;
  String get role => isAdmin ? 'it_head' : 'student';

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? isAdmin,
    DateTime? createdAt,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'isAdmin': isAdmin,
      'createdAt': createdAt.toIso8601String(),
      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    // Check either explicit boolean `isAdmin` or role string
    final bool adminFlag = map['isAdmin'] == true ||
        map['role'] == 'admin' ||
        map['role'] == 'it_head';

    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Campus User',
      isAdmin: adminFlag,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      photoUrl: map['photoUrl'] as String?,
    );
  }
}

// Typedef alias for backwards compatibility
typedef AdminUser = AppUser;

class BlockEvent {
  final String id;
  final String domain;
  final String? clientIp;
  final String userAgent;
  final DateTime createdAt;

  BlockEvent({
    required this.id,
    required this.domain,
    this.clientIp,
    this.userAgent = 'Campus-WiFi Client',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'domain': domain,
      'clientIp': clientIp,
      'userAgent': userAgent,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BlockEvent.fromMap(String id, Map<String, dynamic> map) {
    return BlockEvent(
      id: id,
      domain: map['domain'] as String? ?? '',
      clientIp: map['clientIp'] as String?,
      userAgent: map['userAgent'] as String? ?? 'Campus-WiFi Client',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class DhcpClient {
  final String ip;
  final String mac;
  final String hostName;
  final String leaseTime;
  final bool isFlagged;

  DhcpClient({
    required this.ip,
    required this.mac,
    required this.hostName,
    required this.leaseTime,
    this.isFlagged = false,
  });
}
