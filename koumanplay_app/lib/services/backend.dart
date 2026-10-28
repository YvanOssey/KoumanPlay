import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../models/contribution.dart';
import '../models/player.dart';
import '../models/social.dart';

/// Accès à Supabase. Toutes les méthodes échouent en silence (retournent
/// null/false) quand le backend n'est pas configuré ou que le réseau manque :
/// l'app doit toujours rester jouable hors-ligne.
class Backend {
  Backend._(this._client);

  final SupabaseClient? _client;

  static const _timeout = Duration(seconds: 8);

  static Future<Backend> init() async {
    if (!AppConfig.hasBackend) return Backend._(null);
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
      return Backend._(Supabase.instance.client);
    } catch (e) {
      debugPrint('Supabase indisponible : $e');
      return Backend._(null);
    }
  }

  /// Backend désactivé (tests, mode local).
  factory Backend.disabled() => Backend._(null);

  bool get enabled => _client != null;

  User? get user => _client?.auth.currentUser;

  /// Vrai tant que le joueur n'a pas créé de compte (session anonyme).
  bool get isAnonymous => user == null || user!.isAnonymous;

  String? get email => user?.email;

  /// Ouvre une session anonyme si aucune n'existe : le joueur joue tout de
  /// suite, son compte pourra être « confirmé » plus tard.
  Future<bool> ensureSession() async {
    final client = _client;
    if (client == null) return false;
    if (client.auth.currentSession != null) return true;
    // Plusieurs appels simultanés au démarrage : un seul compte anonyme.
    return _pendingSession ??= _signInAnonymously(client).whenComplete(() => _pendingSession = null);
  }

  Future<bool>? _pendingSession;

  Future<bool> _signInAnonymously(SupabaseClient client) async {
    try {
      await client.auth.signInAnonymously().timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Session anonyme impossible : $e');
      return false;
    }
  }

  /// Contenu publié dans Supabase, au format de assets/content/*.json.
  /// Retourne null si rien n'est publié ou en cas d'erreur.
  Future<Map<String, dynamic>?> fetchContent() async {
    final client = _client;
    if (client == null) return null;
    try {
      final results = await Future.wait([
        client.from('languages').select().order('sort', ascending: true),
        client.from('levels').select().not('language_id', 'is', null).order('sort', ascending: true),
        client.from('words').select().eq('published', true).order('sort', ascending: true),
        client.from('activities').select().eq('published', true).order('sort', ascending: true),
        client.from('challenges').select().eq('published', true).order('sort', ascending: true),
      ]).timeout(_timeout);
      if (results[0].isEmpty || results[1].isEmpty) return null;
      // Bibliothèque, événements et réglages : chargés à part, pour que le
      // jeu marche même si ces tables (migration 0004) n'existent pas encore.
      Future<List<Map<String, dynamic>>> optional(Future<List<Map<String, dynamic>>> query) async {
        try {
          return await query.timeout(_timeout);
        } catch (e) {
          debugPrint('Table facultative indisponible : $e');
          return const [];
        }
      }

      final extras = await Future.wait([
        optional(client.from('works').select().eq('published', true).order('sort', ascending: true)),
        optional(client.from('culture_events').select().eq('published', true).order('starts_at', ascending: true)),
        optional(client.from('app_settings').select()),
        optional(client.from('language_sounds').select().eq('published', true)),
      ]);
      return {
        'works': [
          for (final w in extras[0])
            {
              'id': w['id'],
              'title': w['title'],
              'kind': w['kind'],
              'description': w['description'],
              'people': w['people'],
              'region': w['region'],
              'period': w['period'],
              'museum': w['museum'],
              'city': w['city'],
              'address': w['address'],
              'imageUrl': w['image_url'],
              'link': w['link'],
            },
        ],
        'events': [
          for (final e in extras[1])
            {
              'id': e['id'],
              'title': e['title'],
              'organizer': e['organizer'],
              'description': e['description'],
              'startsAt': e['starts_at'],
              'endsAt': e['ends_at'],
              'place': e['place'],
              'city': e['city'],
              'imageUrl': e['image_url'],
              'link': e['link'],
              'minDiamonds': e['min_diamonds'],
            },
        ],
        'settings': {for (final s in extras[2]) s['key']: s['value']},
        'sounds': [
          for (final s in extras[3])
            {'languageId': s['language_id'], 'kind': s['kind'], 'audio': s['audio'], 'text': s['text']},
        ],
        'version': 0,
        'languages': results[0],
        'levels': [
          for (final l in results[1])
            {
              'id': l['id'],
              'languageId': l['language_id'],
              'order': l['sort'],
              'title': l['title'],
              'kind': l['kind'],
              'passRatio': l['pass_ratio'],
            },
        ],
        'words': [
          for (final w in results[2])
            {
              'id': w['id'],
              'levelId': w['level_id'],
              'french': w['french'],
              'local': w['local'],
              'pronunciation': w['pronunciation'],
              'audio': w['audio'],
              'xp': w['xp'],
              'validated': w['validated'],
            },
        ],
        'activities': [
          for (final a in results[3])
            {
              'id': a['id'],
              'levelId': a['level_id'],
              'proverb': a['proverb'],
              'original': a['original'],
              'language': a['language'],
              'question': a['question'],
              'answers': a['answers'],
              'correct': a['correct'],
              'explanation': a['explanation'],
              'audio': a['audio'],
              'xp': a['xp'],
              'validated': a['validated'],
            },
        ],
        'challenges': [
          for (final c in results[4])
            {
              'id': c['id'],
              'role': c['role'],
              'unlockAfterLevel': c['unlock_after_level'],
              'title': c['title'],
              'description': c['description'],
              'rewardXp': c['reward_xp'],
              'durationMin': c['duration_min'],
              'difficulty': c['difficulty'],
              'steps': c['steps'],
              'notePrompt': c['note_prompt'],
            },
        ],
      };
    } catch (e) {
      debugPrint('Contenu distant indisponible : $e');
      return null;
    }
  }

  Future<PlayerState?> fetchPlayer() async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) return null;
    try {
      final row = await client.from('player_states').select('state').eq('user_id', uid).maybeSingle().timeout(_timeout);
      if (row == null) return null;
      return PlayerState.fromJson((row['state'] as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('Lecture progression impossible : $e');
      return null;
    }
  }

  Future<bool> pushPlayer(PlayerState player) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) return false;
    try {
      await client.from('player_states').upsert({
        'user_id': uid,
        'first_name': player.firstName,
        'role': player.role,
        'group_id': player.groupId,
        'xp': player.xp,
        'state': player.toJson(),
        'updated_at': player.updatedAt.toUtc().toIso8601String(),
      }).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Sauvegarde progression impossible : $e');
      return false;
    }
  }

  Future<bool> sendEvents(List<Map<String, dynamic>> events) async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null || events.isEmpty) return false;
    try {
      await client.from('events').insert([for (final e in events) {...e, 'user_id': uid}]).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Envoi des événements impossible : $e');
      return false;
    }
  }

  /// Envoie une transmission d'aîné : ses enregistrements dans le bucket
  /// privé « contributions » (dossier = id du joueur), puis une ligne dans
  /// la table `contributions`, que l'équipe vérifie.
  Future<bool> sendContribution(Contribution c, List<Uint8List> audios, PlayerState player) async {
    final client = _client;
    if (client == null || !await ensureSession()) return false;
    final uid = user!.id;
    try {
      final paths = <String>[];
      for (final (i, bytes) in audios.indexed) {
        final ext = c.audioPaths[i].endsWith('.webm') || c.audioPaths[i].startsWith('blob:') ? 'webm' : 'm4a';
        final path = '$uid/${c.id}-$i.$ext';
        await client.storage
            .from('contributions')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: ext == 'webm' ? 'audio/webm' : 'audio/mp4', upsert: true),
            )
            .timeout(const Duration(seconds: 60));
        paths.add(path);
      }
      await client.from('contributions').upsert({
        'id': c.id,
        'user_id': uid,
        'kind': c.kind.name,
        'language_id': c.languageId,
        'prompt_id': c.promptId,
        'prompt_french': c.promptFrench,
        'text': c.text,
        'audio_paths': paths,
        'contributor_name': player.creditName ? player.firstName : null,
        'village': player.village,
        'consent_at': player.consentAt?.toUtc().toIso8601String(),
        'created_at': c.createdAt.toUtc().toIso8601String(),
      }).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Envoi de la transmission impossible : $e');
      return false;
    }
  }

  /// Statuts mis à jour par l'équipe (en vérification, publié, non retenu).
  Future<Map<String, ContributionStatus>?> fetchContributionStatuses() async {
    final client = _client;
    final uid = user?.id;
    if (client == null || uid == null) return null;
    try {
      final rows = await client.from('contributions').select('id, status').eq('user_id', uid).timeout(_timeout);
      return {for (final r in rows) r['id'] as String: ContributionStatus.fromCode(r['status'] as String?)};
    } catch (e) {
      debugPrint('Lecture des statuts impossible : $e');
      return null;
    }
  }

  /// Transforme la session anonyme en compte email + mot de passe, en gardant
  /// le même identifiant (donc la même progression).
  Future<void> upgradeAccount({required String email, required String password}) async {
    await _client!.auth.updateUser(UserAttributes(email: email, password: password));
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client!.auth.signInWithPassword(email: email, password: password);
  }

  // ---------------------------------------------------------------- Boutique

  /// Produits vendus en ligne (packs de cauris, KoumanPlay+).
  Future<List<ShopProduct>?> fetchProducts() async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client.from('shop_products').select().eq('active', true).order('sort').timeout(_timeout);
      return [for (final r in rows) ShopProduct.fromRow(r)];
    } catch (e) {
      debugPrint('Boutique indisponible : $e');
      return null;
    }
  }

  /// Demande un paiement GeniusPay (fonction create-payment) et renvoie le lien
  /// de la page de paiement. [method] : wave, orange, mtn ou card.
  Future<PaymentStart> createPayment(String productId, String method) async {
    final client = _client;
    if (client == null || !await ensureSession()) {
      return const PaymentStart.failed('Connexion impossible. Vérifie ton accès à internet.');
    }
    try {
      final res = await client.functions
          .invoke('create-payment', body: {'product_id': productId, 'method': method})
          .timeout(const Duration(seconds: 20));
      final data = (res.data as Map).cast<String, dynamic>();
      final url = data['checkout_url'] as String?;
      final reference = data['reference'] as String?;
      if (url == null || reference == null) {
        return PaymentStart.failed(data['error'] as String? ?? 'Le paiement n\'a pas pu être créé.');
      }
      return PaymentStart(reference: reference, url: url);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      return PaymentStart.failed(message ?? 'Le paiement n\'a pas pu être créé.');
    } catch (e) {
      debugPrint('Paiement impossible : $e');
      return const PaymentStart.failed('Le paiement n\'a pas pu être créé. Réessaie dans un instant.');
    }
  }

  /// Statut d'un paiement : pending, completed, failed, cancelled, expired…
  Future<String?> paymentStatus(String reference) async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client.from('payments').select('status').eq('reference', reference).maybeSingle().timeout(_timeout);
      return row?['status'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Récupère les achats livrés : cauris payés (une seule fois) et date de fin
  /// de KoumanPlay+.
  Future<({int cauris, DateTime? premiumUntil})?> claimPurchases() async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return null;
    try {
      final data = (await client.rpc('claim_wallet_credits').timeout(_timeout) as Map).cast<String, dynamic>();
      return (
        cauris: (data['cauris'] as num?)?.toInt() ?? 0,
        premiumUntil: DateTime.tryParse(data['premium_until'] as String? ?? ''),
      );
    } catch (e) {
      debugPrint('Achats non récupérés : $e');
      return null;
    }
  }

  // ---------------------------------------------------------------- Ligues

  /// Envoie l'XP de la semaine et renvoie le groupe de ligue du joueur
  /// (migration 0007). Null hors connexion.
  Future<LeagueBoard?> syncLeague({required String week, required int points, required String name, required Map<String, dynamic> avatar}) async {
    final client = _client;
    if (client == null || !await ensureSession()) return null;
    try {
      final data = await client
          .rpc('league_sync', params: {'p_week': week, 'p_points': points, 'p_name': name, 'p_avatar': avatar})
          .timeout(_timeout);
      return LeagueBoard.fromJson((data as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('Ligue indisponible : $e');
      return null;
    }
  }

  // ---------------------------------------------------------------- Duels en direct

  /// Cherche un adversaire inconnu (migration 0008). Renvoie la partie dès
  /// qu'un joueur est trouvé, null tant que le joueur attend en file.
  Future<LiveMatch?> matchFind({required String mode, required String languageId, required String name, required Map<String, dynamic> avatar}) async {
    final client = _client;
    if (client == null || !await ensureSession()) return null;
    try {
      final row = await client
          .rpc('match_find', params: {'p_mode': mode, 'p_language': languageId, 'p_name': name, 'p_avatar': avatar})
          .timeout(_timeout);
      return row is Map && row['id'] != null ? LiveMatch.fromRow(row.cast<String, dynamic>(), user?.id) : null;
    } catch (e) {
      debugPrint('Recherche d\'adversaire impossible : $e');
      return null;
    }
  }

  Future<void> matchLeave() async {
    try {
      await _client?.rpc('match_leave').timeout(_timeout);
    } catch (e) {
      debugPrint('File d\'attente non quittée : $e');
    }
  }

  /// Défi entre amis : crée une partie avec un code à partager.
  Future<LiveMatch?> roomCreate({required String mode, required String languageId, required String name, required Map<String, dynamic> avatar}) async {
    final client = _client;
    if (client == null || !await ensureSession()) return null;
    try {
      final row = await client
          .rpc('room_create', params: {'p_mode': mode, 'p_language': languageId, 'p_name': name, 'p_avatar': avatar})
          .timeout(_timeout);
      return LiveMatch.fromRow((row as Map).cast<String, dynamic>(), user?.id);
    } catch (e) {
      debugPrint('Défi non créé : $e');
      return null;
    }
  }

  /// Rejoint le défi d'un ami avec son code. Renvoie la partie, ou un message.
  Future<({LiveMatch? match, String? error})> roomJoin(String code, {required String name, required Map<String, dynamic> avatar}) async {
    final client = _client;
    if (client == null || !await ensureSession()) {
      return (match: null, error: 'Connexion impossible. Vérifie ton accès à internet.');
    }
    try {
      final row = await client
          .rpc('room_join', params: {'p_code': code, 'p_name': name, 'p_avatar': avatar})
          .timeout(_timeout);
      return (match: LiveMatch.fromRow((row as Map).cast<String, dynamic>(), user?.id), error: null);
    } on PostgrestException catch (e) {
      final message = e.message;
      return (
        match: null,
        error: message.contains('introuvable')
            ? 'Ce code ne correspond à aucun duel.'
            : message.contains('propre')
            ? 'C\'est ton propre code : envoie-le à un ami.'
            : message.contains('déjà pris')
            ? 'Ce duel a déjà un adversaire.'
            : message.contains('expiré')
            ? 'Ce code a expiré. Demande à ton ami d\'en créer un nouveau.'
            : 'Impossible de rejoindre ce duel pour le moment.',
      );
    } catch (e) {
      debugPrint('Défi non rejoint : $e');
      return (match: null, error: 'Connexion impossible. Vérifie ton accès à internet.');
    }
  }

  Future<LiveMatch?> fetchMatch(String id) async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client.from('live_matches').select().eq('id', id).maybeSingle().timeout(_timeout);
      return row == null ? null : LiveMatch.fromRow(row, user?.id);
    } catch (e) {
      debugPrint('Partie indisponible : $e');
      return null;
    }
  }

  Future<void> matchFinish(String id, {required int score, required bool won}) async {
    try {
      await _client?.rpc('match_finish', params: {'p_id': id, 'p_score': score, 'p_won': won}).timeout(_timeout);
    } catch (e) {
      debugPrint('Résultat non envoyé : $e');
    }
  }

  /// Canal temps réel d'une partie : les deux joueurs s'y envoient leur score.
  RealtimeChannel? duelChannel(String matchId) => _client?.channel('duel:$matchId');

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}

