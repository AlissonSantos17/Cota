# Handoff: Rebranding do Cota (painel + Settings)

Destino no repositório: `Design/Rebrand/` (este pacote inteiro). O `CLAUDE.md` deste pacote vai na **raiz** do repositório.

## Visão geral
Novo visual do Cota, o app de cotações em real que fica na barra de menus do macOS. O app passa a usar as cores do ícone (menta sobre quase-preto) no lugar do azul do sistema. Também ganha:
- linhas do painel que abrem no lugar, com gráfico grande, a linha do alerta desenhada, um conversor e ações;
- Settings com barra lateral no lugar de abas;
- alertas escritos como frases;
- uma folha "Adicionar par" com busca no lugar do menu com submenu;
- suporte a **Português (Brasil)** e **English**, escolhido dentro do app.

## Sobre os arquivos de design
O arquivo `design/Cota Rebrand.dc.html` é uma **referência feita em HTML**, um protótipo navegável. Não é código de produção. A tarefa é **recriar o design em SwiftUI** dentro da estrutura atual (`Sources/Cota/Views`, `CotaKit`), seguindo os padrões do projeto.

Abra o arquivo no navegador (precisa de `support.js` e `assets/` ao lado). Seções:
- **2a — Painel** e **2b — Settings**: aprovadas. Implemente estas.
- **Brief**: princípios, tom de voz e paleta. É contexto, não tela.
- **1a–1d**: exploração anterior. Não implemente.
- **Hoje**: recriação do app atual, para comparar.

No painel de opções do protótipo, `lang` troca o idioma e `stale` simula dado velho.

## Fidelidade
**Alta fidelidade.** Cores, medidas, tipografia, textos e interações são os finais. A fonte é a do sistema (SF Pro) com `.monospacedDigit()` em todo número. Os ícones do protótipo são Lucide; troque pelos SF Symbols equivalentes (tabela no fim).

Aparência: o design é **escuro**. Recomendação: forçar `.preferredColorScheme(.dark)` no painel e no Settings. Uma variante clara ainda não foi desenhada (pendência).

---

## Tela 1 — Painel (popover da barra de menus) · seção 2a
Arquivo atual: `PanelView.swift`, `SparklineView.swift`, `Components/ListRow.swift`, `Components/PairLabel.swift`, `Components/SegmentedControl.swift`.

**Contêiner**
- Largura 360 pt. Fundo `#111714`. Borda 1 pt `white 9%`. Raio 12. Sombra `0 20 50 black 50%`.
- Estrutura vertical: cabeçalho → lista → divisor 1 pt `white 7%` → rodapé.

**Cabeçalho** (altura 44, padding horizontal 16, gap 8)
- Ícone do app 20×20 (`Design/icon.svg`).
- Título "Cotações" / "Rates": 13 pt semibold, `#F2F5F3`, ocupa o espaço restante.
- Contador de alertas ativos: cápsula com padding 3×8, raio 10, fundo `mint 10%`, texto 11 pt `#7BE0AE`. Leva o símbolo `bell` 11 pt e o número.

**Linha de par (fechada)**
- Margem 2 pt vertical e 8 pt horizontal, raio 10. Área clicável com altura 50, padding horizontal 10 e gap 10.
- **Avatar** 28×28, círculo `#1B2420`, glifo da moeda de origem em 15 pt semibold `#7BE0AE`.
  - Glifos: BRL `R$`, USD `$`, EUR `€`, GBP `£`, JPY `¥`, CHF `Fr`, CAD `C$`, AUD `A$`, CNY `元`, ARS/MXN/CLP `$`, BTC `₿`, ETH `Ξ`, XRP `X`.
  - **Atenção:** isso não é `Currency.symbol`, que mantém "$" compartilhado de propósito. Crie `Currency.avatarGlyph`.
