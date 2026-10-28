-- Ligues de la semaine et duels entre amis (v1.7).
-- À lancer dans l'éditeur SQL de Supabase. Relançable sans risque.
--
-- Les joueurs ne lisent ni n'écrivent ces tables directement : tout passe par
-- les fonctions ci-dessous (security definer), qui ne montrent que le prénom
-- et l'avatar des autres joueurs.

-- ---------------------------------------------------------------- Ligues

-- Un joueur dans une semaine : sa ligue (0 Bronze, 1 Argent, 2 Or, 3 Baobab),
-- son groupe de 20 et l'XP gagné cette semaine.
create table if not exists public.league_members (
  week text not null,                         -- semaine ISO, ex. 2026-W44
  user_id uuid not null references auth.users (id) on delete cascade,
  tier smallint not null default 0 check (tier between 0 and 3),
  grp integer not null,
  name text not null default '',
  avatar jsonb,
  points integer not null default 0 check (points >= 0),
  updated_at timestamptz not null default now(),
  primary key (week, user_id)
);

create index if not exists league_members_group on public.league_members (week, tier, grp);

alter table public.league_members enable row level security;

-- Envoie l'XP de la semaine et renvoie le groupe du joueur, du premier au
-- dernier. À la première visite d'une semaine, le joueur est placé selon sa
-- semaine précédente : les 5 premiers montent, les 5 derniers descendent.
create or replace function public.league_sync(p_week text, p_points integer, p_name text, p_avatar jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cur_week text := to_char(now() at time zone 'utc', 'IYYY-"W"IW');
  prev_week text := to_char((now() at time zone 'utc') - interval '7 days', 'IYYY-"W"IW');
  me public.league_members;
  prev public.league_members;
  prev_rank integer;
  prev_size integer;
  new_tier smallint := 0;
  previous jsonb;
  board jsonb;
begin
  if uid is null then
    raise exception 'non connecté';
  end if;

  select * into prev from public.league_members where week = prev_week and user_id = uid;
  if prev.user_id is not null then
    select count(*) into prev_size from public.league_members
      where week = prev_week and tier = prev.tier and grp = prev.grp;
    select count(*) + 1 into prev_rank from public.league_members m
      where m.week = prev_week and m.tier = prev.tier and m.grp = prev.grp
        and (m.points > prev.points or (m.points = prev.points and m.updated_at < prev.updated_at));
    new_tier := prev.tier;
    if prev.points > 0 and prev_rank <= 5 and prev.tier < 3 then
      new_tier := prev.tier + 1;
    elsif prev_size >= 10 and prev_rank > prev_size - 5 and prev.tier > 0 then
      new_tier := prev.tier - 1;
    end if;
    previous := jsonb_build_object(
      'week', prev_week, 'tier', prev.tier, 'rank', prev_rank,
      'size', prev_size, 'points', prev.points, 'new_tier', new_tier
    );
  end if;

  select * into me from public.league_members where week = cur_week and user_id = uid;
  if me.user_id is null then
    -- Un seul placement à la fois par ligue : les groupes restent à 20.
    perform pg_advisory_xact_lock(hashtext('league:' || cur_week || ':' || new_tier));
    insert into public.league_members (week, user_id, tier, grp, name, avatar)
    values (
      cur_week, uid, new_tier,
      coalesce(
        (select grp from public.league_members
          where week = cur_week and tier = new_tier
          group by grp having count(*) < 20 order by grp limit 1),
        (select coalesce(max(grp), -1) + 1 from public.league_members where week = cur_week and tier = new_tier)
      ),
      left(coalesce(p_name, ''), 30), p_avatar
    )
    on conflict (week, user_id) do nothing;
  end if;

  -- L'XP ne fait que monter, et seulement pour la semaine en cours.
  update public.league_members set
    points = case when p_week = cur_week then greatest(points, least(coalesce(p_points, 0), 20000)) else points end,
    updated_at = case when p_week = cur_week and coalesce(p_points, 0) > points then now() else updated_at end,
    name = left(coalesce(nullif(trim(p_name), ''), name), 30),
    avatar = coalesce(p_avatar, avatar)
  where week = cur_week and user_id = uid
  returning * into me;

  select coalesce(jsonb_agg(jsonb_build_object(
      'name', m.name, 'avatar', m.avatar, 'points', m.points, 'me', m.user_id = uid
    ) order by m.points desc, m.updated_at), '[]'::jsonb)
    into board
    from public.league_members m
    where m.week = cur_week and m.tier = me.tier and m.grp = me.grp;

  return jsonb_build_object('week', cur_week, 'tier', me.tier, 'members', board, 'previous', previous);
end;
$$;

grant execute on function public.league_sync(text, integer, text, jsonb) to authenticated;

-- ---------------------------------------------------------------- Duels

-- Les deux joueurs reçoivent les mêmes questions (items + seed). Chacun envoie
-- son score une seule fois.
create table if not exists public.duels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  language_id text not null,
  items text[] not null,
  seed integer not null,
  creator uuid not null references auth.users (id) on delete cascade,
  creator_name text not null default '',
  creator_score integer,
  creator_ms integer,
  opponent uuid references auth.users (id) on delete set null,
  opponent_name text,
  opponent_score integer,
  opponent_ms integer,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days'
);

