import 'dart:convert';

import 'package:http/http.dart' as http;

/// `Authorization: Basic` pour un flux privé. `null` si aucun identifiant.
String? basicAuthorization(String? username, String? password) {
  final user = username?.trim() ?? '';
  final pass = password ?? '';
  if (user.isEmpty && pass.isEmpty) return null;
  final token = base64Encode(utf8.encode('$user:$pass'));
  return 'Basic $token';
}

/// En-têtes d’une requête liée à un podcast. L’autorisation n’est ajoutée
/// que si un identifiant ou un mot de passe est renseigné.
Map<String, String> podcastRequestHeaders({
  required String userAgent,
  String? username,
  String? password,
}) {
  final headers = <String, String>{'User-Agent': userAgent};
  final authorization = basicAuthorization(username, password);
  if (authorization != null) {
    headers['Authorization'] = authorization;
  }
  return headers;
}

/// Suit les redirections en conservant `Authorization`.
///
/// Le client `package:http` retire cet en-tête quand l’hôte change.
/// Un flux privé sert parfois l’audio sur un autre chemin du même compte.
Future<http.StreamedResponse> sendKeepingAuthorization(
  http.Client client,
  http.BaseRequest request, {
  int maxRedirects = 5,
}) async {
  var current = request;
  for (var hop = 0; hop <= maxRedirects; hop++) {
    final response = await client.send(current);
    final code = response.statusCode;
    final redirect =
        code == 301 || code == 302 || code == 303 || code == 307 || code == 308;
    if (!redirect || hop == maxRedirects) return response;

    final location = response.headers['location'];
    if (location == null || location.isEmpty) return response;
    await response.stream.drain<void>();

    final nextUrl = current.url.resolve(location);
    final nextMethod = code == 303 ? 'GET' : current.method;
    final next = http.Request(nextMethod, nextUrl);
    next.followRedirects = false;
    next.headers.addAll(current.headers);
    if (nextMethod == 'GET') {
      next.headers.remove('content-length');
      next.headers.remove('content-type');
    }
    current = next;
  }
  return client.send(current);
}

/// GET qui conserve l’authentification à travers les redirections.
Future<http.Response> getKeepingAuthorization(
  Uri url, {
  required Map<String, String> headers,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', url);
    request.followRedirects = false;
    request.headers.addAll(headers);
    final streamed = await sendKeepingAuthorization(client, request).timeout(
      timeout,
    );
    return await http.Response.fromStream(streamed);
  } finally {
    client.close();
  }
}