/// Produit vendu en ligne.
class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.priceXof,
    required this.cauris,
    required this.premiumDays,
  });

  final String id;

  /// 'cauris' ou 'premium'.
  final String kind;
  final String title;
  final String description;
  final int priceXof;
  final int cauris;
  final int premiumDays;

  bool get isPremium => kind == 'premium';

  /// Mêmes offres que la migration 0006 : affichées quand le serveur ne répond
  /// pas, et dans la version de démonstration.
  static const catalog = [
    ShopProduct(id: 'cauris-100', kind: 'cauris', title: 'Petit sac de cauris', description: '100 cauris', priceXof: 500, cauris: 100, premiumDays: 0),
    ShopProduct(id: 'cauris-250', kind: 'cauris', title: 'Sac de cauris', description: '250 cauris (25 offerts)', priceXof: 1000, cauris: 250, premiumDays: 0),
    ShopProduct(id: 'cauris-700', kind: 'cauris', title: 'Grand sac de cauris', description: '700 cauris (200 offerts)', priceXof: 2500, cauris: 700, premiumDays: 0),
    ShopProduct(
      id: 'plus-30',
      kind: 'premium',
      title: 'KoumanPlay+ · 30 jours',
      description: 'Énergie illimitée et coffres doublés pendant 30 jours',
      priceXof: 1000,
      cauris: 0,
      premiumDays: 30,
    ),
  ];

  factory ShopProduct.fromRow(Map<String, dynamic> r) => ShopProduct(
    id: r['id'] as String,
    kind: r['kind'] as String,
    title: r['title'] as String,
    description: r['description'] as String? ?? '',
    priceXof: (r['price_xof'] as num).toInt(),
    cauris: (r['cauris'] as num?)?.toInt() ?? 0,
    premiumDays: (r['premium_days'] as num?)?.toInt() ?? 0,
  );
}

/// Début d'un paiement : lien de la page GeniusPay, ou message d'erreur.
class PaymentStart {
  const PaymentStart({required this.reference, required this.url}) : error = null;

  const PaymentStart.failed(String this.error) : reference = null, url = null;

  final String? reference;
  final String? url;
  final String? error;
}
