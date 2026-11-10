#!/usr/bin/env bash
# Hook PreToolUse da fábrica. Lê o JSON do evento no stdin e bloqueia (exit 2) ações perigosas.
# - Bash: force push e push na branch base (guard_push.py), delete de master|main, rm -rf amplo, curl|sh.
#   Push da branch do job é permitido: a fábrica publica a branch e abre MR.
# - Edit/Write dentro de um worktree da fábrica: proíbe mexer nos próprios gates, hooks e config
#   (o builder não pode "passar" afrouxando a verificação) e em arquivos fora do worktree.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    # Push comum é permitido (a fábrica publica a branch do job e abre MR). A regra fica em guard_push.py.
    if [[ "$CMD" == *push* ]]; then
      REASON="$(printf '%s' "$INPUT" | python3 -I "$HERE/guard_push.py" 2>/dev/null)"; RC=$?
      [[ $RC -eq 2 ]] && block "$REASON"
      [[ $RC -ne 0 && "$CMD" =~ git[[:space:]]+([^|;&]*[[:space:]])?push ]] && block "não consegui analisar este git push (guard_push.py falhou)."
    fi
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
