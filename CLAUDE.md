# qubit-factory

App iOS em Swift. Este repo tem uma **software factory** (`/factory`) que produz features, correções de bug e refactors com agentes. Detalhes em `factory/README.md`.

## Projeto
- Linguagem: Swift 6, UI em SwiftUI. Mínimo iOS: _preencher_.
- Arquitetura: _preencher (ex.: MVVM com @Observable, injeção por inicializador)_.
- Estrutura de pastas: _preencher quando o projeto Xcode existir_.

## Comandos (a fábrica usa estes; mantenha em sincronia com `factory/config.sh`)
- Gates completos: `bash scripts/factory-gates.sh run .`
- Build: `xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Testes: `xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Lint: `swiftlint lint --strict`

## Convenções
- Mensagens de commit em português: `tipo(escopo): resumo` (feat, fix, refactor, test, chore, docs).
- Sem `force unwrap`, `try!` nem `fatalError` fora de testes.
- Concorrência estrita do Swift 6: sem warnings; `@MainActor` em UI; `async/await` em vez de callbacks.
- Todo texto de usuário localizável; suporte a Dynamic Type, dark mode e VoiceOver.
- Dependência de terceiros só com aprovação explícita no spec.
- Segredos nunca no repo; dados sensíveis no Keychain.

## Regras da fábrica
- Agentes **não** alteram `.claude/`, `scripts/factory-*`, `factory/config.sh`, `factory/lessons.md` nem este arquivo dentro de um worktree (o hook `guard.sh` bloqueia). Quem muda isso é uma pessoa.
- Nunca `git push`. O merge é local, na `master`, feito pelo orquestrador depois do `APPROVE`.
