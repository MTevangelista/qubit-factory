# qubit-factory

Este repo tem uma **software factory** (`/qubit`) que produz features, correções de bug e refactors com agentes. A fábrica é independente de linguagem: a stack vem do perfil escolhido em `factory/config.sh` (`FACTORY_PROFILE`), com os perfis em `plugins/qubit/profiles/` (ou em `factory/profiles/`, para sobrescrever um perfil só neste projeto). Detalhes em `factory/README.md`.

## Projeto
- Perfil da fábrica: `ios` (troque em `factory/config.sh` se a stack mudar).
- Linguagem e stack: Swift 6, UI em SwiftUI. Mínimo iOS: _preencher_.
- Arquitetura: _preencher (ex.: MVVM com @Observable, injeção por inicializador)_.
- Estrutura de pastas: _preencher quando o projeto existir_.
- Como subir o app para screenshots (simulador, emulador ou navegador): _preencher_.

## Comandos (a fábrica usa estes; mantenha em sincronia com `factory/config.sh`)
- Gates completos: `bash plugins/qubit/scripts/factory-gates.sh run .` (o resumo mostra os comandos exatos que rodaram)
- Build e testes: definidos pelo perfil ou por `FACTORY_BUILD_CMD` / `FACTORY_TEST_CMD` em `factory/config.sh`.
- Autoteste da fábrica: `bash plugins/qubit/scripts/factory-selftest.sh`

## Convenções
- Mensagens de commit em inglês, no imperativo: `type(scope): summary` (feat, fix, refactor, test, chore, docs).
- As convenções da stack (código, testes, segurança, UI, UX) ficam em `plugins/qubit/profiles/<perfil>.md`. Regras específicas deste projeto que contrariem o perfil vão aqui; elas vencem o perfil.
- Dependência de terceiros só com aprovação explícita no spec.
- Segredos nunca no repo; dados sensíveis no armazenamento seguro da plataforma.
- Todo texto de usuário localizável e acessível.

## Regras da fábrica
- Agentes **não** alteram `.claude/`, `plugins/qubit/`, `factory/config.sh`, `factory/profiles/`, `factory/lessons.md` nem este arquivo dentro de um worktree (o hook `guard.sh` bloqueia). Quem muda isso é uma pessoa.
- Branch do job no padrão conventional commits: `<type>/<job-id>` (`feat/`, `fix/`, `refactor/`), criada a partir da branch base (`FACTORY_BASE_BRANCH`, aqui `master`).
- `git push` é permitido **só na branch do job**: push logo depois de criar a branch e depois de cada commit. Nunca force push e nunca push direto na branch base (o hook `guard.sh` bloqueia os dois).
- A fábrica **não faz merge**. Depois do `APPROVE` (ou de `/qubit approve <job-id>`), o orquestrador abre o MR da branch do job para a branch base; o merge é de uma pessoa, no remoto.
