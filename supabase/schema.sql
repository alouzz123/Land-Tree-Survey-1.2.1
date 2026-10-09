-- À exécuter une seule fois dans Supabase > SQL Editor.
-- Activez aussi Authentication > Providers > Anonymous Sign-Ins.

create table if not exists public.placettes (
  id text not null,
  device_id text not null,
  user_id uuid not null default auth.uid(),
  pays text not null default 'Sénégal',
  region text not null,
  superficie double precision not null default 0,
  latitude double precision not null default 0,
  longitude double precision not null default 0,
  occupation_sol text not null default '',
  presence_culture boolean not null default false,
  presence_feux boolean not null default false,
  observations text not null default '',
  agent text not null default '',
  photo_path text,
  date_creation timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (id, device_id)
);

alter table public.placettes
  add column if not exists pays text not null default 'Sénégal';

create table if not exists public.arbres (
  id text not null,
  placette_id text not null,
  device_id text not null,
  user_id uuid not null default auth.uid(),
  nom_espece text not null,
  mode_inventaire text not null default 'dendrometrique',
  dap double precision not null default 0,
  type_tronc text not null default 'Tronc unique',
  nombre_troncs integer not null default 1 check (nombre_troncs >= 1),
  diametre_cumule double precision not null default 0,
  hauteur double precision not null default 0,
  diametre_couronne double precision,
  latitude double precision,
  longitude double precision,
  forme_tronc text,
  methode_hauteur text,
  distance_clinometre double precision,
  angle_cime double precision,
  angle_base double precision,
  houppier_ns double precision,
  houppier_eo double precision,
  etat_sanitaire text,
  observations text,
  volume_estime double precision not null default 0,
  photo_path text,
  date_creation timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (id, placette_id, device_id),
  foreign key (placette_id, device_id)
    references public.placettes (id, device_id)
    on delete cascade
);

-- Migration sûre pour une table arbres déjà existante.
alter table public.arbres
  add column if not exists mode_inventaire text not null default 'dendrometrique',
  add column if not exists type_tronc text not null default 'Tronc unique',
  add column if not exists nombre_troncs integer not null default 1,
  add column if not exists diametre_cumule double precision not null default 0,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists forme_tronc text,
  add column if not exists methode_hauteur text,
  add column if not exists distance_clinometre double precision,
  add column if not exists angle_cime double precision,
  add column if not exists angle_base double precision,
  add column if not exists houppier_ns double precision,
  add column if not exists houppier_eo double precision;

alter table public.placettes enable row level security;
alter table public.arbres enable row level security;

create policy "Agents insert own placettes"
on public.placettes for insert to authenticated
with check (auth.uid() = user_id);
create policy "Agents read own placettes"
on public.placettes for select to authenticated
using (auth.uid() = user_id);
create policy "Agents update own placettes"
on public.placettes for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Agents delete own placettes"
on public.placettes for delete to authenticated
using (auth.uid() = user_id);

create policy "Agents insert own arbres"
on public.arbres for insert to authenticated
with check (auth.uid() = user_id);
create policy "Agents read own arbres"
on public.arbres for select to authenticated
using (auth.uid() = user_id);
create policy "Agents update own arbres"
on public.arbres for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Agents delete own arbres"
on public.arbres for delete to authenticated
using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('land-tree-photos', 'land-tree-photos', false)
on conflict (id) do update set public = excluded.public;

create policy "Agents upload own Land Tree photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'land-tree-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "Agents update own Land Tree photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'land-tree-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'land-tree-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "Agents read own Land Tree photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'land-tree-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);
