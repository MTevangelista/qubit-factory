# Perfil: android

Convenções e checklists que os agentes da fábrica seguem quando `FACTORY_PROFILE="android"`. Cada agente lê só as seções do seu papel. O `CLAUDE.md` do projeto vence este arquivo quando os dois discordarem.

## Stack
App Android em Kotlin (Java onde já existir), build com Gradle (`./gradlew`). UI em Jetpack Compose ou Views/XML. Lint com Android Lint e, se configurados, ktlint/spotless e detekt. Testes unitários com JUnit (4 ou 5) e, se houver, Robolectric, Turbine e MockK.

## Código
- Kotlin idiomático: `val` por padrão, null safety sem `!!` fora de testes, `sealed`/`data class` para estado, `when` exaustivo.
- Concorrência com coroutines: `viewModelScope`/`lifecycleScope`, nada de `GlobalScope`; dispatchers injetados; `Flow`/`StateFlow` para estado; coleta ligada ao ciclo de vida (`collectAsStateWithLifecycle`, `repeatOnLifecycle`).
- Arquitetura: respeita as camadas do projeto (UI, ViewModel, domínio, dados); dependências por injeção (Hilt/Koin/manual, o que o projeto usar).
- Compose: estado elevado (state hoisting), `remember`/`rememberSaveable` corretos, `key` estável em `LazyColumn`, sem trabalho pesado na composição, `Modifier` como primeiro parâmetro opcional.
- Memória: nada de `Context` de Activity guardado em singleton ou ViewModel; listeners removidos.
- Strings de usuário em `res/values/strings.xml`; cores e dimensões por tema/tokens.
- Dependência nova no Gradle (ou no version catalog) só com aprovação explícita no spec.

## Testes
- Unitários em `src/test` (JUnit); instrumentados em `src/androidTest` só se o projeto já tiver.
- Coroutines com `runTest` e `StandardTestDispatcher`; `Flow` com Turbine se disponível. Nada de `Thread.sleep`.
- Teste sem asserção, mock que devolve o próprio valor esperado ou asserção trivial não contam como cobertura.
- Use `git diff --diff-filter=MD -- '*/src/test/*' '*/src/androidTest/*'` para achar testes existentes alterados.

## Segurança
- **Segredos:** chaves e tokens em código, `gradle.properties` versionado, `BuildConfig` ou `strings.xml`.
- **Armazenamento:** credencial e token via Android Keystore (ou EncryptedSharedPreferences / DataStore cifrado); nunca em `SharedPreferences` em claro, arquivo externo ou log.
- **Rede:** `usesCleartextTraffic`, `network_security_config` permissivo, `TrustManager`/`HostnameVerifier` que aceita tudo, pinning ausente onde o spec exige.
- **Componentes exportados:** `Activity`/`Service`/`Receiver`/`Provider` com `exported="true"` sem permissão; `PendingIntent` sem `FLAG_IMMUTABLE`; intent implícito com dado sensível.
- **WebView:** `setJavaScriptEnabled` com conteúdo remoto, `addJavascriptInterface`, `setAllowFileAccess`.
- **Entrada não confiável:** deep links, intents de outros apps, arquivos, JSON do servidor; SQL montado por concatenação.
- **Logs:** `Log.*` com dado sensível em release.
- **Privacidade:** permissão nova no `AndroidManifest.xml` sem justificativa no spec; permissão perigosa sem explicação prévia.
- **Release:** `debuggable`, backup (`allowBackup`) de dados sensíveis, código de debug fora de `BuildConfig.DEBUG`.

## UI
- **Fonte escalável:** tamanhos em `sp`, layout que não corta com fonte grande.
- **Tema:** cores do `MaterialTheme`/tema, suporte a dark theme, contraste WCAG AA (4.5:1).
- **Layout adaptativo:** telas pequenas e grandes, orientação, insets (edge-to-edge, `WindowInsets`), tablets e dobráveis se o projeto suportar.
- **Componentes:** reutiliza o design system; espaçamentos por tokens.
- **Acessibilidade técnica:** `contentDescription` em ícones e imagens (null em decorativas), alvo mínimo de 48x48 dp, `semantics`/`mergeDescendants` coerentes.
- **Localização:** strings em recursos, plurais com `plurals`, RTL com `start`/`end`.
- **Previews:** `@Preview` cobrindo normal, vazio, erro, fonte grande e dark.

## UX
- **Navegação pelo Material:** botão e gesto de voltar previsíveis, back stack coerente, sem beco sem saída.
- **Estados:** carregando, vazio, erro, offline e sucesso, com mensagem humana e ação de recuperação; estado sobrevive a rotação e morte do processo.
- **Feedback:** resposta imediata (estado do botão, indicador de progresso, `Snackbar`); ação destrutiva com confirmação ou desfazer.
- **Entrada de dados:** `KeyboardOptions` (tipo, `imeAction`), foco entre campos, validação inline, autofill.
- **TalkBack:** ordem de leitura, anúncios de mudanças dinâmicas (`liveRegion`), foco após navegação.
- **Permissões:** explicar antes de pedir (rationale); funcionar com permissão negada.

## Spec
- Riscos típicos: ciclo de vida (rotação, morte do processo), concorrência com coroutines, migração de banco (Room), `minSdk`, acessibilidade, permissões no manifest.
- Feature com UI: ACs de fonte escalável, TalkBack, contraste, dark theme e estados.
- Plano de testes: unitário (JUnit + coroutines-test); instrumentado só se o projeto já usar.

## Logs
Padrão para filtrar logs de build e teste:
`rg -n 'e: |error:|FAILED|BUILD FAILED|Exception|warning:' <log> | head -40`

## Skills
Nenhuma skill específica de Android vem com a fábrica; use as que estiverem instaladas.
