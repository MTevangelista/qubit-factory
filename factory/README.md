# Software factory (iOS / Swift)

Uma skill orquestradora, 8 subagentes e arquivos markdown como estado. Você pede uma feature, um bug ou um refactor; os agentes escrevem o spec, constroem em uma branch própria, passam por gates determinísticos, são revisados e então aprovados (merge local) ou escalados para você.

## Uso

```
/factory <descrição>                 # tipo inferido
/factory --bug <descrição>           # bug: teste de regressão obrigatório
/factory --refactor <descrição>      # refactor: sem mudar comportamento nem testes existentes
/factory next                        # primeiro item não marcado de factory/backlog.md
/factory status
/factory approve <job-id>            # merge de um job em needs-human, depois de você revisar
/factory rework <job-id> <nota>      # devolve ao builder com a sua nota
```

Dashboard: `python3 -m http.server -d factory 8000` e abra http://localhost:8000/dashboard.html.

## O loop

```
INIT (worktree + baseline) -> SPEC -> BUILD -> GATES --FAIL--> BUILD
                                                 |
                                               PASS
                                                 v
                      REVIEW (paralelo) --CHANGES--> BUILD   (até max_rounds)
                                                 |
                                               PASS
                                                 v
                                APPROVE -> gates de novo -> MERGE   |  ESCALATE -> needs-human
```

## Agentes

| Agente | Modelo | Papel | Escreve |
|---|---|---|---|
| `spec-writer` | opus | spec com ACs verificáveis | `spec.md` |
| `builder` | opus | implementa com testes, no worktree | commits + `build.md` |
| `reviewer-tests` | opus | verifica ACs e testes **sem ler `build.md`** | `review-tests.md` |
| `reviewer-code` | sonnet | correção, concorrência, performance | `review-code.md` |
| `reviewer-security` | opus | Keychain, ATS, privacidade, segredos | `review-security.md` |
| `reviewer-ui` | sonnet | Dynamic Type, dark mode, layout (só se tocar UI) | `review-ui.md` |
| `reviewer-ux` | sonnet | fluxo, estados, HIG (só se tocar UI e não for refactor) | `review-ux.md` |
| `approver` | opus | confere cada AC; `APPROVE` ou `ESCALATE` | `decision.md` |

## Garantias e controles

- **Gates sem LLM** (`scripts/factory-gates.sh`): segredos no diff, SwiftLint, build e testes. Falha de gate volta ao builder **sem gastar revisores**. Sem projeto configurado, os gates falham de propósito.
- **Baseline:** o estado antes do job é registrado; o builder só responde pelo que piorou.
- **Revisores independentes:** não leem `build.md`; rodam o código e conferem o diff.
- **Tipos de job:** bug exige teste que falha antes e passa depois; refactor exige caracterização antes e proíbe alterar testes existentes.
- **Custo:** `max_rounds` e `max_agent_calls` por job (`factory/config.sh`), registro de cada chamada em `job.json`.
- **Guarda** (`.claude/hooks/guard.sh`): bloqueia `git push`, `rm -rf` amplo e edição de gates/hooks/config dentro de worktrees.
- **Resiliência:** revisor sem arquivo válido roda de novo uma vez, depois escala; conflito de merge tem uma tentativa de rebase, depois escala.
- **Memória:** achados repetidos em 2+ jobs viram linha em `lessons.md`.
- **Autoteste:** `bash scripts/factory-selftest.sh` valida agentes, formatos de veredito, hook e gates sem gastar nenhuma chamada de LLM. Rode depois de mexer em qualquer prompt.
- **Estado:** `factory/jobs/` é local e ignorado pelo git; worktrees ficam em `../qubit-factory-factory/`.

## Limites conhecidos

- Os revisores têm `Bash` e `Write` (precisam rodar testes e gravar a revisão). "Não editar código" é regra de prompt, não barreira técnica; o hook só protege gates, hooks e config.
- Não há CI remoto: o gate local faz esse papel. Se adicionar CI, exija-o no passo MERGE.
- Antes de usar de verdade, preencha `factory/config.sh` e o `CLAUDE.md` quando o projeto Xcode existir.
