import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';

/// Transforme la session anonyme en vrai compte, ou connecte un compte
/// existant (ex. nouveau téléphone).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signInMode = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid => _email.text.contains('@') && _password.text.length >= 6;

  Future<void> _submit() async {
    final backend = ref.read(backendProvider);
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_signInMode) {
        await backend.signIn(email: _email.text.trim(), password: _password.text);
        await ref.read(playerProvider.notifier).pullAfterSignIn();
        if (mounted) context.go('/play');
      } else {
        await backend.ensureSession();
        await backend.upgradeAccount(email: _email.text.trim(), password: _password.text);
        ref.read(analyticsProvider).track('account_created');
        setState(() => _info = 'Compte créé ! Vérifie ta boîte mail pour confirmer ton adresse.');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Impossible de joindre le serveur. Vérifie ta connexion.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(backendProvider);
    final theme = Theme.of(context);
    if (!backend.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon compte')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Connecté avec', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.gray500)),
              Text(backend.email ?? '', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Ta progression est sauvegardée automatiquement.'),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_signInMode ? 'Me connecter' : 'Sauvegarder ma progression')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text(
            _signInMode
                ? 'Retrouve ta progression sur ce téléphone. Attention : la partie en cours ici sera remplacée.'
                : 'Crée un compte pour retrouver ta progression si tu changes de téléphone.',
            style: const TextStyle(color: AppColors.gray700),
          ),
          const SizedBox(height: AppSpacing.section),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Mot de passe (6 caractères min.)'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!, style: const TextStyle(color: AppColors.green500, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpacing.section),
          FilledButton(
            onPressed: _valid && !_loading ? _submit : null,
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(_signInMode ? 'Me connecter' : 'Créer mon compte'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _signInMode = !_signInMode;
              _error = null;
              _info = null;
            }),
            child: Text(_signInMode ? 'Pas encore de compte ? Créer un compte' : 'J\'ai déjà un compte'),
          ),
        ],
      ),
    );
  }
}
