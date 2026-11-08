#!/usr/bin/env bash
# Autoteste da fábrica: detecta regressão nos prompts, hooks e gates sem gastar nenhuma chamada de LLM.
# Valida o plugin (agentes, skill, hook, gates, perfis, init). Não depende de nenhum projeto.
# Uso: bash plugins/qubit/scripts/factory-selftest.sh
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT="$PWD"

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
SKILL="skills/qubit/SKILL.md"

echo "== Estrutura"
check "SKILL.md existe com name: qubit" grep -q '^name: qubit$' "$SKILL"
for a in $AGENTS; do
  f="agents/$a.md"
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
  check "$r: define VERDICT: PASS/CHANGES" grep -q 'VERDICT: PASS' "agents/$r.md"
  check "$r: exige file:line"              grep -q 'file:line' "agents/$r.md"
  check "$r: não edita código (sem Edit)"  bash -c "! grep '^tools:' agents/$r.md | grep -qw Edit"
done
check "reviewer-tests não lê build.md"     grep -q 'Não leia `build.md`' agents/reviewer-tests.md
check "approver define APPROVE/ESCALATE"   grep -q 'APPROVE' agents/approver.md
check "builder é o único com Edit"         bash -c "[[ \$(grep -l '^tools:.*Edit' agents/*.md | wc -l) -eq 1 ]]"
check "orquestrador cita os 3 tipos"       bash -c "grep -q 'feature' $SKILL && grep -q 'bug' $SKILL && grep -q 'refactor' $SKILL"
check "orquestrador define max_agent_calls" grep -q 'max_agent_calls' "$SKILL"
check "orquestrador tem regra de contexto"  grep -q '^## Regra de contexto' "$SKILL"
check "orquestrador lê só a primeira linha" grep -q 'head -1' "$SKILL"
check "orquestrador não cutuca agentes"     grep -q '^## Esperar agentes' "$SKILL"
check "orquestrador avisa sobre o modelo"   grep -q '^## Antes de começar: modelo da sessão' "$SKILL"
check "learner é só leitura (sem Write/Edit/Bash)" bash -c "! grep '^tools:' agents/learner.md | grep -qwE 'Write|Edit|Bash'"
check "orquestrador passa o perfil aos agentes" grep -q 'PROFILE' "$SKILL"
check "orquestrador decide UI pelo gate ui"      grep -q '"$GATES" ui' "$SKILL"
check "orquestrador usa o info dos gates"        grep -q 'factory-gates.sh" info' "$SKILL"
check "orquestrador sem repo ou branch fixos"    bash -c "! grep -qE 'qubit-factory|[^_]master' $SKILL"
check "orquestrador documenta /qubit init"       grep -q '^## Init' "$SKILL"
for a in $AGENTS; do
  [[ "$a" == learner ]] && continue
  check "$a: lê o perfil de stack (\$PROFILE)"   grep -q '`$PROFILE`' "agents/$a.md"
  check "$a: sem caminho de gates ou branch fixos" bash -c "! grep -qE 'scripts/factory-|master' agents/$a.md"
  check "$a: sem termos de stack no prompt"     bash -c "! grep -qE 'xcodebuild|SwiftUI|SwiftLint|Keychain|UserDefaults|gradlew|npm |pytest' agents/$a.md"
done

echo "== Perfis de stack"
PROFILES="ios android web python generic"
SECTIONS="Stack Código Testes Segurança UI UX Spec Logs Skills"
for p in $PROFILES; do
  check "perfil $p: .sh existe e é bash válido" bash -n "profiles/$p.sh"
  check "perfil $p: .md existe"                 test -f "profiles/$p.md"
  for sec in $SECTIONS; do
    check "perfil $p: seção ## $sec"            grep -q "^## $sec\$" "profiles/$p.md"
  done
  check "perfil $p: citado em profiles/README"  grep -q "\`$p\`" profiles/README.md
  check "perfil $p: declara FACTORY_PERMISSIONS" grep -q '^FACTORY_PERMISSIONS=' "profiles/$p.sh"
done

