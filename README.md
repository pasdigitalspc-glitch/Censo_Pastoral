# Censo Pastoral — piloto

Aplicação web responsiva (HTML/CSS/JS) com Supabase Auth, PostgreSQL e gráficos agregados. Paleta azul-marinho e azul-claro inspirada na imagem fornecida. Não está hospedada nem conectada a um projeto real.

## Instalação
1. Crie um projeto no https://supabase.com.
2. No SQL Editor, execute integralmente `schema.sql`.
3. Em Authentication > Users, crie os usuários autorizados com e-mail e senha. Desabilite o cadastro público em Authentication > Providers/Settings (conforme interface vigente).
4. Para cada usuário, copie o UUID e execute no SQL Editor: `insert into public.profiles(id,role) values ('UUID_DO_USUARIO','admin');` ou `...,'interviewer');`. Apenas administradores devem receber `admin`.
5. Em Project Settings > API, copie URL do projeto e chave **publishable/anon** para `config.js`. Nunca exponha a chave `service_role`.
6. Hospede `index.html`, `config.js` e `logo.jpg` em um site HTTPS estático, como Netlify, Cloudflare Pages ou Vercel. Abra o endereço e entre com um usuário cadastrado.

## Funcionalidades
- Entrevistadores autenticados, sem acesso às respostas individuais.
- Local selecionado no começo de cada entrevista: Santuário São Paulo da Cruz (estrutura própria) ou uma das seis comunidades. Todas as sete unidades usam o mesmo questionário.
- Data de nascimento convertida no navegador para faixa etária, sem armazenar data exata.
- Sexo, inclusive opção de não informar.
- Escala de 1 a 5 e alternativa não aplicável.
- Administradores podem incluir e desativar perguntas. Recomenda-se definir perguntas oficiais antes da coleta para manter comparabilidade.
- Estatísticas por pergunta para o conjunto das sete unidades ou por unidade, inclusive a estrutura própria do Santuário, atualizadas automaticamente a cada 15 segundos (quase em tempo real).

## Limitações e cuidados antes do uso real
- É um piloto, não um sistema auditado para produção. Teste autenticação, permissões, regras SQL e concorrência.
- Não coletar nomes, contatos ou identificadores dos respondentes. A autenticação identifica somente o entrevistador, não o respondente.
- Em comunidades pequenas, combinações de idade e sexo podem aumentar risco de reidentificação. O banco só guarda faixa etária, mas recomenda-se publicar apenas agregados com tamanho mínimo de amostra.
- O painel exibe contagens agregadas; não há mecanismo de prevenção de entrevistas duplicadas, pois não há identificação do respondente.
- Mudanças de perguntas durante a pesquisa afetam a comparabilidade. Idealmente usar versões de questionário e datas de vigência em produção.
- O Supabase Auth pode ter logs técnicos de autenticação dos usuários; a afirmação de anonimato diz respeito aos respondentes, não aos entrevistadores.
- Configure política de retenção, aviso de privacidade, backup e governança LGPD antes de coleta pública.

## Atualização de banco já instalado
Se o SQL original já foi executado, **não execute novamente todo o schema**. Execute apenas: `insert into public.communities(name) values ('Santuário São Paulo da Cruz') on conflict (name) do nothing;`
