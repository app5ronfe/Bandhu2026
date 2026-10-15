-- Bandhu GO: classificações passam a devolver o fato e acessórios em uso (só substitui 2 funções de leitura)
create or replace function public.bandhu_leaderboard(p_name text default null, p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  with best as (
    select distinct on (lower(name)) name, score, created_at
    from public.bandhu_scores
    order by lower(name), score desc, created_at asc
  ), ranked as (
    select b.name, b.score, row_number() over (order by b.score desc, b.created_at asc) as pos,
           pl.profile->>'skin' as skin, pl.profile->'acc' as acc
    from best b left join public.bandhu_players pl on pl.name_key = lower(b.name)
  )
  select json_build_object(
    'top', (select coalesce(json_agg(t order by t.pos), '[]'::json)
            from (select name, score, pos, case when pos <= 3 then skin end as skin, case when pos <= 3 then acc end as acc
                  from ranked order by pos limit least(greatest(coalesce(p_limit,20),1),50)) t),
    'me', (select json_build_object('name',name,'score',score,'pos',pos) from ranked where lower(name) = lower(p_name) limit 1),
    'total', (select count(*) from best)
  );
$$;

create or replace function public.bandhu_tour_board(p_name text default null, p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  with best as (
    select distinct on (s.name_key) s.name_key, p.name, s.score, s.created_at, p.profile
    from bandhu_tour_scores s join bandhu_players p using (name_key)
    order by s.name_key, s.score desc, s.created_at asc
  ), ranked as (select name_key, name, score, profile, row_number() over (order by score desc, created_at asc) as pos from best)
  select json_build_object(
    'phase', bandhu_tour_phase(),
    'top', (select coalesce(json_agg(json_build_object('name',name,'score',score,'pos',pos,
              'skin', case when pos <= 3 then profile->>'skin' end, 'acc', case when pos <= 3 then profile->'acc' end) order by pos), '[]'::json)
            from (select * from ranked order by pos limit least(greatest(coalesce(p_limit,20),1),50)) t),
    'me', (select json_build_object('name',name,'score',score,'pos',pos) from ranked where name_key = lower(btrim(p_name))),
    'total', (select count(*) from best),
    'registered', (select count(*) from bandhu_tour_reg));
$$;
