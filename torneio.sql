-- Bandhu GO: Torneio Bandhu Oficial (só ACRESCENTA tabelas e funções)
-- Inscrições: qua 21/10 00:00 → sex 23/10 23:59 · Torneio: qui 22/10 00:00 → sex 23/10 23:59 (hora de Portugal)
create table if not exists public.bandhu_tour_reg (
  name_key text primary key references public.bandhu_players(name_key),
  full_name text not null check (char_length(full_name) between 3 and 80),
  age int not null check (age between 5 and 99),
  scout boolean not null,
  scout_group text check (char_length(scout_group) <= 60),
  parent_ok boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.bandhu_tour_scores (
  id bigserial primary key,
  name_key text not null references public.bandhu_players(name_key),
  score int not null check (score between 1 and 200000),
  meters int,
  created_at timestamptz not null default now()
);
alter table public.bandhu_tour_reg enable row level security;
alter table public.bandhu_tour_scores enable row level security;
revoke all on public.bandhu_tour_reg, public.bandhu_tour_scores from anon, authenticated;

create or replace function public.bandhu_tour_phase() returns text language sql stable as $$
  select case when now() < '2026-10-21 00:00+01' then 'soon'
              when now() < '2026-10-22 00:00+01' then 'reg'
              when now() < '2026-10-24 00:00+01' then 'live'
              else 'closed' end;
$$;

create or replace function public.bandhu_tour_register(p_name text, p_token uuid, p_full text, p_age int, p_scout boolean, p_group text, p_parent boolean)
returns text language plpgsql security definer set search_path = public as $$
declare k text := lower(btrim(p_name)); ph text := bandhu_tour_phase();
begin
  if ph not in ('reg','live') then return 'closed'; end if;
  if not exists (select 1 from bandhu_players where name_key = k and token = p_token and pin_hash is not null) then return 'denied'; end if;
  if char_length(btrim(coalesce(p_full,''))) < 3 or p_age is null or p_age not between 5 and 99 then return 'invalid'; end if;
  if p_age < 14 and not coalesce(p_parent,false) then return 'parent'; end if;
  insert into bandhu_tour_reg(name_key, full_name, age, scout, scout_group, parent_ok)
  values (k, btrim(p_full), p_age, coalesce(p_scout,false), nullif(btrim(coalesce(p_group,'')),''), coalesce(p_parent,false))
  on conflict (name_key) do update set full_name = excluded.full_name, age = excluded.age, scout = excluded.scout, scout_group = excluded.scout_group, parent_ok = excluded.parent_ok;
  return 'ok';
end $$;

create or replace function public.bandhu_tour_status(p_name text, p_token uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('phase', bandhu_tour_phase(),
    'registered', exists (select 1 from bandhu_tour_reg r join bandhu_players p using (name_key) where p.name_key = lower(btrim(p_name)) and p.token = p_token));
$$;

create or replace function public.bandhu_tour_submit(p_name text, p_token uuid, p_score int, p_meters int)
returns text language plpgsql security definer set search_path = public as $$
declare k text := lower(btrim(p_name));
begin
  if bandhu_tour_phase() <> 'live' then return 'closed'; end if;
  if not exists (select 1 from bandhu_players where name_key = k and token = p_token) then return 'denied'; end if;
  if not exists (select 1 from bandhu_tour_reg where name_key = k) then return 'notreg'; end if;
  if p_score is null or p_score < 1 or p_score > 200000 then return 'invalid'; end if;
  insert into bandhu_tour_scores(name_key, score, meters) values (k, p_score, p_meters);
  return 'ok';
end $$;

-- classificação pública do torneio (mostra só o nome do jogo, nunca o nome completo)
create or replace function public.bandhu_tour_board(p_name text default null, p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  with best as (
    select distinct on (s.name_key) s.name_key, p.name, s.score, s.created_at
    from bandhu_tour_scores s join bandhu_players p using (name_key)
    order by s.name_key, s.score desc, s.created_at asc
  ), ranked as (select name_key, name, score, row_number() over (order by score desc, created_at asc) as pos from best)
  select json_build_object(
    'phase', bandhu_tour_phase(),
    'top', (select coalesce(json_agg(json_build_object('name',name,'score',score,'pos',pos) order by pos), '[]'::json)
            from (select * from ranked order by pos limit least(greatest(coalesce(p_limit,20),1),50)) t),
    'me', (select json_build_object('name',name,'score',score,'pos',pos) from ranked where name_key = lower(btrim(p_name))),
    'total', (select count(*) from best),
    'registered', (select count(*) from bandhu_tour_reg));
$$;

revoke all on function public.bandhu_tour_register(text,uuid,text,int,boolean,text,boolean) from public;
revoke all on function public.bandhu_tour_status(text,uuid) from public;
revoke all on function public.bandhu_tour_submit(text,uuid,int,int) from public;
revoke all on function public.bandhu_tour_board(text,int) from public;
grant execute on function public.bandhu_tour_register(text,uuid,text,int,boolean,text,boolean) to anon, authenticated;
grant execute on function public.bandhu_tour_status(text,uuid) to anon, authenticated;
grant execute on function public.bandhu_tour_submit(text,uuid,int,int) to anon, authenticated;
grant execute on function public.bandhu_tour_board(text,int) to anon, authenticated;
