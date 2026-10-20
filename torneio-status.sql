-- Bandhu GO: o estado do torneio passa a dizer também se o inscrito é escuteiro (para o lembrete do formulário oficial)
create or replace function public.bandhu_tour_status(p_name text, p_token uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('phase', bandhu_tour_phase(),
    'registered', r.name_key is not null,
    'scout', r.scout)
  from (select 1) one
  left join bandhu_players p on p.name_key = lower(btrim(p_name)) and p.token = p_token
  left join bandhu_tour_reg r on r.name_key = p.name_key;
$$;