- **Selo de destino** (em todo par, inclusive BRL, que mostra `R$`): círculo de 15 pt em grafite a 55% (`CotaTheme.badgeFill`), sem borda — só para notar o selo, ainda transparente —, com o glifo do destino em 11 pt light, menta a 35% (`CotaTheme.badgeGlyph`). Fica no canto inferior direito, 4 pt para fora da borda do avatar e 3 pt abaixo (`CotaTheme.Size.badgeOutset`). Glifos de dois caracteres (`R$`, `C$`, `A$`, `Fr`) usam 8,5 pt, para não cobrir o símbolo principal nem encostar no texto ao lado.
- **Nome**: nome da moeda de origem, localizado ("Euro", "Dólar americano"), 13 pt medium `#F2F5F3`, uma linha com reticências. Abaixo, o par `EUR/BRL` em 11 pt `#7E8B85`.
- **Sparkline** 56×22: linha de 1,5 pt (menta em alta, coral `#FF8A7A` em baixa) e linha de abertura tracejada (2/3) 1 pt `#4B5C55`. Some (opacidade 0) quando a linha está aberta.
- **Coluna de valor** com 96 pt, alinhada à direita:
  - valor com o símbolo da moeda de **destino** ("R$ 5,6480", "€ 0,8924"), 13 pt medium;
  - variação abaixo, "▼ 0,84%" em 11 pt menta ou coral.

**Linha aberta** (clique alterna; só uma aberta por vez)
- Fundo da linha `#17201C`. Conteúdo com padding 0/10/12 e gap vertical 10.
- **Gráfico** 324×116:
  - área sob a linha com a cor da tendência a 12%;
  - abertura tracejada (3/4) `#4B5C55`;
  - linha de 2 pt na cor da tendência;
  - ponto branco de 4 pt de raio no último valor.
- **Alerta no gráfico** (quando há alerta ligado para o par):
  - linha pontilhada (1/3) menta a 80% na altura do alvo. O eixo Y inclui o alvo, para ele sempre aparecer;
  - etiqueta à esquerda, alinhada à linha: cápsula menta, texto `#0E1411` 10 pt semibold, `bell` + "acima de 5,70".
- **Linha de controles**:
  - à esquerda, segmentado 24h/7d/30d: trilho `white 5%` com raio 7 e padding 2; segmento com padding 3×9, raio 5, 11 pt; selecionado em `mint 16%` com texto menta semibold, os outros em `#7E8B85`;
  - à direita, "mín 5,61 · máx 5,70" em 11 pt, rótulo `#7E8B85` e número `#C4CCC8`.
- **Conversor** (novo):
  - caixa de 40 pt, raio 9, fundo `white 4%`, borda `white 7%`, padding 0/6/0/10, gap 8;
  - campo numérico com 70 pt de largura, 15 pt medium, alinhado à direita, valor inicial `100`;
  - código da moeda de entrada em 12 pt semibold menta;
  - botão inverter: círculo de 24 pt, `mint 12%`, `arrow.left.arrow.right` 11 pt menta;
  - resultado alinhado à direita, 17 pt semibold, tracking −0,01 em, com o símbolo da moeda de saída.
  - Entrada padrão: origem → destino. Inverter faz destino → origem.
  - O valor digitado e o sentido são **globais**: valem para qualquer par aberto.
- **Ações**: grade de 2 colunas, gap 8, botões de 28 pt, raio 7, 12 pt.
  - **Copiar**: fundo `white 6%` (hover 10%), `doc.on.doc` + "Copiar 5,6480". Copia o valor formatado. Por 1,4 s mostra `checkmark` + "Copiado".
  - **Novo alerta**: fundo `mint 14%`, texto menta medium, `plus`. Cria alerta "acima de" valor atual × 1,008, arredondado conforme a magnitude.
  - Com alerta já existente, o botão vira **Remover alerta** (fundo `white 6%`, `bell.slash`).

**Rodapé** (altura 36, padding 0/16, gap 14)
- Ponto de 6 pt + status em 11 pt:
  - normal: ponto menta, "Atualizado agora", texto `white 55%`;
  - dado velho: ponto e texto âmbar `#F5C26B`, "Dados de 18 min atrás · tentando de novo".
- Ícones de 13 pt em `#7E8B85`: `arrow.clockwise` (atualizar), `gearshape` (abre Settings), `power` (sair).

**Dado velho**: todos os valores, gráficos e o resultado do conversor ficam com opacidade 0,5. Nada some.

## Tela 2 — Rótulo da barra de menus
Arquivo atual: `MenuBarLabelView.swift`, `CotaKit/Services/MenuBarLabel.swift`, `Models/MenuBarFormat.swift`.
- Sem mudança de formato. O usuário continua escolhendo entre Símbolo, Código, Bandeira e Só o valor, com indicador Nenhum, Seta ou Percentual.
- **Novo**: ponto menta de 5 pt depois do valor quando o par tem alerta ligado.
- Com vários pares fixados, os itens ficam separados por 12 pt.