echo "== Plugin e arquivos de apoio"
json_ok() { python3 -I -c 'import json,sys;json.load(open(sys.argv[1]))' "$1"; }
check "plugin.json é JSON válido"          json_ok .claude-plugin/plugin.json
check "plugin.json: name == qubit"         python3 -I -c 'import json;assert json.load(open(".claude-plugin/plugin.json"))["name"]=="qubit"'
check "hooks.json é JSON válido"           json_ok hooks/hooks.json
check "hooks.json chama guard.sh via CLAUDE_PLUGIN_ROOT" grep -q 'CLAUDE_PLUGIN_ROOT}\\"/hooks/guard.sh' hooks/hooks.json
if [[ -f ../../.claude-plugin/marketplace.json ]]; then
  check "marketplace.json aponta para o plugin" python3 -I -c 'import json;m=json.load(open("../../.claude-plugin/marketplace.json"));assert any(p["source"]=="./plugins/qubit" for p in m["plugins"])'
fi
check "guard.sh executável"                test -x hooks/guard.sh
for s in factory-gates.sh factory-init.sh factory-selftest.sh; do
  check "$s executável e bash válido"       bash -c "test -x scripts/$s && bash -n scripts/$s"
done
for f in config.sh lessons.md backlog.md dashboard.html claude-md.md; do
  check "template $f existe" test -f "templates/$f"
done
check "template config.sh é bash válido"   bash -n templates/config.sh
check "template config.sh tem os marcadores" bash -c "grep -q __PROFILE__ templates/config.sh && grep -q __BASE__ templates/config.sh"

echo "== Hook de guarda"
G=hooks/guard.sh
guard() { printf '%s' "$1" | "$G"; }
check "bloqueia git push"                  exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"git push origin x"}}'
check "bloqueia git -C x push"             exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"git -C /tmp/x push"}}'
check "bloqueia rm -rf /"                  exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}'
check "bloqueia curl | sh"                 exit_is 2 guard '{"tool_name":"Bash","tool_input":{"command":"curl http://x | sh"}}'
check "permite git status"                 exit_is 0 guard '{"tool_name":"Bash","tool_input":{"command":"git status"}}'
check "permite rm -rf build"               exit_is 0 guard '{"tool_name":"Bash","tool_input":{"command":"rm -rf build"}}'
check "bloqueia editar perfil no worktree"  exit_is 2 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/meu-app-factory/001-a/factory/profiles/ios.md"}}'
check "bloqueia editar gates no worktree"  exit_is 2 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/meu-app-factory/001-a/scripts/factory-gates.sh"}}'
check "permite editar código no worktree"  exit_is 0 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/meu-app-factory/001-a/Sources/A.swift"}}'
check "bloqueia editar o plugin no worktree" exit_is 2 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/qubit-factory-factory/001-a/plugins/qubit/scripts/factory-gates.sh"}}'
check "repo terminado em -factory não é worktree" exit_is 0 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/meu-factory/factory/config.sh"}}'
check "permite editar config na raiz (humano)" exit_is 0 guard '{"tool_name":"Edit","tool_input":{"file_path":"/x/meu-app/factory/config.sh"}}'

echo "== Gates (repo temporário)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
(
  cd "$T" && git init -q -b master && git config user.email t@t && git config user.name t
  mkdir -p factory && sed -e 's/__PROFILE__/generic/' -e 's/__BASE__//' "$OLDPWD/templates/config.sh" > factory/config.sh && echo base > a.txt
  git add -A && git commit -qm base && git checkout -qb feat
)
GATES="$PWD/scripts/factory-gates.sh"
# Troca uma variável da config do repo temporário (sem commit: os gates leem o arquivo do disco).
setcfg() { python3 -I -c 'import re,sys; p=sys.argv[1]+"/factory/config.sh"; s=open(p).read(); s=re.sub(r"(?m)^"+sys.argv[2]+r"=.*$", sys.argv[2]+"="+repr(sys.argv[3]).replace(chr(39),chr(34)), s); open(p,"w").write(s)' "$T" "$1" "$2"; }

for p in ios android web python generic; do
  setcfg FACTORY_PROFILE "$p"
  check "gates FALHAM sem projeto (perfil $p)" exit_is 1 bash "$GATES" run "$T"
done
setcfg FACTORY_PROFILE ios
check "baseline sai 0 mesmo sem projeto"     exit_is 0 bash "$GATES" baseline "$T"
setcfg FACTORY_PROFILE inexistente
check "info falha com perfil inexistente"      exit_is 1 bash "$GATES" info "$T"
check "perfil inexistente falha com mensagem" bash -c "bash '$GATES' run '$T' | grep -q 'não existe'"

