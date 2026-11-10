-- Caixinha de Promessas: sorteio sem repetição entre convidados.
-- Cole tudo no SQL Editor do Supabase e clique em Run (uma vez só).

create table if not exists public.sorteios (
  versiculo  smallint primary key check (versiculo between 0 and 299),
  convidado  uuid not null unique,
  criado_em  timestamptz not null default now()
);

-- Ninguém lê nem escreve a tabela direto pela internet; só a função abaixo.
alter table public.sorteios enable row level security;

create or replace function public.sortear_versiculo(p_convidado uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v int;
  restantes int;
begin
  -- Um sorteio por vez: duas pessoas tocando no mesmo segundo nunca recebem o mesmo.
  perform pg_advisory_xact_lock(727274);

  -- Quem já tirou recebe sempre o mesmo versículo.
  select s.versiculo into v from sorteios s where s.convidado = p_convidado;

  if v is null then
    select g into v
      from generate_series(0, 299) as g
     where not exists (select 1 from sorteios s where s.versiculo = g)
     order by random()
     limit 1;

    if v is null then
      return json_build_object('versiculo', null, 'restantes', 0);  -- caixinha esgotada
    end if;

    insert into sorteios (versiculo, convidado) values (v, p_convidado);
  end if;

  select 300 - count(*) into restantes from sorteios;
  return json_build_object('versiculo', v, 'restantes', restantes);
end;
$$;

revoke all on function public.sortear_versiculo(uuid) from public;
grant execute on function public.sortear_versiculo(uuid) to anon, authenticated;

-- Para zerar a caixinha depois dos testes:
--   truncate table public.sorteios;
