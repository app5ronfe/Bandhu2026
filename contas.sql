-- Bandhu2026: contas com nome + PIN (só ACRESCENTA colunas e funções; não apaga nada)
create extension if not exists pgcrypto with schema extensions;
alter table public.bandhu_players add column if not exists pin_hash text;
alter table public.bandhu_players add column if not exists profile jsonb;
alter table public.bandhu_players add column if not exists updated_at timestamptz;

-- criar conta / definir PIN (só o aparelho dono do nome, ou nome ainda livre)
create or replace function public.bandhu_set_pin(p_name text, p_token uuid, p_pin text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare n text := btrim(p_name); k text := lower(btrim(p_name)); t uuid;
begin
  if char_length(n) not between 2 and 20 or p_pin !~ '^[0-9]{4}$' then return 'invalid'; end if;
  insert into bandhu_players(name_key, name, token) values (k, n, p_token) on conflict (name_key) do nothing;
  select token into t from bandhu_players where name_key = k;
  if t <> p_token then return 'taken'; end if;
  update bandhu_players set pin_hash = crypt(p_pin, gen_salt('bf')) where name_key = k;
  return 'ok';
end $$;

-- entrar noutro browser/telemóvel: devolve a chave da conta e o progresso guardado
create or replace function public.bandhu_login(p_name text, p_pin text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare r bandhu_players%rowtype;
begin
  select * into r from bandhu_players where name_key = lower(btrim(p_name));
  if not found then return json_build_object('status','nouser'); end if;
  if r.pin_hash is null then return json_build_object('status','nopin'); end if;
  if r.pin_hash <> crypt(coalesce(p_pin,''), r.pin_hash) then return json_build_object('status','badpin'); end if;
  return json_build_object('status','ok','name',r.name,'token',r.token,'profile',r.profile);
end $$;

-- guardar o progresso (só quem tem a chave da conta)
create or replace function public.bandhu_save_profile(p_name text, p_token uuid, p_profile jsonb)
returns text language plpgsql security definer set search_path = public as $$
begin
  if pg_column_size(p_profile) > 40000 then return 'invalid'; end if;
  update bandhu_players set profile = p_profile, updated_at = now()
   where name_key = lower(btrim(p_name)) and token = p_token and pin_hash is not null;
  if not found then return 'denied'; end if;
  return 'ok';
end $$;

-- ler o progresso mais recente ao abrir o jogo
create or replace function public.bandhu_load_profile(p_name text, p_token uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select profile from bandhu_players where name_key = lower(btrim(p_name)) and token = p_token;
$$;

revoke all on function public.bandhu_set_pin(text,uuid,text) from public;
revoke all on function public.bandhu_login(text,text) from public;
revoke all on function public.bandhu_save_profile(text,uuid,jsonb) from public;
revoke all on function public.bandhu_load_profile(text,uuid) from public;
grant execute on function public.bandhu_set_pin(text,uuid,text) to anon, authenticated;
grant execute on function public.bandhu_login(text,text) to anon, authenticated;
grant execute on function public.bandhu_save_profile(text,uuid,jsonb) to anon, authenticated;
grant execute on function public.bandhu_load_profile(text,uuid) to anon, authenticated;
