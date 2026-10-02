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

  // Câmera traseira
  var cam = valorDe('Câmera traseira');
  if (cam.isEmpty) cam = valorDe('Câmera');
  specs[0] = cam;

  // Câmera frontal
  specs[1] = valorDe('Câmera frontal');

  // RAM
  var ram = valorDe('RAM');
  if (ram.isEmpty) {
    final m = RegExp(r'(\d{1,2})\s?GB[^,;]*RAM', caseSensitive: false).firstMatch(texto);
    if (m != null) ram = '${m.group(1)} GB de RAM';
  }
  specs[2] = ram;

  // Bateria
  var bat = valorDe('Bateria');
  if (bat.isEmpty) {
    final m = RegExp(r'(\d{3,5})\s?mAh', caseSensitive: false).firstMatch(texto);
    if (m != null) bat = '${m.group(1)} mAh';
  }
  specs[3] = bat;

  // Processador
  var cpu = valorDe('Processador');
  if (cpu.isEmpty) {
    final m = RegExp(r'(\d+\s?Core[^;,\n]*)', caseSensitive: false).firstMatch(texto);
    if (m != null) cpu = m.group(1)!.trim();
  }
  specs[4] = cpu;

  // Tela
  var tela = valorDe('Tela');
  if (tela.isEmpty) {
    final m = RegExp(r'(\d{1,2}[,.]\d{1,2})[\s\"]*', caseSensitive: false).firstMatch(texto);
    if (m != null) tela = '${m.group(1)}"';
  }
  specs[5] = tela;

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
