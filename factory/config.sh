# Configuração da fábrica. Lido por scripts/factory-gates.sh e pelo orquestrador.
# Edite quando o projeto Xcode existir. Sem isso, os gates FALHAM de propósito
# (um gate que passa sem rodar nada é pior do que nenhum gate).

# --- Projeto Xcode (use WORKSPACE ou PROJECT; vazio = autodetecta *.xcworkspace / *.xcodeproj) ---
FACTORY_WORKSPACE=""
FACTORY_PROJECT=""
FACTORY_SCHEME=""                       # obrigatório para projetos Xcode
FACTORY_DESTINATION="platform=iOS Simulator,name=iPhone 16"

# --- Swift Package (se não houver projeto Xcode e existir Package.swift, usa `swift test`) ---

# --- Linters (rodam só se o binário existir; use REQUIRE=1 para falhar quando faltar) ---
FACTORY_SWIFTLINT_REQUIRE=0
FACTORY_SWIFTFORMAT_REQUIRE=0

# --- Limites de custo por job ---
FACTORY_MAX_ROUNDS=2                    # rodadas de retrabalho do builder
FACTORY_MAX_AGENT_CALLS=20              # teto de chamadas de subagente por job
GATE_TIMEOUT_SECONDS=1800               # teto por comando de build/teste

# --- Excepcional: permite gates PASS sem projeto (ex.: repositório só de docs). Mantenha 0. ---
FACTORY_ALLOW_NO_PROJECT=0
