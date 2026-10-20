# Cota — instruções para agentes

- O redesign aprovado está em `Design/Rebrand/`. Leia `Design/Rebrand/README.md` (especificação) e `Design/Rebrand/IMPLEMENTATION.md` (ordem de trabalho) antes de mexer em qualquer view.
- `Design/Rebrand/design/Cota Rebrand.dc.html` é a referência visual (abre no navegador). As seções **2a** (painel) e **2b** (Settings) são as aprovadas. 1a, 1b, 1c e 1d são exploração descartada; não implemente.
- Fonte da verdade para números: `QuoteFormat` (CotaKit). Não copie as regras de casas decimais do protótipo; só torne o locale configurável.
- Fonte da verdade para pares: `PairCatalog`. A folha "Adicionar par" desabilita destinos que não existem no catálogo.
- Todo texto visível passa por `L10n.t` com chave em `Sources/CotaKit/Resources/*.lproj/Localizable.strings` (as duas línguas têm as mesmas chaves). Nada de string solta em view.
- `L10n` e os textos ficam no `CotaKit`, não no app: `QuoteFormat`, `MenuBarLabel` e as notificações também precisam do idioma.
- Cores e medidas vêm de `CotaTheme`. Nada de hex solto em view.
- Rode `make` / `scripts/test.sh` e `scripts/lint.sh` antes de concluir.
