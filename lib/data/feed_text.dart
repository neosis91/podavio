import 'dart:convert';

/// Décode un document RSS ou Atom.
///
/// Sans charset, le client HTTP prend Latin-1. Un flux UTF-8 voit alors
/// « é » devenir « Ã© ». La déclaration XML prime, sinon c’est l’UTF-8.
String decodeFeedDocument(List<int> bytes, {String? contentType}) {
  if (bytes.isEmpty) return '';
  final encoding = _feedEncoding(bytes, contentType);
  try {
    return encoding.decode(bytes);
  } on FormatException {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

/// « é » lu en Latin-1 (« Ã© ») redevient « é ». Un texte déjà juste ne change pas.
String repairMojibake(String value) {
  if (value.isEmpty || (!value.contains('Ã') && !value.contains('Â'))) {
    return value;
  }
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  } on ArgumentError {
    return value;
  }
}

Encoding _feedEncoding(List<int> bytes, String? contentType) {
  final declared = _xmlDeclaredEncoding(bytes);
  final fromXml = declared == null ? null : _encodingByName(declared);
  if (fromXml != null) return fromXml;
  final charset = _contentTypeCharset(contentType);
  final fromHeader = charset == null ? null : _encodingByName(charset);
  if (fromHeader != null) return fromHeader;
  return utf8;
}

String? _xmlDeclaredEncoding(List<int> bytes) {
  final headLength = bytes.length < 400 ? bytes.length : 400;
  final head = latin1.decode(bytes.sublist(0, headLength));
  final match = RegExp(
    'encoding\\s*=\\s*["\']([A-Za-z0-9._\\-]+)["\']',
    caseSensitive: false,
  ).firstMatch(head);
  return match?.group(1);
}

String? _contentTypeCharset(String? contentType) {
  if (contentType == null || contentType.isEmpty) return null;
  final match = RegExp(
    'charset\\s*=\\s*"?([^";\\s]+)',
    caseSensitive: false,
  ).firstMatch(contentType);
  return match?.group(1);
}

Encoding? _encodingByName(String name) {
  final normalized = name.trim().toLowerCase().replaceAll('_', '-');
  return switch (normalized) {
    'utf-8' || 'utf8' => utf8,
    'us-ascii' || 'ascii' => ascii,
    'iso-8859-1' ||
    'latin1' ||
    'latin-1' ||
    'iso-latin-1' ||
    'windows-1252' ||
    'cp1252' => latin1,
    _ => Encoding.getByName(normalized),
  };
}
