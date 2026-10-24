// Génère supabase/seed.sql depuis assets/content/content_v2.json, pour copier
// le contenu embarqué dans Supabase.
//   dart run tool/generate_seed.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final json = jsonDecode(File('assets/content/content_v2.json').readAsStringSync()) as Map<String, dynamic>;
  final out = StringBuffer('-- Généré par tool/generate_seed.dart, ne pas modifier à la main.\n\n');

  String q(Object? v) {
    if (v == null) return 'null';
    if (v is bool || v is num) return '$v';
    if (v is List) return "'${jsonEncode(v).replaceAll("'", "''")}'::jsonb";
    return "'${v.toString().replaceAll("'", "''")}'";
  }

  void insert(String table, List<String> columns, List<List<Object?>> rows) {
    if (rows.isEmpty) return;
    out.writeln('insert into public.$table (${columns.join(', ')}) values');
    out.writeln(rows.map((r) => '  (${r.map(q).join(', ')})').join(',\n'));
    final updates = columns.skip(1).map((c) => '$c = excluded.$c').join(', ');
    out.writeln('on conflict (id) do update set $updates;\n');
  }

  List<Map<String, dynamic>> list(String key) => ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();

  var i = 0;
  insert('languages', ['id', 'name', '"group"', 'region', 'color', 'sort'], [
    for (final l in list('languages')) [l['id'], l['name'], l['group'], l['region'], l['color'], i++],
  ]);
  insert('levels', ['id', 'language_id', 'category_id', 'sort', 'title', 'kind', 'pass_ratio'], [
    for (final l in list('levels')) [l['id'], l['languageId'], null, l['order'], l['title'], l['kind'], l['passRatio']],
  ]);
  i = 0;
  insert('words', ['id', 'level_id', 'french', 'local', 'pronunciation', 'audio', 'xp', 'validated', 'validated_by', 'sort'], [
    for (final w in list('words'))
      [w['id'], w['levelId'], w['french'], w['local'], w['pronunciation'], w['audio'], w['xp'] ?? 10, w['validated'] ?? false, w['validatedBy'], i++],
  ]);
  i = 0;
  insert('activities', [
    'id', 'level_id', 'proverb', 'original', 'language', 'question', 'answers', 'correct', 'explanation', 'audio', 'xp', 'validated', 'sort'
  ], [
    for (final a in list('activities'))
      [a['id'], a['levelId'], a['proverb'], a['original'], a['language'], a['question'], a['answers'], a['correct'], a['explanation'], a['audio'], a['xp'], a['validated'], i++],
  ]);
  i = 0;
  insert('challenges', [
    'id', 'role', 'unlock_after_level', 'title', 'description', 'reward_xp', 'duration_min', 'difficulty', 'steps', 'note_prompt', 'sort'
  ], [
    for (final c in list('challenges'))
      [c['id'], c['role'], c['unlockAfterLevel'], c['title'], c['description'], c['rewardXp'], c['durationMin'], c['difficulty'], c['steps'], c['notePrompt'], i++],
  ]);

  // Niveaux qui n'existent plus dans le contenu (ex. anciens « prov-1 ») :
  // leurs proverbes et défis ont été rattachés ci-dessus aux nouveaux niveaux.
  final levelIds = list('levels').map((l) => q(l['id'])).join(', ');
  out.writeln('delete from public.levels where id not in ($levelIds);');

  File('supabase/seed.sql').writeAsStringSync(out.toString());
  stdout.writeln('supabase/seed.sql écrit.');
}
