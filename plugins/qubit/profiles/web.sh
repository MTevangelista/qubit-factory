# Perfil web: JavaScript / TypeScript (React, Vue, Svelte, Node...), via package.json.
# Sourced pelos gates (factory-gates.sh) na raiz do worktree, depois de factory/config.sh.
# Regra: só preencha o que a config deixou vazio. Os comandos vêm dos scripts do package.json.

# Regras de permissão (separadas por ;) que o /qubit init sugere em .claude/settings.json.
FACTORY_PERMISSIONS="Bash(npm run:*);Bash(npm ci:*);Bash(pnpm run:*);Bash(yarn run:*);Bash(npx --no-install tsc:*)"

FACTORY_SOURCE_EXTS="ts tsx js jsx mjs cjs vue svelte"
FACTORY_UI_PATH_REGEX='\.(tsx|jsx|vue|svelte|astro|css|scss|sass|less|html)$'
FACTORY_UI_CONTENT_REGEX=''

if [[ -f package.json ]]; then
  _pm="npm"; _install="npm install"
  [[ -f package-lock.json ]] && _install="npm ci"
  if   [[ -f pnpm-lock.yaml ]]; then _pm="pnpm"; _install="pnpm install --frozen-lockfile"
  elif [[ -f yarn.lock      ]]; then _pm="yarn"; _install="yarn install --frozen-lockfile"
  elif [[ -f bun.lockb || -f bun.lock ]]; then _pm="bun"; _install="bun install --frozen-lockfile"; fi
  _has_script() {
    python3 -I -c 'import json,sys; sys.exit(0 if sys.argv[1] in json.load(open("package.json")).get("scripts", {}) else 1)' "$1" 2>/dev/null
  }
  [[ -z "${FACTORY_SETUP_CMD:-}" && ! -d node_modules ]] && FACTORY_SETUP_CMD="$_install"
  [[ -z "${FACTORY_LINT_CMD:-}"   ]] && _has_script lint && FACTORY_LINT_CMD="$_pm run lint"
  if [[ -z "${FACTORY_FORMAT_CMD:-}" ]]; then
    if   _has_script format:check; then FACTORY_FORMAT_CMD="$_pm run format:check"
    elif _has_script check:format; then FACTORY_FORMAT_CMD="$_pm run check:format"; fi
  fi
  if [[ -z "${FACTORY_TYPECHECK_CMD:-}" ]]; then
    if   _has_script typecheck;  then FACTORY_TYPECHECK_CMD="$_pm run typecheck"
    elif _has_script type-check; then FACTORY_TYPECHECK_CMD="$_pm run type-check"
    elif [[ -f tsconfig.json ]]; then FACTORY_TYPECHECK_CMD="npx --no-install tsc --noEmit"; fi
  fi
  [[ -z "${FACTORY_BUILD_CMD:-}" ]] && _has_script build && FACTORY_BUILD_CMD="$_pm run build"
  [[ -z "${FACTORY_TEST_CMD:-}"  ]] && _has_script test  && FACTORY_TEST_CMD="CI=true $_pm run test"
  unset -f _has_script
  unset _pm _install
fi
