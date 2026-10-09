-- À exécuter dans Supabase > SQL Editor si la table arbres existe déjà.
alter table public.arbres
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

-- Initialise le diamètre cumulé des anciens arbres (tous considérés à tronc unique).
update public.arbres
set diametre_cumule = dap * greatest(nombre_troncs, 1)
where diametre_cumule = 0;

-- Récupère les valeurs structurées des anciens enregistrements. Les nouveaux
-- enregistrements sont déjà envoyés colonne par colonne par l'application.
update public.arbres
set
  latitude = coalesce(latitude, nullif(replace(substring(observations from 'GPS: *([-0-9.]+)'), ',', '.'), '')::double precision),
  longitude = coalesce(longitude, nullif(replace(substring(observations from 'GPS: *[-0-9.]+, *([-0-9.]+)'), ',', '.'), '')::double precision),
  forme_tronc = coalesce(forme_tronc, nullif(trim(substring(observations from 'Forme tronc: *([^•]+)')), '')),
  type_tronc = coalesce(nullif(trim(substring(observations from 'Type tronc: *([^•]+)')), ''), type_tronc),
  nombre_troncs = coalesce(nullif(substring(observations from 'Nombre troncs: *([0-9]+)'), '')::integer, nombre_troncs),
  methode_hauteur = coalesce(methode_hauteur, nullif(trim(substring(observations from 'Méthode hauteur: *([^•]+)')), '')),
  distance_clinometre = coalesce(distance_clinometre, nullif(replace(substring(observations from 'Clinomètre: distance *([-0-9.,]+)'), ',', '.'), '')::double precision),
  angle_cime = coalesce(angle_cime, nullif(replace(substring(observations from 'angle cime *([-0-9.,]+)'), ',', '.'), '')::double precision),
  angle_base = coalesce(angle_base, nullif(replace(substring(observations from 'angle base *([-0-9.,]+)'), ',', '.'), '')::double precision),
  houppier_ns = coalesce(houppier_ns, nullif(replace(substring(observations from 'Houppier: *([0-9.,]+)'), ',', '.'), '')::double precision),
  houppier_eo = coalesce(houppier_eo, nullif(replace(substring(observations from 'Houppier: *[0-9.,]+m? *x *([0-9.,]+)'), ',', '.'), '')::double precision)
where observations is not null;

-- Après extraction, observations redevient exclusivement le commentaire libre.
update public.arbres
set observations = coalesce(nullif(trim(substring(observations from 'Notes: *([^•]+)')), ''), '')
where observations ~ '(GPS:|Forme tronc:|Type tronc:|Nombre troncs:|Diamètre cumulé:|Méthode hauteur:|Clinomètre:|Houppier:|📸 Photo:)';
