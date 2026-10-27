// Crée un paiement GeniusPay pour un produit de la boutique et renvoie le lien
// de la page de paiement (Wave, Orange Money, MTN MoMo ou carte).
// Secrets : GENIUSPAY_API_KEY, GENIUSPAY_API_SECRET (jamais dans l'app),
// PAYMENT_RETURN_URL (page affichée après le paiement, facultative).
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const GENIUSPAY_URL = 'https://pay.genius.ci/api/v1/merchant/payments';

// Choix du joueur dans l'app -> code GeniusPay. Sans choix : page de paiement
// GeniusPay avec tous les moyens.
const METHODS: Record<string, string> = { wave: 'wave', orange: 'orange_money', mtn: 'mtn_money', card: 'card' };

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user) return json({ error: 'Connexion requise.' }, 401);

    const { product_id, method } = await req.json();
    const { data: product } = await admin
      .from('shop_products')
      .select('*')
      .eq('id', product_id)
      .eq('active', true)
      .maybeSingle();
    if (!product) return json({ error: 'Produit inconnu.' }, 400);

    const returnUrl = Deno.env.get('PAYMENT_RETURN_URL') ?? 'https://pay.genius.ci';
    const body: Record<string, unknown> = {
      amount: product.price_xof,
      currency: 'XOF',
      description: `KoumanPlay · ${product.title}`,
      success_url: `${returnUrl}?statut=ok`,
      error_url: `${returnUrl}?statut=erreur`,
      metadata: { user_id: auth.user.id, product_id: product.id },
    };
    if (typeof method === 'string' && METHODS[method]) body.payment_method = METHODS[method];

    const res = await fetch(GENIUSPAY_URL, {
      method: 'POST',
      headers: {
        'X-API-Key': Deno.env.get('GENIUSPAY_API_KEY')!,
        'X-API-Secret': Deno.env.get('GENIUSPAY_API_SECRET')!,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    const payload = await res.json().catch(() => ({}));
    const payment = payload?.data;
    if (!res.ok || !payment?.reference) {
      console.error('GeniusPay a refusé le paiement', res.status, payload);
      return json({ error: 'Le paiement n\'a pas pu être créé. Réessaie dans un instant.' }, 502);
    }

    const { error: insertError } = await admin.from('payments').insert({
      reference: payment.reference,
      user_id: auth.user.id,
      product_id: product.id,
      amount_xof: product.price_xof,
      payment_method: typeof method === 'string' ? method : null,
      status: payment.status ?? 'pending',
    });
    if (insertError) throw insertError;

    return json({ reference: payment.reference, checkout_url: payment.checkout_url ?? payment.payment_url });
  } catch (e) {
    console.error(e);
    return json({ error: 'Erreur du serveur de paiement.' }, 500);
  }
});
