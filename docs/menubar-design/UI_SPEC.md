# UI spec — Quotes (menu bar app)

Especificação de redesenho para as duas telas do app: a view principal de
cotações e o painel de Settings. Escrita para ser implementada sem contexto
externo — tudo o que é necessário está aqui.

Mockup visual de referência: `mockup.html` (abrir no navegador).

**Escopo:** layout, hierarquia visual e a escala dos sparklines. Não altera
persistência, camada de rede, nem nomes de modelos. As strings da UI
permanecem em inglês.

---

## 1. Fundamentos (valem para as duas telas)

### Grade

O problema central do desenho atual é que cada bloco foi posicionado por
conta própria. Nenhum elemento deve ter inset próprio.

- Margem interna única de **16px**, aplicada a todo conteúdo: títulos de
  seção, linhas de lista, botões, campos de formulário, rodapé.
- A margem vale igualmente para a **borda direita**. Hoje o segmented
  control para antes dela e o card de novo alerta vai quase até a borda.
- Espaçamento vertical: **16px** entre seções, **8px** entre o título de
  uma seção e seu conteúdo.
- Altura de linha: **34px** em listas de Settings, **48px** nas linhas de
  cotação (que têm duas linhas de texto).

### Separadores

- Entre linhas de uma mesma lista: 0.5px, respeitando a margem de 16px.
- Entre seções: 0.5px, de borda a borda.

### Tipografia

| Papel | Tamanho | Peso |
|---|---|---|
| Nome do par | 13px | medium |
| Valor da cotação | 13px | regular, **tabular** |
| Título de seção | 11px | regular, cor secundária, sentence case |
| Meta / variação / rodapé | 11px | regular, tabular quando numérico |

Sentence case em todo lugar: "Currency pairs", não "Currency Pairs".

**Todo número exibido usa fonte tabular** (dígitos de largura fixa). Em
SwiftUI: `.monospacedDigit()`. Sem isso as colunas de preço dançam a cada
refresh.

### Cores

Nada de hex fixo. Use tokens do sistema, para funcionar em light mode e com
"Increase contrast" ligado:

- Destaque (segmented control selecionado, toggles ligados):
  `NSColor.controlAccentColor` / `.accentColor`. **Não** use azul fixo — o
  usuário pode ter escolhido roxo ou verde no sistema.
- Texto secundário: `secondaryLabelColor`. Terciário: `tertiaryLabelColor`.
- Separadores: `separatorColor`.
- Alta/baixa: verde/vermelho do sistema, **sempre acompanhados de ▲/▼**.
  Cor sozinha não comunica direção para quem tem daltonismo.

---

## 2. View principal (Quotes)

### 2.1 Sparklines — corrigir antes de tudo

Este é o único item da spec que corrige informação errada, não aparência.
Faça primeiro.

**Problema:** cada sparkline é auto-escalado ao próprio min/max da série.
O EUR/BRL variou -0,02% (praticamente reta) e desenha uma cordilheira; o
BTC caiu -0,48%, 24× mais, e parece igualmente agitado. O gráfico está
amplificando ruído de quarta casa decimal.

**Correção, duas partes:**

1. **Piso de escala.** Calcule o range da série em variação percentual. Se
   for menor que **0,5%**, force o domínio do eixo Y para ±0,25% em torno do
   valor de abertura. Abaixo desse piso a linha fica visualmente reta — que
   é a leitura correta.
2. **Linha de referência.** Horizontal tracejada, 1px, cor de separador, no
   **valor de abertura do período**. Dá âncora imediata para "subiu ou
   desceu em relação a quê".

Não normalize a escala entre pares — quando um ativo domina, achata os
outros.

Dimensões: 60×24pt, largura fixa, coluna fixa. Hoje cada sparkline começa e
termina onde quer.

### 2.2 Período

A view nunca declara a janela de tempo. `-0,02%` desde quando? O sparkline
implica um período que não está escrito em lugar nenhum.

Adicione um segmented control compacto no cabeçalho, à direita de "Quotes":
**24h / 7d / 30d**. Ele governa tanto o sparkline quanto a variação
percentual. Persista a escolha.

### 2.3 Linha de cotação

Quatro colunas, nesta ordem:

```
[badge 24px] [par + range          ] [sparkline 60px] [valor    ]
                                                      [▼ 0,48%  ]
```

