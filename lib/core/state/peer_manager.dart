import '../../models.dart';

class PeerManager {
  final List<Peer> _peers = [];
  final void Function() _onChanged;

  final Set<String> _blockedPeerIds = {};
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
    _peers.removeWhere((p) => p.id == id);
    _onChanged();
  }

  bool isBlocked(String peerId) {
    return _blockedPeerIds.contains(peerId);
  }

  void blockPeer(String peerId) {
    _blockedPeerIds.add(peerId);
    _onChanged();
  }

  void unblockPeer(String peerId) {
    _blockedPeerIds.remove(peerId);
    _msgTimestamps.remove(peerId);
    _onChanged();
  }

  bool registerMessageAndCheckSpam(String peerId) {
    if (isBlocked(peerId)) {
      return true;
    }
    final now = DateTime.now();
    final timestamps = _msgTimestamps.putIfAbsent(peerId, () => []);
    timestamps.add(now);

    timestamps.removeWhere((t) => now.difference(t).inSeconds > 3);

    if (timestamps.length > 5) {
      blockPeer(peerId);
      return true;
    }
    return false;
  }

  /// Sweeps stale peers.
  /// If no packet or beacon from peer for > 10 seconds, mark as stale.
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
