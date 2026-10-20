# Cota — pacote de Temas

Implementa **Settings → Temas** com quatro temas (Cota, Escuro, Claro, Liquid Glass) e a opção "Seguir o macOS". O tema vale para o painel, a janela de Settings, a folha "Adicionar par" e a prévia da barra de menus.

Este pacote vem **depois** do `design_handoff_cota_rebrand` (já aplicado). Ele foi escrito sobre o código atual do repositório: `CotaTheme`, `SettingsStore`, `SettingsView`, `PanelView` e `SettingsWindowController` como estão hoje.

## Como aplicar
1. Copie os arquivos novos para os mesmos caminhos no repositório:
   - `Sources/CotaKit/Models/AppTheme.swift`
   - `Sources/Cota/Views/Components/CotaTheme.swift` (**substitui** o atual)
   - `Sources/Cota/Views/Components/ThemeController.swift`
   - `Sources/Cota/Views/Components/ThemeSurface.swift`
   - `Sources/Cota/Views/ThemesSection.swift`
   - `Tests/CotaKitTests/AppThemeTests.swift`
2. Aplique as mudanças de `PATCHES.md` (SettingsStore, CotaApp, PanelView, SettingsView, AddPairSheet, AlertRows, SettingsWindowController e strings).
3. Rode `scripts/test.sh` e `scripts/lint.sh`.
4. Compare com `design/Cota Rebrand.dc.html` (seções 2a e 2b), trocando o tema pelo seletor **Tema** no topo da página.

## Como funciona
- **Nenhuma view muda de nome de token.** `CotaTheme.mint`, `.night`, `.textSecondary` e os outros continuam existindo, mas passam de `static let` para `static var` lidos da paleta ativa (`CotaTheme.palette`). As cerca de 150 chamadas atuais compilam sem mudança.
- **`ThemeController`** junta três fontes: a escolha (`settings.theme`), o "Seguir o macOS" (`settings.followsSystemAppearance`) e a aparência do sistema (KVO em `NSApp.effectiveAppearance`). Ele calcula o tema ativo com `AppTheme.resolve`, troca `CotaTheme.palette` e publica `active`.
- **Redesenho:** o painel e o Settings já usam `.id(settings.language)` para trocar o idioma na hora. Isso vira `.id(ThemeKey(language:theme:))`, então a troca de tema usa o mesmo mecanismo, já testado.
- **Tinta:** sobreposições como divisores, campos e botões usam `palette.ink(α)`: branco nos temas escuros e preto no Claro. O `inkScale` reforça as opacidades no Glass, para os elementos continuarem legíveis sobre um fundo movimentado.
- **Liquid Glass:**
  - no macOS 26+, compilado com Xcode 26: `glassEffect(.regular, in:)`;
  - antes disso: `NSVisualEffectView` (material `.popover`, `.behindWindow`) com a cor do tema por cima e uma borda superior iluminada;
  - a janela de Settings fica transparente (`isOpaque = false`, fundo `.clear`) para o vidro ter o que desfocar.
- **"Seguir o macOS":** no modo claro do sistema usa sempre o Claro. No modo escuro mantém o tema escolhido (Cota, Escuro ou Glass); se o escolhido for Claro, volta para o Cota. Escolher um cartão à mão desliga o "Seguir" quando ele estiver forçando outro tema.
- **A barra de menus** (o rótulo de verdade) não muda de tema: ela segue o macOS, como o relógio.

## Tokens por tema
Os valores completos estão em `CotaTheme.swift` → `Palette`.

| | Cota | Escuro | Claro | Liquid Glass |
|---|---|---|---|---|
| Painel | `#111714` | `#1E1F21` | `#FFFFFF` | `#18201C` 42% + vidro |
| Janela | `#1C211F` | `#232426` | `#FFFFFF` | `#18201C` 38% + vidro |
| Barra lateral | `#161B18` | `#1C1D1F` | `#F4F6F5` | branco 6% |
| Folha | `#1F2622` | `#2A2B2E` | `#FFFFFF` | `#1E2823` 62% + vidro |
| Linha aberta | `#17201C` | `#28292C` | `#F2F6F4` | branco 8% |
| Texto | `#F2F5F3` | `#F5F5F7` | `#111714` | branco |
| Secundário | `#7E8B85` | `#8E8E93` | `#6B7570` | branco 62% |
| Acento / alta | `#7BE0AE` | `#7BE0AE` | `#138A55` | `#8EF0BF` |
| Baixa | `#FF8A7A` | `#FF8A7A` | `#D4483B` | `#FF9C8F` |
| Âmbar (dado velho) | `#F5C26B` | `#F5C26B` | `#B07A12` | `#FFD27F` |
| Tinta (×) | branco ×1 | branco ×1,15 | preto ×0,85 | branco ×1,7 |

O acento do Claro é verde-escuro para ter contraste de 4,5:1 sobre branco. O menta original some no branco.

## Seção Temas (Settings)
- Cabeçalho com título e subtítulo.
- Grade 2×2 de cartões: raio 12, padding 8, gap 12.
  - Selecionado: borda de acento e fundo de acento a 8%.
  - Cada cartão mostra, sobre o fundo do tema em 132 pt, um mini painel com os 3 primeiros pares **da própria lista do usuário**. Abaixo vêm o nome, a descrição e um rádio.
- Os cartões desenham com `Palette.of(tema)` direto, não com `CotaTheme`, para cada um mostrar o próprio tema enquanto o resto da janela está no tema ativo.
- Linha "Seguir o macOS" com toggle.

## Arquivos
- `README.md`: este documento.
- `PATCHES.md`: mudanças nos arquivos existentes.
- `Sources/…` e `Tests/…`: arquivos novos e substituídos.
- `Resources/*/Localizable.strings.append`: textos em PT-BR e EN.
- `design/`: protótipo de referência (abra `Cota Rebrand.dc.html` no navegador).

## Notas de implementação
O pacote foi aplicado como veio. Diferenças em relação a ele:
- **Prévia da barra de menus:** o PATCHES sugeria `Color(hex: 0x111714)` na view. Viraram tokens: `CotaTheme.menuBarPreviewText` e `CotaTheme.menuBarPreviewPill` (preto 10% no Claro, como `barPill` do protótipo). O rótulo da prévia usa as cores dinâmicas do AppKit, por isso agora é desenhado sob a aparência do tema (`palette.appearance`). Sem isso, ele saía branco sobre a faixa clara quando o macOS estava escuro.
- **Ponto final do gráfico:** era branco fixo e sumia no Claro. Agora é `CotaTheme.chartDot` (`#111714` no Claro, branco nos outros), como `dot` no protótipo.
- **`ThemeController`:** usa `NSApplication.shared` em vez de `NSApp?`. `attach` roda em `CotaApp.init`, que pode vir antes de `NSApp` existir, e aí o "Seguir o macOS" nunca ouviria o sistema.
- **Lint:** `p` virou `palette` em `ThemeCard`, `==` de `Palette` usa `lhs`/`rhs`, e a variação do mini painel foi para `Row.changeText`.
- **Liquid Glass** só pode ser conferido no app de verdade: renderização offscreen não desfoca o que está atrás da janela.
