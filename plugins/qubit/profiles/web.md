# Perfil: web

Convenções e checklists que os agentes da fábrica seguem quando `FACTORY_PROFILE="web"`. Cada agente lê só as seções do seu papel. O `CLAUDE.md` do projeto vence este arquivo quando os dois discordarem.

## Stack
JavaScript/TypeScript com `package.json` (npm, pnpm, yarn ou bun, pelo lockfile). Frontend (React, Vue, Svelte, Next, Vite...) e/ou backend Node. Os gates usam os scripts do `package.json`: `lint`, `format:check`, `typecheck` (ou `tsc --noEmit`), `build` e `test`.

## Código
- TypeScript estrito quando o projeto usa TS: sem `any` novo, sem `as` para calar o compilador, sem `@ts-ignore` sem justificativa; tipos nas fronteiras (API, props).
- Assincronia: `async/await`, toda promise tratada (nada de promise solta), erros não engolidos, cancelamento (`AbortController`) em requisições ligadas a componente.
- React: hooks com dependências corretas, sem estado derivado duplicado, `key` estável em listas, efeitos com limpeza, sem re-render pesado; Vue/Svelte: reatividade idiomática do framework.
- Backend Node: validação de entrada nas fronteiras, sem bloquear o event loop, erros com status corretos.
- Arquitetura: respeita a estrutura de pastas e camadas do projeto; reaproveita utilitários existentes.
- Textos de usuário pela solução de i18n do projeto, se houver.
- Dependência nova no `package.json` só com aprovação explícita no spec; lockfile atualizado junto.

## Testes
- Use o runner do projeto (Vitest, Jest, Playwright, Testing Library...). Testes de componente pelo comportamento visível (papel, texto), não por detalhes de implementação.
- Teste sem asserção, snapshot gigante como única asserção ou mock que devolve o próprio valor esperado não contam como cobertura.
- Arquivos de teste: `*.test.*`, `*.spec.*`, `__tests__/`. Use `git diff --diff-filter=MD -- '*.test.*' '*.spec.*' '**/__tests__/**'` para achar testes existentes alterados.
- Flaky: timers reais, rede real, ordem; use fake timers e mocks de rede (MSW ou equivalente).

## Segurança
- **Segredos:** chaves no código ou em variável exposta ao cliente (`NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`); `.env` versionado.
- **XSS:** `dangerouslySetInnerHTML`, `v-html`, `{@html}`, `innerHTML` com dado não sanitizado; URL `javascript:` em `href`.
- **Autenticação e sessão:** token em `localStorage` quando cookie `HttpOnly` é viável; cookie sem `Secure`/`SameSite`; CSRF em rotas que mudam estado.
- **Backend:** SQL/NoSQL montado por concatenação, path traversal, SSRF, validação ausente, CORS `*` com credenciais, rate limit onde o spec exige.
- **Dados sensíveis:** PII em log, analytics ou URL; resposta de API devolvendo campos a mais.
- **Dependências:** pacote novo sem justificativa, pacote abandonado ou com nome parecido com um popular (typosquatting); `postinstall` suspeito.
- **Cabeçalhos:** CSP, `X-Frame-Options`/`frame-ancestors` quando o projeto controla o servidor.

## UI
- **Responsivo:** de 320 px a desktop, sem rolagem horizontal; unidades relativas (`rem`) para texto.
- **Tema:** tokens/variáveis CSS do projeto; dark mode se o projeto suportar; contraste WCAG AA (4.5:1).
- **Componentes:** reutiliza o design system; nada de recriar botão ou input que já existe.
- **Acessibilidade técnica:** HTML semântico (`button`, `label`, `nav`, cabeçalhos em ordem), `alt` em imagens, nome acessível em controles só com ícone, ARIA só quando o HTML não resolve, foco visível, alvo mínimo de 24x24 px (WCAG 2.2).
- **Teclado:** tudo operável por teclado, ordem de tab lógica, sem armadilha de foco.
- **Animações:** respeitam `prefers-reduced-motion`.
- **Evidência visual:** se o `CLAUDE.md` disser como subir o app, gere screenshots (por exemplo com Playwright).

## UX
- **Fluxo:** caminho feliz curto, URL reflete o estado navegável, voltar do navegador funciona, sem beco sem saída.
- **Estados:** carregando (skeleton ou indicador), vazio, erro e sucesso, com mensagem humana e ação de recuperação.
- **Feedback:** resposta imediata a cliques, botão desabilitado durante envio, ação destrutiva com confirmação ou desfazer.
- **Formulários:** `label` associado, `type`/`autocomplete`/`inputmode` corretos, validação inline e mensagem de erro ligada ao campo (`aria-describedby`).
- **Leitor de tela:** anúncios de mudanças dinâmicas (`aria-live`), foco gerenciado em modais e trocas de rota.

## Spec
- Riscos típicos: compatibilidade de navegadores, SSR/hidratação, cache e invalidação, contrato de API, migração de banco (backend), acessibilidade, SEO.
- Feature com UI: ACs de teclado, leitor de tela, contraste, responsivo e estados.
- Plano de testes: unitário/componente com o runner do projeto; e2e só se o projeto já tiver.

## Logs
Padrão para filtrar logs de build e teste:
`rg -n 'error|Error:|FAIL|✕|×|failed|TS[0-9]{4}' <log> | head -40`

## Skills
Nenhuma skill específica de web vem com a fábrica; use as que estiverem instaladas.
