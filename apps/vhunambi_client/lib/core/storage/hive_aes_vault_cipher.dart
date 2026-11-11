import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/features/offline/domain/services/vault_envelope_crypto.dart';

/// Deterministic RFC 5869 HKDF-SHA256 256-bit key derivation for Sovereign Hive
/// AES-256 at-rest encryption and `.vmf` vault envelopes (`REQ-P60-UPG-02`, `Phase 61`).
class HiveAesVaultCipher {
  HiveAesVaultCipher._();

  static const String deviceGenesisSaltPrefsKey =
      'sovereign_device_genesis_salt_v61';

  /// Alias matching Phase 61 design specification terminology.
  static const String deviceGenesisSaltPrefKey = deviceGenesisSaltPrefsKey;

  static const String _defaultSovereignIkm =
      'vhunambi_sovereign_brain_hkdf_ikm_v60_2026';
  static const String _defaultDeviceSalt =
      'vhunambi_default_device_genesis_salt_v1';
  static const String _defaultDomainInfo =
      'vhunambi_hive_aes256_at_rest_domain_v1';

  static String? _activeDeviceSalt;
  static String? _cachedSalt;
  static String? _cachedDomainInfo;
  static Uint8List? _cachedKeyBytes;

  static String? get activeDeviceSalt => _activeDeviceSalt;

  /// Ensures a per-device 256-bit CSPRNG salt is generated once and persisted
  /// in unencrypted [prefsBox] prior to opening AES-256 encrypted Hive boxes.
  static Future<String> ensureDeviceGenesisSalt(Box<dynamic> prefsBox) async {
    final existing = prefsBox.get(deviceGenesisSaltPrefsKey);
    if (existing is String && existing.trim().isNotEmpty) {
      final resolved = existing.trim();
      _activeDeviceSalt = resolved;
      return resolved;
    }

    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    await prefsBox.put(deviceGenesisSaltPrefsKey, generated);
    _activeDeviceSalt = generated;
    return generated;
  }

  /// Pure-Dart RFC 2104 HMAC-SHA256 backed by [VaultEnvelopeCrypto.sha256Bytes].
  static Uint8List hmacSha256(Uint8List key, Uint8List data) {
    const blockSize = 64;
    var effectiveKey = key;
    if (effectiveKey.length > blockSize) {
      effectiveKey = VaultEnvelopeCrypto.sha256Bytes(effectiveKey);
    }

    final keyBlock = Uint8List(blockSize);
    keyBlock.setRange(0, effectiveKey.length, effectiveKey);

    final iKeyPad = Uint8List(blockSize);
    final oKeyPad = Uint8List(blockSize);
    for (var i = 0; i < blockSize; i++) {
      iKeyPad[i] = keyBlock[i] ^ 0x36;
      oKeyPad[i] = keyBlock[i] ^ 0x5C;
    }

    final innerInput = Uint8List(blockSize + data.length);
    innerInput.setRange(0, blockSize, iKeyPad);
    innerInput.setRange(blockSize, innerInput.length, data);
    final innerHash = VaultEnvelopeCrypto.sha256Bytes(innerInput);

    final outerInput = Uint8List(blockSize + innerHash.length);
    outerInput.setRange(0, blockSize, oKeyPad);
    outerInput.setRange(blockSize, outerInput.length, innerHash);
    return VaultEnvelopeCrypto.sha256Bytes(outerInput);
  }

  /// Derives a 32-byte (256-bit) AES key using HKDF-Extract + HKDF-Expand (HMAC-SHA256).
  static Uint8List derive256BitKey({
    String deviceSalt = _defaultDeviceSalt,
    String domainInfo = _defaultDomainInfo,
  }) {
    if (_cachedKeyBytes != null &&
        _cachedSalt == deviceSalt &&
        _cachedDomainInfo == domainInfo) {
      return Uint8List.fromList(_cachedKeyBytes!);
    }

    final saltBytes = Uint8List.fromList(utf8.encode(deviceSalt));
    final ikmBytes = Uint8List.fromList(utf8.encode(_defaultSovereignIkm));

    // HKDF-Extract: PRK = HMAC-SHA256(salt, IKM)
    final prk = hmacSha256(saltBytes, ikmBytes);

    // HKDF-Expand: OKM(32 bytes) = HMAC-SHA256(PRK, info || 0x01)
    final infoBytes = utf8.encode(domainInfo);
    final infoWithCounter = Uint8List(infoBytes.length + 1);
    infoWithCounter.setRange(0, infoBytes.length, infoBytes);
    infoWithCounter[infoBytes.length] = 0x01;
    final okm = hmacSha256(prk, infoWithCounter);

    _cachedSalt = deviceSalt;
    _cachedDomainInfo = domainInfo;
    _cachedKeyBytes = Uint8List.fromList(okm);
    return Uint8List.fromList(okm);
  }

  /// Builds a [HiveAesCipher] instance backed by the 32-byte sovereign key.
  static HiveAesCipher buildCipher({
    String? deviceSalt,
    String? deviceSaltOverride,
  }) {
    final key = derive256BitKey(
      deviceSalt:
          deviceSaltOverride ??
          deviceSalt ??
          _activeDeviceSalt ??
          _defaultDeviceSalt,
    );
    return HiveAesCipher(key);
  }

  /// Creates a [HiveAesCipher] instance backed by the 32-byte sovereign key
  /// (delegates to [buildCipher] for Phase 60/61 method parity).
  static HiveAesCipher createCipher({String? deviceSalt}) =>
      buildCipher(deviceSalt: deviceSalt);

  /// Clears in-memory device salt & derived key cache (invoked during cold restart resets).
  static void clearRuntimeCache() {
    _activeDeviceSalt = null;
    _cachedSalt = null;
    _cachedDomainInfo = null;
    _cachedKeyBytes = null;
  }

  @visibleForTesting
  static void resetForTesting() => clearRuntimeCache();
}
