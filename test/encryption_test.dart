import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/core/security/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    final service = EncryptionService();

    test('Symmetric Encryption/Decryption', () {
      final key = service.generateSymmetricKey();
      const plainText = "Hello OfflineMesh Chat! This is a secret message.";

      final cipherText = service.encryptSymmetric(plainText, key);
      expect(cipherText, isNot(equals(plainText)));

      final decryptedText = service.decryptSymmetric(cipherText, key);
      expect(decryptedText, equals(plainText));
    });

    test('Asymmetric RSA Encryption/Decryption', () {
      final pair = service.generateKeyPair();
      final pubKey = pair['publicKey']!;
      final privKey = pair['privateKey']!;
      const plainText = "RSA Securing Handshake";

      final cipherText = service.encryptWithPublicKey(plainText, pubKey);
      expect(cipherText, isNot(equals(plainText)));

      final decryptedText = service.decryptWithPrivateKey(cipherText, privKey);
      expect(decryptedText, equals(plainText));
    });
  });
}