- **Badge:** círculo de 24px com o símbolo da moeda, fundo tonal. Substitui
  os emojis de bandeira. Hoje há duas bandeiras emoji e um `₿` de texto —
  tamanhos ópticos, pesos e baselines diferentes, e emoji renderiza
  diferente entre versões de macOS.
- **Segunda linha do bloco de nome:** substituir "Euro/Real Brasileiro" pelo
  **range do período** (ex. `6,01 – 6,04`). O subtítulo atual repete o que
  "EUR/BRL" já diz; o range é o que falta para interpretar a cotação.
- **Valor:** remover o prefixo `R$`. O `/BRL` no nome do par já informa a
  moeda, e o prefixo faz o número flutuar em x diferentes a cada linha.
  Alinhado à direita, tabular, coluna de largura mínima fixa (84pt).
- **Variação:** abaixo do valor, 11px, com seta ▲/▼.
- Valores grandes (BTC) podem abreviar no **range** (`403k – 409k`) mas não
  no valor principal.

### 2.4 Rodapé

Substituir os botões "Refresh" e "Settings" por ícones com tooltip, na
mesma linha do timestamp. Eles ocupam ~40pt de altura para ações raras — o
app atualiza sozinho no intervalo configurado, e Settings se abre uma vez
por mês.

`Updated 2 min ago` à esquerda; refresh, settings e quit como ícones de
15pt à direita.

Ressalva: se os usuários forem pouco técnicos, mantenha o rótulo em
Settings — descoberta importa mais que densidade nesse caso.

**Timestamp:** trocar `Updated at 1 Sep 2026 at 09:12` (tem "at" duplicado
e mostra uma data que quase sempre é hoje) por tempo relativo, que responde
a pergunta real: "isso está velho?".

### 2.5 Estados que faltam

A view atual só existe no caminho feliz. Implemente:

- **Falha de rede:** manter o último valor conhecido, esmaecido, com
  "Couldn't update" no rodapé. Não sumir com os dados.
- **Dado velho:** se o último fetch tem mais que 3× o intervalo
  configurado, marcar como stale. Uma cotação de 40 minutos parecendo
  fresca é pior que nenhuma cotação.
- **Primeiro carregamento:** skeleton nas linhas, não popover vazio.
- **Nenhum par configurado:** empty state com atalho para Settings.

---

## 3. Settings

### 3.1 Consistência de controles

O app usa três linguagens para a mesma ideia: `×` para deletar par,
checkbox quadrado para "Launch at Login", toggle + `×` para alertas.

- **"Launch at Login" vira toggle.** No macOS, checkbox e toggle não são
  intercambiáveis: checkbox é para opções dentro de um formulário que será
  submetido; toggle para algo que age imediatamente.
- **Mover "Launch at Login" para uma seção "General" no fim do painel.**
  Hoje está encravado entre duas features, quebrando a leitura.
- **"+ Add Pair" perde o chevron.** Hoje parece botão e dropdown ao mesmo
  tempo. Vira uma linha de ação com ícone `+`, alinhada às demais linhas da
  lista, que abre um seletor.
- **Todos os `×` alinhados na mesma coluna**, com largura reservada. Hoje o
  `×` dos pares e o dos alertas caem em x diferentes porque o toggle empurra
  a linha.

### 3.2 Currency pairs

Hoje é uma lista de texto morto. Sendo um app de cotação, essa lista pode
carregar informação:

```
[handle] [EUR-BRL] [6,2140] [+0,42%] [×]
```

- Handle de arrastar à esquerda: a ordem define a ordem na barra de menu.
  Persista.
- Cotação e variação tabulares, alinhadas à direita.
- Variação colorida com seta.
- O `×` aparece só no hover da linha, para reduzir ruído.

### 3.3 Refresh interval

- Segmented control ocupando **100% da largura**, com os cinco segmentos de
  largura **idêntica** — grid de 5 colunas iguais, não dimensionado pelo
  texto. Hoje "30s" é mais largo que "1m" e o conjunto não alcança a margem
  direita.
- Linha de ajuda 11px em cor terciária abaixo:
  `Values are cached between refreshes.`

### 3.4 Price alerts

`EUR-BRL above 6` é uma frase: difícil de escanear e não conversa com o
formulário abaixo, que é estruturado em colunas.

- Reescrever cada alerta em **colunas**: par (76pt) | condição (52pt) |
  valor (flex) | toggle | ×.
- O formulário de novo alerta usa **exatamente as mesmas larguras de
  coluna**, para parecer a próxima linha da lista. Remover o fundo de card
  próprio dele — é o que hoje o faz parecer um bloco solto colado no fim.
