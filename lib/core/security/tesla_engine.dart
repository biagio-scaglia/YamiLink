import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import '../protocol/frame.dart';

enum TeslaDecision {
  allow,
  drop,
  quarantine,
  rateLimit
}

/// TeslaEngine is the central orchestrator for Application-Level Protocol Defense.
/// It acts as a firewall between the raw FFI networking layer and the App State.
class TeslaEngine {
  static final TeslaEngine instance = TeslaEngine._();

  TeslaEngine._();

  final _packetValidator = TeslaPacketValidator();
  final _spoofGuard = TeslaSpoofGuard();
  final _replayGuard = TeslaReplayGuard();

  /// Maximum allowed payload size from FFI to prevent memory exhaustion and buffer bloat.
  static const int maxPacketSize = 4096;

  /// Inspects raw packet bytes before they are decoded or parsed.
  TeslaDecision inspectRawPacket(String senderHash, Uint8List packetBytes) {
    if (packetBytes.length > maxPacketSize) {
      debugPrint('TESLA: Dropped oversized packet (${packetBytes.length} bytes) from $senderHash');
      return TeslaDecision.drop;
    }

    if (!_packetValidator.isValidFormat(packetBytes)) {
      debugPrint('TESLA: Dropped malformed raw packet from $senderHash');
      return TeslaDecision.drop;
    }

    return TeslaDecision.allow;
  }

  /// Inspects a parsed Frame for logical spoofing and replay attacks.
  Future<TeslaDecision> inspectParsedFrame(Frame frame, String senderHash) async {
    // 1. Check Spoofing (Cryptographic verification)
    if (!await _spoofGuard.verifyIdentity(frame, senderHash)) {
      debugPrint('TESLA: Spoofing detected! Invalid signature for senderId ${frame.senderId}');
      return TeslaDecision.drop;
    }

    // 2. Check Replay (Is the message old or a duplicate?)
    if (!_replayGuard.isFreshAndUnique(frame.senderId, frame.messageId, frame.timestamp)) {
      // Replays are dropped silently in release to avoid log spam, but we log in debug
      if (kDebugMode) {
        debugPrint('TESLA: Replay detected for ${frame.senderId}:${frame.messageId}');
      }
      return TeslaDecision.drop;
    }

    return TeslaDecision.allow;
  }

  /// Purges old state for memory management
  void sweep() {
    _replayGuard.sweepOldEntries();
  }
}

/// Validates raw packets for fundamental structural integrity.
class TeslaPacketValidator {
  bool isValidFormat(Uint8List packetBytes) {
    // Minimal heuristic: YML2 binary frames start with version byte = 2
    if (packetBytes.isEmpty) return false;
    
    if (packetBytes[0] != 2) { 
      return false;
    }

    // Must at least have header size
    if (packetBytes.length < Frame.headerSize) {
      return false;
    }

    return true;
  }
}

/// Guards against identity reuse and spoofing by verifying Ed25519 PKI signatures.
class TeslaSpoofGuard {
  final Map<String, int> _violationCounts = {};

  Future<bool> verifyIdentity(Frame frame, String senderHash) async {
    final senderId = frame.senderId;
    if (senderId.isEmpty || frame.signature == null) return false;

    // Rate-limit check to prevent CPU exhaustion from bad signatures
    final violations = _violationCounts[senderHash] ?? 0;
    if (violations > 10) {
      return false; // Drop without verifying if this hash is spamming bad sigs
    }

    try {
      final pubKeyBytes = hex.decode(senderId);
      final signatureBytes = frame.signature!;

      final ed25519 = Ed25519();
      final pubKey = SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519);
      final sig = Signature(signatureBytes.toList(), publicKey: pubKey);

      final isValid = await ed25519.verify(
        frame.signableBytes,
        signature: sig,
      );

      if (!isValid) {
        _violationCounts[senderHash] = violations + 1;
      }
      return isValid;
    } catch (e) {
      _violationCounts[senderHash] = violations + 1;
      return false;
    }
  }
}

/// Guards against Replay Attacks using a sliding window and deduplication cache.
class TeslaReplayGuard {
  // Maps senderId:messageId -> timestamp
  final Map<String, int> _seenMessages = {};
  
  // Max age of a packet to be considered valid (e.g., 60 seconds)
  static const int maxAgeMs = 60000;

  bool isFreshAndUnique(String senderId, int messageId, int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 1. Time-based Replay Check
    // If the packet timestamp is too far in the past or the future, drop it.
    if (now - timestamp > maxAgeMs || timestamp > now + 5000) {
      return false; // Stale or from the future
    }

    // 2. Exact Duplicate Check
    final key = '$senderId:$messageId';
    if (_seenMessages.containsKey(key)) {
      return false; // Already seen and processed
    }

    _seenMessages[key] = timestamp;
    return true;
  }

  void sweepOldEntries() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _seenMessages.removeWhere((key, timestamp) => now - timestamp > maxAgeMs);
  }
}
