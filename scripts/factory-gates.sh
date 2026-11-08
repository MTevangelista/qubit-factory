#!/usr/bin/env bash
# Gates determinísticos da fábrica (sem LLM).
#
# Uso:
#   scripts/factory-gates.sh run      <dir-do-worktree>   # PASS/FAIL; falha se algo quebrar
#   scripts/factory-gates.sh baseline <dir-do-worktree>   # só registra o estado inicial; sai sempre 0
#
# Saída em markdown no stdout. Primeira linha: "GATES: PASS" | "GATES: FAIL" (run)
# ou "BASELINE" (baseline). Código de saída: 0 = PASS, 1 = FAIL.
set -u -o pipefail

MODE="${1:-}"
DIR="${2:-}"
if [[ "$MODE" != "run" && "$MODE" != "baseline" ]] || [[ -z "$DIR" ]]; then
  echo "uso: $0 run|baseline <dir>" >&2
  exit 2
fi
cd "$DIR" || { echo "GATES: FAIL"; echo "diretório inexistente: $DIR"; exit 1; }

# Config do repo-fonte: no worktree ela vem versionada em factory/config.sh.
CONFIG="factory/config.sh"
[[ -f "$CONFIG" ]] && source "$CONFIG"
: "${FACTORY_DESTINATION:=platform=iOS Simulator,name=iPhone 16}"
: "${GATE_TIMEOUT_SECONDS:=1800}"
: "${FACTORY_ALLOW_NO_PROJECT:=0}"

BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
FAILED=0

section() { printf '\n## %s\n' "$1" >>"$BODY"; }
ok()      { printf -- '- OK: %s\n' "$1" >>"$BODY"; }
fail()    { printf -- '- FALHOU: %s\n' "$1" >>"$BODY"; FAILED=1; }
skip()    { printf -- '- PULADO: %s\n' "$1" >>"$BODY"; }

# Roda um comando com timeout (se `timeout`/`gtimeout` existir) e anexa as últimas linhas ao corpo.
run_cmd() {
  local label="$1"; shift
  local out rc t=""
  command -v timeout  >/dev/null 2>&1 && t="timeout $GATE_TIMEOUT_SECONDS"
  command -v gtimeout >/dev/null 2>&1 && t="gtimeout $GATE_TIMEOUT_SECONDS"
  out="$($t "$@" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "$label"
  else
    fail "$label (exit $rc)"
    { echo '```'; echo "$out" | tail -n 60; echo '```'; } >>"$BODY"
  fi
  return $rc
}

# ---------------------------------------------------------------- 1. segredos no diff
section "Segredos no diff"
BASE_REF="master"
git rev-parse --verify -q "$BASE_REF" >/dev/null || BASE_REF="main"
if git rev-parse --verify -q "$BASE_REF" >/dev/null; then
  HITS="$(git diff "$BASE_REF"...HEAD -U0 -- . ':!factory/jobs' \
    | grep -E '^\+' | grep -vE '^\+\+\+' \
    | grep -nEi '(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*"[^"]{8,}")' || true)"
  if [[ -n "$HITS" ]]; then
    fail "possíveis segredos adicionados"
    { echo '```'; echo "$HITS" | head -20; echo '```'; } >>"$BODY"
  else
    ok "nenhum padrão de segredo nas linhas adicionadas"
  fi
else
  skip "sem branch base para comparar"
fi

# ---------------------------------------------------------------- 2. lint
section "Lint"
HAS_SWIFT="$(find . -name '*.swift' -not -path './.build/*' -not -path '*/DerivedData/*' | head -1)"
if [[ -z "$HAS_SWIFT" ]]; then
  skip "nenhum arquivo .swift ainda"
elif command -v swiftlint >/dev/null 2>&1; then
  run_cmd "swiftlint --strict" swiftlint lint --strict --quiet
else
  if [[ "${FACTORY_SWIFTLINT_REQUIRE:-0}" == "1" ]]; then fail "swiftlint não instalado (exigido)"; else skip "swiftlint não instalado"; fi
fi
if command -v swift-format >/dev/null 2>&1 && [[ -f .swift-format ]]; then
  run_cmd "swift-format lint" swift-format lint --strict --recursive .
else
  if [[ "${FACTORY_SWIFTFORMAT_REQUIRE:-0}" == "1" ]]; then fail "swift-format indisponível (exigido)"; else skip "swift-format não configurado"; fi
fi

# ---------------------------------------------------------------- 3. build + testes
section "Build e testes"
XC_ARGS=()
if [[ -n "${FACTORY_WORKSPACE:-}" ]]; then XC_ARGS=(-workspace "$FACTORY_WORKSPACE")
elif [[ -n "${FACTORY_PROJECT:-}" ]]; then XC_ARGS=(-project "$FACTORY_PROJECT")
else
  WS="$(find . -maxdepth 2 -name '*.xcworkspace' -not -path '*/xcodeproj/*' -not -path './.build/*' | head -1)"
  PJ="$(find . -maxdepth 2 -name '*.xcodeproj' -not -path './.build/*' | head -1)"
  if   [[ -n "$WS" ]]; then XC_ARGS=(-workspace "$WS")
  elif [[ -n "$PJ" ]]; then XC_ARGS=(-project "$PJ"); fi
fi

if [[ ${#XC_ARGS[@]} -gt 0 ]]; then
  if [[ -z "${FACTORY_SCHEME:-}" ]]; then
    fail "FACTORY_SCHEME vazio em factory/config.sh"
  else
    run_cmd "xcodebuild build-for-testing" \
      xcodebuild "${XC_ARGS[@]}" -scheme "$FACTORY_SCHEME" -destination "$FACTORY_DESTINATION" \
      -quiet build-for-testing \
      && run_cmd "xcodebuild test-without-building" \
      xcodebuild "${XC_ARGS[@]}" -scheme "$FACTORY_SCHEME" -destination "$FACTORY_DESTINATION" \
      -quiet test-without-building
  fi
elif [[ -f Package.swift ]]; then
  run_cmd "swift build" swift build \
    && run_cmd "swift test" swift test
elif [[ "$FACTORY_ALLOW_NO_PROJECT" == "1" ]]; then
  skip "sem projeto Xcode/SwiftPM (FACTORY_ALLOW_NO_PROJECT=1)"
else
  fail "nenhum projeto Xcode nem Package.swift encontrado; configure factory/config.sh"
fi

# ---------------------------------------------------------------- saída
if [[ "$MODE" == "baseline" ]]; then
  echo "BASELINE"
  echo "Estado antes do job (falhas aqui não são do builder, mas não podem piorar)."
  cat "$BODY"
  exit 0
fi

if [[ $FAILED -eq 0 ]]; then echo "GATES: PASS"; else echo "GATES: FAIL"; fi
cat "$BODY"
exit $FAILED
