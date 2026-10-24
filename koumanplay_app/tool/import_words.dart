// Importe les mots collectés (content/collecte_mots.csv, séparateur « ; »,
// format Excel) dans assets/content/content_v2.json, puis régénérer le seed :
//   dart run tool/import_words.dart
//   dart run tool/generate_seed.dart
//
// Seules les lignes dont la colonne « langue_locale » est remplie sont
// importées. Une ligne avec « valide_par » rempli est marquée validée.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final csvPath = args.isNotEmpty ? args.first : 'content/collecte_mots.csv';
  final lines = File(csvPath).readAsStringSync().replaceFirst('﻿', '').split(RegExp(r'\r?\n'));
  final header = lines.first.split(';').map((h) => h.trim()).toList();
  int col(String name) {
    final index = header.indexOf(name);
    if (index < 0) throw FormatException('Colonne « $name » absente de $csvPath');
    return index;
  }

  final id = col('id'), level = col('niveau'), french = col('francais'), local = col('langue_locale');
  final pronunciation = col('prononciation'), audio = col('audio'), validatedBy = col('valide_par');

  final contentFile = File('assets/content/content_v2.json');
  final content = jsonDecode(contentFile.readAsStringSync()) as Map<String, dynamic>;
  final levelIds = (content['levels'] as List).map((l) => (l as Map)['id']).toSet();

  String? cell(List<String> row, int i) {
    final value = i < row.length ? row[i].trim() : '';
    return value.isEmpty ? null : value;
  }

  final words = <Map<String, dynamic>>[];
  for (final (n, line) in lines.skip(1).indexed) {
    if (line.trim().isEmpty) continue;
    final row = line.split(';');
    if (cell(row, local) == null) continue;
    final levelId = cell(row, level);
    if (!levelIds.contains(levelId)) {
      stderr.writeln('Ligne ${n + 2} ignorée : niveau « $levelId » inconnu.');
      continue;
    }
    words.add({
      'id': cell(row, id),
      'levelId': levelId,
      'french': cell(row, french),
      'local': cell(row, local),
      'pronunciation': cell(row, pronunciation),
      'audio': cell(row, audio),
      'validated': cell(row, validatedBy) != null,
      'validatedBy': cell(row, validatedBy),
    });
  }

  content['words'] = words;
  contentFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(content));
  stdout.writeln('${words.length} mots importés dans ${contentFile.path}.');

  // Un niveau a besoin d'au moins 4 mots pour être jouable.
  final perLevel = <String, int>{};
  for (final w in words) {
    perLevel.update(w['levelId'] as String, (v) => v + 1, ifAbsent: () => 1);
  }
  perLevel.forEach((levelId, count) {
    if (count < 4) stdout.writeln('  ⚠ $levelId : $count mot(s), il en faut au moins 4 pour jouer.');
  });
}
