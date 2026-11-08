# Software factory (iOS / Swift)

Uma skill orquestradora, 9 subagentes e arquivos markdown como estado. Você pede uma feature, um bug ou um refactor; os agentes escrevem o spec, constroem em uma branch própria, passam por gates determinísticos, são revisados e então aprovados (merge local) ou escalados para você.

## Uso

```
/qubit <descrição>                   # tipo inferido
/qubit --bug <descrição>             # bug: teste de regressão obrigatório
/qubit --refactor <descrição>        # refactor: sem mudar comportamento nem testes existentes
/qubit next                          # primeiro item não marcado de factory/backlog.md
/qubit status
/qubit approve <job-id>              # merge de um job em needs-human, depois de você revisar
/qubit rework <job-id> <nota>        # devolve ao builder com a sua nota
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

| Agente | Modelo / effort | Papel | Escreve |
|---|---|---|---|
| orquestrador (`/qubit`) | **o da sessão**: use Sonnet 5.5 ou Haiku 5.5 | dispara agentes, lê primeiras linhas, atualiza `job.json` | `job.json` |
| `spec-writer` | Opus 5.5 (`claude-opus-5-5`) / high | spec com ACs verificáveis | `spec.md` |
| `builder` | Opus 5.5 (`claude-opus-5-5`) / high | implementa com testes, no worktree | commits + `build.md` |
| `reviewer-tests` | Opus 5.5 (`claude-opus-5-5`) / high | verifica ACs e testes **sem ler `build.md`** | `review-tests.md` |
| `reviewer-code` | Sonnet 5.5 (`claude-sonnet-5-5`) / medium | correção, concorrência, performance | `review-code.md` |
| `reviewer-security` | Opus 5.5 (`claude-opus-5-5`) / high | Keychain, ATS, privacidade, segredos | `review-security.md` |
| `reviewer-ui` | Sonnet 5.5 (`claude-sonnet-5-5`) / medium | Dynamic Type, dark mode, layout (só se tocar UI) | `review-ui.md` |
| `reviewer-ux` | Sonnet 5.5 (`claude-sonnet-5-5`) / medium | fluxo, estados, HIG (só se tocar UI e não for refactor) | `review-ux.md` |
| `approver` | Opus 5.5 (`claude-opus-5-5`) / high | confere cada AC; `APPROVE` ou `ESCALATE` | `decision.md` |
| `learner` | Sonnet 5.5 (`claude-sonnet-5-5`) / low | propõe lições comparando com jobs anteriores (só leitura) | nada; o orquestrador grava `lessons.md` |

**Antes de rodar `/qubit`, troque o modelo da sessão para Sonnet 5.5 ou Haiku 5.5.** O orquestrador roda no modelo da sessão e acompanha o job inteiro; os agentes têm `model` (ID exato, não alias) e `effort` fixos no frontmatter, então o custo deles não depende da sessão. Num fluxo equivalente, com a geração anterior de modelos, a diferença medida foi de US$ 2,65 (Haiku) para US$ 43,68 (Opus).

## Garantias e controles

- **Gates sem LLM** (`scripts/factory-gates.sh`): segredos no diff, SwiftLint, build e testes. Falha de gate volta ao builder **sem gastar revisores**. Sem projeto configurado, os gates falham de propósito.
- **Baseline:** o estado antes do job é registrado; o builder só responde pelo que piorou.
- **Revisores independentes:** não leem `build.md`; rodam o código e conferem o diff.
- **Tipos de job:** bug exige teste que falha antes e passa depois; refactor exige caracterização antes e proíbe alterar testes existentes.
- **Custo:** `max_rounds` e `max_agent_calls` por job (`factory/config.sh`), registro de cada chamada em `job.json`.
- **Guarda** (`.claude/hooks/guard.sh`): bloqueia `git push`, `rm -rf` amplo e edição de gates/hooks/config dentro de worktrees.
- **Resiliência:** revisor sem arquivo válido roda de novo uma vez, depois escala; conflito de merge tem uma tentativa de rebase, depois escala.
- **Contexto do orquestrador:** cada agente termina com um bloco `RELATÓRIO` de até 15 linhas; o orquestrador decide por ele e pela primeira linha dos arquivos, sem ler spec, build, reviews nem decision inteiros. Ele também não manda mensagens de "já acabou?" para agentes em andamento.
- **Saída de build fora do contexto:** agentes com `Bash` usam `factory-gates.sh` (que resume) ou redirecionam `xcodebuild`/`swift test` para `factory/jobs/<id>/logs/` e leem só com `rg`.
- **Memória:** achados repetidos em 2+ jobs viram linha em `lessons.md` (o `learner` propõe, o orquestrador grava).
- **Autoteste:** `bash scripts/factory-selftest.sh` valida agentes, formatos de veredito, hook e gates sem gastar nenhuma chamada de LLM. Rode depois de mexer em qualquer prompt.
- **Estado:** `factory/jobs/` é local e ignorado pelo git; worktrees ficam em `../qubit-factory-factory/`.

## Limites conhecidos

- Os revisores têm `Bash` e `Write` (precisam rodar testes e gravar a revisão). "Não editar código" é regra de prompt, não barreira técnica; o hook só protege gates, hooks e config.
- Não há CI remoto: o gate local faz esse papel. Se adicionar CI, exija-o no passo MERGE.
- Antes de usar de verdade, preencha `factory/config.sh` e o `CLAUDE.md` quando o projeto Xcode existir.
