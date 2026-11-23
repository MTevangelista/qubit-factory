#!/usr/bin/env bash
# Limpeza de um job depois que o MR dele foi mergeado (sem LLM).
#
# Uso:
#   factory-cleanup.sh pending <raiz-do-repo>                        # ids dos jobs em mr-open, um por linha
#   factory-cleanup.sh job     <raiz-do-repo> <job-id> [--assume-merged]
#
# Modo job: confirma o merge e, só então, remove o lixo do job:
#   - worktree (../<repo>-factory/<job-id>) e registros órfãos (git worktree prune);
#   - branch local e branch remota do job (nunca a base, master ou main);
#   - caches do perfil fora do worktree (ex.: DerivedData do Xcode), via factory_cleanup_caches do perfil;
#   - refs remotas que não existem mais (git fetch --prune) e a pasta de worktrees, se ficar vazia.
# A pasta factory/jobs/<job-id> fica (histórico do job, usado pelo learner e pelo dashboard).
# Não escreve job.json: quem atualiza o status é o orquestrador.
#
# Como o merge é confirmado, nesta ordem:
#   1. job.json.mr + CLI do host (gh pr view / glab mr view): MERGED, CLOSED ou aberto;
#   2. sem CLI: a ponta da branch do job está contida em origin/<base> (merge comum ou fast-forward);
#   3. --assume-merged: o orquestrador confirmou o merge por outro meio (ex.: ferramenta MCP do host).
# Squash merge sem CLI e sem --assume-merged dá PENDING: não dá para provar o merge pelo git.
#
# Primeira linha: "CLEANUP: DONE" | "CLEANUP: PENDING" | "CLEANUP: CLOSED" | "CLEANUP: ERRO".
# Código de saída: 0 = DONE, 1 = ERRO, 3 = PENDING ou CLOSED (nada foi apagado).
set -u -o pipefail

FACTORY_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$FACTORY_HOME/scripts/factory-gates.sh"

MODE="${1:-}"
REPO="${2:-}"
usage() { echo "uso: $0 pending <repo> | job <repo> <job-id> [--assume-merged]" >&2; exit 2; }
[[ "$MODE" == "pending" || "$MODE" == "job" ]] && [[ -n "$REPO" ]] || usage
REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { echo "CLEANUP: ERRO"; echo "- repositório inexistente: ${2}"; exit 1; }

# Lê um campo de job.json (string; vazio se ausente).
jfield() { python3 -I -c 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2],""); print(v if isinstance(v,str) else "")' "$1" "$2" 2>/dev/null; }

