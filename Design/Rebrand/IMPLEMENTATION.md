# Plano de implementação — Rebranding do Cota

> Estado em 2026-10-19: passos 0 a 5 feitos na branch `feat/rebrand`. Ver "Notas de implementação" no fim.

Cada passo deve compilar e passar em `scripts/test.sh` e `scripts/lint.sh` antes do seguinte. A especificação visual está em `README.md`.

## 0. Colocar o pacote no repositório
- [x] Copiar esta pasta para `Design/Rebrand/`.
- [x] Copiar `Design/Rebrand/CLAUDE.md` para a raiz do repo.

## 1. Fundação: tema e idioma
- [x] Mover `swift/CotaTheme.swift` para `Sources/Cota/Views/Components/CotaTheme.swift`.
- [x] Mover `swift/L10n.swift` para `Sources/Cota/L10n.swift`.
- [x] Mover `Resources/` para `Sources/Cota/Resources/`.
- [x] `Package.swift`: `defaultLocalization: "pt-BR"` e, no alvo `Cota`, `resources: [.process("Resources")]`.
- [x] Empacotamento (`Makefile`, `rebuild.sh`, `scripts/make-dmg.sh`): copiar `.build/<config>/Cota_Cota.bundle` para `Cota.app/Contents/Resources/`. Adicionar `CFBundleLocalizations` ao `Info.plist`.
- [x] `SettingsStore`: `language: AppLanguage` em `UserDefaults`; atualiza `L10n.language`. Teste em `SettingsStoreTests`.
- [x] `QuoteFormat`: o locale vira parâmetro (padrão: idioma do app). Ajustar `QuoteFormatTests` para cobrir `en_US` ("5.6480", "398k", "1,000.50" no parse).
- [x] `Currency`: adicionar `avatarGlyph` (tabela no README). **Não** mudar `symbol`, porque o formato `auto` depende das colisões de "$".

## 2. Painel (`PanelView.swift` e componentes)
- [x] Contêiner, cabeçalho e rodapé com `CotaTheme`. Painel e Settings em `.preferredColorScheme(.dark)`.
- [x] `ListRow`: avatar com selo de destino, nome localizado, coluna de valor de 96 pt com o símbolo do destino.
- [x] `SparklineView`: cores menta e coral, linha de abertura `#4B5C55`. Novo modo grande (324×116) com área, ponto final e linha de alerta opcional.
- [x] Linha expansível (`expandedPairID`), com animação `CotaTheme.Motion.expand`.
- [x] `SegmentedControl`: variante menta (seleção `mint 16%`). Remover a dependência de `controlAccentColor`.
- [x] Conversor: campo, inverter e resultado, usando `QuoteFormat.parseThreshold` e `QuoteFormat.value`.
- [x] Copiar e Copiado (1,4 s).
- [x] Novo alerta e Remover alerta pelo `QuoteStore` / alertas existentes.
- [x] Contador de alertas no cabeçalho.
- [x] Dado velho: opacidade 0,5 nos valores e status âmbar no rodapé.
- [x] `.contentTransition(.numericText())` nos valores.

## 3. Rótulo da barra (`MenuBarLabelView.swift`)
- [x] Ponto menta de 5 pt quando o par tem alerta ligado.
- [x] Manter os formatos e indicadores atuais.

## 4. Settings
- [x] `SettingsView`: trocar as abas por barra lateral (190 pt) + conteúdo, com contagens em Pares e Alertas. Ajustar o tamanho em `SettingsWindowController` para cerca de 820×600.
- [x] Geral: intervalo, **Idioma** e abrir ao iniciar.
- [x] Pares: linhas de 46 pt, alfinete no lugar do checkbox, remover, arrastar para reordenar (mantém o comportamento atual).
- [x] **Folha "Adicionar par"**: substitui o menu com submenu. Busca, sugestões, colunas De/Para respeitando `PairCatalog`, inverter, prévia, aviso de par existente.
- [x] Barra de menus (`MenuBarSettingsSection`): prévia ao vivo dos pares fixados e formatos como cartões.
- [x] Alertas (`AlertsSection`, `AlertRows`): compositor em frase com dica ao vivo; linhas com progresso, estado e toggle.

## 5. Textos
- [x] Passar todo texto visível para `L10n.t`. Procurar strings literais nas views (`grep -n '"[A-Z]' Sources/Cota/Views`).
- [x] Notificações (`NotificationService`) com as chaves `notification.*`.
- [ ] Revisar EN e PT lado a lado com o protótipo (opção `lang`).

## 6. Conferência final
- [ ] Comparar cada tela com `design/Cota Rebrand.dc.html` (seções 2a e 2b), também com `stale = true`.
- [ ] Testar pares cruzados (USD/EUR, BRL/JPY) e cripto (BTC/USD).
- [x] Atualizar o `README.md` do repo com capturas novas, se houver.

## Pendências de design
- Variante clara (modo claro do macOS) ainda não desenhada.
- Estado vazio do painel (nenhum par) e do Alertas (nenhum alerta) ainda não desenhados.

## Notas de implementação
Onde o código saiu diferente do plano, e por quê:
- **`L10n` e `Resources/` estão no `CotaKit`**, não no alvo `Cota`. `QuoteFormat`, `MenuBarLabel`, `NotificationService` e `SettingsStore` vivem no `CotaKit` e precisam do idioma. O bundle empacotado é `Cota_CotaKit.bundle`.
- `L10n.language` começa em `.ptBR`. Só o store do app (`SettingsStore(drivesLocalization: true)`) o altera, para os testes não disputarem esse estado global.
- `Currency.moneySymbol` (US$, C$, CN¥…) prefixa valores no painel, no conversor e nos alertas. `symbol` e `avatarGlyph` seguem como no README.
- `QuoteFormat.threshold` mostra alvos sem casas sobrando (5,70) e nunca arredonda o que foi digitado. `QuoteFormat.parseThreshold` também recebe o locale: em EN, `5.123` é decimal.
- O formato `auto` aparece como "Símbolo".
- A janela do `MenuBarExtra` não acompanha a altura do conteúdo, então `syncsWindowHeight()` redimensiona a janela quando uma linha abre.
- O selo de destino aparece em todo par, inclusive BRL (`R$`). Antes ficava escondido nos pares em real, e o avatar sozinho não dizia em que moeda o par estava. O README foi atualizado.
- O selo tem um círculo discreto (grafite a 55%, 15 pt, sem borda) e o glifo do destino: menta a 35% (valor do Claude Design), 11 pt light, 4 pt para fora da borda do avatar. Glifos de dois caracteres usam 8,5 pt, para que `R$` não cubra o símbolo principal.
- O título da notificação usa o nome da moeda sem artigo ("Euro passou de R$ 5,75").
- Pendentes: conferência visual com `stale = true` e com pares cripto (BTC/USD) no app real.

