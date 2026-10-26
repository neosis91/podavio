import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';

const webCompanionSalt = 'podavio-web-v1';
const webCompanionInfo = 'podavio-web-session';

String webCompanionB64(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

List<int> webCompanionB64Decode(String value) {
  final pad = (4 - value.length % 4) % 4;
  return base64Url.decode(value + ('=' * pad));
}

String webCompanionSafetyNumber(List<int> pwaPub, List<int> phonePub) {
  final hex = sha256
      .convert([...pwaPub, ...phonePub])
      .bytes
      .take(10)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return [
    for (var i = 0; i < hex.length; i += 4) hex.substring(i, i + 4),
  ].join(' ');
}

List<int> webCompanionAad(String role, String conn, int counter) {
  return utf8.encode('$role:$conn:$counter');
}

String webCompanionRandomId(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return webCompanionB64(bytes);
}

class WebCompanionQr {
  const WebCompanionQr({
    required this.relay,
    required this.session,
    required this.pwaPub,
  });

  final String relay;
  final String session;
  final List<int> pwaPub;

  static WebCompanionQr? parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final relay = decoded['relay'];
    final session = decoded['session'];
    final pub = decoded['pub'];
    if (relay is! String || session is! String || pub is! String) return null;
    final uri = Uri.tryParse(relay);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'wss')) return null;
    if (session.length < 8 || session.length > 128) return null;
    List<int> pwaPub;
    try {
      pwaPub = webCompanionB64Decode(pub);
    } catch (_) {
      return null;
    }
    if (pwaPub.length != 32) return null;
    return WebCompanionQr(relay: relay, session: session, pwaPub: pwaPub);
  }
}

class WebCompanionHandshake {
  const WebCompanionHandshake({
    required this.phonePub,
    required this.key,
    required this.fingerprint,
    required this.hello,
  });

  final List<int> phonePub;
  final List<int> key;
  final String fingerprint;
  final WebCompanionSealed hello;
}

class WebCompanionSealed {
  const WebCompanionSealed({required this.iv, required this.ct});

  final List<int> iv;
  final List<int> ct;
}

Future<List<int>> _sessionKey(List<int> shared) {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  return hkdf
      .deriveKey(
        secretKey: SecretKey(shared),
        nonce: utf8.encode(webCompanionSalt),
        info: utf8.encode(webCompanionInfo),
      )
      .then((key) => key.extractBytes());
}

Future<List<int>> _sharedSecret({
  required SimpleKeyPair keyPair,
  required List<int> remotePub,
}) async {
  final shared = await X25519().sharedSecretKey(
    keyPair: keyPair,
    remotePublicKey: SimplePublicKey(remotePub, type: KeyPairType.x25519),
  );
  return shared.extractBytes();
}

Future<WebCompanionSealed> webCompanionSeal({
  required List<int> key,
  required List<int> plain,
  required List<int> aad,
  required Random random,
}) async {
  final iv = Uint8List.fromList(
    List<int>.generate(12, (_) => random.nextInt(256)),
  );
  final box = await AesGcm.with256bits().encrypt(
    plain,
    secretKey: SecretKey(key),
    nonce: iv,
    aad: aad,
  );
  return WebCompanionSealed(iv: iv, ct: [...box.cipherText, ...box.mac.bytes]);
}

Future<List<int>?> webCompanionOpen({
  required List<int> key,
  required List<int> iv,
  required List<int> ct,
  required List<int> aad,
}) async {
  if (iv.length != 12 || ct.length < 16) return null;
  try {
    return await AesGcm.with256bits().decrypt(
      SecretBox(
        ct.sublist(0, ct.length - 16),
        nonce: iv,
        mac: Mac(ct.sublist(ct.length - 16)),
      ),
      secretKey: SecretKey(key),
      aad: aad,
    );
  } on SecretBoxAuthenticationError {
    return null;
  }
}

/// Clé de session à partir de la clé publique lue dans le QR.
Future<WebCompanionHandshake> webCompanionHandshake({
  required List<int> pwaPub,
  required String conn,
  required Random random,
}) async {
  final keyPair = await X25519().newKeyPair();
  final phonePub = (await keyPair.extractPublicKey()).bytes;
  final shared = await _sharedSecret(keyPair: keyPair, remotePub: pwaPub);
  final key = await _sessionKey(shared);
  final helloPlain = utf8.encode(
    jsonEncode({'v': 1, 'role': 'phone', 'pub': webCompanionB64(phonePub)}),
  );
  final hello = await webCompanionSeal(
    key: key,
    plain: helloPlain,
    aad: webCompanionAad('phone', conn, 0),
    random: random,
  );
  return WebCompanionHandshake(
    phonePub: phonePub,
    key: key,
    fingerprint: webCompanionSafetyNumber(pwaPub, phonePub),
    hello: hello,
  );
}
