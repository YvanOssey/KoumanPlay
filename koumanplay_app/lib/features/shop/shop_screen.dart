import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/game_rules.dart';
import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../services/providers.dart';
import '../../widgets/cauris.dart';
import '../../widgets/common.dart';
import '../../widgets/links.dart';

final shopProductsProvider = FutureProvider.autoDispose<List<ShopProduct>?>(
  (ref) => AppConfig.demoShop ? Future.value(ShopProduct.catalog) : ref.read(backendProvider).fetchProducts(),
);

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String _price(int xof) {
  final digits = xof.toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$grouped FCFA';
}

/// Boutique : cauris et KoumanPlay+ payés en ligne (Wave, Orange Money,
/// MTN MoMo, carte), et accès aux objets d'avatar payés en cauris.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final backend = ref.watch(backendProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final premium = GameRules.isPremium(player, now);
    const demo = AppConfig.demoShop;
    final products = ref.watch(shopProductsProvider);
    final live = switch (products) {
      AsyncData(value: final list?) when list.isNotEmpty => list,
      _ => null,
    };
    // Sans réponse du serveur, les offres restent visibles mais pas achetables.
    final preview = !demo && live == null;
    final list = live ?? ShopProduct.catalog;

    return Scaffold(
      appBar: AppBar(title: const Text('Boutique')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(playerProvider.notifier).refreshPurchases();
          ref.invalidate(shopProductsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            AppCard(
              color: const Color(0xFFFFF4DC),
              border: false,
              child: Row(
                children: [
                  const CauriIcon(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${player.cauris} cauris',
                          style: theme.textTheme.titleLarge?.copyWith(color: caurisColor),
                        ),
                        Text(
                          premium
                              ? 'KoumanPlay+ actif jusqu\'au ${player.premiumUntil!.day} ${_months[player.premiumUntil!.month - 1]}'
                              : 'Gagne-en avec les coffres et les quêtes du jour.',
                          style: const TextStyle(color: AppColors.gray700, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Text('Objets d\'avatar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            AppCard(
              onTap: () => context.push('/avatar'),
              child: const Row(
                children: [
                  Icon(Icons.checkroom_rounded, color: AppColors.purple500),
                  SizedBox(width: 12),
                  Expanded(child: Text('Tenues, coiffures, bijoux et décors à débloquer avec tes cauris.')),
                  Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            if (AppConfig.paymentsInApp || demo) ...[
              if (demo) ...[
                const SizedBox(height: AppSpacing.section),
                const _Notice(
                  icon: Icons.slideshow_rounded,
                  text: 'Version de démonstration : les paiements sont simulés, aucun argent n\'est débité.',
                ),
              ] else if (products is AsyncLoading) ...[
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (preview) ...[
                const SizedBox(height: AppSpacing.section),
                const _Notice(
                  icon: Icons.schedule_rounded,
                  text: 'Les paiements en ligne ouvrent bientôt. Voici les offres prévues.',
                ),
              ] else if (backend.isAnonymous) ...[
                const SizedBox(height: AppSpacing.section),
                AppCard(
                  color: AppColors.purple100,
                  border: false,
                  onTap: () => context.push('/account'),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.purple500),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Crée un compte avant d\'acheter : tu garderas tes achats si tu changes de téléphone.',
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ],
              if (demo || products is! AsyncLoading) ...[
                const SizedBox(height: AppSpacing.section),
                Text('KoumanPlay+', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final p in list.where((p) => p.isPremium))
                  _ProductCard(product: p, highlight: true, enabled: !preview),
                const SizedBox(height: AppSpacing.section),
                Text('Packs de cauris', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final p in list.where((p) => !p.isPremium)) ...[
                  _ProductCard(product: p, enabled: !preview),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Paiement sécurisé par GeniusPay : Wave, Orange Money, MTN MoMo ou carte bancaire.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray500, fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, this.highlight = false, this.enabled = true});

  final ShopProduct product;
  final bool highlight;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      color: highlight ? AppColors.purple100 : null,
      border: !highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (product.isPremium)
                const Icon(Icons.workspace_premium_rounded, color: AppColors.purple500, size: 32)
              else
                const CauriIcon(size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (product.description.isNotEmpty)
                      Text(product.description, style: const TextStyle(color: AppColors.gray700, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (product.isPremium) ...[
            const SizedBox(height: 10),
            for (final perk in const [
              'Énergie illimitée',
              'Coffres doublés',
              'Soutiens la transmission de nos langues',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 18, color: AppColors.green500),
                    const SizedBox(width: 6),
                    Text(perk, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? () => _buy(context, ref, product) : null,
              child: Text(enabled ? 'Acheter · ${_price(product.priceXof)}' : 'Bientôt · ${_price(product.priceXof)}'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choix du moyen de paiement, puis page GeniusPay, puis attente de la livraison.
Future<void> _buy(BuildContext context, WidgetRef ref, ShopProduct product) async {
  final method = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => _MethodSheet(product: product),
  );
  if (method == null || !context.mounted) return;
  if (AppConfig.demoShop) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DemoCheckout(product: product, method: method),
    );
    return;
  }
  final start = await ref.read(backendProvider).createPayment(product.id, method);
  if (!context.mounted) return;
  if (start.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(start.error!)));
    return;
  }
  ref.read(analyticsProvider).track('payment_started', {'product': product.id, 'method': method});
  await openLink(context, start.url!);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentWaiting(reference: start.reference!, product: product),
  );
}

class _MethodSheet extends StatelessWidget {
  const _MethodSheet({required this.product});

  final ShopProduct product;

  static const methods = [
    ('wave', 'Wave', Color(0xFF1DC4FF)),
    ('orange', 'Orange Money', Color(0xFFFF7900)),
    ('mtn', 'MTN MoMo', Color(0xFFFFCC00)),
    ('card', 'Carte bancaire (Visa, Mastercard)', AppColors.purple500),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payer ${_price(product.priceXof)}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(product.title, style: const TextStyle(color: AppColors.gray500)),
            const SizedBox(height: 16),
            for (final (id, label, color) in methods) ...[
              AppCard(
                onTap: () => Navigator.pop(context, id),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: color,
                      child: Icon(
                        id == 'card' ? Icons.credit_card_rounded : Icons.phone_android_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Attend la confirmation du paiement (le serveur la reçoit de GeniusPay), puis
/// livre les cauris ou KoumanPlay+.
class _PaymentWaiting extends ConsumerStatefulWidget {
  const _PaymentWaiting({required this.reference, required this.product});

  final String reference;
  final ShopProduct product;

  @override
  ConsumerState<_PaymentWaiting> createState() => _PaymentWaitingState();
}

class _PaymentWaitingState extends ConsumerState<_PaymentWaiting> {
  static const _poll = Duration(seconds: 4);
  static const _giveUp = Duration(minutes: 5);

  Timer? _timer;
  late final DateTime _started = DateTime.now();
  String _status = 'pending';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_poll, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    final status = await ref.read(backendProvider).paymentStatus(widget.reference);
    _checking = false;
    if (!mounted || status == null) return;
    if (status == 'completed') {
      _timer?.cancel();
      await ref.read(playerProvider.notifier).refreshPurchases();
      ref.read(analyticsProvider).track('payment_completed', {'product': widget.product.id});
    } else if (DateTime.now().difference(_started) > _giveUp) {
      _timer?.cancel();
    }
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final done = _status == 'completed';
    final failed = const {'failed', 'cancelled', 'expired', 'refunded'}.contains(_status);
    return AlertDialog(
      icon: Icon(
        done ? Icons.check_circle_rounded : (failed ? Icons.error_rounded : Icons.hourglass_top_rounded),
        color: done ? AppColors.green500 : (failed ? AppColors.error : AppColors.purple500),
        size: 44,
      ),
      title: Text(done ? 'Paiement reçu !' : (failed ? 'Paiement non abouti' : 'Paiement en cours')),
      content: Text(
        done
            ? (widget.product.isPremium
                  ? 'KoumanPlay+ est activé. Bon jeu !'
                  : '${widget.product.cauris} cauris ont été ajoutés à ton sac.')
            : failed
            ? 'Le paiement a été annulé ou refusé. Aucun montant n\'a été débité pour cet achat.'
            : 'Termine le paiement sur la page qui s\'est ouverte, puis reviens ici. '
                  'La confirmation arrive en général en quelques secondes.',
        textAlign: TextAlign.center,
      ),
      actions: [
        if (!done && !failed) TextButton(onPressed: _check, child: const Text('J\'ai payé, vérifier')),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(done || failed ? 'Fermer' : 'Plus tard')),
      ],
    );
  }
}

/// Paiement simulé de la version de démonstration : même parcours que le vrai,
/// livré sur le téléphone, sans serveur ni argent débité.
class _DemoCheckout extends ConsumerStatefulWidget {
  const _DemoCheckout({required this.product, required this.method});

  final ShopProduct product;
  final String method;

  @override
  ConsumerState<_DemoCheckout> createState() => _DemoCheckoutState();
}

class _DemoCheckoutState extends ConsumerState<_DemoCheckout> {
  String _step = 'confirm';

  Future<void> _pay() async {
    setState(() => _step = 'paying');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await ref
        .read(playerProvider.notifier)
        .applyDemoPurchase(cauris: widget.product.cauris, premiumDays: widget.product.premiumDays);
    if (mounted) setState(() => _step = 'done');
  }

  @override
  Widget build(BuildContext context) {
    final (_, label, color) = _MethodSheet.methods.firstWhere((m) => m.$1 == widget.method);
    final product = widget.product;
    return switch (_step) {
      'confirm' => AlertDialog(
        icon: CircleAvatar(
          radius: 24,
          backgroundColor: color,
          child: Icon(
            widget.method == 'card' ? Icons.credit_card_rounded : Icons.phone_android_rounded,
            color: Colors.white,
          ),
        ),
        title: Text('Payer ${_price(product.priceXof)}'),
        content: Text(
          '${product.title}\navec $label\n\nDémonstration : aucun argent ne sera débité.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: _pay, child: const Text('Payer')),
        ],
      ),
      'paying' => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Paiement en cours…'),
          ],
        ),
      ),
      _ => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.green500, size: 44),
        title: const Text('Paiement reçu !'),
        content: Text(
          product.isPremium ? 'KoumanPlay+ est activé. Bon jeu !' : '${product.cauris} cauris ont été ajoutés à ton sac.',
          textAlign: TextAlign.center,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    };
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.purple100,
      border: false,
      child: Row(
        children: [
          Icon(icon, color: AppColors.purple500),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
