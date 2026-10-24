import 'dart:convert';
import 'dart:io';

void main() async {
  final currentFile = File('assets/celulares.json');
  final newFile = File('assets/celulares_new.json');

  if (!await newFile.exists()) {
    print('New file not found at assets/celulares_new.json');
    return;
  }

  final current = json.decode(await currentFile.readAsString()) as List;
  final newData = json.decode(await newFile.readAsString()) as List;

  final existingKeys = <String>{};
  for (final e in current) {
    existingKeys.add('${e['marca']}|${e['modelo']}|${e['armazenamento']}');
  }

  int added = 0;
  for (final e in newData) {
    final key = '${e['marca']}|${e['modelo']}|${e['armazenamento']}';
    if (!existingKeys.contains(key)) {
      current.add(e);
      existingKeys.add(key);
      added++;
    }
  }

  if (added > 0) {
    current.sort((a, b) => '${a['marca']} ${a['modelo']}'.compareTo('${b['marca']} ${b['modelo']}'));
    await currentFile.writeAsString(const JsonEncoder.withIndent('  ').convert(current));
    print('Adicionados $added novos modelos. Total: ${current.length}');
  } else {
    print('Nenhum modelo novo para adicionar.');
  }
}