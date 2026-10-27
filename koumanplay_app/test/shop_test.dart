import 'package:flutter_test/flutter_test.dart';
import 'package:koumanplay/core/game_rules.dart';
import 'package:koumanplay/models/avatar.dart';
import 'package:koumanplay/models/player.dart';

void main() {
  final now = DateTime(2026, 10, 27, 12);
  PlayerState fresh({int cauris = 50}) => PlayerState.initial().copyWith(onboarded: true, cauris: cauris);

  test('une pièce payante se débloque une fois avec des cauris', () {
    final p = fresh();
    expect(p.ownsItem('outfit:wax'), isFalse);
    final bought = GameRules.buyItem(p, 'outfit:wax', now)!;
    expect(bought.ownsItem('outfit:wax'), isTrue);
    expect(bought.cauris, 50 - AvatarConfig.priceOf('outfit:wax'));
    // Déjà acquise : plus rien à payer.
    expect(GameRules.buyItem(bought, 'outfit:wax', now)!.cauris, bought.cauris);
    // Pas assez de cauris : refusé.
    expect(GameRules.buyItem(fresh(cauris: 5), 'outfit:bogolan', now), isNull);
  });

  test("le coût d'un avatar ne compte que les pièces payantes pas encore acquises", () {
    const avatar = AvatarConfig(outfit: 'wax', background: 'lagune', accessories: {'lunettes', 'collier'});
    final p = fresh();
    expect(
      GameRules.avatarCost(p, avatar),
      AvatarConfig.priceOf('outfit:wax') +
          AvatarConfig.priceOf('background:lagune') +
          AvatarConfig.priceOf('accessory:collier'),
    );
    expect(GameRules.avatarCost(p, AvatarConfig.youngDefault), 0);
  });

  test("les pièces déjà portées avant la boutique restent acquises", () {
    const avatar = AvatarConfig(outfit: 'bogolan');
    final json = fresh().copyWith(avatar: avatar).toJson()..remove('ownedItems');
    expect(PlayerState.fromJson(json).ownsItem('outfit:bogolan'), isTrue);
  });

  test('KoumanPlay+ : énergie illimitée et coffres doublés tant qu\'il est actif', () {
    final premium = fresh().copyWith(premiumUntil: now.add(const Duration(days: 30)));
    expect(GameRules.isPremium(premium, now), isTrue);
    expect(GameRules.loseEnergy(premium, now), same(premium));
    expect(GameRules.energyAt(premium.copyWith(energy: 0, energySince: now), now), PlayerState.maxEnergy);
    expect(GameRules.isPremium(premium, now.add(const Duration(days: 31))), isFalse);
  });

  test('les achats en ligne livrés ajoutent les cauris et prolongent KoumanPlay+', () {
    final p = fresh();
    final until = now.add(const Duration(days: 30));
    final paid = GameRules.applyPurchases(p, cauris: 250, premiumUntil: until, now: now);
    expect(paid.cauris, p.cauris + 250);
    expect(paid.premiumUntil, until);
    // Une date plus ancienne ne raccourcit pas l'abonnement.
    final again = GameRules.applyPurchases(paid, cauris: 0, premiumUntil: now, now: now);
    expect(again.premiumUntil, until);
    // Rien de neuf : le joueur ne change pas.
    expect(GameRules.applyPurchases(paid, cauris: 0, premiumUntil: until, now: now), same(paid));
  });
}