if [[ "$MODE" == "pending" ]]; then
  for f in "$REPO"/factory/jobs/*/job.json; do
    [[ -f "$f" ]] || continue
    [[ "$(jfield "$f" status)" == "mr-open" ]] && basename "$(dirname "$f")"
  done
  exit 0
fi

ID="${3:-}"
ASSUME=0
[[ "${4:-}" == "--assume-merged" ]] && ASSUME=1
[[ -n "$ID" ]] || usage
LOG=()
note() { LOG+=("$1"); }
finish() { # finish <resultado> <código>
  echo "CLEANUP: $1"
  [[ ${#LOG[@]} -gt 0 ]] && printf -- '- %s\n' "${LOG[@]}"
  exit "$2"
}

JOBJSON="$REPO/factory/jobs/$ID/job.json"
[[ -f "$JOBJSON" ]] || { note "job.json não existe: $JOBJSON"; finish ERRO 1; }

INFO="$(bash "$GATES" info "$REPO" 2>&1)"
if [[ "$(head -1 <<<"$INFO")" != "INFO" ]]; then
  note "info da fábrica falhou:"; while IFS= read -r l; do note "  $l"; done <<<"$INFO"; finish ERRO 1
fi
BASE="$(sed -n 's/^base: //p' <<<"$INFO")"
WTROOT="$(sed -n 's/^worktrees: //p' <<<"$INFO")"
PROFILE="$(sed -n 's/^profile: //p' <<<"$INFO")"

BRANCH="$(jfield "$JOBJSON" branch)"
MR="$(jfield "$JOBJSON" mr)"
WT="$(jfield "$JOBJSON" worktree)"
[[ -n "$WT" ]] || WT="$WTROOT/$ID"

# Trava: só apaga branch de job da fábrica, nunca a base.
if [[ ! "$BRANCH" =~ ^(feat|fix|refactor)/[0-9]{3}-[A-Za-z0-9._-]+$ ]] || [[ "$BRANCH" == "$BASE" ]]; then
  note "branch \`$BRANCH\` não tem o formato de branch de job (<type>/<NNN-slug>); nada foi apagado"
  finish ERRO 1
fi

git -C "$REPO" fetch -q --prune origin 2>/dev/null || note "aviso: \`git fetch origin\` falhou; usando as refs locais"

# ---------------------------------------------------------------- 1. o MR foi mergeado?
STATE=""   # merged | closed | open | ""
HOST_URL="$(git -C "$REPO" remote get-url origin 2>/dev/null || true)"
if [[ $ASSUME -eq 1 ]]; then
  STATE="merged"; note "merge confirmado pelo orquestrador (--assume-merged)"
elif [[ "$HOST_URL" == *github* ]] && command -v gh >/dev/null 2>&1; then
  S="$(cd "$REPO" && gh pr view "${MR:-$BRANCH}" --json state -q .state 2>/dev/null || true)"
  case "$S" in MERGED) STATE=merged ;; CLOSED) STATE=closed ;; OPEN) STATE=open ;; esac
  [[ -n "$STATE" ]] && note "gh: MR ${MR:-$BRANCH} está $S"
elif [[ "$HOST_URL" == *gitlab* ]] && command -v glab >/dev/null 2>&1; then
  S="$(cd "$REPO" && glab mr view "$BRANCH" --output json 2>/dev/null \
      | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("state",""))' 2>/dev/null || true)"
  case "$S" in merged) STATE=merged ;; closed) STATE=closed ;; opened|locked) STATE=open ;; esac
  [[ -n "$STATE" ]] && note "glab: MR de $BRANCH está $S"
fi
if [[ -z "$STATE" ]]; then
  TIP="$(git -C "$REPO" rev-parse -q --verify "refs/heads/$BRANCH" 2>/dev/null \
      || git -C "$REPO" rev-parse -q --verify "refs/remotes/origin/$BRANCH" 2>/dev/null || true)"
  if [[ -n "$TIP" ]] && git -C "$REPO" merge-base --is-ancestor "$TIP" "refs/remotes/origin/$BASE" 2>/dev/null; then
    STATE="merged"; note "git: a ponta de \`$BRANCH\` já está em origin/$BASE"
  elif [[ -z "$TIP" ]]; then
    note "branch \`$BRANCH\` não existe mais (nem local nem remota); sem como confirmar o merge pelo git"
  fi
fi
case "$STATE" in
  closed) note "MR fechado sem merge: nada foi apagado (para abandonar o job, limpe à mão)"; finish CLOSED 3 ;;
  merged) ;;
  *) [[ "$STATE" == "open" ]] || note "merge não confirmado (MR aberto, squash merge sem CLI do host, ou host desconhecido)"
     finish PENDING 3 ;;
esac

# ---------------------------------------------------------------- 2. worktree
if [[ -d "$WT" ]]; then
  # Arquivos ignorados (build, dependências) não contam; mudança rastreada ou arquivo novo não versionado, sim.
  DIRTY="$(git -C "$WT" status --porcelain 2>/dev/null | head -5)"
  if [[ -n "$DIRTY" ]]; then
    note "worktree com mudanças não commitadas; nada foi apagado ($WT):"
    while IFS= read -r l; do note "  $l"; done <<<"$DIRTY"
    finish ERRO 1
  fi
  if git -C "$REPO" worktree remove "$WT" 2>/dev/null; then note "worktree removido: $WT"
  else note "não consegui remover o worktree: $WT"; finish ERRO 1; fi
else
  note "worktree já não existia: $WT"
fi
git -C "$REPO" worktree prune
rmdir "$WTROOT" 2>/dev/null && note "pasta de worktrees vazia removida: $WTROOT"

# ---------------------------------------------------------------- 3. branches
if git -C "$REPO" rev-parse -q --verify "refs/heads/$BRANCH" >/dev/null; then
  # -D: squash merge não deixa a branch "mergeada" para o git, mas o merge já foi confirmado acima.
  if git -C "$REPO" branch -q -D "$BRANCH" 2>/dev/null; then note "branch local apagada: $BRANCH"
  else note "não consegui apagar a branch local \`$BRANCH\` (está em uso?)"; fi
else
  note "branch local já não existia: $BRANCH"
fi
if git -C "$REPO" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  if git -C "$REPO" push -q origin --delete "$BRANCH" 2>/dev/null; then note "branch remota apagada: origin/$BRANCH"
  else note "aviso: não consegui apagar origin/$BRANCH (permissão ou branch protegida)"; fi
else
  note "branch remota já não existia (o host apagou no merge)"
fi
git -C "$REPO" fetch -q --prune origin 2>/dev/null || true

# ---------------------------------------------------------------- 4. caches do perfil
# O perfil pode definir factory_cleanup_caches <worktree> para caches que vivem fora do worktree.
PROFILE_SH=""
if   [[ -f "$REPO/factory/profiles/$PROFILE.sh" ]]; then PROFILE_SH="$REPO/factory/profiles/$PROFILE.sh"
elif [[ -f "$FACTORY_HOME/profiles/$PROFILE.sh" ]]; then PROFILE_SH="$FACTORY_HOME/profiles/$PROFILE.sh"; fi
if [[ -n "$PROFILE_SH" ]]; then
  # shellcheck disable=SC1090
  (cd "$REPO" && source "$REPO/factory/config.sh" && source "$PROFILE_SH" \
    && if declare -F factory_cleanup_caches >/dev/null; then factory_cleanup_caches "$WT"; fi) >"${TMPDIR:-/tmp}/qubit-cleanup.$$" 2>&1
  while IFS= read -r l; do [[ -n "$l" ]] && note "$l"; done <"${TMPDIR:-/tmp}/qubit-cleanup.$$"
  rm -f "${TMPDIR:-/tmp}/qubit-cleanup.$$"
fi

finish DONE 0
