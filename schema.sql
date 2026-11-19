-- Execute no SQL Editor do Supabase. Crie usuários em Authentication > Users.
create extension if not exists pgcrypto;
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, role text not null default 'interviewer' check(role in ('admin','interviewer')));
create table public.communities (id integer generated always as identity primary key, name text unique not null);
insert into public.communities(name) values ('Santuário São Paulo da Cruz'),('Santa Luzia'),('Nossa Senhora da Conceição (Santa Margarida)'),('Nossa Senhora das Graças'),('São Pedro'),('Nossa Senhora Aparecida (Santa Helena)'),('São Judas Tadeu');
create table public.questions (id integer generated always as identity primary key, category text not null, title text not null, position integer not null default 0, active boolean not null default true);
insert into public.questions(category,title,position) values
('Estrutura','Como você avalia a conservação e a estrutura física da comunidade?',1),
('Acessibilidade','Como você avalia a facilidade de acesso à igreja?',2),
('Mobilidade','Como você avalia as condições de circulação e mobilidade?',3),
('Banheiros','Como você avalia a limpeza e as condições dos banheiros?',4),
('Bebedouros','Como você avalia a disponibilidade de água potável e bebedouros?',5),
('Cantina','Como você avalia o atendimento e a estrutura da cantina?',6),
('Acolhimento','Como você avalia o acolhimento oferecido pela comunidade?',7),
('Comunicação','Como você avalia a divulgação dos horários, eventos e atividades?',8),
('Pastoral','Como você avalia as oportunidades de participação pastoral?',9),
('Conforto','Como você avalia a iluminação, ventilação e conforto nas celebrações?',10);
-- Não há nome, CPF, telefone, IP ou vínculo entre entrevistado e entrevistador.
-- Faixa etária calculada no navegador, evitando armazenar nascimento exato.
create table public.responses (id uuid primary key default gen_random_uuid(), community_id integer not null references public.communities(id), age_band text not null check(age_band in ('0-17','18-29','30-44','45-59','60+','não informado')), sex text not null check(sex in ('Masculino','Feminino','Prefiro não informar')), created_at timestamptz not null default now());
create table public.answers (response_id uuid not null references public.responses(id) on delete cascade, question_id integer not null references public.questions(id), score integer check(score between 1 and 5), primary key(response_id,question_id));
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
create function public.submit_survey(p_community integer,p_age_band text,p_sex text,p_answers jsonb) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; item jsonb; v_q integer; v_score integer; v_count integer;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid()) then raise exception 'Acesso negado'; end if;
 if not exists(select 1 from public.communities where id=p_community) then raise exception 'Comunidade inválida'; end if;
 if p_age_band not in ('0-17','18-29','30-44','45-59','60+','não informado') or p_sex not in ('Masculino','Feminino','Prefiro não informar') then raise exception 'Dados inválidos'; end if;
 if jsonb_typeof(p_answers) <> 'array' then raise exception 'Respostas inválidas'; end if;
 select count(*) into v_count from public.questions where active;
 if jsonb_array_length(p_answers) <> v_count then raise exception 'Responda a todas as perguntas'; end if;
 insert into public.responses(community_id,age_band,sex) values(p_community,p_age_band,p_sex) returning id into v_id;
 for item in select * from jsonb_array_elements(p_answers) loop
   v_q := (item->>'question_id')::integer;
   v_score := nullif(item->>'score','')::integer;
   if not exists(select 1 from public.questions where id=v_q and active) or (v_score is not null and (v_score<1 or v_score>5)) then raise exception 'Resposta inválida'; end if;
   insert into public.answers(response_id,question_id,score) values(v_id,v_q,v_score);
 end loop;
 return v_id;
end $$;
-- Estatísticas somente agregadas, sem exposição de registros individuais.
create function public.survey_stats() returns table(community_id integer,question_id integer,score integer,total bigint) language sql stable security definer set search_path = '' as $$
 select r.community_id,a.question_id,a.score,count(*) from public.answers a join public.responses r on r.id=a.response_id where exists(select 1 from public.profiles where id=auth.uid()) group by r.community_id,a.question_id,a.score
$$;
revoke all on public.responses,public.answers from anon,authenticated;
revoke all on function public.submit_survey(integer,text,text,jsonb) from public,anon;
revoke all on function public.survey_stats() from public,anon;
grant execute on function public.submit_survey(integer,text,text,jsonb) to authenticated;
grant execute on function public.survey_stats() to authenticated;
alter table public.profiles enable row level security;
alter table public.communities enable row level security;
alter table public.questions enable row level security;
alter table public.responses enable row level security;
alter table public.answers enable row level security;
create policy "profile self" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy "admin profiles" on public.profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "communities read" on public.communities for select to authenticated using(true);
create policy "questions read" on public.questions for select to authenticated using(true);
create policy "admin questions" on public.questions for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin communities" on public.communities for all to authenticated using(public.is_admin()) with check(public.is_admin());
-- Para atualização ao vivo, o navegador consulta os agregados a cada 15 segundos.
