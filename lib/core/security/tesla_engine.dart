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
  static const int maxPacketSize = 2048;

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
  TeslaDecision inspectParsedFrame(Frame frame, String senderHash) {
    // 1. Check Spoofing (Does the senderId match the network hash?)
    if (!_spoofGuard.verifyIdentity(frame.senderId, senderHash)) {
      debugPrint('TESLA: Spoofing detected! Frame senderId ${frame.senderId} does not match network hash $senderHash');
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

/// Validates raw packets for fundamental structural integrity before UTF-8 decoding.
class TeslaPacketValidator {
  bool isValidFormat(Uint8List packetBytes) {
    // Minimal heuristic: YamiLink frames start with "YML1:"
    if (packetBytes.length < 5) return false;
    
    if (packetBytes[0] != 89 || // Y
        packetBytes[1] != 77 || // M
        packetBytes[2] != 76 || // L
        packetBytes[3] != 49 || // 1
        packetBytes[4] != 58) { // :
      return false;
    }

    return true;
  }
}

/// Guards against identity reuse and spoofing by binding logical senderId to network senderHash.
class TeslaSpoofGuard {
  // Maps senderId -> senderHash
  final Map<String, String> _identityBindings = {};

  bool verifyIdentity(String senderId, String senderHash) {
    // In local broadcast without strong PKI on every packet, we bind the first
    // senderHash that claims an ID. If it changes, it's a suspicious identity takeover.
    // If senderId is "*", it's a broadcast recipient, but here we check senderId (the origin).
    
    if (senderId.isEmpty || senderHash.isEmpty) return false;

    if (_identityBindings.containsKey(senderId)) {
      if (_identityBindings[senderId] != senderHash) {
        // Identity collision! Someone is spoofing an existing senderId.
        return false;
      }
    } else {
      // First time seeing this senderId, bind it to this hash for the session
      _identityBindings[senderId] = senderHash;
      
      // Limit memory
      if (_identityBindings.length > 1000) {
        _identityBindings.remove(_identityBindings.keys.first);
      }
    }

    return true;
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
