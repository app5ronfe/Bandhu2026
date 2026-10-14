-- Bandhu2026: classificação (melhor pontuação por nome, com posição geral). Só leitura.
create or replace function public.bandhu_leaderboard(p_name text default null, p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  with best as (
    select distinct on (lower(name)) name, score, created_at
    from public.bandhu_scores
    order by lower(name), score desc, created_at asc
  ), ranked as (
    select name, score, row_number() over (order by score desc, created_at asc) as pos from best
  )
  select json_build_object(
    'top', (select coalesce(json_agg(t order by t.pos), '[]'::json)
            from (select name, score, pos from ranked order by pos limit least(greatest(coalesce(p_limit,20),1),50)) t),
    'me', (select row_to_json(m) from (select name, score, pos from ranked where lower(name) = lower(p_name) limit 1) m),
    'total', (select count(*) from best)
  );
$$;
revoke all on function public.bandhu_leaderboard(text,int) from public;
grant execute on function public.bandhu_leaderboard(text,int) to anon, authenticated;
