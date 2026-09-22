import 'dart:convert';
import 'dart:io';

/// Publica o conteúdo do CHANGELOG.md como "notes" no release e no patch
/// mais recentes do Shorebird. Requer SHOREBIRD_TOKEN no ambiente.
///
/// Uso: dart run scripts/update_shorebird_notes.dart
Future<void> main() async {
  final token = Platform.environment['SHOREBIRD_TOKEN'] ?? '';
  if (token.isEmpty) {
    stderr.writeln('SHOREBIRD_TOKEN não definido');
    exit(1);
  }

  final appId = _readAppId();
  if (appId == null) {
    stderr.writeln('app_id não encontrado no shorebird.yaml');
    exit(1);
  }

  final notes = _readChangelog();
  if (notes.isEmpty) {
    stdout.writeln('CHANGELOG.md vazio — nada a publicar');
    return;
  }

  final client = HttpClient();
  try {
    final releases = await _get(client, token, '/api/v1/apps/$appId/releases');
    final list = (releases['releases'] as List?) ?? [];
    if (list.isEmpty) {
      stdout.writeln('Nenhum release encontrado');
      return;
    }
    // Versão alvo (opcional). Sem ela, usa o release mais recente.
    final targetVersion = Platform.environment['SHOREBIRD_RELEASE_VERSION'];
    Map<String, dynamic> release;
    if (targetVersion != null && targetVersion.isNotEmpty) {
      release = list.firstWhere(
        (r) => r['version'] == targetVersion,
        orElse: () => list.reduce((a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String) >= 0 ? a : b),
      );
    } else {
      release = list.reduce((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String) >= 0 ? a : b);
    }
    final releaseId = release['id'];
    stdout.writeln('Release alvo: ${release['version']} (id=$releaseId)');

    final rCode = await _patch(
      client,
      token,
      '/api/v1/apps/$appId/releases/$releaseId',
      {'notes': notes, 'status': 'active', 'platform': 'android'},
    );
    stdout.writeln('Notes do release -> HTTP $rCode');

    final patches = await _get(
      client, token, '/api/v1/apps/$appId/releases/$releaseId/patches');
    final patchList = (patches['patches'] as List?) ?? [];
    if (patchList.isNotEmpty) {
      final patch = patchList.last;
      final pCode = await _patch(
        client,
        token,
        '/api/v1/apps/$appId/releases/$releaseId/patches/${patch['id']}',
        {'notes': notes},
      );
      stdout.writeln('Notes do patch #${patch['number']} -> HTTP $pCode');
    } else {
      stdout.writeln('Nenhum patch para anotar');
    }
  } finally {
    client.close();
  }
}

String? _readAppId() {
  try {
    final yaml = File('shorebird.yaml').readAsStringSync();
    return RegExp(r'app_id:\s*(\S+)').firstMatch(yaml)?.group(1);
  } catch (_) {
    return null;
  }
}

/// Primeira seção do changelog (do primeiro "## " até o próximo "## ").
String _readChangelog() {
  try {
    final content = File('CHANGELOG.md').readAsStringSync();
    final lines = content.split(RegExp(r'\r?\n'));
    final out = <String>[];
    var started = false;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (started) break;
        started = true;
        out.add(line);
        continue;
      }
      if (started) out.add(line);
    }
    final texto = out.join('\n').trim();
    return texto.length > 4000 ? texto.substring(0, 4000) : texto;
  } catch (_) {
    return '';
  }
}

Future<Map<String, dynamic>> _get(
    HttpClient client, String token, String path) async {
  final req = await client.getUrl(Uri.parse('https://api.shorebird.dev$path'));
  req.headers.set('Authorization', 'Bearer $token');
  req.headers.set('Accept', 'application/json');
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  if (resp.statusCode != 200) return {};
  final decoded = json.decode(body);
  return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
}

Future<int> _patch(HttpClient client, String token, String path,
    Map<String, dynamic> body) async {
  final req = await client.patchUrl(Uri.parse('https://api.shorebird.dev$path'));
  req.headers.set('Authorization', 'Bearer $token');
  req.headers.set('Content-Type', 'application/json; charset=utf-8');
  req.headers.set('Accept', 'application/json');
  req.add(utf8.encode(json.encode(body)));
  final resp = await req.close();
  await resp.drain<void>();
  return resp.statusCode;
}