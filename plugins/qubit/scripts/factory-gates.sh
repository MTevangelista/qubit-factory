#!/usr/bin/env bash
# Gates determinísticos da fábrica (sem LLM), independentes de linguagem.
#
# Uso:
#   factory-gates.sh run      <dir-do-worktree>   # PASS/FAIL; falha se algo quebrar
#   factory-gates.sh baseline <dir-do-worktree>   # só registra o estado inicial; sai sempre 0
#   factory-gates.sh ui       <dir-do-worktree>   # "UI: yes" | "UI: no" (o diff toca interface?)
#   factory-gates.sh info     <raiz-do-repo>      # caminhos e branch que o orquestrador usa; sai 1 se a config estiver errada
#
# Os comandos vêm de factory/config.sh do projeto; o que estiver vazio lá recebe o padrão do perfil.
# Perfil: factory/profiles/<FACTORY_PROFILE>.sh do projeto, se existir; senão o do plugin (profiles/).
# Saída em markdown no stdout.
# Primeira linha: "GATES: PASS" | "GATES: FAIL" (run), "BASELINE" (baseline), "UI: ..." (ui) ou "INFO" | "INFO: ERRO" (info).
# Código de saída: 0 = PASS, 1 = FAIL.
set -u -o pipefail

# Raiz da fábrica (plugin): a pasta acima de scripts/.
FACTORY_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="${1:-}"
DIR="${2:-}"
if [[ "$MODE" != "run" && "$MODE" != "baseline" && "$MODE" != "ui" && "$MODE" != "info" ]] || [[ -z "$DIR" ]]; then
  echo "uso: $0 run|baseline|ui|info <dir>" >&2
  exit 2
fi
cd "$DIR" || { echo "GATES: FAIL"; echo "diretório inexistente: $DIR"; exit 1; }

BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
FAILED=0

section() { printf '\n## %s\n' "$1" >>"$BODY"; }
ok()      { printf -- '- OK: %s\n' "$1" >>"$BODY"; }
fail()    { printf -- '- FALHOU: %s\n' "$1" >>"$BODY"; FAILED=1; }
skip()    { printf -- '- PULADO: %s\n' "$1" >>"$BODY"; }

# ---------------------------------------------------------------- config + perfil
# Config do projeto: no worktree ela vem versionada em factory/config.sh.
CONFIG="factory/config.sh"
HAS_CONFIG=0
# shellcheck disable=SC1090
[[ -f "$CONFIG" ]] && { source "$CONFIG"; HAS_CONFIG=1; }
: "${FACTORY_PROFILE:=generic}"
: "${FACTORY_BASE_BRANCH:=}"
: "${GATE_TIMEOUT_SECONDS:=1800}"
: "${FACTORY_ALLOW_NO_PROJECT:=0}"
: "${FACTORY_REQUIRE_TOOLS:=0}"
FACTORY_PROFILE_ERROR=""
FACTORY_SOURCE_EXTS=""
FACTORY_UI_PATH_REGEX=""
FACTORY_UI_CONTENT_REGEX=""

# Perfil do projeto vence o do plugin (permite customizar sem fork).
profile_file() { # profile_file <ext>
  if [[ -f "factory/profiles/$FACTORY_PROFILE.$1" ]]; then echo "$PWD/factory/profiles/$FACTORY_PROFILE.$1"
  elif [[ -f "$FACTORY_HOME/profiles/$FACTORY_PROFILE.$1" ]]; then echo "$FACTORY_HOME/profiles/$FACTORY_PROFILE.$1"; fi
}
PROFILE_SH="$(profile_file sh)"
PROFILE_MD="$(profile_file md)"
if [[ -n "$PROFILE_SH" ]]; then
  # O perfil só preenche o que a config deixou vazio.
  # shellcheck disable=SC1090
  source "$PROFILE_SH"
else
  FACTORY_PROFILE_ERROR="perfil '$FACTORY_PROFILE' não existe (nem em factory/profiles/ nem em $FACTORY_HOME/profiles/)"
fi

