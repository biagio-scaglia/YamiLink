import 'dart:math';

enum TrustLevel {
  unverified,
  paired,
  blocked,
}

enum ProximityHint {
  immediate, // 0-3m
  near,      // 3-10m
  far,       // 10-30m
  unknown,
}

enum MessageStatus {
  sending,
  delivered,
  failed,
}

class EphemeralProfile {
  final String id;
  final String alias;
  final int avatarSeed;
  final DateTime createdAt;

  EphemeralProfile({
    required this.id,
    required this.alias,
    required this.avatarSeed,
    required this.createdAt,
  });

  factory EphemeralProfile.generate(String alias) {
    final random = Random();
    final id = List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    return EphemeralProfile(
      id: id,
      alias: alias,
      avatarSeed: random.nextInt(1000000),
      createdAt: DateTime.now(),
    );
  }
}

class Peer {
  final String id;
  final String alias;
  final int avatarSeed;
  TrustLevel trustLevel;
  ProximityHint proximityHint;
  final bool relayCapability;
  DateTime lastSeen;

  Peer({
    required this.id,
    required this.alias,
    required this.avatarSeed,
    this.trustLevel = TrustLevel.unverified,
    this.proximityHint = ProximityHint.unknown,
    this.relayCapability = false,
    required this.lastSeen,
  });

  Peer copyWith({
    String? alias,
    int? avatarSeed,
    TrustLevel? trustLevel,
    ProximityHint? proximityHint,
    bool? relayCapability,
    DateTime? lastSeen,
  }) {
    return Peer(
      id: id,
      alias: alias ?? this.alias,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      trustLevel: trustLevel ?? this.trustLevel,
      proximityHint: proximityHint ?? this.proximityHint,
      relayCapability: relayCapability ?? this.relayCapability,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String senderAlias;
  final String? recipientId; // null means local broadcast (room chat)
  final String content;
  final DateTime timestamp;
  MessageStatus status;
  final int hopCount;

  Message({
    required this.id,
    required this.senderId,
    required this.senderAlias,
    this.recipientId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.hopCount = 1,
  });
}

class Session {
  final String id;
  final String name;
  final DateTime joinedAt;

  Session({
    required this.id,
    required this.name,
    required this.joinedAt,
  });
}
