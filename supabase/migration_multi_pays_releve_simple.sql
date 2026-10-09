-- Migration Land.Tree Survey : configuration multi-pays et relevé simple.
-- À exécuter une seule fois dans Supabase > SQL Editor avant le nouveau build.

alter table public.placettes
  add column if not exists pays text not null default 'Sénégal';

alter table public.arbres
  add column if not exists mode_inventaire text not null default 'dendrometrique';

comment on column public.placettes.pays is
  'Pays choisi définitivement lors de la configuration locale du projet.';

comment on column public.arbres.mode_inventaire is
  'Protocole de collecte : dendrometrique ou simple.';

drop policy if exists "Agents delete own placettes" on public.placettes;
create policy "Agents delete own placettes"
on public.placettes for delete to authenticated
using (auth.uid() = user_id);

drop policy if exists "Agents delete own arbres" on public.arbres;
create policy "Agents delete own arbres"
on public.arbres for delete to authenticated
using (auth.uid() = user_id);
