<!-- qubit:begin (seção criada por /qubit init; edite à vontade) -->
## Software factory (`/qubit`)
Este repo usa a fábrica `/qubit` (plugin `qubit`): um pedido vira spec, build num worktree isolado, gates determinísticos, revisão por especialistas e abertura de MR (o merge é seu, no remoto). A stack vem do perfil em `factory/config.sh` (`FACTORY_PROFILE`).

### Projeto (preencha; os agentes leem esta seção)
- Linguagem e stack: _preencher_.
- Arquitetura: _preencher (ex.: camadas, padrão de estado, injeção de dependência)_.
- Estrutura de pastas: _preencher_.
- Como subir o app para screenshots (simulador, emulador ou navegador): _preencher_.

### Convenções
- Mensagens de commit em inglês, no imperativo: `type(scope): summary` (feat, fix, refactor, test, chore, docs).
- As convenções da stack ficam no perfil do plugin. Regras deste projeto que contrariem o perfil vão aqui e vencem o perfil.
- Dependência de terceiros só com aprovação explícita no spec. Segredos nunca no repo.

### Regras da fábrica
- Agentes **não** alteram `.claude/`, `factory/config.sh`, `factory/profiles/`, `factory/lessons.md` nem este arquivo dentro de um worktree (o hook do plugin bloqueia). Quem muda isso é uma pessoa.
- Branch do job no padrão conventional commits: `<type>/<job-id>` (`feat/`, `fix/`, `refactor/`), criada a partir da branch base (`FACTORY_BASE_BRANCH`).
- `git push` é permitido **só na branch do job**: push logo depois de criar a branch e depois de cada commit. Nunca force push e nunca push direto na branch base (o hook do plugin bloqueia os dois).
- A fábrica **não faz merge**. Depois do `APPROVE` (ou de `/qubit approve <job-id>`), o orquestrador abre o MR da branch do job para a branch base; o merge é de uma pessoa, no remoto.
<!-- qubit:end -->
