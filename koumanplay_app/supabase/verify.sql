-- Vérifications après branchement (Supabase > SQL Editor).

-- 1. Progression synchronisée : une ligne par joueur.
select first_name, role, xp, updated_at, jsonb_object_keys(state->'levels') as niveau_joue
from public.player_states
order by updated_at desc;

-- 2. Événements reçus, par type.
select name, count(*) from public.events group by name order by count(*) desc;

-- 3. KPI.
select * from kpi.summary;
select * from kpi.questions;
select * from kpi.notes_partagees;
select * from kpi.langues;          -- parties et niveaux validés par langue (après 0002)

-- 4. (Optionnel) Nettoyer les données du joueur de test « Kouadio » avant les
--    vrais tests. Supprime son compte anonyme, sa progression et ses
--    événements (cascade).
-- delete from auth.users
-- where id in (select user_id from public.player_states where first_name = 'Kouadio');
