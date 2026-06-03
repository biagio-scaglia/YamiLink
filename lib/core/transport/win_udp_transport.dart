import 'dart:typed_data';
import '../../ffi_bridge.dart';
import 'transport_interface.dart';

class WinUdpTransport implements DiscoveryTransport, MessageTransport {
  void Function(String nodeHash, String alias, int seed, double rssi)?
  _onPeerFound;
  void Function(String senderHash, Uint8List packetBytes)? _onDataReceived;
  bool _isScanning = false;

  WinUdpTransport() {
    YamiLinkFfiBridge.instance.onEvent = _handleFfiEvent;
  }

  @override
  bool get isScanning => _isScanning;

  @override
  void startDiscovery({
    required void Function(String nodeHash, String alias, int seed, double rssi)
    onPeerFound,
    required void Function(String nodeHash) onPeerLost,
  }) {
    _onPeerFound = onPeerFound;
    _isScanning = true;
  }

  @override
  void stopDiscovery() {
    _isScanning = false;
    _onPeerFound = null;
  }

  @override
  Future<bool> sendBroadcast(Uint8List packetBytes) async {
    final res = YamiLinkFfiBridge.instance.send(null, packetBytes);
    return res == 0;
  }

  @override
  Future<bool> sendDirect(String recipientHash, Uint8List packetBytes) async {
    final res = YamiLinkFfiBridge.instance.send(recipientHash, packetBytes);
    return res == 0;
  }

  @override
  void registerReceiveCallback(
    void Function(String senderHash, Uint8List packetBytes) onDataReceived,
  ) {
    _onDataReceived = onDataReceived;
  }

  @override
  void clearReceiveCallback() {
    _onDataReceived = null;
  }

  void _handleFfiEvent(
    int eventType,
    String senderHash,
    String senderAlias,
    int seed,
    Uint8List payload,
    double signal,
  ) {
    if (!_isScanning) return;

    if (eventType == 0) {
      _onPeerFound?.call(senderHash, senderAlias, seed, signal);
    } else if (eventType == 1) {
      _onDataReceived?.call(senderHash, payload);
    }
  }
}
