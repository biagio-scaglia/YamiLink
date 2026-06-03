import '../../models.dart';

class PeerManager {
  final List<Peer> _peers = [];
  final void Function() _onChanged;

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

    if (index == -1) {
      _peers.add(
        Peer(
          id: id,
          alias: alias,
          avatarSeed: seed,
          proximityHint: hint,
          relayCapability: true,
          lastSeen: now,
          trustLevel: TrustLevel.unverified,
        ),
      );
    } else {
      _peers[index] = _peers[index].copyWith(
        alias: alias,
        avatarSeed: seed,
        proximityHint: hint,
        lastSeen: now,
      );
    }
    _onChanged();
  }

  void handlePeerLost(String id) {
    final removed = _peers.removeWhere((p) => p.id == id);
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
    _onChanged();
  }
}
