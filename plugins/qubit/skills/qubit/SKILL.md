---
name: qubit
description: Software factory independente de linguagem (a stack vem do perfil em factory/config.sh). Use para rodar um job completo (spec, build, gates, revisão, aprovação, abertura de MR) de uma feature, bug ou refactor, ou para instalar a fábrica num projeto. Comandos - /qubit init [perfil], /qubit [JIRA-123] <descrição>, /qubit --bug|--refactor <descrição>, /qubit next, /qubit status, /qubit approve <job-id>, /qubit rework <job-id> <nota>, /qubit cleanup [job-id].
---

# Orquestrador da fábrica

Você (a sessão que recebeu `/qubit`) é o **orquestrador**. Você spawna os subagentes, roda os gates e é o **único escritor de `job.json`**. Cada subagente escreve só o seu arquivo de saída.

Regras gerais:

- Estado vive em arquivos em `factory/jobs/<job-id>/`, nunca na conversa. Passe aos agentes **caminhos**, não resumos.
- Raiz do repo = `$REPO`. Pasta do job = `$REPO/factory/jobs/<job-id>` (`$JOB`). Worktree do job = `$WTROOT/<job-id>` (`$WT`). Branch do job = `$BRANCH` (veja **Branch do job**). O código do job só muda dentro de `$WT`; na raiz do repo você só escreve em `factory/`.
- Leia `factory/config.sh` (limites, comandos e `FACTORY_PROFILE`) antes de começar. Você não lê o perfil nem `lessons.md`: eles são para os agentes.
- Passe `$PROFILE`, `$GATES` e `$BASE` a **todo** agente (exceto `learner`). Ao `builder`, passe também `$BRANCH`.
- A fábrica **não faz merge**: ela publica a branch do job e abre o MR (merge request; pull request no GitHub). O merge é de uma pessoa, no remoto.
- Os agentes têm nomes curtos (`builder`, `reviewer-code`...). Instalada como plugin, a fábrica os expõe como `qubit:builder` etc. Use o nome que aparecer na sua lista de agentes.

## Antes de qualquer comando: localizar a fábrica
1. `$FACTORY_HOME` = raiz da fábrica, duas pastas acima do diretório desta skill (o "Base directory" que o Claude Code mostra ao carregá-la). Resolva links: `FACTORY_HOME="$(cd -P "<base directory>" && cd ../.. && pwd)"`.
2. Exceto em `/qubit init`, rode `bash "$FACTORY_HOME/scripts/factory-gates.sh" info "$REPO"`.
   - `INFO: ERRO`: mostre as linhas ao usuário e pare. Se faltar `factory/config.sh`, sugira `/qubit init`.
   - `INFO`: guarde `$BASE` (linha `base:`), `$WTROOT` (`worktrees:`), `$PROFILE` (`profile_md:`), `$GATES` (`gates:`) e `$JIRA_MR_STATUS` (`jira_mr_status:`, pode vir vazio). Não invente esses valores. O script de limpeza é `$CLEANUP` = `$FACTORY_HOME/scripts/factory-cleanup.sh`.
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
| `/qubit init [perfil]` | Instala a fábrica no projeto atual (veja **Init**). Não roda job. |
| `/qubit <desc>` | Novo job. Tipo inferido (feature, bug, refactor) ou forçado com `--bug` / `--refactor` / `--feature`. Card do Jira opcional (veja **Card do Jira**). Antes do INIT, faça a **varredura de limpeza**. |
| `/qubit next` | Pega o primeiro item `- [ ]` de `factory/backlog.md`, marca `- [~] <job-id>` e roda. Antes do INIT, faça a **varredura de limpeza**. |
| `/qubit status` | Lista jobs (id, tipo, status, rodada, chamadas de agente, link do MR). Só lê `job.json`. |
| `/qubit approve <id>` | Só para `approving` (o approver deu `APPROVE`) ou `needs-human` (ex.: MR não abriu): é a aprovação da pessoa para **abrir o MR** (roda o passo MR). Nunca abre MR sem esse comando. Não faz merge. |
| `/qubit cleanup [id]` | Limpa jobs cujo MR já foi mergeado (veja **10. LIMPEZA**). Sem `id`, varre todos os jobs em `mr-open`. |
| `/qubit rework <id> <nota>` | Para `needs-human`, `approving` ou `mr-open` (ex.: mudança pedida no review do MR): grava a nota em `human-note.md`, zera `round`, volta ao passo BUILD. Se o worktree já foi removido, recrie-o antes: `git worktree add "$WT" "$BRANCH"`. |

