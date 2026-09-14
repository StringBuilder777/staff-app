-- Additive staff-app support. Existing tables, columns, data, functions and
-- policies remain unchanged.

alter table public.integrantes
  add column if not exists nfc_token uuid default gen_random_uuid(),
  add column if not exists nfc_activa boolean not null default true,
  add column if not exists nfc_emitida_en timestamp with time zone,
  add column if not exists nfc_ultimo_leido_en timestamp with time zone,
  add column if not exists checkin_en timestamp with time zone,
  add column if not exists checkin_registrado_por uuid references public.staff(id),
  add column if not exists desayuno_en timestamp with time zone,
  add column if not exists desayuno_registrado_por uuid references public.staff(id),
  add column if not exists comida_en timestamp with time zone,
  add column if not exists comida_registrado_por uuid references public.staff(id);

alter table public.staff
  add column if not exists perfil_id uuid references public.perfiles(id);

create unique index if not exists integrantes_nfc_token_unique
  on public.integrantes (nfc_token)
  where nfc_token is not null;

create index if not exists integrantes_checkin_registrado_por_idx
  on public.integrantes (checkin_registrado_por);

create index if not exists integrantes_desayuno_registrado_por_idx
  on public.integrantes (desayuno_registrado_por);

create index if not exists integrantes_comida_registrado_por_idx
  on public.integrantes (comida_registrado_por);

create unique index if not exists staff_perfil_id_unique
  on public.staff (perfil_id)
  where perfil_id is not null;
