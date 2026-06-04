import 'dart:convert';
import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final x25519 = X25519();
  final aliceKp = await x25519.newKeyPair();
  final bobKp = await x25519.newKeyPair();

  final alicePk = await aliceKp.extractPublicKey();
  final bobPk = await bobKp.extractPublicKey();

  print("Alice PK length: ${alicePk.bytes.length}");

  try {
    final remotePk = SimplePublicKey(alicePk.bytes, type: KeyPairType.x25519);
    final sharedSecret = await x25519.sharedSecretKey(
      keyPair: bobKp,
      remotePublicKey: remotePk,
    );
    final sharedBytes = await sharedSecret.extractBytes();
    print("Shared secret length: ${sharedBytes.length}");
  } catch (e) {
    print("Error: $e");
  }
}
