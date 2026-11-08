#!/usr/bin/env bash
# Hook PreToolUse da fábrica. Lê o JSON do evento no stdin e bloqueia (exit 2) ações perigosas.
# - Bash: git push, force/delete de master|main, rm -rf amplo, curl|sh.
# - Edit/Write dentro de um worktree da fábrica: proíbe mexer nos próprios gates, hooks e config
#   (o builder não pode "passar" afrouxando a verificação) e em arquivos fora do worktree.
set -u

INPUT="$(cat)"
read_field() {
  printf '%s' "$INPUT" | python3 -I -c '
import json,sys
d=json.load(sys.stdin)
k=sys.argv[1]
v=d
for p in k.split("."):
    v=v.get(p,"") if isinstance(v,dict) else ""
print(v if isinstance(v,str) else "")
' "$1" 2>/dev/null
}

TOOL="$(read_field tool_name)"
block() { echo "BLOQUEADO pela fábrica: $1" >&2; exit 2; }

case "$TOOL" in
  Bash)
    CMD="$(read_field tool_input.command)"
    [[ "$CMD" =~ git[[:space:]]+([^|;&]*[[:space:]])?push ]] && block "git push não é permitido; o merge é local e feito pelo orquestrador."
    [[ "$CMD" =~ git[[:space:]]+branch[[:space:]]+-[dD][[:space:]]+(master|main)([[:space:]]|$) ]] && block "não apague master/main."
    [[ "$CMD" =~ git[[:space:]]+reset[[:space:]]+--hard[[:space:]]+origin ]] && block "reset --hard para origin não é permitido."
    [[ "$CMD" =~ rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)[a-zA-Z]*[[:space:]]+(/|~|\\\$HOME|\.\.|\*)([[:space:]]|$) ]] && block "rm -rf amplo."
    [[ "$CMD" =~ (curl|wget)[^|]*\|[[:space:]]*(ba|z)?sh ]] && block "não execute scripts baixados."
    ;;
  Edit|Write|NotebookEdit)
    FILE="$(read_field tool_input.file_path)"
    # Só vale dentro de worktrees da fábrica ("../<repo>-factory/<NNN-slug>/...").
    # Exige o diretório de job logo após "-factory/" para não pegar repos cujo nome termina em "-factory".
    if [[ "$FILE" =~ -factory/[0-9]{3}-[^/]+/(.*)$ ]]; then
      REL="${BASH_REMATCH[1]}"
      case "$REL" in
        .claude/*|.claude-plugin/*|plugins/qubit/*|scripts/factory-*|factory/config.sh|factory/profiles/*|factory/lessons.md|CLAUDE.md)
          block "agentes não podem alterar $REL (gates, hooks, config e regras são do humano)." ;;
      esac
    fi
    ;;
esac
exit 0
