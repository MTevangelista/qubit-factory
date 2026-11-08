#!/usr/bin/env bash
# Instala a fábrica num projeto: cria os arquivos do projeto a partir de templates/ e checa a config.
# Nunca sobrescreve arquivo existente; pode rodar de novo sem risco.
#
# Uso: factory-init.sh <raiz-do-repo> [perfil]
#   perfil: ios | android | web | python | generic (sem perfil, detecta pela stack)
set -u -o pipefail

FACTORY_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$FACTORY_HOME/templates"
REPO="${1:-}"
PROFILE="${2:-}"
[[ -n "$REPO" ]] || { echo "uso: $0 <raiz-do-repo> [perfil]" >&2; exit 2; }
cd "$REPO" || { echo "INIT: ERRO"; echo "- diretório inexistente: $REPO"; exit 1; }

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "INIT: ERRO"; echo "- $PWD não é um repositório git (rode git init antes)"; exit 1; }
[[ "$(cd "$TOP" && pwd -P)" == "$(pwd -P)" ]] || { echo "INIT: ERRO"; echo "- rode na raiz do repo: $TOP"; exit 1; }

# ---------------------------------------------------------------- perfil
detect_profile() {
  if compgen -G '*.xcodeproj' >/dev/null || compgen -G '*.xcworkspace' >/dev/null || [[ -f Package.swift ]] \
     || compgen -G '*/*.xcodeproj' >/dev/null; then echo ios
  elif [[ -f gradlew ]] || compgen -G 'build.gradle*' >/dev/null || compgen -G 'settings.gradle*' >/dev/null; then echo android
  elif [[ -f package.json ]]; then echo web
  elif [[ -f pyproject.toml || -f setup.py || -f requirements.txt ]]; then echo python
  else echo generic; fi
}
DETECTED=""
if [[ -z "$PROFILE" ]]; then PROFILE="$(detect_profile)"; DETECTED=", detectado"; fi
if [[ ! "$PROFILE" =~ ^[a-z0-9_-]+$ ]] || [[ ! -f "factory/profiles/$PROFILE.sh" && ! -f "$FACTORY_HOME/profiles/$PROFILE.sh" ]]; then
  echo "INIT: ERRO"
  echo "- perfil '$PROFILE' não existe. Disponíveis: $(cd "$FACTORY_HOME/profiles" && ls ./*.sh | sed 's|^\./||; s|\.sh$||' | tr '\n' ' ')"
  exit 1
fi

# ---------------------------------------------------------------- branch base
detect_base() {
  local b
  b="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; b="${b#origin/}"
  if [[ -n "$b" ]] && git rev-parse --verify -q "refs/heads/$b" >/dev/null; then echo "$b"; return; fi
  for b in master main; do git rev-parse --verify -q "refs/heads/$b" >/dev/null && { echo "$b"; return; }; done
  git symbolic-ref -q --short HEAD 2>/dev/null || echo main
}
BASE="$(detect_base)"

CREATED=(); KEPT=()
created() { CREATED+=("$1"); }
kept()    { KEPT+=("$1"); }

# ---------------------------------------------------------------- arquivos do projeto
mkdir -p factory/jobs
if [[ -f factory/config.sh ]]; then kept "factory/config.sh"
else
  sed -e "s|__PROFILE__|$PROFILE|" -e "s|__BASE__|$BASE|" "$T/config.sh" > factory/config.sh
  created "factory/config.sh (perfil $PROFILE$DETECTED; base $BASE)"
fi
for f in lessons.md backlog.md dashboard.html; do
  if [[ -f "factory/$f" ]]; then kept "factory/$f"; else cp "$T/$f" "factory/$f"; created "factory/$f"; fi
done
[[ -f factory/jobs/.gitkeep ]] || { : > factory/jobs/.gitkeep; created "factory/jobs/.gitkeep"; }

if grep -qsx 'factory/jobs/\*' .gitignore; then kept ".gitignore (já ignora factory/jobs)"
else
  {
    [[ -s .gitignore && -n "$(tail -c1 .gitignore)" ]] && echo
    [[ -s .gitignore ]] && echo
    echo "# Software factory (estado local dos jobs; worktrees ficam fora do repo)"
    echo 'factory/jobs/*'
    echo '!factory/jobs/.gitkeep'
  } >> .gitignore
  created ".gitignore (factory/jobs ignorado)"
fi

if grep -qs 'qubit:begin' CLAUDE.md; then kept "CLAUDE.md (seção da fábrica)"
else
  if [[ -f CLAUDE.md ]]; then { echo; cat "$T/claude-md.md"; } >> CLAUDE.md
  else { echo "# $(basename "$PWD")"; echo; cat "$T/claude-md.md"; } > CLAUDE.md; fi
  created "CLAUDE.md (seção da fábrica, com campos _preencher_)"
fi

# ---------------------------------------------------------------- permissões
PROFILE_SH="factory/profiles/$PROFILE.sh"; [[ -f "$PROFILE_SH" ]] || PROFILE_SH="$FACTORY_HOME/profiles/$PROFILE.sh"
# shellcheck disable=SC1090
PERMS="$(FACTORY_PERMISSIONS=""; source "$PROFILE_SH" >/dev/null 2>&1; printf '%s' "${FACTORY_PERMISSIONS:-}")"
mkdir -p .claude
PERM_MSG="$(python3 -I - "$PERMS" <<'PY'
import json, os, sys
p = ".claude/settings.json"
try:
    d = json.load(open(p)) if os.path.exists(p) else {}
except ValueError:
    print("ERRO: .claude/settings.json não é JSON válido; não mexi"); sys.exit(0)
perm = d.setdefault("permissions", {})
allow = perm.setdefault("allow", []); deny = perm.setdefault("deny", [])
want = ["Bash(git worktree:*)", "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)"]
want += [r for r in sys.argv[1].split(";") if r]
added = [r for r in want if r not in allow]; allow += added
deny_want = ["Bash(git " + "push:*)"]
deny_added = [r for r in deny_want if r not in deny]; deny += deny_added
if added or deny_added:
    with open(p, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
    print(f"criado: .claude/settings.json (+{len(added)} allow, +{len(deny_added)} deny)")
else:
    print("mantido: .claude/settings.json (permissões já presentes)")
PY
)"

# ---------------------------------------------------------------- resumo
echo "INIT"
echo "Fábrica: $FACTORY_HOME"
for c in "${CREATED[@]+"${CREATED[@]}"}"; do echo "- criado: $c"; done
for k in "${KEPT[@]+"${KEPT[@]}"}"; do echo "- mantido: $k"; done
echo "- $PERM_MSG"
echo
bash "$FACTORY_HOME/scripts/factory-gates.sh" info "$PWD"
INFO_RC=$?
echo
echo "Próximos passos (pessoa):"
echo "1. Preencha os campos _preencher_ do CLAUDE.md e revise factory/config.sh (comandos que o perfil não detectar)."
echo "2. Faça commit na branch $BASE de factory/, .gitignore, CLAUDE.md e .claude/settings.json (o worktree nasce dela)."
echo "3. Rode /qubit <descrição> (ou /qubit next com itens em factory/backlog.md)."
exit $INFO_RC