## `job.json`

```json
{
  "id": "003-login-biometrico",
  "type": "feature | bug | refactor",
  "title": "...",
  "status": "spec | building | gates | reviewing | approving | mr-open | needs-human | failed | merged",
  "round": 0,
  "max_rounds": 2,
  "max_agent_calls": 20,
  "branch": "feat/003-login-biometrico",
  "mr": "",
  "jira": "",
  "worktree": "/caminho/meu-app-factory/003-login-biometrico",
  "reviewers": [],
  "events": [{"at": "ISO-8601", "agent": "builder", "model": "claude-opus-5-5", "effort": "high", "round": 1, "note": ""}]
}
```

`mr` guarda a URL do MR depois de aberto. `jira` guarda a chave do card (ex.: `ABC-123`), vazia se o job não veio do Jira. `merged` é o status final, gravado pela LIMPEZA. Atualize `job.json` a cada transição. Cada chamada de agente vira um item em `events`. **Se `len(events) >= max_agent_calls`, pare**: status `needs-human`, motivo em `decision.md` escrito por você (primeira linha `ESCALATE`).

## Init
`/qubit init [perfil]` prepara o projeto atual para a fábrica. Não cria job nem worktree.
1. Rode `bash "$FACTORY_HOME/scripts/factory-init.sh" "$REPO" [perfil]`. Sem perfil, o script detecta a stack.
2. Mostre a saída como veio. Ela lista o que foi criado, o que já existia (nunca sobrescreve) e o resultado do `info`.
3. Diga ao usuário o que falta ser feito por uma pessoa: preencher as seções `_preencher_` do `CLAUDE.md`, revisar `factory/config.sh` (no `ios`, `FACTORY_SCHEME`) e fazer commit desses arquivos na branch base, já publicada no remoto, antes do primeiro job (o worktree nasce da branch base, então a config precisa estar commitada; commit da base que não estiver no remoto entraria no MR do job). O projeto também precisa de um remoto `origin` e, para abrir o MR, da CLI do host (`gh` ou `glab`) autenticada.

## Card do Jira
O pedido pode trazer um card: `/qubit [--bug|--refactor|--feature] ABC-123 [descrição]`, ou a URL do card (`https://<site>.atlassian.net/browse/ABC-123`). A chave é o primeiro token no formato `[A-Z][A-Z0-9]+-[0-9]+` (ou o fim da URL `/browse/<chave>`); grave-a em `job.json.jira`. Item do backlog também pode começar com a chave.
- **Só a chave, sem descrição:** busque o card com a ferramenta do Jira da sua lista (Atlassian MCP: `getJiraIssue`; o `cloudId` vem de `getAccessibleAtlassianResources`) e grave o resumo e a descrição em `$JOB/jira.md`. Esse arquivo é a descrição que vai para o `spec-writer`. Sem a ferramenta, pare e peça a descrição ao usuário.
- **Chave e descrição:** a descrição do usuário vale; a chave só serve para mover o card (passo MR) e entra na descrição do MR.
- Sem card, o job segue igual e o Jira não é tocado.

## Branch do job
`$BRANCH` = `<prefixo>/<job-id>`, no padrão conventional commits. O prefixo vem do tipo do job:

