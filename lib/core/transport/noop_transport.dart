import 'dart:typed_data';
import 'transport_interface.dart';

/// A No-Op transport used as a structural fallback when the native 
/// FFI bridge is unsupported on the current platform (e.g. Android right now).
/// This prevents crashes and gracefully degrades to an empty "zero peers" state 
/// instead of using fake simulator data.
class NoOpTransport implements DiscoveryTransport, MessageTransport {
  bool _isScanning = false;

  @override
  bool get isScanning => _isScanning;

  @override
  void startDiscovery({
    required void Function(String nodeHash, String alias, int seed, double rssi) onPeerFound,
    required void Function(String nodeHash) onPeerLost,
  }) {
    _isScanning = true;
    // No-op: non produce peer finti
  }

  @override
  void stopDiscovery() {
    _isScanning = false;
  }

  @override
  Future<bool> sendBroadcast(Uint8List packetBytes) async {
    return true; // Silent success
  }

  @override
  Future<bool> sendDirect(String recipientHash, Uint8List packetBytes) async {
    return true; // Silent success
  }

  @override
  void registerReceiveCallback(
    void Function(String senderHash, Uint8List packetBytes) onDataReceived,
  ) {
    // No-op: won't ever receive data
  }

  @override
  void clearReceiveCallback() {
    // No-op
  }
}
