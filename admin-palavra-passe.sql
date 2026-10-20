-- Definir (ou trocar) a palavra-passe de administrador da conta Raposa Astuta.
-- Troca A-TUA-PALAVRA-PASSE por uma palavra-passe forte (pelo menos 10 caracteres) e carrega em Run.
update public.bandhu_admins
   set pass_hash = extensions.crypt('A-TUA-PALAVRA-PASSE', extensions.gen_salt('bf'))
 where name_key = 'raposa astuta';
