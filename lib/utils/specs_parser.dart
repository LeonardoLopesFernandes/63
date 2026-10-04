/// Extrai as 6 especificações (câmera traseira/frontal, RAM, bateria,
/// processador e tela) a partir do texto de uma ficha técnica colada.
///
/// Usado tanto no cadastro manual quanto na edição de specs de um aparelho.
List<String> parseSpecsDeFicha(String texto) {
  // Normaliza o texto: se os labels vierem grudados (ex: "...50 MPCâmera
  // frontal: 5 MP"), insere quebra de linha antes de cada label conhecido.
  var normalizado = texto;
  const labels = [
    'Câmera traseira', 'Câmera frontal', 'Câmera', 'Bateria',
    'RAM', 'Processador', 'Tela', 'Descrição', 'Descricao',
  ];
  for (final label in labels) {
    normalizado = normalizado.replaceAllMapped(
      RegExp('($label[\\s:])', caseSensitive: false),
      (m) => '\n${m.group(1)}',
    );
  }
  // Também quebra quando um label minúsculo vem após texto sem espaço
  // (ex: "mAhRAM: 4 GB" -> "mAh\nRAM: 4 GB").
  for (final label in labels) {
    final rl = label.toLowerCase();
    normalizado = normalizado.replaceAllMapped(
      RegExp('($rl[\\s:])', caseSensitive: false),
      (m) => '\n${m.group(1)}',
    );
  }

  final linhas = normalizado
      .split(RegExp(r'[\n\r]'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final specs = List<String>.filled(6, '');

  String valorDe(String label) {
    for (final linha in linhas) {
      final lower = linha.toLowerCase();
      if (lower.startsWith(label.toLowerCase())) {
        var v = linha.substring(label.length).trim();
        v = v.replaceAll(RegExp(r'^[:=\-]+'), '').trim();
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  // Remove prefixos já presentes no valor (evita "câmera câmera ...").
  String semPrefixo(String v, List<String> prefixos) {
    var r = v.trim();
    for (final p in prefixos) {
      final m = RegExp('^$p\\s*[:\\-]?\\s*', caseSensitive: false).firstMatch(r);
      if (m != null) {
        r = r.substring(m.end).trim();
        break;
      }
    }
    return r;
  }

  // Normaliza unidades: "50 mp" -> "50MP", "4 gb" -> "4GB",
  // "5000 mah" -> "5000mAh", com espaços ao redor do "+".
  String normUnidade(String v) {
    var r = v;
    r = r.replaceAllMapped(RegExp(r'(\d)\s*mp\b', caseSensitive: false),
        (m) => '${m.group(1)}MP');
    r = r.replaceAllMapped(RegExp(r'(\d)\s*gb\b', caseSensitive: false),
        (m) => '${m.group(1)}GB');
    r = r.replaceAllMapped(RegExp(r'(\d)\s*mah\b', caseSensitive: false),
        (m) => '${m.group(1)}mAh');
    if (r.contains('+')) r = r.split('+').map((s) => s.trim()).join(' + ');
    return r.trim();
  }

  // Câmera traseira -> "Câmera traseira: câmera 50MP + 5MP"
  var cam = valorDe('Câmera traseira');
  if (cam.isEmpty) {
    for (final linha in linhas) {
      final lower = linha.toLowerCase();
      if (lower.startsWith('câmera') && !lower.startsWith('câmera frontal')) {
        var v = linha.substring('câmera'.length).trim();
        v = v.replaceAll(RegExp(r'^[:=\-]+'), '').trim();
        if (v.isNotEmpty) {
          cam = v;
          break;
        }
      }
    }
  }
  cam = normUnidade(semPrefixo(cam, ['câmera traseira', 'traseira', 'câmera']));
  specs[0] = cam.isEmpty ? '' : 'Câmera traseira: câmera $cam';

  // Câmera frontal -> "Câmera frontal: câmera frontal 16MP"
  var front = valorDe('Câmera frontal');
  front =
      normUnidade(semPrefixo(front, ['câmera frontal', 'frontal', 'câmera']));
  specs[1] = front.isEmpty ? '' : 'Câmera frontal: câmera frontal $front';

  // RAM -> "RAM: ram de 4GB"
  var ram = valorDe('RAM');
  if (ram.isEmpty) {
    final m = RegExp(r'(\d{1,2})\s?GB[^,;]*RAM', caseSensitive: false).firstMatch(texto);
    if (m != null) ram = '${m.group(1)} GB de RAM';
  }
  ram = semPrefixo(ram, ['ram de', 'ram']);
  ram = ram.replaceAll(RegExp(r'\s*de\s*ram\s*$', caseSensitive: false), '').trim();
  ram = normUnidade(ram);
  specs[2] = ram.isEmpty ? '' : 'RAM: ram de $ram';

  // Bateria -> "Bateria: bateria 5000mAh"
  var bat = valorDe('Bateria');
  if (bat.isEmpty) {
    final m = RegExp(r'(\d{3,5})\s?mAh', caseSensitive: false).firstMatch(texto);
    if (m != null) bat = '${m.group(1)} mAh';
  }
  bat = normUnidade(semPrefixo(bat, ['bateria']));
  specs[3] = bat.isEmpty ? '' : 'Bateria: bateria $bat';

  // Processador -> "Processador: processador T606 Octa-Core"
  var cpu = valorDe('Processador');
  if (cpu.isEmpty) {
    final m = RegExp(r'(\d+\s?Core[^;,\n]*)', caseSensitive: false).firstMatch(texto);
    if (m != null) cpu = m.group(1)!.trim();
  }
  cpu = semPrefixo(cpu, ['processador']);
  specs[4] = cpu.isEmpty ? '' : 'Processador: processador $cpu';

  // Tela -> 'Tela: tela 6,6"'
  var tela = valorDe('Tela');
  if (tela.isEmpty) {
    final m = RegExp(r'(\d{1,2}[,.]\d{1,2})[\s\"]*', caseSensitive: false).firstMatch(texto);
    if (m != null) tela = '${m.group(1)}"';
  }
  tela = semPrefixo(tela, ['tela']);
  final mt = RegExp(r'(\d{1,2})[,.](\d{1,2})').firstMatch(tela);
  if (mt != null) {
    tela = '${mt.group(1)},${mt.group(2)}"';
  } else {
    tela = '${tela.replaceAll('"', '').trim()}"';
    if (tela == '"') tela = '';
  }
  specs[5] = tela.isEmpty ? '' : 'Tela: tela $tela';

  return specs;
}

/// Tenta descobrir a descrição do aparelho (marca/modelo) no texto colado.
/// Nunca retorna uma linha de spec (câmera, bateria, etc.); devolve vazio
/// quando não encontra, para o usuário preencher.
String extrairDescricao(String texto, String primeiraSpec) {
  final linhas = texto.split(RegExp(r'[\n\r]')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  // 1. Prioridade máxima: label explícito "Descrição: <valor>".
  for (final linha in linhas) {
    final m = RegExp(r'^descri(cao|ção)?\s*[:=\-]?\s*(.+)$', caseSensitive: false).firstMatch(linha);
    if (m != null) {
      final v = m.group(2)!.trim();
      if (v.isNotEmpty && v.length < 80) return v;
    }
  }

  // 2. Procura uma linha que pareça NOME DE APARELHO (marca/modelo),
  //    nunca câmera/bateria/etc.
  for (final linha in linhas) {
    final lower = linha.toLowerCase();
    final temMarca = RegExp(r'samsung|galaxy|motorola|moto|xiaomi|redmi|poco|apple|iphone|edge|realme|huawei|nokia|lg\b').hasMatch(lower);
    final temModelo = RegExp(r'\b[a-z]+\d+[a-z0-9]*\b|\b\d+\s?(gb|tb)\b').hasMatch(lower);
    final ehSpec = lower.startsWith('câmera') || lower.startsWith('camera') ||
        lower.startsWith('bateria') || lower.startsWith('ram') ||
        lower.startsWith('processador') || lower.startsWith('tela') ||
        lower.contains('mAh') || lower.contains('core') || lower.contains('ghz') ||
        lower.contains('mp ') || lower.contains(' polegadas') || lower.contains(' inches');
    if (!ehSpec && (temMarca || temModelo) && linha.length < 80) return linha;
  }

  // 3. Fallback: primeira linha que não é um label/spec.
  for (final linha in linhas) {
    final lower = linha.toLowerCase();
    final ehSpec = lower.startsWith('câmera') || lower.startsWith('camera') ||
        lower.startsWith('bateria') || lower.startsWith('ram') ||
        lower.startsWith('processador') || lower.startsWith('tela') ||
        lower.contains('mAh') || lower.contains('core') || lower.contains('ghz') ||
        lower.contains('mp ') || lower.contains(' polegadas');
    if (!ehSpec && linha.length < 80) return linha;
  }

  // 4. Nunca retorna a câmera; devolve vazio p/ usuário preencher.
  return '';
}
