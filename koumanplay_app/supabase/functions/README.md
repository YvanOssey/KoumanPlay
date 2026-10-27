# Paiements en ligne (GeniusPay)

Wave, Orange Money, MTN MoMo et carte bancaire passent par GeniusPay
(pay.genius.ci). Les clés secrètes restent sur le serveur Supabase : jamais
dans l'app, jamais dans git.

## Parcours d'un achat

1. Dans la Boutique, le joueur choisit un produit et un moyen de paiement.
2. L'app appelle la fonction `create-payment`, qui crée le paiement chez
   GeniusPay et renvoie le lien de la page de paiement.
3. Le joueur paie sur la page GeniusPay.
4. GeniusPay prévient la fonction `geniuspay-webhook`. Elle vérifie la
   signature, relit le paiement chez GeniusPay, puis livre le produit :
   cauris dans `wallet_credits`, ou jours de KoumanPlay+ dans `premium`.
5. L'app récupère ses achats (`claim_wallet_credits`) dès que le paiement est
   confirmé, au retour dans l'app et à chaque démarrage.

## Mise en service

1. Dans l'éditeur SQL de Supabase, lancer `migrations/0006_boutique_paiements.sql`.
   Les prix se changent ensuite dans la table `shop_products`.
2. Ouvrir un compte marchand sur pay.genius.ci et récupérer les clés **sandbox**
   (`pk_sandbox_…`, `sk_sandbox_…`) et le secret de webhook (`whsec_sandbox_…`).
3. Installer la CLI Supabase, puis, depuis `koumanplay_app` :

   ```bash
   supabase login
   supabase link --project-ref <ref-du-projet>
   supabase secrets set GENIUSPAY_API_KEY=pk_sandbox_... GENIUSPAY_API_SECRET=sk_sandbox_... GENIUSPAY_WEBHOOK_SECRET=whsec_sandbox_...
   supabase functions deploy create-payment
   supabase functions deploy geniuspay-webhook --no-verify-jwt
   ```

4. Dans le tableau de bord GeniusPay, déclarer l'URL du webhook :
   `https://<ref-du-projet>.supabase.co/functions/v1/geniuspay-webhook`
5. Tester un achat en sandbox (carte de test GeniusPay : 4084 0841 1111 1111).
6. Pour passer en réel : remplacer les trois secrets par les clés `live` et
   refaire l'étape 4 avec le secret de webhook `live`.

## Version Play Store

Google impose son propre système de paiement pour les achats dans une app du
Play Store. Pour cette version, compiler avec `--dart-define=PAYMENTS_IN_APP=false` :
la boutique n'affiche plus les boutons de paiement, mais les achats faits sur
la version web (même compte) sont bien livrés.