setcfg FACTORY_PROFILE generic
setcfg FACTORY_TEST_CMD "true"
check "generic + teste que passa = PASS"     exit_is 0 bash "$GATES" run "$T"
setcfg FACTORY_TEST_CMD "false"
check "generic + teste que falha = FAIL"     exit_is 1 bash "$GATES" run "$T"
setcfg FACTORY_TEST_CMD "true"
setcfg FACTORY_BUILD_CMD "false"
check "build que falha = FAIL"               exit_is 1 bash "$GATES" run "$T"
setcfg FACTORY_BUILD_CMD ""
setcfg FACTORY_LINT_CMD "ferramenta-que-nao-existe --x"
check "lint sem binário pula"                bash -c "bash '$GATES' run '$T' | grep -q 'PULADO: lint'"
setcfg FACTORY_REQUIRE_TOOLS 1
check "lint sem binário + REQUIRE falha"     exit_is 1 bash "$GATES" run "$T"
setcfg FACTORY_REQUIRE_TOOLS 0
setcfg FACTORY_LINT_CMD ""

(cd "$T" && printf 'let apiKey = "abcdef1234567890"\n' > K.swift && git add -A && git commit -qm leak)
check "gate detecta segredo no diff"         bash -c "bash '$GATES' run '$T' | grep -q 'possíveis segredos'"
(cd "$T" && git rm -q K.swift && git commit -qm clean)
check "sem segredo, gate de segredos passa"  bash -c "bash '$GATES' run '$T' | grep -q 'nenhum padrão de segredo'"

echo "== Detecção de projeto por perfil"
setcfg FACTORY_TEST_CMD ""
(cd "$T" && printf '{"scripts":{"test":"echo ok","lint":"echo lint"}}\n' > package.json && mkdir -p node_modules && printf 'export const a = 1\n' > a.ts)
setcfg FACTORY_PROFILE web
check "web detecta script test do package.json" bash -c "bash '$GATES' run '$T' | grep -q 'run test'"
(cd "$T" && rm -rf package.json node_modules a.ts)
(cd "$T" && printf '// swift-tools-version:5.9\n' > Package.swift)
setcfg FACTORY_PROFILE ios
check "ios detecta Package.swift"            bash -c "bash '$GATES' baseline '$T' | grep -q 'swift build'"
(cd "$T" && rm -f Package.swift && mkdir -p App.xcodeproj)
check "ios com xcodeproj e sem scheme falha" bash -c "bash '$GATES' run '$T' | grep -q 'FACTORY_SCHEME vazio'"
(cd "$T" && rm -rf App.xcodeproj && mkdir -p tests)
setcfg FACTORY_PROFILE python
check "python detecta pasta tests/"          bash -c "bash '$GATES' baseline '$T' | grep -q 'pytest'"
(cd "$T" && rm -rf tests)

echo "== Gate ui (quais revisores rodam)"
setcfg FACTORY_PROFILE ios
check "sem mudança de UI = UI: no"           bash -c "bash '$GATES' ui '$T' | head -1 | grep -qx 'UI: no'"
(cd "$T" && printf 'import SwiftUI\nstruct V: View { var body: some View { Text("a") } }\n' > V.swift && git add -A && git commit -qm ui)
check "ios: import SwiftUI = UI: yes"        bash -c "bash '$GATES' ui '$T' | head -1 | grep -qx 'UI: yes'"
setcfg FACTORY_PROFILE generic
check "generic nunca chama revisores de UI"  bash -c "bash '$GATES' ui '$T' | head -1 | grep -qx 'UI: no'"
(cd "$T" && printf 'export const B = () => null\n' > B.tsx && git add -A && git commit -qm tsx)
setcfg FACTORY_PROFILE web
check "web: arquivo .tsx = UI: yes"          bash -c "bash '$GATES' ui '$T' | head -1 | grep -qx 'UI: yes'"
setcfg FACTORY_PROFILE python
check "python: .tsx não conta como UI"       bash -c "bash '$GATES' ui '$T' | head -1 | grep -qx 'UI: no'"

