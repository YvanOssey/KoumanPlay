/// Configuration passée au build :
///   flutter run --dart-define-from-file=env.json
/// Sans ces valeurs, l'app fonctionne entièrement hors-ligne (mode local).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Boutons de paiement (Wave, Orange Money, MTN MoMo, carte) dans l'app.
  /// À mettre à false pour la version Play Store : Google impose son propre
  /// paiement pour les achats dans l'app. Les achats faits sur la version web
  /// y sont quand même débloqués.
  static const paymentsInApp = bool.fromEnvironment('PAYMENTS_IN_APP', defaultValue: true);
}
