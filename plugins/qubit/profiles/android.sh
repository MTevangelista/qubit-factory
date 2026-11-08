# Perfil android: Kotlin / Java com Gradle (Jetpack Compose ou Views).
# Sourced pelos gates (factory-gates.sh) na raiz do worktree, depois de factory/config.sh.
# Regra: só preencha o que a config deixou vazio.

# Regras de permissão (separadas por ;) que o /qubit init sugere em .claude/settings.json.
FACTORY_PERMISSIONS="Bash(./gradlew:*);Bash(bash ./gradlew:*)"

FACTORY_SOURCE_EXTS="kt kts java"
FACTORY_UI_PATH_REGEX='(^|/)res/(layout|drawable|values|menu|navigation|mipmap)[^/]*/'
FACTORY_UI_CONTENT_REGEX='@Composable|androidx\.compose\.ui|android\.widget\.'

if [[ -f gradlew ]]; then
  _gw="bash ./gradlew --console=plain"
  _gradle_files="$(ls build.gradle* settings.gradle* */build.gradle* 2>/dev/null | tr '\n' ' ')"
  [[ -z "${FACTORY_LINT_CMD:-}"  ]] && FACTORY_LINT_CMD="$_gw lint"
  if [[ -z "${FACTORY_FORMAT_CMD:-}" && -n "$_gradle_files" ]]; then
    if   grep -qs ktlint  $_gradle_files gradle/libs.versions.toml; then FACTORY_FORMAT_CMD="$_gw ktlintCheck"
    elif grep -qs spotless $_gradle_files gradle/libs.versions.toml; then FACTORY_FORMAT_CMD="$_gw spotlessCheck"; fi
  fi
  if [[ -z "${FACTORY_TYPECHECK_CMD:-}" && -n "$_gradle_files" ]] && grep -qs detekt $_gradle_files gradle/libs.versions.toml; then
    FACTORY_TYPECHECK_CMD="$_gw detekt"
  fi
  [[ -z "${FACTORY_BUILD_CMD:-}" ]] && FACTORY_BUILD_CMD="$_gw assembleDebug"
  [[ -z "${FACTORY_TEST_CMD:-}"  ]] && FACTORY_TEST_CMD="$_gw testDebugUnitTest"
  unset _gw _gradle_files
fi
