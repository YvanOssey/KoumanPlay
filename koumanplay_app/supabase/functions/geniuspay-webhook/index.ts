// Reçoit les notifications GeniusPay et livre le produit payé : cauris à
// récupérer (wallet_credits) ou jours de KoumanPlay+ (premium).
// Secrets : GENIUSPAY_API_KEY, GENIUSPAY_API_SECRET, GENIUSPAY_WEBHOOK_SECRET.
// À déployer sans vérification JWT : GeniusPay n'a pas de session Supabase.
//   supabase functions deploy geniuspay-webhook --no-verify-jwt
import { createClient } from 'npm:@supabase/supabase-js@2.45.4';

const GENIUSPAY_URL = 'https://pay.genius.ci/api/v1/merchant/payments';
const MAX_AGE_SECONDS = 300;

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function sameString(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/// Horodatage en secondes (accepte aussi des millisecondes ou une date ISO).
function toSeconds(timestamp: string): number {
  const n = Number(timestamp);
  if (Number.isFinite(n)) return n > 1e12 ? n / 1000 : n;
  return Date.parse(timestamp) / 1000;
}

Deno.serve(async (req) => {
  // Signature : HMAC-SHA256 de « timestamp.corps_brut » avec le secret du webhook.
  const raw = await req.text();
  const timestamp = req.headers.get('X-Webhook-Timestamp') ?? '';
  const signature = (req.headers.get('X-Webhook-Signature') ?? '').toLowerCase();
  const age = Math.abs(Date.now() / 1000 - toSeconds(timestamp));
  if (!Number.isFinite(age) || age > MAX_AGE_SECONDS) return new Response('horodatage invalide', { status: 401 });
  const expected = await hmacHex(Deno.env.get('GENIUSPAY_WEBHOOK_SECRET')!, `${timestamp}.${raw}`);
  if (!sameString(expected, signature)) return new Response('signature invalide', { status: 401 });

  const event = JSON.parse(raw);
  const reference: string | undefined = event?.data?.reference;
  if (!reference) return new Response('ok');

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: row } = await admin.from('payments').select('*').eq('reference', reference).maybeSingle();
  if (!row) return new Response('paiement inconnu');

  // On ne livre jamais sur la seule foi du webhook : on relit le paiement chez GeniusPay.
  const res = await fetch(`${GENIUSPAY_URL}/${encodeURIComponent(reference)}`, {
    headers: {
      'X-API-Key': Deno.env.get('GENIUSPAY_API_KEY')!,
      'X-API-Secret': Deno.env.get('GENIUSPAY_API_SECRET')!,
    },
  });
  if (!res.ok) return new Response('vérification impossible', { status: 502 });
  const payment = (await res.json())?.data ?? {};
  const status: string = payment.status ?? row.status;
  const paid = status === 'completed' && Number(payment.amount) >= row.amount_xof;

  await admin
    .from('payments')
    .update({
      status,
      payment_method: payment.payment_method ?? row.payment_method,
      completed_at: paid ? (payment.completed_at ?? new Date().toISOString()) : row.completed_at,
    })
    .eq('reference', reference);
  if (!paid || row.credited) return new Response('ok');

  // Livraison une seule fois, même si GeniusPay renvoie la notification.
  const { data: claimed } = await admin
    .from('payments')
    .update({ credited: true })
    .eq('reference', reference)
    .eq('credited', false)
    .select()
    .maybeSingle();
  if (!claimed) return new Response('ok');

  const { data: product } = await admin.from('shop_products').select('*').eq('id', row.product_id).single();
  if (product.cauris > 0) {
    await admin.from('wallet_credits').insert({ user_id: row.user_id, cauris: product.cauris, payment_reference: reference });
  }
  if (product.premium_days > 0) {
    const { data: current } = await admin.from('premium').select('premium_until').eq('user_id', row.user_id).maybeSingle();
    const start = Math.max(Date.now(), current ? Date.parse(current.premium_until) : 0);
    const until = new Date(start + product.premium_days * 24 * 3600 * 1000).toISOString();
    await admin.from('premium').upsert({ user_id: row.user_id, premium_until: until });
  }
  return new Response('ok');
});
