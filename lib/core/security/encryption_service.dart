import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/api.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  /// Generates a new secure RSA key pair.
  /// Returns a Map containing the PEM-encoded keys: {'publicKey': '...', 'privateKey': '...'}
  Map<String, String> generateKeyPair() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));

    final keyGen = RSAKeyGenerator();
    keyGen.init(pc.ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 1024, 64),
      secureRandom,
    ));

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    final encrypter = enc.Encrypter(enc.RSA(
      publicKey: publicKey,
      privateKey: privateKey,
    ));

    // For ease of transport and storage, we will serialize the modulus and exponents
    final pubKeyString = '${publicKey.modulus}:${publicKey.exponent}';
    final privKeyString = '${privateKey.modulus}:${privateKey.privateExponent}:${privateKey.p}:${privateKey.q}';

    return {
      'publicKey': base64Encode(utf8.encode(pubKeyString)),
      'privateKey': base64Encode(utf8.encode(privKeyString)),
    };
  }

  /// Parses public key from transport string
  RSAPublicKey _parsePublicKey(String keyBase64) {
    final decoded = utf8.decode(base64Decode(keyBase64));
    final parts = decoded.split(':');
    final modulus = BigInt.parse(parts[0]);
    final exponent = BigInt.parse(parts[1]);
    return RSAPublicKey(modulus, exponent);
  }

  /// Parses private key from transport string
  RSAPrivateKey _parsePrivateKey(String keyBase64) {
    final decoded = utf8.decode(base64Decode(keyBase64));
    final parts = decoded.split(':');
    final modulus = BigInt.parse(parts[0]);
    final privateExponent = BigInt.parse(parts[1]);
    final p = BigInt.parse(parts[2]);
    final q = BigInt.parse(parts[3]);
    return RSAPrivateKey(modulus, privateExponent, p, q);
  }

  /// Encrypts text using RSA Public Key
  String encryptWithPublicKey(String plainText, String publicKeyBase64) {
    if (publicKeyBase64.startsWith('mock_')) {
      return plainText; // Bypass encryption for simulator nodes
    }
    try {
      final publicKey = _parsePublicKey(publicKeyBase64);
      final encrypter = enc.Encrypter(enc.RSA(publicKey: publicKey));
      final encrypted = encrypter.encrypt(plainText);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      return plainText; // Fallback or handle error
    }
  }

  /// Decrypts text using RSA Private Key
  String decryptWithPrivateKey(String cipherText, String privateKeyBase64) {
    if (privateKeyBase64.startsWith('mock_')) {
      return cipherText; // Bypass decryption for simulator nodes
    }
    try {
      final privateKey = _parsePrivateKey(privateKeyBase64);
      final encrypter = enc.Encrypter(enc.RSA(privateKey: privateKey));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(cipherText));
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      return cipherText;
    }
  }

  /// Generates a random AES key string (256-bit)
  String generateSymmetricKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(values);
  }

  /// Encrypts message content symmetrically using AES-256
  String encryptSymmetric(String plainText, String keyBase64) {
    try {
      final keyBytes = base64Decode(keyBase64);
      final key = enc.Key(keyBytes);
      final iv = enc.IV(Uint8List(16)); // Zero IV for deterministic padding with one-time keys
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return encrypted.base64;
    } catch (e) {
      print('Symmetric encryption error: $e');
      return plainText;
    }
  }

  /// Decrypts message content symmetrically using AES-256
  String decryptSymmetric(String cipherText, String keyBase64) {
    try {
      final keyBytes = base64Decode(keyBase64);
      final key = enc.Key(keyBytes);
      final iv = enc.IV(Uint8List(16));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(cipherText), iv: iv);
      return decrypted;
    } catch (e) {
      print('Symmetric decryption error: $e');
      return cipherText;
    }
  }

  /// Computes a hash of text (e.g. for message verification or device signatures)
  String sha256Hash(String text) {
    final bytes = utf8.encode(text);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
