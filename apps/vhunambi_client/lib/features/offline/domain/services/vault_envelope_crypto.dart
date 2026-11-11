import 'dart:math';
import 'dart:typed_data';

import 'package:vhunambi_client/core/storage/hive_aes_vault_cipher.dart';

/// Cryptographic engine implementing the Vhunambi Encrypted Media (.vmf) format.
///
/// Features a self-contained pure-Dart CTR stream cipher with SHA-256 block derivation:
/// - Magic header: Exactly 4 bytes `0x56, 0x48, 0x55, 0x4E` ("VHUN")
/// - Version: 2 bytes `0x0001`
/// - IV / Nonce: 16 cryptographically random bytes
/// - Payload size: 8 bytes big-endian unsigned integer
/// - Payload: Stream-cipher encrypted audio with arbitrary seekable slice decryption
class VaultEnvelopeCrypto {
  static const List<int> magicBytes = <int>[0x56, 0x48, 0x55, 0x4E]; // "VHUN"
  static const int version = 0x0001;
  static const int headerSize = 30; // 4 + 2 + 16 + 8

  final Uint8List _key;

  VaultEnvelopeCrypto({Uint8List? key}) : _key = key ?? _deriveDefaultKey();

  static Uint8List _deriveDefaultKey() {
    return HiveAesVaultCipher.derive256BitKey();
  }

  /// Encapsulates raw audio bytes into an encrypted .vmf envelope.
  Uint8List encryptToEnvelope(Uint8List rawAudio) {
    final iv = Uint8List(16);
    final secureRandom = Random.secure();
    for (int i = 0; i < 16; i++) {
      iv[i] = secureRandom.nextInt(256);
    }

    final ciphertext = _applyCtrStream(rawAudio, iv, _key, 0);

    final header = ByteData(headerSize);
    for (int i = 0; i < 4; i++) {
      header.setUint8(i, magicBytes[i]);
    }
    header.setUint16(4, version, Endian.big);
    for (int i = 0; i < 16; i++) {
      header.setUint8(6 + i, iv[i]);
    }
    header.setUint64(22, rawAudio.length, Endian.big);

    final result = Uint8List(headerSize + ciphertext.length);
    result.setRange(0, headerSize, header.buffer.asUint8List());
    result.setRange(headerSize, result.length, ciphertext);
    return result;
  }

  /// Decrypts raw audio bytes from a .vmf envelope.
  Uint8List decryptFromEnvelope(Uint8List envelope) {
    if (envelope.length < headerSize) {
      throw const FormatException(
        'Invalid envelope: length smaller than header',
      );
    }

    for (int i = 0; i < 4; i++) {
      if (envelope[i] != magicBytes[i]) {
        throw const FormatException('Invalid envelope: magic header mismatch');
      }
    }

    final byteData = ByteData.sublistView(envelope, 0, headerSize);
    final parsedVersion = byteData.getUint16(4, Endian.big);
    if (parsedVersion != version) {
      throw FormatException('Unsupported envelope version: $parsedVersion');
    }

    final iv = envelope.sublist(6, 22);
    final payloadSize = byteData.getUint64(22, Endian.big);
    final ciphertext = envelope.sublist(headerSize);

    final plaintext = _applyCtrStream(ciphertext, iv, _key, 0);
    return plaintext.sublist(0, min(payloadSize, plaintext.length));
  }

  /// Decrypts an arbitrary slice $[start, end)$ from an envelope without full-file decryption.
  Uint8List decryptSlice(Uint8List envelope, int start, int end) {
    if (envelope.length < headerSize) {
      throw const FormatException(
        'Invalid envelope: length smaller than header',
      );
    }

    final iv = envelope.sublist(6, 22);
    final byteData = ByteData.sublistView(envelope, 0, headerSize);
    final payloadSize = byteData.getUint64(22, Endian.big);

    final clampedStart = start.clamp(0, payloadSize);
    final clampedEnd = end.clamp(clampedStart, payloadSize);
    final sliceLen = clampedEnd - clampedStart;
    if (sliceLen <= 0) return Uint8List(0);

    final ciphertextSlice = envelope.sublist(
      headerSize + clampedStart,
      headerSize + clampedEnd,
    );

    return _applyCtrStream(ciphertextSlice, iv, _key, clampedStart);
  }

  /// CTR stream XOR processing with byte offset support.
  static Uint8List _applyCtrStream(
    Uint8List input,
    Uint8List iv,
    Uint8List key,
    int byteOffset,
  ) {
    final output = Uint8List(input.length);
    const blockSize = 32; // SHA-256 yields 32 bytes per block

    int initialBlock = byteOffset ~/ blockSize;
    int blockRemainder = byteOffset % blockSize;

    final blockCounter = Uint8List(16 + 4);
    blockCounter.setRange(0, 16, iv);

    int processed = 0;
    int currentBlockIndex = initialBlock;

    while (processed < input.length) {
      // Set 32-bit big-endian counter into blockCounter[16..19]
      blockCounter[16] = (currentBlockIndex >> 24) & 0xFF;
      blockCounter[17] = (currentBlockIndex >> 16) & 0xFF;
      blockCounter[18] = (currentBlockIndex >> 8) & 0xFF;
      blockCounter[19] = currentBlockIndex & 0xFF;

      // Generate 32-byte pseudorandom keystream block via SHA-256(key + counter)
      final inputBytes = Uint8List(key.length + blockCounter.length);
      inputBytes.setRange(0, key.length, key);
      inputBytes.setRange(key.length, inputBytes.length, blockCounter);
      final keystream = sha256Bytes(inputBytes);

      final startInKeystream = (processed == 0) ? blockRemainder : 0;
      final bytesToTake = min(
        blockSize - startInKeystream,
        input.length - processed,
      );

      for (int i = 0; i < bytesToTake; i++) {
        output[processed + i] =
            input[processed + i] ^ keystream[startInKeystream + i];
      }

      processed += bytesToTake;
      currentBlockIndex++;
    }

    return output;
  }

  /// Pure Dart SHA-256 implementation (FIPS 180-4).
  static Uint8List sha256Bytes(Uint8List data) {
    final h = <int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];

    const k = <int>[
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];

    final bitLen = data.length * 8;
    final padLen = (data.length % 64 < 56)
        ? (56 - data.length % 64)
        : (120 - data.length % 64);
    final padded = Uint8List(data.length + padLen + 8);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    final bd = ByteData.view(padded.buffer);
    bd.setUint64(padded.length - 8, bitLen, Endian.big);

    final w = List<int>.filled(64, 0);

    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = bd.getUint32(chunk + i * 4, Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        final s0 =
            _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 =
            _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h[0], b = h[1], c = h[2], d = h[3];
      int e = h[4], f = h[5], g = h[6], hVal = h[7];

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (hVal + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        hVal = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h[0] = (h[0] + a) & 0xFFFFFFFF;
      h[1] = (h[1] + b) & 0xFFFFFFFF;
      h[2] = (h[2] + c) & 0xFFFFFFFF;
      h[3] = (h[3] + d) & 0xFFFFFFFF;
      h[4] = (h[4] + e) & 0xFFFFFFFF;
      h[5] = (h[5] + f) & 0xFFFFFFFF;
      h[6] = (h[6] + g) & 0xFFFFFFFF;
      h[7] = (h[7] + hVal) & 0xFFFFFFFF;
    }

    final out = Uint8List(32);
    final outBd = ByteData.view(out.buffer);
    for (int i = 0; i < 8; i++) {
      outBd.setUint32(i * 4, h[i], Endian.big);
    }
    return out;
  }

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;
}
