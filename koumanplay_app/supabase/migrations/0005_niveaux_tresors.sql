-- Nouveau type de niveau « tresors » : questions sur les œuvres de la Bibliothèque.
-- À lancer dans l'éditeur SQL de Supabase avant seed.sql. Relançable sans risque.

alter table public.levels drop constraint if exists levels_kind_check;
alter table public.levels add constraint levels_kind_check
  check (kind in ('mots', 'phrases', 'proverbes', 'tresors'));
