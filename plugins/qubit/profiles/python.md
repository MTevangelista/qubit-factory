# Perfil: python

Convenções e checklists que os agentes da fábrica seguem quando `FACTORY_PROFILE="python"`. Cada agente lê só as seções do seu papel. O `CLAUDE.md` do projeto vence este arquivo quando os dois discordarem.

## Stack
Python 3 (backend, CLI, dados). Dependências com uv, poetry ou pip (pelo lockfile). Lint e formato com ruff, tipos com mypy se configurado, testes com pytest.

## Código
- Type hints em funções públicas; sem `Any` novo sem motivo; `dataclass`/`pydantic` para estruturas.
- Erros: nada de `except:` ou `except Exception: pass`; exceções específicas; sem engolir erro.
- Recursos com `with` (arquivos, conexões, locks); nada de argumento padrão mutável.
- Assincronia (se o projeto usa `asyncio`): sem chamada bloqueante dentro de `async def`, tasks guardadas e canceladas.
- Arquitetura: respeita os módulos e camadas do projeto; dependências injetadas, não importadas globalmente para estado.
- Performance: nada de consulta N+1, nada de carregar arquivo grande inteiro sem necessidade.
- Dependência nova no `pyproject.toml`/`requirements` só com aprovação explícita no spec; lockfile atualizado junto.

## Testes
- pytest com fixtures; `parametrize` para variações; nada de teste que depende de outro.
- Teste sem `assert`, mock que devolve o próprio valor esperado ou asserção trivial não contam como cobertura.
- Arquivos de teste: `tests/`, `test_*.py`, `*_test.py`. Use `git diff --diff-filter=MD -- 'tests/*' '*test_*.py' '*_test.py'` para achar testes existentes alterados.
- Flaky: `time.sleep`, relógio real, rede real, ordem; use `freezegun`/injeção de relógio e mocks de rede.

## Segurança
- **Segredos:** chaves e senhas no código, em `settings.py` ou `.env` versionado.
- **Injeção:** SQL por f-string/concatenação (use parâmetros do driver/ORM), `subprocess` com `shell=True` e entrada externa, `eval`/`exec`.
- **Desserialização:** `pickle`, `yaml.load` sem `SafeLoader`, `marshal` com dado não confiável.
- **Arquivos e rede:** path traversal, SSRF em URL vinda do usuário, `verify=False` em `requests`/`httpx`.
- **Web (Django/FastAPI/Flask):** validação de entrada, autenticação e autorização por rota, CSRF, CORS permissivo, `DEBUG=True`.
- **Dados sensíveis:** PII ou credencial em log; senha sem hash forte (bcrypt/argon2).
- **Criptografia:** `random` onde cabe `secrets`; MD5/SHA1 para segurança.
- **Dependências:** pacote novo sem justificativa, nome parecido com um popular.

## UI
Este perfil não presume interface. Se o projeto tiver templates web, aplique: HTML semântico, `label` em campos, contraste WCAG AA, layout responsivo e textos por i18n se existir.

## UX
Para CLI e APIs: mensagens de erro claras e acionáveis, códigos de saída corretos, `--help` útil, respostas de API com status e corpo de erro consistentes.

## Spec
- Riscos típicos: migração de banco, compatibilidade de versão do Python, contrato de API, concorrência (`asyncio`, threads), volume de dados.
- Plano de testes: unitário com pytest; integração com banco só se o projeto já tiver infraestrutura.

## Logs
Padrão para filtrar logs de teste e lint:
`rg -n 'FAILED|ERROR|Error|error:|Traceback|assert' <log> | head -40`

## Skills
Nenhuma skill específica de Python vem com a fábrica; use as que estiverem instaladas.