- Trocar o botão `+` por um **"Add"** com a mesma altura dos campos,
  desabilitado enquanto par, operador e valor não estiverem preenchidos. Um
  `+` de 12px é alvo de clique ruim e não comunica que existe validação.
- Valor com fonte tabular.

**Ponto em aberto:** se o toggle de um alerta nunca é usado, ele é
decoração e o `×` é o único controle real. Decidir se os dois se justificam.

---

## 4. Estrutura do código

Extraia dois componentes reutilizáveis e reconstrua todas as seções em cima
deles:

- **Cabeçalho de seção** — título 11px secundário, espaçamento padrão.
- **Linha de lista** — slot à esquerda (handle/badge/ícone), conteúdo
  central, acessórios à direita com colunas de largura reservada.

O alinhamento tem que ser garantido pela estrutura, não repetido à mão em
cada linha. É esse item que impede o desalinhamento de voltar na próxima
feature.

---

## 5. Ordem sugerida

1. Escala e linha de referência dos sparklines (§2.1) — corrige informação.
2. Componentes de linha e cabeçalho (§4) — base para o resto.
3. View principal (§2.2–2.4).
4. Settings (§3).
5. Barra de menu (§6) — depende da seção "Menu bar" em Settings.
6. Estados de erro, stale, loading e vazio (§2.5), incluindo o stale da barra.

Um commit por bloco.

---

## 6. Barra de menu

Terceira superfície do app, e a mais restrita: ~22pt de altura, largura
disputada com todos os outros itens da barra. Mockup: `mockup-menubar.html`.

### 6.1 Problema atual

Hoje a barra mostra `🇪🇺 → 🇧🇷 6,01`.

- **Duas bandeiras emoji gastam quase metade da largura** e informam pouco.
  Nesse tamanho a bandeira da UE vira um retângulo azul e a do Brasil um
  borrão verde; com mais moedas configuradas, viram blobs indistinguíveis.
- **O destino é constante.** Todos os pares terminam em BRL. A bandeira do
  Brasil e a seta podem sair juntas, liberando ~30pt.
- **Falta a direção.** A barra é a superfície de olhada rápida; hoje é
  preciso abrir o popover para saber se subiu ou caiu.
- **Dígitos não tabulares.** Quando `6,01` vira `6,10` a largura muda e os
  ícones à esquerda dançam.

### 6.2 Formato configurável

Nova seção "Menu bar" em Settings, com **preview ao vivo no topo** — a
escolha só faz sentido se a pessoa vê o resultado enquanto decide.

**Pairs to show** — checkbox por par configurado. Padrão: o primeiro.
Hoje a regra de qual par aparece é implícita; torná-la explícita.

**Format** — três opções, cada uma com exemplo renderizado ao lado:

| Opção | Saída | Quando usar |
|---|---|---|
| `auto` | `€ 6,02` ou `EUR 6,02` | Padrão. Símbolo quando não há ambiguidade, código quando há. |
| `code` | `EUR 6,02` | Código sempre, para quem prefere previsibilidade. |
| `flag` | `🇪🇺 6,02` | Bandeira do país emissor. Cai para o símbolo em cripto. |
| `value` | `6,02` | Mínimo. Só disponível com um par selecionado. |

**Change indicator** — segmented: `None` / `Arrow` / `Percent`.

#### O formato `auto`

Usa o símbolo da moeda quando ele for **único entre os pares atualmente
selecionados**; cai para o código quando houver colisão.

```
EUR sozinho     →  € 6,02
EUR + USD       →  € 6,02   $ 5,19        símbolos distintos
USD + CAD       →  USD 5,19   CAD 3,80    ambos usam $, cai para código
```

A queda é **global, não por par**. Se dois pares colidem, todos passam a
exibir o código — `USD 5,19   CAD 3,80   € 6,02` mistura duas convenções na
mesma linha e fica pior que qualquer uma delas pura.

**Por que isso, e não `symbol` como opção manual:** o risco de `symbol` não
é a moeda sem símbolo — praticamente todas têm um. É que muitos símbolos
são **compartilhados**: `$` cobre USD, CAD, AUD, ARS, CLP, MXN, COP, UYU,
HKD, SGD e NZD; `¥` cobre JPY e CNY; `kr` cobre SEK, NOK, DKK e ISK; `£`
cobre GBP, EGP e LBP.