| Tipo | Prefixo | Exemplo |
|---|---|---|
| feature | `feat` | `feat/003-login-biometrico` |
| bug | `fix` | `fix/004-crash-ao-abrir` |
| refactor | `refactor` | `refactor/005-extrair-cliente-http` |

O mesmo prefixo abre as mensagens de commit do builder e o título do MR. Grave `$BRANCH` em `job.json.branch` e leia de lá ao retomar um job; não recalcule.

Push: sempre com remoto e branch explícitos (`git -C "$WT" push origin "$BRANCH"`). Nunca force push, nunca push na branch base; o hook de guarda bloqueia os dois.

## O loop

### 1. INIT
1. Calcule o próximo número `NNN` (maior prefixo em `factory/jobs/` + 1) e um slug curto. `id = NNN-slug`.
2. Crie `factory/jobs/<id>/` e o `job.json`.
3. Crie o worktree já na branch do job: `git worktree add -b "$BRANCH" "$WTROOT/<id>" "$BASE"`.
4. Publique a branch logo depois de criá-la: `git -C "$WT" push -u origin "$BRANCH"`. Se o push falhar (sem remoto `origin`, sem permissão, sem rede), pare com status `needs-human` e mostre o erro: sem remoto não há MR.
5. Rode `bash "$GATES" baseline "$WT"` e guarde a saída em `baseline.md`. Isso registra o que já estava quebrado antes do job; o builder e os gates só respondem pelo que ele mudou.

### 2. SPEC
Spawne `spec-writer` (`claude-opus-5-5`). Entrada: descrição, tipo, caminho do job, `$WT`, `$PROFILE`. Saída: `spec.md`.
O spec deve ter critérios de aceitação numerados e verificáveis (`AC-1`, `AC-2`...). Se o relatório vier com `resultado: BLOQUEADO` (seção `## Dúvidas bloqueantes` não vazia), pare com status `needs-human` e mostre as dúvidas do relatório ao usuário. Não leia o spec para isso.

### 3. BUILD
Spawne `builder` (`claude-opus-5-5`) com `cwd` = `$WT`. Entrada: `spec.md`, `lessons.md`, `baseline.md`, `$PROFILE`, e na rodada > 1 os arquivos de `round-<n-1>/` e `gates.md`. Além do padrão, passe `$BRANCH`. Saída: commits em `$BRANCH`, **cada um já publicado** (o builder faz `git push origin "$BRANCH"` depois de cada commit), e `build.md`.
Na rodada de retrabalho, **retome o mesmo builder** (SendMessage) em vez de criar outro.

### 4. GATES (determinístico, sem LLM)
Rode `bash "$GATES" run "$WT" > "$JOB/round-<n>/gates.md" 2>&1` (em background se puder passar de 10 min) e leia só `head -1` (`GATES: PASS` ou `GATES: FAIL`).
- `FAIL`: não gaste revisores. Conte como rodada e volte ao BUILD com o `gates.md`.
- `PASS`: siga para REVIEW.

### 5. REVIEW
Decida os revisores. Para saber se o diff toca interface, rode `bash "$GATES" ui "$WT" | head -1` (`UI: yes` ou `UI: no`); quais arquivos contam como interface é definido pelo perfil, não por você.

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
- `APPROVE` com gates finais `PASS`: grave `status` = `approving` e **pare**. Não abra o MR. Mostre ao usuário a linha de resumo do `decision.md` e diga: "Aprovado pelo approver. Para abrir o MR, rode `/qubit approve <id>`." O MR só nasce com esse comando.
- `ESCALATE` (ou gates finais `FAIL`): status `needs-human`. Mostre ao usuário só a seção `## Motivo` (`sed -n '/^## Motivo/,$p'`).

