# KoumanPlay — V1.2

Application Flutter (Android + web de démo) : on apprend les langues ivoiriennes en jouant, des premiers mots jusqu'aux proverbes, on gagne de l'XP et des badges, puis on relève des défis avec quelqu'un d'une autre génération.

## Parcours

Splash → onboarding (3 écrans) → prénom + profil Jeune/Aîné → **Accueil** (niveau, XP, série, « Continuer », défi à la une) → **Carte** → **Partie** (60 % de bonnes réponses pour valider) → **Résultat** (score, XP, badges, défi débloqué) → **Défis** (étapes, note, validation) → **Profil** (stats, badges, progression par langue, sauvegarde du compte).

**La carte** : une étape par langue — Baoulé (Akan), Bété (Krou), Dioula (Mandé), Sénoufo (Gour). Chaque langue a ses niveaux : *mots* (salutations, famille, nombres), puis *phrases* (se présenter, au quotidien), puis *proverbes*. Effet 3D léger : chemin en relief, boutons en volume qui s'enfoncent, niveau en cours qui flotte avec l'avatar, bandeaux d'étape en perspective, décor qui défile à plusieurs vitesses.

- Une étape s'ouvre quand toutes les étapes précédentes *qui ont du contenu* sont terminées.
- Un niveau sans contenu (moins de 4 mots, ou aucun proverbe) s'affiche « en préparation » et ne bloque pas la suite.
- Niveaux de mots/phrases : les questions sont générées automatiquement (traduire dans un sens puis dans l'autre, 4 choix tirés du même niveau). Il suffit donc de fournir la liste des mots.

- **Jouer d'abord** : aucune inscription au départ. Avec Supabase, une session anonyme est créée en silence ; le joueur peut ensuite créer un compte email depuis Profil sans perdre sa progression.
- **Hors-ligne** : contenu embarqué dans l'app, progression sauvegardée sur le téléphone, synchronisée quand le réseau revient.
- **XP** : 10 XP par mot, 20 XP par proverbe, réussis *la première fois* (rejouer ne permet pas de farmer), l'XP est gardé même si le niveau échoue, 200 XP par niveau joueur.

## Profil Aîné : transmettre

Le jeune **apprend**, l'aîné **transmet**. À l'inscription, l'aîné choisit la langue qu'il parle (et son village). Son accueil propose 4 grands boutons : **Des mots**, **Un proverbe**, **Un conte**, **Jouer**.

- **Accord** : avant le premier enregistrement, l'aîné accepte l'utilisation de sa voix et choisit d'afficher son prénom ou de rester anonyme.
- **Des mots** : l'app affiche un mot de la liste de collecte (« Comment dit-on *Merci* en Baoulé ? »), l'aîné appuie sur le micro et parle, réécoute, envoie. Même liste de 42 mots que `content/collecte_mots.csv`.
- **Un proverbe** : deux enregistrements (le proverbe, puis son explication) + traduction facultative.
- **Un conte** : un enregistrement jusqu'à 6 minutes + titre facultatif.
- **Hors-ligne** : les enregistrements attendent sur le téléphone et partent dès que le réseau revient.
- **Suivi** : « Mes transmissions » affiche *En attente d'envoi → En vérification → Publié dans le jeu*.
- **Reconnaissance** : XP (10 par mot, 30 par proverbe, 50 par conte), badges *Passeur de savoir*, *Gardien de la parole*, *Conteur*.

**Côté équipe** (Supabase, après `0003_transmissions.sql`) : table `contributions` (une ligne par transmission, avec le prénom de l'aîné s'il l'accepte, son village, la date de l'accord) et bucket privé `contributions` (les enregistrements). Pour chaque ligne : écouter, écrire le mot ou le proverbe dans `transcription`, puis passer `status` à `publie` (ou `refuse`). L'aîné voit le nouveau statut dans l'app. Pour l'ajouter au jeu : le reporter dans `words` ou `activities` avec son audio. Vue de suivi : `select * from kpi.transmissions;`.

## Lancer

```bash
flutter pub get
flutter test
flutter run                     # mode local, sans backend
flutter run -d chrome           # version web
```

Avec Supabase : copier `env.example.json` en `env.json` (non versionné), y mettre l'URL et la clé publishable du projet, puis :

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
flutter build web --release --dart-define-from-file=env.json
```

## Android : APK et Play Store

Prévoir **au moins 8 Go libres** sur le disque (Gradle télécharge ses outils au premier build).

**Windows avec un espace dans le nom d'utilisateur** : Gradle échoue avec `Unable to establish loopback connection`. Préfixer les commandes Android (Git Bash) :

```bash
JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:/Users/Public" flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```

ou définir une fois pour toutes la variable d'environnement Windows `JAVA_TOOL_OPTIONS` = `-Djdk.net.unixdomain.tmpdir=C:/Users/Public`.

`--split-per-abi` produit un APK par type de processeur dans `build/app/outputs/flutter-apk/` ; à distribuer aux testeurs : `app-arm64-v8a-release.apk` (quasi tous les téléphones récents), `app-armeabi-v7a-release.apk` pour les vieux Android.

**Clé de signature (une seule fois, à garder précieusement)** — sans elle, impossible de mettre à jour l'app sur le Play Store :

```bash
keytool -genkey -v -keystore C:/Users/VOUS/koumanplay-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Puis copier `android/key.properties.example` en `android/key.properties` et le remplir. Sans ce fichier, l'APK est signé avec la clé debug : installable pour les tests, refusé par le Play Store. Sauvegarder le `.jks` et les mots de passe hors de l'ordinateur (gestionnaire de mots de passe), jamais dans git.

Pour le Play Store, construire un bundle : `flutter build appbundle --release --dart-define-from-file=env.json`.

## Mettre en place Supabase

1. Créer un projet sur supabase.com (région la plus proche : Europe).
2. *Authentication > Providers* : activer **Anonymous sign-ins** et **Email**.
3. *SQL Editor* : exécuter dans l'ordre `supabase/migrations/0001_init.sql`, `0002_langues.sql`, `0003_transmissions.sql`, puis `supabase/seed.sql` (le contenu actuel). Projet déjà installé : exécuter seulement les migrations pas encore lancées.
4. Le contenu se gère ensuite directement dans le *Table Editor* (tables `words`, `activities`, `challenges`, `levels`, `languages`).

## Ajouter les mots collectés auprès des aînés

`content/collecte_mots.csv` (s'ouvre dans Excel) liste déjà, pour chaque langue et chaque niveau, les mots et phrases en français. Il reste à remplir la colonne `langue_locale` (et si possible `prononciation`, `audio`, `valide_par`). Aucun mot n'a été inventé : une ligne vide reste ignorée.

```bash
dart run tool/import_words.dart     # CSV → assets/content/content_v2.json
dart run tool/generate_seed.dart    # → supabase/seed.sql, à relancer dans Supabase
```

Un niveau devient jouable dès qu'il a 4 mots remplis. Les enregistrements audio se mettent dans Supabase *Storage* (bucket public), et leur URL dans la colonne `audio` : un bouton « écouter » apparaît alors dans la partie. L'app télécharge le contenu publié au démarrage et le garde en cache ; sans réseau, elle utilise la dernière version connue ou celle embarquée.

Pour vérifier que tout remonte (progression, événements, KPI) : `supabase/verify.sql`.

Après modification de `assets/content/content_v2.json`, régénérer le seed : `dart run tool/generate_seed.dart`.

## Mesurer (KPI investisseurs)

L'app envoie des événements (`app_open`, `onboarding_completed`, `level_started`, `answer`, `level_completed`, `badge_earned`, `challenge_started`, `challenge_completed`, `account_created`) dans la table `events`. Dans le SQL Editor :

```sql
select * from kpi.summary;          -- joueurs, activation, niveau validé, défi réalisé, rétention J+7
select * from kpi.questions;        -- taux de réussite par question
select * from kpi.notes_partagees;  -- proverbes collectés via les défis (avec accord du joueur)
select * from kpi.langues;          -- parties et niveaux validés par langue
```

## ⚠️ Avant de diffuser à de vrais utilisateurs

- **Contenu à collecter et valider** : aucun mot ni phrase n'est encore rempli (voir « Ajouter les mots collectés »). Les 15 proverbes (niveaux 6 à 8 du Baoulé) sont en français, brouillon (`"validated": false`) : à valider et à compléter avec leur version en Baoulé, avec le référent culturel (DEHE Firmin).
- **Identifiant Android** : `ci.koumanplay.koumanplay`. À confirmer avant la première publication sur le Play Store (il ne pourra plus changer).
- **Signature release Android** : voir la section Android ci-dessus (clé d'upload + `android/key.properties`).
- **Play Store** : avec un compte développeur personnel, Google impose un test fermé (environ 12 testeurs pendant 14 jours) avant la production. Le lancer tôt.
- **Police** : Poppins est chargée par `google_fonts` au premier lancement (réseau requis une fois). Pour un rendu 100 % hors-ligne, ajouter les fichiers `.ttf` dans `assets/fonts/` (voir la doc du package).

## Architecture

```
lib/
  main.dart                 démarrage, injection (prefs, Supabase, contenu)
  core/
    config.dart             clés passées par --dart-define
    game_rules.dart         règles pures : XP, étapes, niveaux, déblocages, badges, série
    lesson.dart             génération des questions d'un niveau
    router.dart             navigation (go_router)
    theme.dart              tokens du Design System V1
  models/                   contenu culturel + état du joueur (JSON)
  services/
    backend.dart            Supabase (tout échoue en silence hors-ligne)
    providers.dart          état Riverpod : contenu, joueur, analytics
  features/                 un dossier par écran/onglet (elder/ = profil Aîné, transmissions)
  widgets/common.dart       composants partagés
supabase/                   schéma SQL, vues KPI, seed
assets/content/             contenu embarqué
content/collecte_mots.csv   modèle de collecte des mots, à remplir avec les aînés
tool/                       import des mots, génération du seed
```

Prévu ensuite : vraie 3D (après le spike moteur prévu au cadrage), contes audio, boîte culturelle, énergie, notifications, espace admin dédié.
