# Configuração da fábrica. Lido por scripts/factory-gates.sh e pelo orquestrador.
# Sem um comando de teste (aqui ou detectado pelo perfil), os gates FALHAM de propósito
# (um gate que passa sem rodar nada é pior do que nenhum gate).

# --- Perfil de stack ---
# Um de factory/profiles/: ios, android, web, python, generic.
# O perfil traz os comandos padrão (factory/profiles/<perfil>.sh) e as convenções e checklists
# que os agentes seguem (factory/profiles/<perfil>.md).
FACTORY_PROFILE="ios"

# --- Comandos dos gates (vazio = usa o padrão detectado pelo perfil) ---
# Cada comando roda com `bash -c` na raiz do worktree.
FACTORY_SETUP_CMD=""                    # instala dependências (ex.: "npm ci"); roda antes de tudo
FACTORY_LINT_CMD=""                     # ex.: "swiftlint lint --strict", "npm run lint", "ruff check ."
FACTORY_FORMAT_CMD=""                   # checagem de formato, sem reescrever (ex.: "ruff format --check .")
FACTORY_TYPECHECK_CMD=""                # ex.: "npx --no-install tsc --noEmit", "mypy ."
FACTORY_BUILD_CMD=""                    # opcional em linguagens interpretadas
FACTORY_TEST_CMD=""                     # obrigatório (ou detectado pelo perfil)
FACTORY_REQUIRE_TOOLS=0                 # 1 = falha se o binário de lint/formato/tipos não estiver instalado

# --- Específico do perfil ios (ignorado pelos outros) ---
FACTORY_WORKSPACE=""                    # vazio = autodetecta *.xcworkspace / *.xcodeproj
FACTORY_PROJECT=""
FACTORY_SCHEME=""                       # obrigatório para projetos Xcode
FACTORY_DESTINATION="platform=iOS Simulator,name=iPhone 16"

# --- Limites de custo por job ---
FACTORY_MAX_ROUNDS=2                    # rodadas de retrabalho do builder
FACTORY_MAX_AGENT_CALLS=20              # teto de chamadas de subagente por job
GATE_TIMEOUT_SECONDS=1800               # teto por comando de build/teste

# --- Excepcional: permite gates PASS sem comando de teste (ex.: repositório só de docs). Mantenha 0. ---
FACTORY_ALLOW_NO_PROJECT=0