### 8. MR (só com `/qubit approve <id>`, nunca automático)
Esta etapa roda **somente** quando a pessoa manda `/qubit approve <id>` num job em `approving` (ou `needs-human`, para retomar um MR que não abriu). Ao receber o comando, confira `job.json.status` e siga. Não entre nesta etapa logo depois do approver, mesmo com `APPROVE`.
Você abre o MR de `$BRANCH` para `$BASE`. Você **não faz merge**, nem local nem no remoto.
1. **Sincronize:** `git -C "$WT" fetch origin "$BASE"` e `git -C "$WT" push origin "$BRANCH"` (garante que todo commit está no remoto).
2. **Conflito com a base:** rode `git -C "$WT" merge-tree --write-tree HEAD "origin/$BASE" > /dev/null`; código de saída diferente de 0 é conflito. Nesse caso, retome o builder para **uma** tentativa de `git merge "origin/$BASE"` dentro de `$WT` (merge, nunca rebase: a branch já está publicada e force push é bloqueado), com commit e push; depois rode os gates de novo. Se o conflito ou os gates falharem de novo: `needs-human`, sem forçar nada.
3. **MR já aberto** (`job.json.mr` preenchido, job que voltou por `rework`): não abra outro; o push do item 1 já atualizou o MR. Pule para o item 6.
4. **Título e corpo:**
   - Título: `<prefixo>(<escopo>): <resumo>`, em inglês, no imperativo (traduza o título do job se preciso). O prefixo é o da branch; o escopo é a área afetada em uma palavra (na dúvida, o slug do job).
   - Corpo: monte por shell, **sem ler** os arquivos: `{ printf 'Job `%s` (%s), branch `%s`.\nAprovação: %s.\n' "<id>" "<tipo>" "$BRANCH" "<approver | pessoa, via /qubit approve>"; [ -n "<jira>" ] && printf 'Jira: %s\n' "<jira>"; printf '\n'; tail -n +2 "$JOB/decision.md"; } > "$JOB/mr-body.md"`.
5. **Abra o MR** conforme o host de `git -C "$REPO" remote get-url origin`:
   - GitHub: `gh pr create --base "$BASE" --head "$BRANCH" --title "<título>" --body-file "$JOB/mr-body.md"`.
   - GitLab: `glab mr create --source-branch "$BRANCH" --target-branch "$BASE" --title "<título>" --description "$(cat "$JOB/mr-body.md")" --yes`.
   - Sem a CLI do host: use a ferramenta de criar MR/PR desse host que estiver na sua lista de ferramentas (MCP), com os mesmos título, corpo, origem e destino.
   - Sem nenhuma das duas, ou se a criação falhar: status `needs-human`. Mostre o erro e diga à pessoa que a branch já está publicada e que basta abrir o MR à mão (título e `mr-body.md` prontos) ou instalar a CLI e rodar `/qubit approve <id>`.
6. **Sucesso:** grave a URL em `job.json.mr`, status `mr-open`, mostre a URL ao usuário, remova o worktree (`git worktree remove "$WT"`; a branch continua local e no remoto) e marque `- [x]` no backlog se veio de `next`.
7. **Card do Jira** (só se `job.json.jira` e `$JIRA_MR_STATUS` estiverem preenchidos): mova o card para o status `$JIRA_MR_STATUS` com a ferramenta do Jira da sua lista (Atlassian MCP):
   - `getTransitionsForJiraIssue` no card; escolha a transição cujo destino (`to.name`) ou nome é igual a `$JIRA_MR_STATUS`, sem diferenciar maiúsculas e espaços nas pontas. Se o card já estiver nesse status, não faça nada.
   - `transitionJiraIssue` com o id dessa transição.
   - Grave o resultado em `job.json.jira_moved`: o nome do status, ou `erro: <motivo>`. Não é chamada de agente: não entra em `events`.
   - **Falha aqui não muda o job:** o MR já está aberto e o status continua `mr-open`. Sem ferramenta do Jira, sem transição com esse nome (o workflow do board não permite ir direto para lá) ou erro da API: avise o usuário em uma linha, com os nomes das transições disponíveis, e siga.
   - Num `rework` de job com MR aberto, este item roda de novo (o card pode ter voltado de coluna no review).