## Tela 3 — Settings · seção 2b
Arquivo atual: `SettingsView.swift`, `MenuBarSettingsSection.swift`, `AlertsSection.swift`, `AlertRows.swift`, `SettingsWindowController.swift`.

**Janela**
- Cerca de 820×600, `NavigationSplitView` ou `HStack`.
- Barra lateral de 190 pt: fundo `#161B18`, divisor direito `white 6%`, padding 14/10.
- Conteúdo: fundo `#1C211F`, padding 22/26, gap 18.
- **Nav**: itens de 30 pt, raio 7, 13 pt, ícone de 14 pt, gap 9.
  - Selecionado: fundo `mint 14%`, texto menta. Normal: `#C4CCC8`.
  - Contagem à direita em 11 pt `#7E8B85`: número de pares em Pares, alertas ligados em Alertas.
  - Ícones: Geral `slider.horizontal.3`, Pares `list.bullet`, Barra de menus `menubar.rectangle`, Alertas `bell`.
- **Cabeçalho de seção**: título 17 pt semibold, subtítulo 12 pt `#8A9690`.
- **Toggle**: 30×18, ligado em menta e desligado em `white 15%`, botão branco de 14 pt. Pode ser `Toggle` com `.tint(CotaTheme.mint)`.
- **Segmentado de Settings**: trilho `white 6%`, raio 7–8; segmento de 12 pt com padding 4×12. Selecionado `mint 16%` com texto menta semibold; os outros `#C4CCC8`.

**Geral**
- "Atualizar a cada": segmentado em largura total com 30s, 1m, 2m, 5m e 10m. Nota abaixo em 11 pt `#7E8B85`.
- **Idioma** (novo): linha com rótulo e nota "Muda textos, nomes das moedas e o formato dos números". À direita, segmentado "Português (Brasil)" / "English". Opcional: um terceiro item "Sistema".
- "Abrir ao iniciar sessão": toggle.
- Linhas separadas por divisor 1 pt `white 6%` e padding vertical 12.

**Pares**
- Linhas de 46 pt, divisor inferior `white 6%`, gap 12, nesta ordem:
  - alça `line.3.horizontal` em 14 pt `#4B5C55`, arrastável;
  - avatar de 26 pt com selo, igual ao do painel;
  - par "USD/EUR" em 13 pt medium, com descrição "Dólar americano em euro" em 11 pt `#7E8B85` abaixo;
  - valor com 110 pt de largura, à direita, 13 pt;
  - variação com 70 pt de largura, 11 pt;
  - **alfinete** `pin.fill` 14 pt: menta quando o par está na barra, `#4B5C55` quando não. Substitui a coluna de checkbox "Menu bar";
  - remover `xmark` 13 pt.
- "Adicionar par": 13 pt menta com `plus`. Abre a folha.

**Folha "Adicionar par"** (substitui o menu com submenu)
- Folha de 500 pt de largura presa ao topo da área de conteúdo, sobre um véu `rgb(6,9,8) 55%`. Fundo `#1F2622`, borda `white 12%` sem a borda de cima, raios inferiores 14, sombra `0 30 60 black 55%`.
- **Topo** (padding 18/20/12, gap 12):
  - título "Adicionar par" em 15 pt semibold, com `xmark` para fechar;
  - busca: campo de 32 pt, raio 8, fundo `white 6%`, borda `white 8%`, `magnifyingglass`, placeholder "Buscar moeda, código ou país". Filtra as duas colunas por código, nome em pt e nome em en;
  - "Sugestões" em 11 pt, seguido de até 4 chips de 24 pt, raio 12, fundo `white 6%` (hover `mint 14%`) com glifo + par. Use USD/EUR, GBP/BRL, BTC/USD, ARS/BRL, ETH/BRL e JPY/BRL, menos os que já estão na lista. Clicar num chip preenche De e Para.
