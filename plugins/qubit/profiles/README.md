# Perfis de stack

A fábrica não depende de linguagem. Tudo o que é específico de uma stack fica num **perfil**, escolhido em `factory/config.sh` com `FACTORY_PROFILE`.

| Perfil | Stack | Detecta |
|---|---|---|
| `ios` | Swift / SwiftUI | `*.xcworkspace`, `*.xcodeproj` ou `Package.swift` |
| `android` | Kotlin / Java, Gradle | `gradlew` |
| `web` | JS / TS (frontend ou Node) | `package.json` e os seus scripts |
| `python` | Python, pytest | `uv.lock`, `poetry.lock`, `tests/`, `pyproject.toml` |
| `generic` | qualquer | nada; os comandos vêm todos da config |

Cada perfil tem dois arquivos:

- **`<perfil>.sh`**: lido por `scripts/factory-gates.sh` (do plugin). Preenche os comandos que a config deixou vazios e declara quais arquivos contam como interface.
- **`<perfil>.md`**: lido pelos agentes. Convenções e checklists por papel.

## Contrato do `<perfil>.sh`

É carregado com `source` na raiz do worktree, depois de `factory/config.sh`. **Só preencha variável vazia**: a config sempre vence.

| Variável | Para quê |
|---|---|
| `FACTORY_SETUP_CMD` | instalar dependências antes dos gates |
| `FACTORY_LINT_CMD` / `FACTORY_FORMAT_CMD` / `FACTORY_TYPECHECK_CMD` | opcionais; se o binário não existir, o gate pula (ou falha com `FACTORY_REQUIRE_TOOLS=1`) |
| `FACTORY_BUILD_CMD` | opcional (linguagem interpretada não precisa) |
| `FACTORY_TEST_CMD` | obrigatório; sem ele o gate falha |
| `FACTORY_SOURCE_EXTS` | extensões de código-fonte, separadas por espaço; sem arquivos delas, o lint pula |
| `FACTORY_UI_PATH_REGEX` | regex (ERE) sobre o caminho dos arquivos do diff que contam como interface |
| `FACTORY_UI_CONTENT_REGEX` | regex (ERE) sobre o conteúdo dos arquivos do diff que contam como interface |
| `FACTORY_PROFILE_ERROR` | mensagem de erro de configuração (ex.: scheme ausente); faz o gate falhar |
| `FACTORY_PERMISSIONS` | regras de permissão do Claude Code, separadas por `;`, que o `/qubit init` adiciona em `.claude/settings.json` (ex.: `Bash(xcodebuild:*)`) |

Os revisores de UI e UX só rodam quando `factory-gates.sh ui <wt>` responde `UI: yes`. Perfil sem as duas regex nunca chama esses revisores.

## Contrato do `<perfil>.md`

As seções abaixo são obrigatórias (o autoteste confere). Cada agente lê só as suas:

| Seção | Quem lê |
|---|---|
| `## Stack` | todos |
| `## Código` | `builder`, `reviewer-code` |
| `## Testes` | `builder`, `reviewer-tests` |
| `## Segurança` | `builder`, `reviewer-security` |
| `## UI` | `builder`, `reviewer-ui` |
| `## UX` | `reviewer-ux` |
| `## Spec` | `spec-writer` |
| `## Logs` | todo agente que roda build ou teste |
| `## Skills` | `builder` e revisores |

## Onde os perfis ficam

Os gates procuram `factory/profiles/<perfil>.sh` (e `.md`) **no projeto** primeiro e, se não acharem, usam os do plugin (esta pasta). Assim um projeto pode ajustar um perfil sem fork do plugin.

## Criar um perfil

- **Para todos os projetos:** copie `generic.sh` e `generic.md` desta pasta para `<nome>.sh` e `<nome>.md`, preencha a detecção de comandos no `.sh` e as seções no `.md`, rode `bash plugins/qubit/scripts/factory-selftest.sh` e incremente `version` em `.claude-plugin/plugin.json`.
- **Só para um projeto:** crie `factory/profiles/<nome>.sh` e `.md` no projeto e troque `FACTORY_PROFILE` em `factory/config.sh`.

Perfis são regras da fábrica: só uma pessoa os altera. O hook `guard.sh` impede os agentes de editá-los dentro de um worktree.
