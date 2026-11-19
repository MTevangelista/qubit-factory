# Perfil ios: Swift / SwiftUI, Xcode ou Swift Package.
# Sourced pelos gates (factory-gates.sh) na raiz do worktree, depois de factory/config.sh.
# Regra: só preencha o que a config deixou vazio.

# Regras de permissão (separadas por ;) que o /qubit init sugere em .claude/settings.json.
FACTORY_PERMISSIONS="Bash(xcodebuild:*);Bash(swift build:*);Bash(swift test:*);Bash(swiftlint:*);Bash(swift-format:*)"

FACTORY_SOURCE_EXTS="swift"
FACTORY_UI_PATH_REGEX='\.(xcassets|storyboard|xib|strings|xcstrings)(/|$)'
FACTORY_UI_CONTENT_REGEX='^[[:space:]]*import[[:space:]]+(SwiftUI|UIKit)'

: "${FACTORY_DESTINATION:=platform=iOS Simulator,name=iPhone 16}"
[[ -z "${FACTORY_LINT_CMD:-}" ]] && FACTORY_LINT_CMD="swiftlint lint --strict --quiet"
if [[ -z "${FACTORY_FORMAT_CMD:-}" && -f .swift-format ]]; then
  FACTORY_FORMAT_CMD="swift-format lint --strict --recursive ."
fi

_ios_xc=""
if   [[ -n "${FACTORY_WORKSPACE:-}" ]]; then _ios_xc="-workspace $(printf %q "$FACTORY_WORKSPACE")"
elif [[ -n "${FACTORY_PROJECT:-}"   ]]; then _ios_xc="-project $(printf %q "$FACTORY_PROJECT")"
else
  _ios_ws="$(find . -maxdepth 2 -name '*.xcworkspace' -not -path '*.xcodeproj/*' -not -path './.build/*' | head -1)"
  _ios_pj="$(find . -maxdepth 2 -name '*.xcodeproj' -not -path './.build/*' | head -1)"
  if   [[ -n "$_ios_ws" ]]; then _ios_xc="-workspace $(printf %q "$_ios_ws")"
  elif [[ -n "$_ios_pj" ]]; then _ios_xc="-project $(printf %q "$_ios_pj")"; fi
fi

if [[ -n "$_ios_xc" ]]; then
  if [[ -z "${FACTORY_SCHEME:-}" ]]; then
    [[ -z "${FACTORY_TEST_CMD:-}" ]] && FACTORY_PROFILE_ERROR="FACTORY_SCHEME vazio em factory/config.sh (projeto Xcode encontrado)"
  else
    _ios_base="xcodebuild $_ios_xc -scheme $(printf %q "$FACTORY_SCHEME") -destination $(printf %q "$FACTORY_DESTINATION") -quiet"
    [[ -z "${FACTORY_BUILD_CMD:-}" ]] && FACTORY_BUILD_CMD="$_ios_base build-for-testing"
    [[ -z "${FACTORY_TEST_CMD:-}"  ]] && FACTORY_TEST_CMD="$_ios_base test-without-building"
  fi
elif [[ -f Package.swift ]]; then
  [[ -z "${FACTORY_BUILD_CMD:-}" ]] && FACTORY_BUILD_CMD="swift build"
  [[ -z "${FACTORY_TEST_CMD:-}"  ]] && FACTORY_TEST_CMD="swift test"
fi
unset _ios_xc _ios_ws _ios_pj _ios_base

# Limpeza pós-merge (factory-cleanup.sh): o Xcode cria um DerivedData por caminho de projeto, então cada
# worktree deixa uma pasta própria em ~/Library/Developer/Xcode/DerivedData. Apaga só as do worktree do job.
factory_cleanup_caches() { # factory_cleanup_caches <caminho-do-worktree>
  local wt="$1" dd="${FACTORY_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}" d wp
  [[ -n "$wt" && -d "$dd" ]] || return 0
  for d in "$dd"/*/; do
    [[ -f "$d/info.plist" ]] || continue
    wp="$(/usr/libexec/PlistBuddy -c 'Print :WorkspacePath' "$d/info.plist" 2>/dev/null \
       || plutil -extract WorkspacePath raw -o - "$d/info.plist" 2>/dev/null)" || continue
    if [[ "$wp" == "$wt"/* ]]; then
      rm -rf "${d%/}" && echo "cache removido: ${d%/}"
    fi
  done
}