- **Colunas**: grade `1fr · 36 pt · 1fr` entre divisores `white 7%`.
  - Cada coluna tem cabeçalho "DE"/"PARA" (11 pt, mono-like, `#7E8B85`) e uma lista rolável de 250 pt.
  - Grupos "MOEDAS" e "CRIPTO": 10 pt semibold, caixa alta, `#4B5C55`.
  - Item de 32 pt, raio 7: glifo 14 pt menta (largura 18), código 13 pt semibold (largura 34), nome 12 pt `#7E8B85`. Selecionado: fundo `mint 14%` e código menta.
  - Na coluna **Para**, destinos fora de `PairCatalog.destinations(from:)` ficam com opacidade 0,3 e não respondem ao clique.
  - Ao trocar a origem, se o destino atual não for válido, o primeiro válido é escolhido.
  - Coluna do meio: botão de inverter, círculo de 26 pt `mint 12%`. Só inverte se o par invertido existir no catálogo.
- **Rodapé** (padding 14/20/16):
  - à esquerda, nota "Prévia · USD/JPY" em 11 pt `#7E8B85`, com "1 dólar americano = ¥ 150,81" em 15 pt abaixo;
  - se o par já está na lista, a nota vira "Já está na sua lista" em âmbar e **Adicionar** fica desabilitado (fundo `white 8%`, texto `#7E8B85`);
  - botões de 30 pt, raio 7, 13 pt: Cancelar com fundo `white 7%`; Adicionar menta com texto `#0E1411` semibold.
  - Ao adicionar: fecha a folha, põe o par no fim da lista e o deixa **aberto** no painel.
- Para a prévia, use a última cotação conhecida. Se o par nunca foi buscado, mostre "—".

**Barra de menus**
- Prévia ao vivo: faixa de 44 pt, raio 10, fundo `#2E3438`. Mostra os pares fixados exatamente como a barra vai renderizar.
- **Formatos como cartões**: grade de 4 colunas com gap 8; cada cartão tem raio 10, padding 12, exemplo em 15 pt e rótulo em 11 pt.
  - Selecionado: borda menta, fundo `mint 8%`, rótulo menta.
  - Normal: borda `white 8%`, fundo `white 3%`, rótulo `#7E8B85`.
- "Variação": segmentado Nenhum / Seta / Percentual.
- "Escurecer dados antigos": toggle, com nota.

**Alertas**
- **Compositor**: cartão com fundo `white 4%`, borda `white 7%`, raio 10, padding 14. É uma frase com chips de 26 pt, raio 6, fundo `white 8%`:
  - "Avise quando [EUR/BRL ⌄] [passar de ⌄] [R$ 5,70]";
  - o campo de valor tem borda `mint 40%` e o símbolo da moeda de destino;
  - "Criar alerta" à direita: menta, 28 pt, 12 pt semibold.
- **Dica ao vivo** em 11 pt: "Agora: R$ 5,6480 · faltam 0,92%". Se o alvo já está do outro lado: "… · já está do outro lado, dispara agora".
- **Linha de alerta**: avatar de 28 pt e frase "EUR/BRL acima de R$ 5,70" em 13 pt. Abaixo:
  - barra de progresso 140×3 menta (âmbar se pausado), com largura `max(6%, 100% − distância% × 25)`;
  - nota em 11 pt: "0,92% do alvo", "Desligado" ou "Pausado · cotação com mais de 1 h" (âmbar).
  - À direita: toggle e `xmark`. Alerta desligado fica com opacidade 0,55.

---

## Interações e comportamento
- **Painel**:
  - clicar numa linha abre ou fecha a linha, com animação de 180 ms ease-out na altura;
  - o período é global e vale para a linha aberta;
  - "Novo alerta" e "Remover alerta" atualizam a lista em Settings → Alertas na hora.
- **Atualização de dados**: só os dígitos que mudaram rolam, com 120 ms ease-out (`.contentTransition(.numericText())`). Nada pisca nem pulsa.
- **Copiar**: `NSPasteboard.general` com o valor formatado no idioma atual.
- **Conversor**:
  - lê o número com `QuoteFormat.parseThreshold` (aceita "1.000,50" e "1000.50");
  - entrada inválida mostra "—";
  - formata a saída com `QuoteFormat.value`.
- **Engrenagem** do rodapé abre Settings em Geral.
- **Alerta disparado** (notificação): título "O euro passou de R$ 5,75", corpo "Agora R$ 5,7612 · ▲ 0,96% hoje". As chaves estão em `notification.*`.

