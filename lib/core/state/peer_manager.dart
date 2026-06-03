import '../../models.dart';

class PeerManager {
  final List<Peer> _peers = [];
  final void Function() _onChanged;

  // Track blocked peer IDs so they remain blocked even if they are swept
  final Set<String> _blockedPeerIds = {};

  // Track message timestamps for burst spam detection (sliding window)
  final Map<String, List<DateTime>> _msgTimestamps = {};

  PeerManager({required void Function() onChanged}) : _onChanged = onChanged;

  List<Peer> get peers => List.unmodifiable(_peers);

  void handlePeerFound({
    required String id,
    required String alias,
    required int seed,
    required double signal,
  }) {
    final index = _peers.indexWhere((p) => p.id == id);
    final now = DateTime.now();

    // Map signal strength (0.0 to 1.0) to proximity hint
    ProximityHint hint;
    if (signal > 0.8) {
      hint = ProximityHint.immediate;
    } else if (signal > 0.4) {
      hint = ProximityHint.near;
    } else {
      hint = ProximityHint.far;
    }

    final isBlockedPeer = _blockedPeerIds.contains(id);

    if (index == -1) {
      _peers.add(
        Peer(
          id: id,
          alias: alias,
          avatarSeed: seed,
          proximityHint: hint,
          relayCapability: true,
          lastSeen: now,
          trustLevel: isBlockedPeer ? TrustLevel.blocked : TrustLevel.unverified,
        ),
      );
    } else {
      _peers[index] = _peers[index].copyWith(
        alias: alias,
        avatarSeed: seed,
        proximityHint: hint,
        lastSeen: now,
        trustLevel: isBlockedPeer ? TrustLevel.blocked : _peers[index].trustLevel,
      );
    }
    _onChanged();
  }

  void handlePeerLost(String id) {
    _peers.removeWhere((p) => p.id == id);
    _onChanged();
  }

  void toggleTrust(String peerId) {
    final index = _peers.indexWhere((p) => p.id == peerId);
    if (index != -1) {
      final currentTrust = _peers[index].trustLevel;
      _peers[index].trustLevel = currentTrust == TrustLevel.paired
          ? TrustLevel.unverified
          : TrustLevel.paired;
      _onChanged();
    }
  }

  bool isBlocked(String peerId) {
    return _blockedPeerIds.contains(peerId);
  }

  void blockPeer(String peerId) {
    _blockedPeerIds.add(peerId);
    final index = _peers.indexWhere((p) => p.id == peerId);
    if (index != -1) {
      _peers[index].trustLevel = TrustLevel.blocked;
    }
    _onChanged();
  }

  void unblockPeer(String peerId) {
    _blockedPeerIds.remove(peerId);
    _msgTimestamps.remove(peerId);
    final index = _peers.indexWhere((p) => p.id == peerId);
    if (index != -1) {
      // Revert to unverified when unblocked
      _peers[index].trustLevel = TrustLevel.unverified;
    }
    _onChanged();
  }

  bool registerMessageAndCheckSpam(String peerId) {
    if (isBlocked(peerId)) {
      return true;
    }
    final now = DateTime.now();
    final timestamps = _msgTimestamps.putIfAbsent(peerId, () => []);
    timestamps.add(now);
    // Keep only timestamps within last 3 seconds
    timestamps.removeWhere((t) => now.difference(t).inSeconds > 3);

    if (timestamps.length > 5) {
      blockPeer(peerId);
      return true;
    }
    return false;
  }

  /// Sweeps stale peers.
  /// If no packet or beacon from peer for > 10 seconds, mark as stale (we can update a hint or keep track of last seen).
  /// If stale for > 15 seconds, remove from the list.
  void sweepStalePeers() {
    final now = DateTime.now();
    bool changed = false;

    for (int i = _peers.length - 1; i >= 0; i--) {
      final peer = _peers[i];
      final difference = now.difference(peer.lastSeen).inSeconds;

      if (difference >= 15) {
        _peers.removeAt(i);
        changed = true;
      } else if (difference >= 10 &&
          peer.proximityHint != ProximityHint.unknown) {
        // Mark as unknown/stale proximity
        _peers[i] = peer.copyWith(proximityHint: ProximityHint.unknown);
        changed = true;
      }
    }

    if (changed) {
      _onChanged();
    }
  }

  void clear() {
    _peers.clear();
    _blockedPeerIds.clear();
    _msgTimestamps.clear();
    _onChanged();
  }
}
