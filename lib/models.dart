import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';

enum TrustLevel { unverified, paired, blocked }

enum ProximityHint { immediate, near, far, unknown }

enum MessageStatus { sending, delivered, failed }

class EphemeralProfile {
  final String id;
  final String alias;
  final int avatarSeed;
  final DateTime createdAt;
  final SimpleKeyPair? identityKeyPair;

  EphemeralProfile({
    required this.id,
    required this.alias,
    required this.avatarSeed,
    required this.createdAt,
    this.identityKeyPair,
  });

  static Future<EphemeralProfile> generate(String alias) async {
    final random = Random();
    
    // Generate Ed25519 KeyPair for PKI identity
    final ed25519 = Ed25519();
    final keyPair = await ed25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final id = hex.encode(publicKey.bytes);

    return EphemeralProfile(
      id: id,
      alias: alias,
      avatarSeed: random.nextInt(1000000),
      createdAt: DateTime.now(),
      identityKeyPair: keyPair,
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
  final String? recipientId;
  final String content;
  final DateTime timestamp;
  MessageStatus status;
  final int hopCount;
  bool isFlagged;
  bool isBlurred;
  String? moderationExplanation;

  Message({
    required this.id,
    required this.senderId,
    required this.senderAlias,
    this.recipientId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sending,
    this.hopCount = 1,
    this.isFlagged = false,
    this.isBlurred = false,
    this.moderationExplanation,
  });
}

class Session {
  final String id;
  final String name;
  final DateTime joinedAt;

  Session({required this.id, required this.name, required this.joinedAt});
}

class Conversation {
  final String id;
  final String peerId;
  final String peerAlias;
  final int peerAvatarSeed;
  String lastMessage;
  DateTime lastTimestamp;
  int unreadCount;
  final List<Message> messages;
  bool isPeerOnline;

  Conversation({
    required this.id,
    required this.peerId,
    required this.peerAlias,
    required this.peerAvatarSeed,
    required this.lastMessage,
    required this.lastTimestamp,
    this.unreadCount = 0,
    required this.messages,
    this.isPeerOnline = true,
  });
}