Isso torna a falha **silenciosa**. Ausência de símbolo seria visível — um
quadrado vazio denuncia o problema. Colisão não: `$ 5,19` parece correto, e
o usuário lê o número errado com total confiança, num item da barra de menu
que ninguém revisita depois de configurar.

Por isso `symbol` não existe como opção manual. Escolher uma configuração
que pode gerar ambiguidade não é uma liberdade que valha oferecer — e
`auto` entrega a mesma compactação no caso comum sem esse risco.

**Ressalva de implementação:** o rótulo muda sozinho quando o usuário mexe
na lista de pares. Isso é aceitável porque a mudança acontece no mesmo
instante em que ele marca o par, com o preview à vista. Não aplique a mesma
lógica adaptativa a nada que mude fora do campo de visão do usuário.

#### Os exemplos ao lado de cada opção

**Devem derivar do primeiro par selecionado**, nunca de um valor fixo. Um
exemplo chumbado em EUR enquanto o usuário acompanha USD e CAD descreve uma
configuração que não é a dele.

**Quando `auto` está em fallback, `auto` e `code` mostram exatamente a mesma
coisa.** Isso é correto e inevitável, mas deixa "Automatic" parecendo uma
opção redundante — sem nada na tela que explique por que ela existe.

Exiba uma linha de ajuda abaixo de "Automatic" sempre que houver colisão,
nomeando as moedas responsáveis:

```
Automatic                                    USD 5,19
  Using codes — USD and CAD both use the $ symbol.
Currency code                                USD 5,19
```

Sem essa linha, o usuário conclui que a opção está quebrada. Com ela, a
coincidência vira informação: ele entende a regra e sabe que ao desmarcar
CAD volta a ver `$ 5,19`.

Se houver mais de uma colisão simultânea, cite apenas a primeira — a linha
precisa caber em duas linhas de texto.

#### O formato `flag`

Uma bandeira por par, sempre a da **moeda de origem** — nunca a do destino,
que é constante em BRL. `🇪🇺 6,02`, não `🇪🇺 → 🇧🇷 6,02`.

**Fallback obrigatório para cripto.** BTC, ETH e afins não têm país
emissor. Use o símbolo da moeda no lugar (`₿ 406k`). Sem isso a barra
exibe um quadrado vazio ou um espaço, e parece bug.

Se o símbolo também não existir, caia para o código.

**Trade-off aceito nesta opção:** a ~16pt de altura, bandeiras com paletas
próximas ficam difíceis de distinguir na periferia da visão, e a emoji
ocupa cerca do dobro da largura de um glifo de texto. Quem escolhe este
formato está trocando densidade e legibilidade rápida por reconhecimento
visual — é uma preferência legítima, e por isso a opção existe. Não é o
padrão pelo mesmo motivo.

**Não misture bandeira e símbolo por par quando ambos existirem.** Se um
par cai para o fallback, só ele muda; os demais mantêm a bandeira. Aqui a
mistura é aceitável (ao contrário do `auto`), porque o fallback é uma
propriedade fixa da moeda e não muda conforme a seleção.

 `6,02 5,19`
sem rótulo é ilegível. Use `disabledReason` explicando o motivo, em vez de
apagar a opção da lista — a opção sumindo e reaparecendo confunde mais que
uma opção cinza com explicação.

**Dim when data is stale** — toggle, ligado por padrão.

### 6.3 Regras de renderização

- **A cor vai no indicador, nunca no número.** Número colorido briga com o
  tint do sistema e fica ruim em fundo claro ou papel de parede colorido. A
  seta ▴/▾ carrega a direção pela forma, então funciona mesmo sem cor.
- **Dígitos tabulares mais largura reservada.** Fonte tabular não basta: se
  o valor puder ir de `9,99` para `10,01`, a contagem de caracteres muda.
  Formate com largura fixa de caracteres.
- **Abreviação para valores grandes.** `₿ 405.884` não cabe. Acima de
  100.000, abreviar para `406k`.
- **Estado stale:** texto esmaecido (`tertiaryLabelColor`) quando o último
  fetch tem mais que 3× o intervalo configurado. Uma cotação de uma hora
  com aparência normal é pior que não mostrar nada.
- **Múltiplos pares:** separar por espaço triplo, não por vírgula ou
  bullet. Dois cabem confortavelmente; três já empurram os outros ícones.
- O código de moeda vai um ponto menor e em cor secundária, para o número
  continuar sendo o elemento dominante. O símbolo, quando `auto` o usa, fica
  no mesmo tamanho do número — é um glifo só, e reduzi-lo o deixa ilegível.
