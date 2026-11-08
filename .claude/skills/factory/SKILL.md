---
name: factory
description: Software factory para o projeto iOS (Swift). Use para rodar um job completo (spec, build, gates, revisão, aprovação, merge) de uma feature, bug ou refactor. Comandos - /factory <descrição>, /factory --bug|--refactor <descrição>, /factory next, /factory status, /factory approve <job-id>, /factory rework <job-id> <nota>.
---

# Orquestrador da fábrica

Você (a sessão que recebeu `/factory`) é o **orquestrador**. Você spawna os subagentes, roda os gates e é o **único escritor de `job.json`**. Cada subagente escreve só o seu arquivo de saída.

Regras gerais:

- Estado vive em arquivos em `factory/jobs/<job-id>/`, nunca na conversa. Passe aos agentes **caminhos**, não resumos.
- Raiz do repo = `$REPO`. Worktree do job = `../qubit-factory-factory/<job-id>` (`$WT`). Nunca trabalhe na raiz do repo, exceto para o merge final.
- Leia `factory/config.sh` (limites e comandos) e `factory/lessons.md` antes de começar.
- Responda ao usuário em português.

## Comandos

| Comando | Ação |
|---|---|
| `/factory <desc>` | Novo job. Tipo inferido (feature, bug, refactor) ou forçado com `--bug` / `--refactor` / `--feature`. |
| `/factory next` | Pega o primeiro item `- [ ]` de `factory/backlog.md`, marca `- [~] <job-id>` e roda. |
| `/factory status` | Lista jobs (id, tipo, status, rodada, chamadas de agente). Só lê `job.json`. |
| `/factory approve <id>` | Só para `needs-human`: roda o passo MERGE. |
| `/factory rework <id> <nota>` | Grava a nota em `human-note.md`, zera `round`, volta ao passo BUILD. |

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
  "events": [{"at": "ISO-8601", "agent": "builder", "model": "opus", "round": 1, "note": ""}]
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
Spawne `spec-writer` (opus). Entrada: descrição, tipo, caminho do job, `$WT`. Saída: `spec.md`.
O spec deve ter critérios de aceitação numerados e verificáveis (`AC-1`, `AC-2`...). Se o spec contiver uma seção `## Dúvidas bloqueantes` não vazia, pare com status `needs-human` e mostre as dúvidas ao usuário.

### 3. BUILD
Spawne `builder` (opus) com `cwd` = `$WT`. Entrada: `spec.md`, `lessons.md`, `baseline.md`, e na rodada > 1 os arquivos de `round-<n-1>/` e `gates.md`. Saída: commits em `factory/<id>` e `build.md`.
Na rodada de retrabalho, **retome o mesmo builder** (SendMessage) em vez de criar outro.

### 4. GATES (determinístico, sem LLM)
Rode `bash scripts/factory-gates.sh run "$WT"`. Saída em `round-<n>/gates.md` (primeira linha `GATES: PASS` ou `GATES: FAIL`).
- `FAIL`: não gaste revisores. Conte como rodada e volte ao BUILD com o `gates.md`.
- `PASS`: siga para REVIEW.

### 5. REVIEW
Decida os revisores a partir do diff (`git -C "$WT" diff --name-only master...HEAD`):

| Revisor | Quando roda | Modelo |
|---|---|---|
| `reviewer-tests` | sempre | opus |
| `reviewer-code` | sempre | sonnet |
| `reviewer-security` | sempre | opus |
| `reviewer-ui` | diff toca `*.swift` com `import SwiftUI`/`UIKit`, `*.xcassets`, `*.storyboard`, `*.xib`, `*.strings`, `*.xcstrings` | sonnet |
| `reviewer-ux` | mesma condição do `reviewer-ui` e tipo ≠ refactor | sonnet |

Grave a lista em `job.json.reviewers`. Spawne todos **em paralelo**, cada um escrevendo `round-<n>/review-<nome>.md`.
Os revisores **não leem `build.md`**: eles verificam o diff e rodam o código por conta própria.

**Resiliência:** a rodada só está completa quando todos os arquivos da lista existem e começam com `VERDICT: PASS` ou `VERDICT: CHANGES`. Arquivo ausente ou malformado: reexecute aquele revisor **uma vez**. Se falhar de novo, status `needs-human`.

### 6. DECIDIR
- Todos `PASS`: vá para APPROVE.
- Algum `CHANGES` e `round < max_rounds`: `round += 1`, volte ao BUILD passando os arquivos `CHANGES`.
- Algum `CHANGES` e `round == max_rounds`: vá para APPROVE mesmo assim (o approver tende a `ESCALATE`).

### 7. APPROVE
Spawne `approver` (opus). Entrada: `spec.md`, todos os `round-*/`, `baseline.md`. Saída: `decision.md`, primeira linha `APPROVE` ou `ESCALATE`.
Antes de aceitar `APPROVE`, rode os gates **de novo** no estado final. Se `FAIL`, trate como `ESCALATE`.

### 8. MERGE (só com `APPROVE`)
1. Na raiz do repo, em `master` limpa: `git merge --no-ff factory/<id> -m "feat(<id>): <título>"`. O prefixo segue o tipo (`feat`, `fix`, `refactor`).
2. **Conflito:** `git merge --abort`, uma tentativa de `git rebase master` dentro de `$WT` feita pelo builder (retome-o), gates de novo e tente o merge uma segunda vez. Se falhar de novo: `needs-human`, sem forçar nada.
3. Sucesso: status `merged`, remova o worktree (`git worktree remove`), marque `- [x]` no backlog se veio de `next`.

### 9. APRENDER
Depois de `merged` ou `needs-human`, leia os `review-*.md` e `decision.md`. Se um mesmo tipo de achado apareceu em 2+ jobs (compare com `lessons.md`), acrescente uma linha curta e acionável em `factory/lessons.md`. Não registre achados únicos.

## Tipos de job

- **feature:** spec com critérios de aceitação; testes novos cobrem cada AC.
- **bug:** o builder **primeiro escreve um teste que reproduz o bug e falha**, registra isso em `build.md` (com a saída da falha), e só então corrige. Sem teste de regressão, não há aprovação.
- **refactor:** comportamento externo não muda. O builder escreve testes de caracterização **antes** de mexer, e o diff não pode alterar testes existentes (só acrescentar). `reviewer-ux` não roda.

## Quando parar e perguntar ao usuário

Dúvidas bloqueantes no spec, estouro de `max_agent_calls`, revisor que falha duas vezes, conflito de merge persistente, `ESCALATE`. Mostre: o `job-id`, o motivo e o caminho do arquivo relevante. Nunca force merge, nunca faça push.
