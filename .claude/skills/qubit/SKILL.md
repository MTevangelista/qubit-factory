---
name: qubit
description: Software factory independente de linguagem (a stack vem do perfil em factory/config.sh). Use para rodar um job completo (spec, build, gates, revisão, aprovação, merge) de uma feature, bug ou refactor. Comandos - /qubit <descrição>, /qubit --bug|--refactor <descrição>, /qubit next, /qubit status, /qubit approve <job-id>, /qubit rework <job-id> <nota>.
---

# Orquestrador da fábrica

Você (a sessão que recebeu `/qubit`) é o **orquestrador**. Você spawna os subagentes, roda os gates e é o **único escritor de `job.json`**. Cada subagente escreve só o seu arquivo de saída.

Regras gerais:

- Estado vive em arquivos em `factory/jobs/<job-id>/`, nunca na conversa. Passe aos agentes **caminhos**, não resumos.
- Raiz do repo = `$REPO`. Pasta do job = `$REPO/factory/jobs/<job-id>` (`$JOB`). Worktree do job = `../qubit-factory-factory/<job-id>` (`$WT`). Nunca trabalhe na raiz do repo, exceto para o merge final.
- Leia `factory/config.sh` (limites, comandos e `FACTORY_PROFILE`) antes de começar. O perfil de stack é `$PROFILE` = `$REPO/factory/profiles/<FACTORY_PROFILE>.md`; se o arquivo não existir, pare e avise o usuário. Passe `$PROFILE` a **todo** agente (exceto `learner`). Você não lê o perfil nem `lessons.md`: eles são para os agentes.
- Responda ao usuário em português.

## Antes de começar: modelo da sessão
Você, orquestrador, roda no modelo **da sessão**, não num modelo fixo. O seu trabalho é disparar agentes, ler primeiras linhas e atualizar `job.json`: isso não precisa de Opus 5.5. Medição real de um fluxo equivalente (geração anterior de modelos): US$ 2,65 com orquestrador em Haiku contra US$ 43,68 em Opus.
Se a sessão estiver em Opus, avise em uma linha antes do INIT: "a sessão está em Opus; troque para Sonnet 5.5 (ou Haiku 5.5) e rode de novo para cortar o custo do orquestrador". Continue se a pessoa mandar seguir. Os subagentes têm `model` (ID exato da versão 5.5) e `effort` fixos no frontmatter, então o custo deles não muda com a sessão.

## Regra de contexto (dura)
O seu contexto precisa durar o job inteiro, com várias rodadas. Por isso:
- **Nunca leia inteiro** `spec.md`, `build.md`, `gates.md`, `review-*.md` nem `decision.md`. Decida pela **primeira linha** (`head -1 <arquivo>`) e pelo **relatório final** que cada agente devolve (bloco `RELATÓRIO <agente>`, no máximo 15 linhas).
- Leitura parcial permitida, só quando for mostrar algo ao usuário: uma seção por cabeçalho, com `sed -n '/^## Dúvidas bloqueantes/,/^## /p' <arquivo>` ou `sed -n '/^## Motivo/,$p' <arquivo>`.
- Para passar achados ao builder, passe **caminhos** dos arquivos, nunca um resumo seu.
- Saída de comandos longos (gates, build, teste) vai para arquivo; você lê só `head -1` ou um `rg` filtrado. Nunca deixe build ou teste imprimir no seu contexto.
- Repasse ao usuário o relatório do agente como veio, sem reescrever.
- Agente que não terminar com o bloco `RELATÓRIO`: confie só na primeira linha do arquivo. Se o arquivo também estiver malformado, aplique a regra de resiliência do passo correspondente.

## Esperar agentes (não cutucar)
- Dispare o agente e espere ele terminar. Nunca mande SendMessage do tipo "já acabou?" ou "como está?": cada mensagem dessas gasta contexto dos dois lados e interrompe o trabalho.
- Revisores em paralelo: dispare todos na mesma mensagem e espere todos os relatórios.
- Agente ou comando em background: espere a notificação de término. Não leia o arquivo de saída em laço nem use `sleep` para checar.
- Gates podem passar de 10 minutos (`GATE_TIMEOUT_SECONDS`): rode-os em background, com a saída redirecionada para o arquivo, e espere a notificação. Um único comando bloqueante, nunca polling.