## Idioma (PT-BR / EN)
- Pacote: `defaultLocalization: "pt-BR"` no `Package.swift` e `resources: [.process("Resources")]` no alvo `Cota`. Arquivos em `Resources/pt-BR.lproj` e `Resources/en.lproj`, prontos neste pacote.
- O empacotamento (`Makefile` / `rebuild.sh` / `make-dmg.sh`) precisa copiar `Cota_Cota.bundle` para `Cota.app/Contents/Resources`. Adicione também `CFBundleLocalizations = [pt-BR, en]` ao `Info.plist`.
- Escolha no app: `SettingsStore.language: AppLanguage` (`system | pt-BR | en`), salvo em `UserDefaults`. `L10n.language` é atualizado no `didSet`. As views observam o store para redesenhar.
- `QuoteFormat` hoje fixa `pt_BR`. Torne o locale um parâmetro, com padrão `L10n.language.locale`: em EN fica "5.6480" e "398k"; em PT fica "5,6480". **As regras de casas decimais de `QuoteFormat` continuam valendo.**
- Nomes de moeda: `L10n.currencyName("USD")`, com chaves `currency.*`.
- Textos com tradução pronta estão nas duas `Localizable.strings`. As chaves com `%@` usam `L10n.t(chave, args…)`.

## Estado
- `QuoteStore`: sem mudança de dados. O painel precisa do histórico por período (já existe) e da última cotação.
- Novos estados de UI no painel (`@State`): `expandedPairID`, `period` (já existe), `convertAmount: String = "100"`, `convertInverted: Bool`, `copiedPairID`.
- `SettingsStore`: `language`. O "alfinete" mapeia para o `PairSetting.showInMenuBar` existente.
- Settings: `selectedSection` e `isAddingPair`. Dentro da folha: `query`, `from`, `to`.

## Tokens
Os valores estão em `swift/CotaTheme.swift`. Resumo:
- **Cores**:
  - Noite `#111714`, Grafite `#1B2420`, Musgo `#4B5C55`;
  - Menta `#7BE0AE` (alta e acento), Coral `#FF8A7A` (baixa), Âmbar `#F5C26B` (dado velho), texto sobre menta `#0E1411`;
  - textos `#F2F5F3` / `#E8ECEA` / `#C4CCC8` / `#7E8B85` / `#8A9690`;
  - superfícies `#17201C` (linha aberta), `#1C211F` (Settings), `#161B18` (barra lateral), `#1F2622` (folha).
- **Alta e baixa** sempre levam seta (▲/▼). Nunca use só a cor.
- **Raios**: 5 (segmento), 6 (chip), 7 (botão), 9 (campo), 10 (linha e cartão), 12 (painel), 14 (folha).
- **Tipografia**: SF Pro com `.monospacedDigit()`. Escala: 10 / 11 / 12 / 13 / 15 / 17 pt; títulos de seção em 17 semibold.
- **Movimento**: 120 ms (dígitos), 180 ms (abrir linha e folha), ease-out.

## SF Symbols (no lugar dos ícones Lucide do protótipo)
- bell → `bell`
- rotate-cw → `arrow.clockwise`
- settings → `gearshape`
- power → `power`
- copy → `doc.on.doc`
- check → `checkmark`
- plus → `plus`
- bell-off → `bell.slash`
- arrow-left-right → `arrow.left.arrow.right`
- grip-vertical → `line.3.horizontal`
- pin → `pin.fill`
- x → `xmark`
- search → `magnifyingglass`
- chevrons-up-down → `chevron.up.chevron.down`
- sliders-horizontal → `slider.horizontal.3`
- list → `list.bullet`
- panel-top → `menubar.rectangle`

## Arquivos deste pacote
- `README.md`: esta especificação.
- `IMPLEMENTATION.md`: ordem de trabalho com checklist e arquivos afetados.
- `CLAUDE.md`: vai na raiz do repo; aponta agentes para cá.
- `swift/CotaTheme.swift`: tokens de cor, medida e movimento.
- `swift/L10n.swift`: escolha de idioma e busca de textos.
- `Resources/pt-BR.lproj/Localizable.strings` e `Resources/en.lproj/Localizable.strings`: todos os textos novos, mais os nomes das moedas.
- `design/Cota Rebrand.dc.html` (com `support.js` e `assets/`): protótipo de referência.
