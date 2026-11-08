# Perfil python: Python (backend, CLI, dados), com pytest.
# Sourced pelos gates (factory-gates.sh) na raiz do worktree, depois de factory/config.sh.
# Regra: só preencha o que a config deixou vazio.

# Regras de permissão (separadas por ;) que o /qubit init sugere em .claude/settings.json.
FACTORY_PERMISSIONS="Bash(pytest:*);Bash(python3 -m pytest:*);Bash(ruff:*);Bash(mypy:*);Bash(uv run:*);Bash(poetry run:*)"

FACTORY_SOURCE_EXTS="py"
FACTORY_UI_PATH_REGEX='(^|/)templates/.*\.(html|jinja2?|j2)$|\.(css|scss)$'
FACTORY_UI_CONTENT_REGEX=''

_py_run=""
if   [[ -f uv.lock     ]]; then _py_run="uv run ";     [[ -z "${FACTORY_SETUP_CMD:-}" ]] && FACTORY_SETUP_CMD="uv sync --frozen"
elif [[ -f poetry.lock ]]; then _py_run="poetry run "; [[ -z "${FACTORY_SETUP_CMD:-}" ]] && FACTORY_SETUP_CMD="poetry install --no-interaction"; fi

[[ -z "${FACTORY_LINT_CMD:-}"   ]] && FACTORY_LINT_CMD="ruff check ."
[[ -z "${FACTORY_FORMAT_CMD:-}" ]] && FACTORY_FORMAT_CMD="ruff format --check ."
if [[ -z "${FACTORY_TYPECHECK_CMD:-}" ]] && { [[ -f mypy.ini ]] || grep -qs '^\[tool\.mypy\]' pyproject.toml; }; then
  FACTORY_TYPECHECK_CMD="${_py_run}mypy ."
fi
if [[ -z "${FACTORY_TEST_CMD:-}" ]]; then
  if [[ -d tests || -f pytest.ini || -f conftest.py ]] || grep -qs '^\[tool\.pytest' pyproject.toml \
     || git ls-files -- 'test_*.py' '*/test_*.py' '*_test.py' 2>/dev/null | grep -q .; then
    if [[ -n "$_py_run" ]]; then FACTORY_TEST_CMD="${_py_run}pytest -q"; else FACTORY_TEST_CMD="python3 -m pytest -q"; fi
  fi
fi
unset _py_run