create index if not exists duels_creator on public.duels (creator, created_at desc);
create index if not exists duels_opponent on public.duels (opponent, created_at desc);

alter table public.duels enable row level security;

drop policy if exists "duels lisibles par leurs joueurs" on public.duels;
create policy "duels lisibles par leurs joueurs" on public.duels
  for select to authenticated
  using (auth.uid() = creator or auth.uid() = opponent);

-- Crée un duel avec un code à 6 caractères faciles à lire (sans 0, O, 1, I, L).
create or replace function public.duel_create(p_language text, p_items text[], p_seed integer, p_name text)
returns public.duels
language plpgsql
security definer
set search_path = public
as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  new_code text;
  d public.duels;
begin
  if auth.uid() is null then
    raise exception 'non connecté';
  end if;
  if coalesce(array_length(p_items, 1), 0) not between 1 and 20 then
    raise exception 'questions invalides';
  end if;
  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    begin
      insert into public.duels (code, language_id, items, seed, creator, creator_name)
      values (new_code, p_language, p_items, p_seed, auth.uid(), left(coalesce(p_name, ''), 30))
      returning * into d;
      return d;
    exception when unique_violation then
      -- Code déjà pris : on en tire un autre.
    end;
  end loop;
end;
$$;

-- Rejoint le duel d'un ami avec son code.
create or replace function public.duel_join(p_code text, p_name text)
returns public.duels
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.duels;
begin
  if auth.uid() is null then
    raise exception 'non connecté';
  end if;
  select * into d from public.duels where code = upper(trim(p_code)) for update;
  if d.id is null then
    raise exception 'duel introuvable';
  end if;
  if d.creator = auth.uid() or d.opponent = auth.uid() then
    return d;
  end if;
  if d.opponent is not null then
    raise exception 'duel déjà pris';
  end if;
  if d.expires_at < now() then
    raise exception 'duel expiré';
  end if;
  update public.duels set opponent = auth.uid(), opponent_name = left(coalesce(p_name, ''), 30)
  where id = d.id
  returning * into d;
  return d;
end;
$$;

-- Enregistre le score du joueur ; un score déjà envoyé ne change plus.
create or replace function public.duel_submit(p_id uuid, p_score integer, p_ms integer)
returns public.duels
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.duels;
  score integer;
begin
  if auth.uid() is null then
    raise exception 'non connecté';
  end if;
  select * into d from public.duels where id = p_id and (creator = auth.uid() or opponent = auth.uid()) for update;
  if d.id is null then
    raise exception 'duel introuvable';
  end if;
  score := least(greatest(coalesce(p_score, 0), 0), coalesce(array_length(d.items, 1), 0));
  update public.duels set
    creator_score = case when creator = auth.uid() and creator_score is null then score else creator_score end,
    creator_ms = case when creator = auth.uid() and creator_score is null then greatest(p_ms, 0) else creator_ms end,
    opponent_score = case when opponent = auth.uid() and opponent_score is null then score else opponent_score end,
    opponent_ms = case when opponent = auth.uid() and opponent_score is null then greatest(p_ms, 0) else opponent_ms end
  where id = d.id
  returning * into d;
  return d;
end;
$$;

grant execute on function public.duel_create(text, text[], integer, text) to authenticated;
grant execute on function public.duel_join(text, text) to authenticated;
grant execute on function public.duel_submit(uuid, integer, integer) to authenticated;