# Branch base: a da config; vazio = origin/HEAD, depois master, depois main.
detect_base() {
  local b
  b="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; b="${b#origin/}"
  if [[ -n "$b" ]] && git rev-parse --verify -q "refs/heads/$b" >/dev/null; then echo "$b"; return; fi
  for b in master main; do
    git rev-parse --verify -q "refs/heads/$b" >/dev/null && { echo "$b"; return; }
  done
  echo "master"
}
BASE_REF="${FACTORY_BASE_BRANCH:-$(detect_base)}"

# ---------------------------------------------------------------- modo info
if [[ "$MODE" == "info" ]]; then
  ERR=()
  REPO="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [[ -z "$REPO" ]]; then
    ERR+=("$DIR não é um repositório git")
  else
    REPO="$(dirname "$REPO")"
    [[ "$(git rev-parse --show-toplevel)" == "$REPO" ]] || ERR+=("rode o info na raiz do repo ($REPO), não num worktree")
  fi
  [[ $HAS_CONFIG -eq 1 ]] || ERR+=("factory/config.sh não existe; rode /qubit init")
  [[ -n "$FACTORY_PROFILE_ERROR" ]] && ERR+=("$FACTORY_PROFILE_ERROR")
  [[ -n "$PROFILE_SH" && -z "$PROFILE_MD" ]] && ERR+=("perfil '$FACTORY_PROFILE' sem o .md de convenções")
  git rev-parse --verify -q "refs/heads/$BASE_REF" >/dev/null || ERR+=("branch base '$BASE_REF' não existe (ajuste FACTORY_BASE_BRANCH em factory/config.sh)")
  if [[ ${#ERR[@]} -gt 0 ]]; then
    echo "INFO: ERRO"; printf -- '- %s\n' "${ERR[@]}"; exit 1
  fi
  echo "INFO"
  echo "repo: $REPO"
  echo "base: $BASE_REF"
  echo "worktrees: $(dirname "$REPO")/$(basename "$REPO")-factory"
  echo "profile: $FACTORY_PROFILE"
  echo "profile_md: $PROFILE_MD"
  echo "gates: $FACTORY_HOME/scripts/factory-gates.sh"
  echo "factory_home: $FACTORY_HOME"
  exit 0
fi

# ---------------------------------------------------------------- modo ui
if [[ "$MODE" == "ui" ]]; then
  if [[ -z "$FACTORY_UI_PATH_REGEX" && -z "$FACTORY_UI_CONTENT_REGEX" ]]; then
    echo "UI: no"; echo "perfil '$FACTORY_PROFILE' não declara arquivos de interface"; exit 0
  fi
  CHANGED="$(git diff --name-only "$BASE_REF"...HEAD -- . ':!factory/jobs' 2>/dev/null || true)"
  HIT=""
  if [[ -n "$FACTORY_UI_PATH_REGEX" ]]; then
    HIT="$(printf '%s\n' "$CHANGED" | grep -E "$FACTORY_UI_PATH_REGEX" | head -1 || true)"
  fi
  if [[ -z "$HIT" && -n "$FACTORY_UI_CONTENT_REGEX" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" && -f "$f" ]] || continue
      if grep -qE "$FACTORY_UI_CONTENT_REGEX" "$f" 2>/dev/null; then HIT="$f"; break; fi
    done <<<"$CHANGED"
  fi
  if [[ -n "$HIT" ]]; then echo "UI: yes"; echo "exemplo: $HIT"; else echo "UI: no"; fi
  exit 0
fi

# Roda um comando (string) com timeout, se `timeout`/`gtimeout` existir, e anexa as últimas linhas ao corpo.
run_cmd() {
  local label="$1" cmd="$2"
  local out rc t=()
  command -v timeout  >/dev/null 2>&1 && t=(timeout "$GATE_TIMEOUT_SECONDS")
  command -v gtimeout >/dev/null 2>&1 && t=(gtimeout "$GATE_TIMEOUT_SECONDS")
  out="$(${t[@]+"${t[@]}"} bash -c "$cmd" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "$label: \`$cmd\`"
  else
    fail "$label: \`$cmd\` (exit $rc)"
    { echo '```'; echo "$out" | tail -n 60; echo '```'; } >>"$BODY"
  fi
  return $rc
}

# Primeiro executável do comando, pulando atribuições de ambiente (ex.: "CI=true npm test" -> npm).
first_bin() {
  local w
  for w in $1; do
    [[ "$w" == *=* ]] && continue
    echo "$w"; return
  done
}

# Há arquivos-fonte do perfil? (sem extensões declaradas, assume que sim)
has_sources() {
  [[ -z "$FACTORY_SOURCE_EXTS" ]] && return 0
  local e
  for e in $FACTORY_SOURCE_EXTS; do
    git ls-files -co --exclude-standard -- "*.$e" ':!factory/jobs' 2>/dev/null | grep -q . && return 0
  done
  return 1
}

# Ferramenta opcional (lint, formato, tipos): sem comando ou sem binário, pula; com REQUIRE=1, falha.
optional_tool() {
  local label="$1" cmd="$2" bin
  if [[ -z "$cmd" ]]; then skip "$label: não configurado"; return; fi
  bin="$(first_bin "$cmd")"
  if ! command -v "$bin" >/dev/null 2>&1; then
    if [[ "$FACTORY_REQUIRE_TOOLS" == "1" ]]; then fail "$label: \`$bin\` não instalado (FACTORY_REQUIRE_TOOLS=1)"
    else skip "$label: \`$bin\` não instalado"; fi
    return
  fi
  run_cmd "$label" "$cmd"
}

printf -- '- Perfil: `%s` (%s)\n- Branch base: `%s`\n' "$FACTORY_PROFILE" "${PROFILE_SH:-ausente}" "$BASE_REF" >>"$BODY"

# ---------------------------------------------------------------- 0. perfil
if [[ -n "$FACTORY_PROFILE_ERROR" ]]; then
  section "Perfil"
  fail "$FACTORY_PROFILE_ERROR"
fi

# ---------------------------------------------------------------- 1. segredos no diff
section "Segredos no diff"
if git rev-parse --verify -q "$BASE_REF" >/dev/null; then
  HITS="$(git diff "$BASE_REF"...HEAD -U0 -- . ':!factory/jobs' \
    | grep -E '^\+' | grep -vE '^\+\+\+' \
    | grep -nEi '(AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|(api[_-]?key|secret|password|token)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}["'"'"'])' || true)"
  if [[ -n "$HITS" ]]; then
    fail "possíveis segredos adicionados"
    { echo '```'; echo "$HITS" | head -20; echo '```'; } >>"$BODY"
  else
    ok "nenhum padrão de segredo nas linhas adicionadas"
  fi
else
  skip "sem branch base para comparar"
fi

# ---------------------------------------------------------------- 2. preparação (dependências)
if [[ -n "${FACTORY_SETUP_CMD:-}" ]]; then
  section "Preparação"
  run_cmd "setup" "$FACTORY_SETUP_CMD"
fi

# ---------------------------------------------------------------- 3. lint, formato e tipos
section "Lint, formato e tipos"
if ! has_sources; then
  skip "nenhum arquivo-fonte ($FACTORY_SOURCE_EXTS) ainda"
else
  optional_tool "lint"    "${FACTORY_LINT_CMD:-}"
  optional_tool "formato" "${FACTORY_FORMAT_CMD:-}"
  optional_tool "tipos"   "${FACTORY_TYPECHECK_CMD:-}"
fi

# ---------------------------------------------------------------- 4. build + testes
section "Build e testes"
if [[ -n "$FACTORY_PROFILE_ERROR" ]]; then
  skip "build e testes não rodam com erro de perfil/config"
elif [[ -n "${FACTORY_TEST_CMD:-}" ]]; then
  if [[ -n "${FACTORY_BUILD_CMD:-}" ]]; then
    run_cmd "build" "$FACTORY_BUILD_CMD" && run_cmd "testes" "$FACTORY_TEST_CMD"
  else
    skip "build: não configurado (ok para linguagens interpretadas)"
    run_cmd "testes" "$FACTORY_TEST_CMD"
  fi
elif [[ "$FACTORY_ALLOW_NO_PROJECT" == "1" ]]; then
  skip "sem comando de teste (FACTORY_ALLOW_NO_PROJECT=1)"
else
  fail "nenhum comando de teste: o perfil '$FACTORY_PROFILE' não detectou o projeto; defina FACTORY_TEST_CMD em factory/config.sh"
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