Review, CI e merge do MR acontecem no remoto e são de uma pessoa. Mudança pedida no review volta pela fábrica com `/qubit rework <id> <nota>`. Depois do merge, o lixo do job sai na LIMPEZA.

### 9. APRENDER
Depois de `mr-open`, `needs-human` ou `approving` (job parado aguardando a pessoa), **não leia** os reviews você mesmo. Spawne `learner` (`claude-sonnet-5-5`, só leitura) com o caminho do job, de `factory/jobs/` e de `factory/lessons.md`. Registre a chamada em `events`; ela roda mesmo com `max_agent_calls` atingido.
- `resultado: NENHUMA`: nada a fazer.
- `resultado: LICOES`: acrescente ao fim de `factory/lessons.md`, na raiz do repo, cada linha do relatório que começa com `- `, como veio (`printf '%s\n' '<linha>' >> factory/lessons.md`).

### 10. LIMPEZA (depois do merge, determinística)
A fábrica não sabe sozinha quando o MR foi mergeado. Ela confere em dois momentos: no `/qubit cleanup [id]` e na **varredura de limpeza**, no começo de `/qubit <desc>` e `/qubit next`.
1. **Quais jobs:** com `id`, só ele; sem `id` (ou na varredura), `bash "$CLEANUP" pending "$REPO"` lista os jobs em `mr-open`, um por linha.
2. **Para cada job:** `bash "$CLEANUP" job "$REPO" <id> > "$JOB/cleanup.md" 2>&1` e leia só `head -1`. O script confirma o merge (CLI do host ou `git`) e só então apaga o worktree, a branch local, a branch remota (nunca a base) e os caches do perfil fora do worktree (no `ios`, o DerivedData do worktree). A pasta do job fica, como histórico.
   - `CLEANUP: DONE`: status `merged` em `job.json`.
   - `CLEANUP: PENDING`: MR ainda aberto ou merge não confirmado. Se o host não tem CLI mas você tem a ferramenta MCP do host (ex.: `get_merge_request` do GitLab), confira o estado do MR por ela; se estiver mergeado, rode de novo com `--assume-merged`. Nunca passe `--assume-merged` sem essa confirmação.
   - `CLEANUP: CLOSED`: MR fechado sem merge. Não apague nada; avise o usuário (o job foi abandonado?).
   - `CLEANUP: ERRO`: mostre `cleanup.md` ao usuário (ex.: worktree com mudanças não commitadas). Nada foi apagado.
3. Na varredura, mostre ao usuário uma linha por job limpo (`<id>: limpo`) e siga para o INIT; `PENDING` não é avisado. A varredura não gasta chamadas de agente nem para o job novo se algo falhar.

## Tipos de job

- **feature:** spec com critérios de aceitação; testes novos cobrem cada AC.
- **bug:** o builder **primeiro escreve um teste que reproduz o bug e falha**, registra isso em `build.md` (com a saída da falha), e só então corrige. Sem teste de regressão, não há aprovação.
- **refactor:** comportamento externo não muda. O builder escreve testes de caracterização **antes** de mexer, e o diff não pode alterar testes existentes (só acrescentar). `reviewer-ux` não roda.

## Quando parar e perguntar ao usuário

Dúvidas bloqueantes no spec, estouro de `max_agent_calls`, revisor que falha duas vezes, push que falha, conflito persistente com a base, MR que não pôde ser aberto, `ESCALATE`, e `APPROVE` aguardando `/qubit approve` (status `approving`). Mostre: o `job-id`, o motivo e o caminho do arquivo relevante. Nunca faça merge, nunca force push, nunca faça push na branch base. Branch remota de job só é apagada pelo script de limpeza, depois do merge confirmado.
