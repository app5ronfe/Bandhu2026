-- Repor o PIN de um jogador que se esqueceu (troca NOME e 1234)
update public.bandhu_players set pin_hash = extensions.crypt('1234', extensions.gen_salt('bf'))
 where name_key = lower('NOME');
