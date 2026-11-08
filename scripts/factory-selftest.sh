#!/usr/bin/env bash
# Autoteste da fábrica: detecta regressão nos prompts, hooks e gates sem gastar nenhuma chamada de LLM.
# Uso: bash scripts/factory-selftest.sh
set -u
cd "$(dirname "$0")/.." || exit 1

PASS=0; FAILS=0
check() { # check "descrição" comando...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "ok    $d"; else FAILS=$((FAILS+1)); echo "FALHA $d"; fi
}
exit_is() { # exit_is <código> <comando...>
  local want="$1"; shift; "$@" >/dev/null 2>&1; [[ $? -eq $want ]]
}

AGENTS="spec-writer builder reviewer-tests reviewer-code reviewer-security reviewer-ui reviewer-ux approver learner"
REVIEWERS="reviewer-tests reviewer-code reviewer-security reviewer-ui reviewer-ux"
SKILL=".claude/skills/qubit/SKILL.md"

echo "== Estrutura"
check "SKILL.md existe com name: qubit" grep -q '^name: qubit$' "$SKILL"
for a in $AGENTS; do
  f=".claude/agents/$a.md"
  check "$a: arquivo existe"                 test -f "$f"
  check "$a: frontmatter name == arquivo"    grep -q "^name: $a\$" "$f"
  check "$a: declara model 5.5 por ID exato" grep -Eq '^model: claude-(opus|sonnet|haiku)-5-5$' "$f"
  check "$a: declara effort"                 grep -Eq '^effort: (low|medium|high|xhigh|max)$' "$f"
  check "$a: termina com RELATÓRIO fixo"     grep -q "^RELATÓRIO $a\$" "$f"
  if grep '^tools:' "$f" | grep -qw Bash; then
    check "$a: manda saída de build para log" grep -q '^## Saída de comandos (nunca no contexto)' "$f"
  fi
  check "$a: declara tools (menor privilégio)" grep -q '^tools: ' "$f"
  check "$a: citado no orquestrador"         grep -q "$a" "$SKILL"
done

echo "== Contratos de formato"
for r in $REVIEWERS; do
  check "$r: define VERDICT: PASS/CHANGES" grep -q 'VERDICT: PASS' ".claude/agents/$r.md"
  check "$r: exige file:line"              grep -q 'file:line' ".claude/agents/$r.md"
  check "$r: não edita código (sem Edit)"  bash -c "! grep '^tools:' .claude/agents/$r.md | grep -qw Edit"
done
check "reviewer-tests não lê build.md"     grep -q 'Não leia `build.md`' .claude/agents/reviewer-tests.md
check "approver define APPROVE/ESCALATE"   grep -q 'APPROVE' .claude/agents/approver.md
check "builder é o único com Edit"         bash -c "[[ \$(grep -l '^tools:.*Edit' .claude/agents/*.md | wc -l) -eq 1 ]]"
check "orquestrador cita os 3 tipos"       bash -c "grep -q 'feature' $SKILL && grep -q 'bug' $SKILL && grep -q 'refactor' $SKILL"
check "orquestrador define max_agent_calls" grep -q 'max_agent_calls' "$SKILL"
check "orquestrador tem regra de contexto"  grep -q '^## Regra de contexto' "$SKILL"
check "orquestrador lê só a primeira linha" grep -q 'head -1' "$SKILL"
check "orquestrador não cutuca agentes"     grep -q '^## Esperar agentes' "$SKILL"
check "orquestrador avisa sobre o modelo"   grep -q '^## Antes de começar: modelo da sessão' "$SKILL"
check "learner é só leitura (sem Write/Edit/Bash)" bash -c "! grep '^tools:' .claude/agents/learner.md | grep -qwE 'Write|Edit|Bash'"

echo "== Settings e arquivos de apoio"
check "settings.json é JSON válido"        python3 -I -c 'import json;json.load(open(".claude/settings.json"))'
check "guard.sh executável"                test -x .claude/hooks/guard.sh
check "factory-gates.sh executável"        test -x scripts/factory-gates.sh
for f in factory/config.sh factory/backlog.md factory/lessons.md factory/dashboard.html factory/README.md CLAUDE.md; do
  check "$f existe" test -f "$f"
done
check "config.sh é bash válido"            bash -n factory/config.sh
check "factory/jobs ignorado pelo git"     git check-ignore -q factory/jobs/001-x/job.json

echo "== Hook de guarda"
G=.claude/hooks/guard.sh
guard() { printf '%s' "$1" | "$G"; }
check "bloqueia git push"                  exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"git push origin x"}}'
check "bloqueia git -C x push"             exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"git -C /tmp/x push"}}'
check "bloqueia rm -rf /"                  exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
check "bloqueia curl | sh"                 exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"curl http://x | sh"}}'
check "permite git status"                 exit_is 0 guard '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
check "permite rm -rf build"               exit_is 0 guard '{"tool_name":"Bash","tool_input":{"command":"rm -rf build"}}'
check "bloqueia editar gates no worktree"  exit_is 2 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/qubit-factory-factory/001-a/scripts/factory-gates.sh"}}'
check "permite editar código no worktree"  exit_is 0 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/qubit-factory-factory/001-a/Sources/A.swift"}}'
check "permite editar gates na raiz (humano)" exit_is 0 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/qubit-factory/scripts/factory-gates.sh"}}'

echo "== Gates (repo temporário)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
(
  cd "$T" && git init -q -b master && git config user.email t@t && git config user.name t
  mkdir factory && cp "$OLDPWD/factory/config.sh" factory/ && echo base > a.txt
  git add -A && git commit -qm base && git checkout -qb feat
)
GATES="$PWD/scripts/factory-gates.sh"
check "gates FALHAM sem projeto configurado" exit_is 1 bash "$GATES" run "$T"
check "baseline sai 0 mesmo sem projeto"     exit_is 0 bash "$GATES" baseline "$T"
(cd "$T" && printf 'let apiKey = "abcdef1234567890"\n' > K.swift && git add -A && git commit -qm leak)
check "gate detecta segredo no diff"         bash -c "bash '$GATES' run '$T' | grep -q 'possíveis segredos'"
(cd "$T" && git rm -q K.swift && git commit -qm clean)
check "sem segredo, gate de segredos passa"  bash -c "bash '$GATES' run '$T' | grep -q 'nenhum padrão de segredo'"

echo
echo "Resultado: $PASS ok, $FAILS falhas"
[[ $FAILS -eq 0 ]]