## Comandos

| Comando | Ação |
|---|---|
| `/qubit <desc>` | Novo job. Tipo inferido (feature, bug, refactor) ou forçado com `--bug` / `--refactor` / `--feature`. |
| `/qubit next` | Pega o primeiro item `- [ ]` de `factory/backlog.md`, marca `- [~] <job-id>` e roda. |
| `/qubit status` | Lista jobs (id, tipo, status, rodada, chamadas de agente). Só lê `job.json`. |
| `/qubit approve <id>` | Só para `needs-human`: roda o passo MERGE. |
| `/qubit rework <id> <nota>` | Grava a nota em `human-note.md`, zera `round`, volta ao passo BUILD. |

## `job.json`

```json
{
  "id": "003-login-biometrico",
  "type": "feature | bug | refactor",
  "title": "...",
  "status": "spec | building | gates | reviewing | approving | merged | needs-human | failed",
  "round": 0,
  "max_rounds": 2,
  "max_agent_calls": 20,
  "branch": "factory/003-login-biometrico",
  "worktree": "../qubit-factory-factory/003-login-biometrico",
  "reviewers": [],
  "events": [{"at": "ISO-8601", "agent": "builder", "model": "claude-opus-5-5", "effort": "high", "round": 1, "note": ""}]
}
```

Atualize `job.json` a cada transição. Cada chamada de agente vira um item em `events`. **Se `len(events) >= max_agent_calls`, pare**: status `needs-human`, motivo em `decision.md` escrito por você (primeira linha `ESCALATE`).

## O loop

### 1. INIT
1. Calcule o próximo número `NNN` (maior prefixo em `factory/jobs/` + 1) e um slug curto. `id = NNN-slug`.
2. Crie `factory/jobs/<id>/` e o `job.json`.
3. Crie o worktree: `git worktree add -b factory/<id> ../qubit-factory-factory/<id> master`.
4. Rode `bash scripts/factory-gates.sh baseline "$WT"` e guarde a saída em `baseline.md`. Isso registra o que já estava quebrado antes do job; o builder e os gates só respondem pelo que ele mudou.

### 2. SPEC
Spawne `spec-writer` (`claude-opus-5-5`). Entrada: descrição, tipo, caminho do job, `$WT`, `$PROFILE`. Saída: `spec.md`.
O spec deve ter critérios de aceitação numerados e verificáveis (`AC-1`, `AC-2`...). Se o relatório vier com `resultado: BLOQUEADO` (seção `## Dúvidas bloqueantes` não vazia), pare com status `needs-human` e mostre as dúvidas do relatório ao usuário. Não leia o spec para isso.

### 3. BUILD
Spawne `builder` (`claude-opus-5-5`) com `cwd` = `$WT`. Entrada: `spec.md`, `lessons.md`, `baseline.md`, `$PROFILE`, e na rodada > 1 os arquivos de `round-<n-1>/` e `gates.md`. Saída: commits em `factory/<id>` e `build.md`.
Na rodada de retrabalho, **retome o mesmo builder** (SendMessage) em vez de criar outro.

### 4. GATES (determinístico, sem LLM)
Rode `bash scripts/factory-gates.sh run "$WT" > "$JOB/round-<n>/gates.md" 2>&1` (em background se puder passar de 10 min) e leia só `head -1` (`GATES: PASS` ou `GATES: FAIL`).
- `FAIL`: não gaste revisores. Conte como rodada e volte ao BUILD com o `gates.md`.
- `PASS`: siga para REVIEW.

### 5. REVIEW
Decida os revisores. Para saber se o diff toca interface, rode `bash scripts/factory-gates.sh ui "$WT" | head -1` (`UI: yes` ou `UI: no`); quais arquivos contam como interface é definido pelo perfil, não por você.