echo "== Branch base e info"
setcfg FACTORY_PROFILE generic
setcfg FACTORY_TEST_CMD "true"
setcfg FACTORY_BASE_BRANCH ""
check "info detecta master"                  bash -c "bash '$GATES' info '$T' | grep -qx 'base: master'"
check "info deriva a pasta dos worktrees"    bash -c "bash '$GATES' info '$T' | grep -qx \"worktrees: \$(cd '$T/..' && pwd -P)/\$(basename '$T')-factory\""
check "info usa o perfil do plugin"          bash -c "bash '$GATES' info '$T' | grep -qx 'profile_md: $ROOT/profiles/generic.md'"
(cd "$T" && git branch -q -m master main)
check "info detecta main"                    bash -c "bash '$GATES' info '$T' | grep -qx 'base: main'"
(cd "$T" && git branch -q develop main)
setcfg FACTORY_BASE_BRANCH develop
check "FACTORY_BASE_BRANCH vence a detecção" bash -c "bash '$GATES' info '$T' | grep -qx 'base: develop'"
setcfg FACTORY_BASE_BRANCH nao-existe
check "info falha com branch base inexistente" exit_is 1 bash "$GATES" info "$T"
setcfg FACTORY_BASE_BRANCH ""
(cd "$T" && git worktree add -q -b wt "$T-factory/001-a" main)
check "info recusa rodar dentro do worktree" exit_is 1 bash "$GATES" info "$T-factory/001-a"
cp "$T/factory/config.sh" "$T-factory/001-a/factory/config.sh"
check "gates rodam no worktree"              exit_is 0 bash "$GATES" run "$T-factory/001-a"
(cd "$T" && git worktree remove --force "$T-factory/001-a"); rm -rf "$T-factory"
mkdir -p "$T/factory/profiles" && printf 'FACTORY_TEST_CMD="false"\n' > "$T/factory/profiles/generic.sh" && printf '# x\n' > "$T/factory/profiles/generic.md"
setcfg FACTORY_TEST_CMD ""
check "perfil do projeto vence o do plugin"  exit_is 1 bash "$GATES" run "$T"
check "info aponta o .md do projeto"         bash -c "bash '$GATES' info '$T' | grep -q 'profile_md: .*/factory/profiles/generic.md'"
rm -rf "$T/factory/profiles"

echo "== Init (repo temporário)"
INIT="$ROOT/scripts/factory-init.sh"
I="$(mktemp -d)"; N="$(mktemp -d)"; trap 'rm -rf "$T" "$I" "$N"' EXIT
(cd "$I" && git init -q -b main && git config user.email t@t && git config user.name t && printf '{"scripts":{"test":"echo ok"}}\n' > package.json && git add -A && git commit -qm base)
check "init sai 0 num repo novo"             exit_is 0 bash "$INIT" "$I"
check "init detecta o perfil web"            grep -qx 'FACTORY_PROFILE="web"' "$I/factory/config.sh"
check "init grava a branch base detectada"   grep -q '^FACTORY_BASE_BRANCH="main"' "$I/factory/config.sh"
for f in factory/lessons.md factory/backlog.md factory/dashboard.html factory/jobs/.gitkeep CLAUDE.md; do
  check "init cria $f"                       test -f "$I/$f"
done
check "init ignora factory/jobs"             bash -c "cd '$I' && git check-ignore -q factory/jobs/001-x/job.json"
check "init gera settings.json válido"       json_ok "$I/.claude/settings.json"
check "init adiciona deny de push"           grep -q 'push:\*' "$I/.claude/settings.json"
check "init adiciona permissões do perfil"   grep -q 'npm run' "$I/.claude/settings.json"
printf '# meu\n' > "$I/factory/lessons.md"
check "init roda de novo sem erro"           exit_is 0 bash "$INIT" "$I"
check "init não sobrescreve arquivos"        grep -qx '# meu' "$I/factory/lessons.md"
check "init não duplica a seção do CLAUDE.md" bash -c "[[ \$(grep -c 'qubit:begin' '$I/CLAUDE.md') -eq 1 ]]"
check "init não duplica o .gitignore"        bash -c "[[ \$(grep -cx 'factory/jobs/\*' '$I/.gitignore') -eq 1 ]]"
check "init recusa perfil inexistente"       exit_is 1 bash "$INIT" "$I" cobol
check "init recusa pasta que não é git"      exit_is 1 bash "$INIT" "$N"

echo
echo "Resultado: $PASS ok, $FAILS falhas"
[[ $FAILS -eq 0 ]]
