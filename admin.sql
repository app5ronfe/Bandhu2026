-- Bandhu GO: vista de administrador das inscrições do torneio (só ACRESCENTA)
create table if not exists public.bandhu_admins (
  name_key text primary key references public.bandhu_players(name_key),
  pass_hash text
);
alter table public.bandhu_admins enable row level security;
revoke all on public.bandhu_admins from anon, authenticated;
insert into public.bandhu_admins(name_key) values ('raposa astuta') on conflict do nothing;

-- o jogo pergunta se esta conta é de administrador (não revela nada além disso)
create or replace function public.bandhu_admin_check(p_name text, p_token uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('admin', exists (select 1 from bandhu_admins a join bandhu_players p using (name_key)
                                            where a.name_key = lower(btrim(p_name)) and p.token = p_token));
$$;

-- lista completa das inscrições: precisa da conta certa E da palavra-passe de administrador
create or replace function public.bandhu_admin_regs(p_name text, p_token uuid, p_pass text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare a bandhu_admins%rowtype;
begin
  select ad.* into a from bandhu_admins ad join bandhu_players p using (name_key)
   where ad.name_key = lower(btrim(p_name)) and p.token = p_token;
  if not found then return json_build_object('status','denied'); end if;
  if a.pass_hash is null then return json_build_object('status','nopass'); end if;
  if a.pass_hash <> crypt(coalesce(p_pass,''), a.pass_hash) then perform pg_sleep(1.5); return json_build_object('status','badpass'); end if;
  return json_build_object('status','ok','rows', (select coalesce(json_agg(x order by x.best desc nulls last, x.created_at), '[]'::json) from (
    select p.name as nick, r.full_name, r.age, r.scout, r.scout_group, r.parent_ok, r.created_at,
           (select max(s.score) from bandhu_tour_scores s where s.name_key = r.name_key) as best
    from bandhu_tour_reg r join bandhu_players p using (name_key)) x));
end $$;

revoke all on function public.bandhu_admin_check(text,uuid) from public;
revoke all on function public.bandhu_admin_regs(text,uuid,text) from public;
grant execute on function public.bandhu_admin_check(text,uuid) to anon, authenticated;
grant execute on function public.bandhu_admin_regs(text,uuid,text) to anon, authenticated;
