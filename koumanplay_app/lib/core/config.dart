/// Configuration passée au build :
///   flutter run --dart-define-from-file=env.json
/// Sans ces valeurs, l'app fonctionne entièrement hors-ligne (mode local).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
