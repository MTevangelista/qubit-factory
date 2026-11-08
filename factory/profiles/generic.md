# Perfil: generic

Perfil sem suposição de linguagem. Use quando nenhum outro servir; as convenções vêm do `CLAUDE.md` do projeto e os comandos de `factory/config.sh` (`FACTORY_TEST_CMD` é obrigatório). Para uma stack que vai se repetir, prefira criar um perfil próprio (veja `factory/profiles/README.md`).

## Stack
Definida pelo `CLAUDE.md` do projeto. Leia-o antes de qualquer coisa.

## Código
- Siga as convenções do `CLAUDE.md` e do código vizinho (nomes, camadas, tratamento de erro).
- Sem erro engolido, sem estado inválido representável, sem duplicar o que já existe no repo.
- Dependência nova só com aprovação explícita no spec.

## Testes
- Use o framework de teste que o projeto já usa.
- Teste sem asserção ou mock que devolve o próprio valor esperado não contam como cobertura.
- Flaky: relógio real, rede real, ordem de execução, esperas fixas.

## Segurança
- Segredos no código ou em arquivo versionado; dado sensível em claro ou em log.
- Entrada não confiável sem validação; injeção (SQL, shell, template); desserialização insegura.
- TLS desligado ou certificado aceito sem validar; criptografia caseira ou fraca.
- Dependência nova sem justificativa.

## UI
Se o projeto tiver interface: fonte escalável, contraste WCAG AA, layout adaptativo, nome acessível em controles, textos localizáveis, reuso do design system.

## UX
Fluxo curto e sem beco sem saída; estados de carregando, vazio, erro e sucesso; feedback imediato; mensagens claras e acionáveis.

## Spec
Riscos típicos: compatibilidade, migração de dados, concorrência, acessibilidade, privacidade.

## Logs
Padrão para filtrar logs de build e teste:
`rg -n -i 'error|fail|exception|panic' <log> | head -40`

## Skills
Nenhuma.
