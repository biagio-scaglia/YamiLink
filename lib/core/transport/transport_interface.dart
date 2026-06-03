import 'dart:typed_data';

abstract class DiscoveryTransport {
  void startDiscovery({
    required void Function(String nodeHash, String alias, int seed, double rssi) onPeerFound,
    required void Function(String nodeHash) onPeerLost,
  });
  void stopDiscovery();
  bool get isScanning;
}

abstract class MessageTransport {
  Future<bool> sendBroadcast(Uint8List packetBytes);
  Future<bool> sendDirect(String recipientHash, Uint8List packetBytes);
  void registerReceiveCallback(void Function(String senderHash, Uint8List packetBytes) onDataReceived);
  void clearReceiveCallback();
}
