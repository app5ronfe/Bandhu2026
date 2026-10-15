-- Ver os inscritos no Torneio Bandhu e a melhor pontuação de cada um (o 1.º é o vencedor)
select row_number() over (order by best.score desc nulls last, best.first_at) as lugar,
       r.full_name as nome_completo, p.name as nome_no_jogo, r.age as idade,
       case when r.scout then 'Sim' else 'Não' end as escuteiro, r.scout_group as agrupamento,
       case when r.age < 14 then (case when r.parent_ok then 'Sim' else 'Não' end) else '—' end as autorizacao_pais,
       best.score as melhor_pontuacao, r.created_at as inscrito_em
from public.bandhu_tour_reg r
join public.bandhu_players p using (name_key)
left join lateral (select max(score) as score, min(created_at) filter (where true) as first_at
                   from public.bandhu_tour_scores s where s.name_key = r.name_key) best on true
order by lugar;
