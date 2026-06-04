import 'dart:typed_data';

class YamiLinkFfiBridge {
  static final YamiLinkFfiBridge instance = YamiLinkFfiBridge._();
  YamiLinkFfiBridge._();

  bool get isSupported => false;

  void Function(
    int eventType,
    String senderHash,
    String senderAlias,
    int seed,
    Uint8List payload,
    double signal,
  )?
  onEvent;

  void load() {}

  int start(String alias, int seed) {
    return -1;
  }

  int send(Uint8List data) {
    return -1;
  }

  int stop() {
    return -1;
  }
}

class YML2PacketFFI {}
