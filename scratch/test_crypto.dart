import 'dart:convert';
import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final _aesGcm = AesGcm.with256bits();
  final sharedKey = await _aesGcm.newSecretKey();
  
  final clearBytes = utf8.encode('Hello');
  final nonce = _aesGcm.newNonce();
  final secretBox = await _aesGcm.encrypt(
    clearBytes,
    secretKey: sharedKey,
    nonce: nonce,
  );
  
  final encryptedBytes = <int>[...nonce, ...secretBox.cipherText, ...secretBox.mac.bytes];
  
  try {
    final iv = encryptedBytes.sublist(0, 12);
    final cipherText = encryptedBytes.sublist(12);
    final box = SecretBox(cipherText, nonce: iv, mac: Mac.empty);
    final decrypted = await _aesGcm.decrypt(box, secretKey: sharedKey);
    print(utf8.decode(decrypted));
  } catch (e) {
    print('Failed with Mac.empty: $e');
  }

  try {
    final iv = encryptedBytes.sublist(0, 12);
    final macLength = 16;
    final cipherText = encryptedBytes.sublist(12, encryptedBytes.length - macLength);
    final macBytes = encryptedBytes.sublist(encryptedBytes.length - macLength);
    
    final box = SecretBox(cipherText, nonce: iv, mac: Mac(macBytes));
    final decrypted = await _aesGcm.decrypt(box, secretKey: sharedKey);
    print('Success with proper Mac: ${utf8.decode(decrypted)}');
  } catch (e) {
    print('Failed with proper Mac: $e');
  }
}
