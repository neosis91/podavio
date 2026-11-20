/// Manière d’écrire la réponse par rapport au morceau déjà reçu.
enum DownloadBodyMode {
  /// Continuer après les octets déjà sur le disque.
  append,

  /// La réponse est le fichier entier. Remplacer le morceau.
  replace,

  /// Le morceau contient déjà tout le fichier.
  complete,

  /// La réponse ne peut pas être utilisée. Recommencer sans plage.
  restart,
}

/// Décision prise à partir du code HTTP et des en-têtes.
class DownloadBodyPlan {
  const DownloadBodyPlan({
    required this.mode,
    required this.already,
    required this.total,
  });

  final DownloadBodyMode mode;

  /// Octets du morceau qui comptent déjà dans la progression.
  final int already;

  /// Taille totale du fichier. 0 si le serveur ne la donne pas.
  final int total;
}

/// `Content-Range`, par exemple `bytes 500-999/1234` ou `bytes */1234`.
class ByteRange {
  const ByteRange({this.start, this.end, this.total});

  final int? start;
  final int? end;
  final int? total;
}

ByteRange? parseByteRange(String? header) {
  if (header == null) return null;
  final full = RegExp(
    r'bytes\s+(\d+)-(\d+)/(\d+|\*)',
    caseSensitive: false,
  ).firstMatch(header);
  if (full != null) {
    final total = full.group(3);
    return ByteRange(
      start: int.parse(full.group(1)!),
      end: int.parse(full.group(2)!),
      total: total == '*' ? null : int.parse(total!),
    );
  }
  final size = RegExp(
    r'bytes\s+\*/(\d+)',
    caseSensitive: false,
  ).firstMatch(header);
  if (size == null) return null;
  return ByteRange(total: int.parse(size.group(1)!));
}

/// ETag, sinon Last-Modified. Sert à ne pas coller deux fichiers différents.
String? downloadValidator(Map<String, String> headers) {
  final etag = headers['etag']?.trim();
  if (etag != null && etag.isNotEmpty) return etag;
  final modified = headers['last-modified']?.trim();
  if (modified != null && modified.isNotEmpty) return modified;
  return null;
}

/// Choisit quoi faire d’une réponse quand [partialBytes] sont déjà gardés.
DownloadBodyPlan planDownloadBody({
  required int statusCode,
  required int partialBytes,
  int? contentLength,
  String? contentRange,
}) {
  final range = parseByteRange(contentRange);
  if (statusCode == 206) {
    final start = range?.start;
    if (start == null || start != partialBytes) {
      return DownloadBodyPlan(
        mode: start == 0 ? DownloadBodyMode.replace : DownloadBodyMode.restart,
        already: 0,
        total: contentLength ?? range?.total ?? 0,
      );
    }
    final total =
        range?.total ??
        (contentLength == null ? 0 : partialBytes + contentLength);
    return DownloadBodyPlan(
      mode: DownloadBodyMode.append,
      already: partialBytes,
      total: total < 0 ? 0 : total,
    );
  }
  if (statusCode == 416) {
    final total = range?.total ?? 0;
    if (total > 0 && partialBytes == total) {
      return DownloadBodyPlan(
        mode: DownloadBodyMode.complete,
        already: total,
        total: total,
      );
    }
    return DownloadBodyPlan(
      mode: DownloadBodyMode.restart,
      already: 0,
      total: total < 0 ? 0 : total,
    );
  }
  return DownloadBodyPlan(
    mode: DownloadBodyMode.replace,
    already: 0,
    total: contentLength ?? 0,
  );
}