| Revisor | Quando roda | Modelo |
|---|---|---|
| `reviewer-tests` | sempre | `claude-opus-5-5` |
| `reviewer-code` | sempre | `claude-sonnet-5-5` |
| `reviewer-security` | sempre | `claude-opus-5-5` |
| `reviewer-ui` | `UI: yes` | `claude-sonnet-5-5` |
| `reviewer-ux` | `UI: yes` e tipo ≠ refactor | `claude-sonnet-5-5` |

Grave a lista em `job.json.reviewers`. Spawne todos **em paralelo**, cada um com `$PROFILE` na entrada e escrevendo `round-<n>/review-<nome>.md`.
Os revisores **não leem `build.md`**: eles verificam o diff e rodam o código por conta própria.

**Resiliência:** a rodada só está completa quando todos os arquivos da lista existem e começam com `VERDICT: PASS` ou `VERDICT: CHANGES` (confira com `head -1`, não lendo o arquivo). Arquivo ausente ou malformado: reexecute aquele revisor **uma vez**. Se falhar de novo, status `needs-human`.

### 6. DECIDIR
- Todos `PASS`: vá para APPROVE.
- Algum `CHANGES` e `round < max_rounds`: `round += 1`, volte ao BUILD passando os arquivos `CHANGES`.
- Algum `CHANGES` e `round == max_rounds`: vá para APPROVE mesmo assim (o approver tende a `ESCALATE`).

### 7. APPROVE
Spawne `approver` (`claude-opus-5-5`). Entrada: `spec.md`, todos os `round-*/`, `baseline.md`, `$PROFILE`. Saída: `decision.md`, primeira linha `APPROVE` ou `ESCALATE` (leia com `head -1`).
Antes de aceitar `APPROVE`, rode os gates **de novo** no estado final (`> "$JOB/final-gates.md"`, só `head -1`). Se `FAIL`, trate como `ESCALATE`.
Em `ESCALATE`, mostre ao usuário só a seção `## Motivo` (`sed -n '/^## Motivo/,$p'`).

### 8. MERGE (só com `APPROVE`)
1. Na raiz do repo, em `master` limpa: `git merge --no-ff factory/<id> -m "feat(<id>): <title>"`. O prefixo segue o tipo (`feat`, `fix`, `refactor`) e o título vai em inglês, no imperativo (traduza o título do spec se preciso).
2. **Conflito:** `git merge --abort`, uma tentativa de `git rebase master` dentro de `$WT` feita pelo builder (retome-o), gates de novo e tente o merge uma segunda vez. Se falhar de novo: `needs-human`, sem forçar nada.
3. Sucesso: status `merged`, remova o worktree (`git worktree remove`), marque `- [x]` no backlog se veio de `next`.

### 9. APRENDER
Depois de `merged` ou `needs-human`, **não leia** os reviews você mesmo. Spawne `learner` (`claude-sonnet-5-5`, só leitura) com o caminho do job, de `factory/jobs/` e de `factory/lessons.md`. Registre a chamada em `events`; ela roda mesmo com `max_agent_calls` atingido.
- `resultado: NENHUMA`: nada a fazer.
- `resultado: LICOES`: acrescente ao fim de `factory/lessons.md`, na raiz do repo, cada linha do relatório que começa com `- `, como veio (`printf '%s\n' '<linha>' >> factory/lessons.md`).

## Tipos de job

- **feature:** spec com critérios de aceitação; testes novos cobrem cada AC.
- **bug:** o builder **primeiro escreve um teste que reproduz o bug e falha**, registra isso em `build.md` (com a saída da falha), e só então corrige. Sem teste de regressão, não há aprovação.
- **refactor:** comportamento externo não muda. O builder escreve testes de caracterização **antes** de mexer, e o diff não pode alterar testes existentes (só acrescentar). `reviewer-ux` não roda.

## Quando parar e perguntar ao usuário

Dúvidas bloqueantes no spec, estouro de `max_agent_calls`, revisor que falha duas vezes, conflito de merge persistente, `ESCALATE`. Mostre: o `job-id`, o motivo e o caminho do arquivo relevante. Nunca force merge, nunca faça push.
