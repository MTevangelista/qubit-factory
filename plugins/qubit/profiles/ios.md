# Perfil: ios

Convenções e checklists que os agentes da fábrica seguem quando `FACTORY_PROFILE="ios"`. Cada agente lê só as seções do seu papel. O `CLAUDE.md` do projeto vence este arquivo quando os dois discordarem.

## Stack
App iOS em Swift 6 com SwiftUI (UIKit onde já existir). Build com Xcode (`xcodebuild`) ou Swift Package (`swift build`/`swift test`). Lint com SwiftLint e, se houver `.swift-format`, swift-format. Testes com Swift Testing (`@Test`, `#expect`) ou XCTest.

## Código
- Swift 6 com concorrência estrita: sem warnings; `@MainActor` em tipos de UI; `Sendable` correto; `async/await` e actors em vez de callbacks e locks.
- Sem `force unwrap`, `try!`, `as!` nem `fatalError` fora de testes e de pontos de inicialização justificados.
- SwiftUI: `@Observable`/`@State`/`@Binding` apropriados, `ForEach` com identidade estável, views pequenas, nada de `AnyView` sem necessidade, sem trabalho pesado no `body`.
- Memória: `[weak self]` em closures guardadas, `Task` longa sem capturar `self` forte, `Task` guardada e cancelada ao sair da tela, observadores e `Timer` invalidados.
- Nomes seguem as Swift API Design Guidelines; nada de `public` desnecessário; tipos acima de ~300 linhas pedem divisão.
- Strings de usuário localizáveis (`String(localized:)`, `LocalizedStringKey`); cores e fontes por tokens/asset catalog.
- Dependência nova (SPM/CocoaPods) só com aprovação explícita no spec.

## Testes
- Swift Testing (`@Test`, `#expect`, `#require`) para testes novos; XCTest onde o projeto já usa.
- Asserção vazia, `XCTAssertTrue(true)`, teste sem `#expect`/`XCTAssert` e mock que devolve o próprio valor esperado não contam como cobertura.
- Arquivos de teste: `*Tests.swift`, em targets `*Tests`. Use `git diff --diff-filter=MD -- '*Tests*'` para achar testes existentes alterados.
- Flaky: `Task.sleep`, relógio real, rede real, ordem de execução. Injete relógio e cliente de rede.
- Snapshot/UI test só se o projeto já tiver a infraestrutura.

## Segurança
- **Segredos:** chaves, tokens e URLs privadas em código, `Info.plist`, `xcconfig` versionado ou testes.
- **Armazenamento:** token, PII e credencial no **Keychain** com `kSecAttrAccessible` adequado; nunca em `UserDefaults`, arquivo em claro ou log. Arquivos sensíveis com `FileProtectionType`.
- **Rede:** `NSAllowsArbitraryLoads` ou exceções de ATS, HTTP em claro, `URLSessionDelegate` aceitando qualquer certificado, pinning ausente onde o spec exige.
- **Logs:** `print`/`NSLog`/`os_log` com dado sensível (use `privacy: .private`); dados sensíveis em crash report ou analytics.
- **Entrada não confiável:** deep links, universal links, URL schemes, pasteboard, arquivos importados, JSON do servidor; `WKWebView` com JavaScript e conteúdo remoto, `evaluateJavaScript` com string concatenada.
- **Autenticação:** `LocalAuthentication` só como UI, sem vínculo com Keychain (`SecAccessControl`); fallback inseguro.
- **Privacidade:** permissão nova no `Info.plist` sem justificativa no spec, string de uso vaga, `PrivacyInfo.xcprivacy` desatualizado, APIs de "required reason".
- **Criptografia:** algoritmo caseiro, MD5/SHA1 para segurança, chave/IV fixos, `arc4random` onde cabe `SecRandomCopyBytes`.
- **Debug:** código de debug ou backdoor fora de `#if DEBUG`.

## UI
- **Dynamic Type:** fontes por `Font.TextStyle`; nada de tamanho fixo que quebre em `accessibilityXXXL`; texto que trunca em tamanhos grandes.
- **Dark mode e cores:** cores semânticas ou do asset catalog, nada de `Color.white`/`.black` fixos sem motivo; contraste WCAG AA (4.5:1).
- **Layout adaptativo:** iPhone SE a Pro Max, iPad, orientação, `safeArea`, sem frames fixos frágeis.
- **Componentes:** reutiliza o design system; espaçamentos e raios por tokens.
- **Acessibilidade técnica:** `accessibilityLabel`/`Hint`/`Value` em controles sem texto, alvo mínimo de 44x44 pt, imagens decorativas escondidas, `accessibilityElement(children:)` coerente.
- **Localização:** nada de concatenar frases traduzíveis; RTL com `leading`/`trailing`.
- **Previews:** `#Preview` cobrindo normal, vazio, erro, texto grande e dark.
- **Animações:** respeitam `accessibilityReduceMotion`.
- **Evidência visual:** se houver simulador e o `CLAUDE.md` disser como, gere screenshots.

## UX
- **Navegação pela HIG:** push vs. sheet, botão de voltar, gesto de fechar; sem beco sem saída.
- **Estados:** carregando, vazio, erro, offline e sucesso, com mensagem humana e ação de recuperação.
- **Feedback:** resposta imediata (estado do botão, `ProgressView`, haptics quando fizer sentido); ação destrutiva com confirmação ou desfazer.
- **Entrada de dados:** `keyboardType`, `textContentType`, `submitLabel`, foco entre campos, validação inline.
- **VoiceOver:** ordem de leitura, foco movido após mudar de tela, `AccessibilityNotification` para mudanças dinâmicas.
- **Permissões:** explicar antes de pedir; funcionar com permissão negada.

## Spec
- Riscos típicos: concorrência (`@MainActor`, `Sendable`), migração de dados persistidos, versão mínima do iOS, acessibilidade, privacidade (`Info.plist`, `PrivacyInfo.xcprivacy`).
- Feature com UI: ACs de Dynamic Type, VoiceOver, contraste, dark mode e estados (carregando, vazio, erro).
- Plano de testes: unitário (Swift Testing), snapshot ou UI test só se o projeto já usar.

## Logs
Padrão para filtrar logs de build e teste:
`rg -n 'error:|warning:|failed|FAIL|✘|Test Case .* failed' <log> | head -40`

## Skills
Skills úteis, se estiverem instaladas: `swift-concurrency`, `swift-testing-expert`, `swiftui-expert-skill`, `swift-code-reviewer`.
