<!-- qubit:begin (seção criada por /qubit init; edite à vontade) -->
## Software factory (`/qubit`)
Este repo usa a fábrica `/qubit` (plugin `qubit`): um pedido vira spec, build num worktree isolado, gates determinísticos, revisão por especialistas e merge local. A stack vem do perfil em `factory/config.sh` (`FACTORY_PROFILE`).

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
- Nunca `git push`. O merge é local, na branch base (`FACTORY_BASE_BRANCH`), feito pelo orquestrador depois do `APPROVE`.
<!-- qubit:end -->
