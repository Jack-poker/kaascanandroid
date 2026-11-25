import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart'; // For hex conversion

/// Verify a Qaad seal using HEX strings
///
/// [publicKeyHex]  : 64 hex characters (32 bytes)
/// [dataHex]       : compressed marks as hex
/// [signatureHex]  : 128 hex characters (64 bytes)
///
/// Returns true if signature is valid, false if not.
Future<bool> verifyQaadSeal({
  required String publicKeyHex,
  required String dataHex,
  required String signatureHex,
}) async {
  try {
    // Convert hex to bytes
    final publicKey = hex.decode(publicKeyHex);
    final data = hex.decode(dataHex);
    final signature = hex.decode(signatureHex);

    return await Ed25519().verify(
      data,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      ),
    );
  } catch (_) {
    return false;
  }
}