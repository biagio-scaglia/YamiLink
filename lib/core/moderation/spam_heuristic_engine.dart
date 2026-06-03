class SpamHeuristicEngine {
  static final SpamHeuristicEngine instance = SpamHeuristicEngine._();
  SpamHeuristicEngine._();

  // Sliding window message timestamps per peer
  final Map<String, List<DateTime>> _msgTimestamps = {};

  // History of the last 10 normalized messages per peer for duplicate checking
  final Map<String, List<String>> _messageHistory = {};

  /// Checks if a peer is flooding (> 5 messages in 3 seconds).
  /// Returns true if flooding is detected.
  bool checkFlood(String peerId) {
    final now = DateTime.now();
    final timestamps = _msgTimestamps.putIfAbsent(peerId, () => []);
    timestamps.add(now);

    // Keep only timestamps within last 3 seconds
    timestamps.removeWhere((t) => now.difference(t).inSeconds > 3);

    return timestamps.length > 5;
  }

  /// Checks if a peer is sending duplicate messages sequentially.
  /// If the exact same normalized text is repeated 3 times sequentially, returns true.
  bool checkDuplicate(String peerId, String normalizedText) {
    if (normalizedText.trim().isEmpty) return false;

    final history = _messageHistory.putIfAbsent(peerId, () => []);
    history.add(normalizedText);

    // Keep only the last 10 messages for each peer
    if (history.length > 10) {
      history.removeAt(0);
    }

    // Check if the last 3 messages are identical
    if (history.length >= 3) {
      final len = history.length;
      if (history[len - 1] == history[len - 2] &&
          history[len - 2] == history[len - 3]) {
        return true;
      }
    }
    return false;
  }

  /// Clears tracked states for a peer.
  void clearPeer(String peerId) {
    _msgTimestamps.remove(peerId);
    _messageHistory.remove(peerId);
  }

  /// Clears all tracked states.
  void clear() {
    _msgTimestamps.clear();
    _messageHistory.clear();
  }
}
