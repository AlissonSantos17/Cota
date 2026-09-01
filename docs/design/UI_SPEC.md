# UI spec — Quotes (menu bar app)

Especificação de design das três superfícies do app: a view principal de
cotações, a janela de Settings e o item da barra de menu. Escrita para ser
lida sem contexto externo — tudo o que é necessário está aqui.

## Estado de implementação

Atualizado em 1 Sep 2026. **Mantenha esta tabela ao alterar a spec** — sem
ela não há como saber quais seções descrevem o app atual e quais descrevem
trabalho pendente.

| Seção | Estado |
|---|---|
| §1 Fundamentos — grade, separadores, tipografia, cores | implementado |
| §1 Fundamentos — formatação de números | implementado |
| §2 View principal | implementado |
| §2.5 Estados — erro, stale, loading, vazio | implementado |
| §3 Settings — janela com abas | implementado |
| §3.3 Pairs — lista unificada | implementado |
| §3.5 Alerts — larguras de coluna | implementado |
| §4 Estrutura do código | implementado |
| §6 Barra de menu | implementado |

O que estiver pendente consta na §5, que hoje está vazia.

## Mockup

Arquivo único: `mockup.html`. Abra no navegador.

Cobre as três superfícies em sequência, cada uma com o estado marcado ao lado
do título. A janela de Settings é interativa — as abas funcionam, e a coluna
"Menu bar" da aba Pairs governa o preview da aba Menu bar, demonstrando que a
lista de pares é a fonte única de verdade (§3.3).

Ao alterar o design, **atualize o mockup no mesmo commit**. Versões paralelas
de arquivos de referência foram a causa de confusão anterior neste projeto:
havia três arquivos, um deles meio obsoleto, sem nada indicando qual valia.

O mockup usa cores fixas por ser referência visual. O código usa tokens do
sistema, conforme §1.

**Escopo:** layout, hierarquia visual, formatação de números e a escala dos
sparklines. Não altera camada de rede, persistência nem nomes de modelos,
exceto onde a spec pedir explicitamente. As strings da UI permanecem em
inglês.

---

## 1. Fundamentos (valem para as três superfícies)

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

### Formatação de números

Uma função única, usada em **todas** as superfícies. Sem isso aparecem
absurdos como `398.348,0000` ao lado de `5,9713` na mesma lista, com o dobro
da largura.

Casas decimais por magnitude:

| Valor | Casas | Exemplo |
|---|---|---|
| < 10 | 4 | `5,9713` |
| 10 – 1.000 | 2 | `42,50` |
| ≥ 1.000 | 0 | `398.348` |

A barra de menu diverge em **dois pontos**, ambos pagos pelos ~22pt de largura
que ela disputa com todos os outros itens da barra:

- **Abreviação acima de 100.000** (`398k`). Nas listas e no popover mostre o
  valor completo — ali existe espaço, e precisão é o que o usuário foi buscar.
- **Duas casas decimais**, onde as demais superfícies mostram quatro:
  `€ 5,97` na barra, `5,9713` no popover. A quarta casa custa quase a largura
  do símbolo da moeda, e a barra é a superfície de olhada rápida — o popover
  está a um clique quando o dígito importa.

Fora esses dois pontos, é a mesma função. A regra de magnitude é uma só, e
vive num lugar só: `QuoteFormat`, em `CotaKit`.

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
- **Primeiro carregamento que falha:** estado de erro com "Try again", não
  skeleton. O skeleton significa "isto está chegando"; depois que o primeiro
  fetch falhou, não está — e placeholders animados para sempre são a mesma
  mentira que uma cotação velha com cara de fresca. Este é o único caso de
  falha que não tem valor anterior para preservar; com qualquer fetch já
  concluído, vale a regra acima: manter os dados, esmaecidos.

---

## 3. Settings — janela com abas

Referência: seção "Janela de Settings" de `mockup.html`.

### 3.1 Por que sair do popover

Depois que a configuração da barra de menu entrou, Settings passou a ocupar
quase a altura da tela e a exigir rolagem dentro de um popover. No macOS isso
é sinal de que o conteúdo passou do formato: popover é superfície de consulta
rápida; configuração merece janela.

Três defeitos concretos que a janela resolve:

- **Duas listas dos mesmos pares**, separadas por 40px: "Currency pairs" e
  "Pairs to show". Olhando as duas não dá para saber qual faz o quê.
- **Hierarquia achatada.** "Pairs to show", "Format" e "Change indicator" são
  filhos de "Menu bar", mas os sete cabeçalhos têm peso idêntico. Sem
  agrupamento visível, tudo vira uma fila de blocos iguais.
- **"Dim when data is stale" órfão**, pendurado sob "Change indicator" sem
  pertencer a ele.

O popover continua existindo — ele é a view de cotações (§2). Só a
configuração se muda para janela própria, aberta pelo ícone de engrenagem do
rodapé.

**Nota de implementação:** a janela é um `NSWindowController` com
`NSHostingView`, não a cena `Settings` do SwiftUI. `SettingsLink` exige macOS
14 e o alvo é o 13, e o seletor antigo `showSettingsWindow:` é privado. Além
disso, um app accessory precisa se ativar à mão (`NSApp.activate`) antes de a
janela poder receber foco: sem ícone no Dock, uma janela aberta sem isso
aparece atrás do que a pessoa estava usando.

### 3.2 As quatro abas

| Aba | Conteúdo |
|---|---|
| General | Refresh interval, Launch at login |
| Pairs | Lista unificada de pares |
| Menu bar | Preview, Format, Change indicator, Dim when stale |
| Alerts | Lista de alertas e composer |

Cada aba deve caber sem rolagem. Se uma passar a exigir rolagem, é sinal de
que precisa ser dividida — foi exatamente assim que o painel antigo cresceu
sem ninguém perceber.

**Refresh interval fica em General, não em Pairs.** É comportamento global do
app, não propriedade dos pares. Além disso, sem ele a aba General teria um
único toggle solitário.

**Quit não aparece em Settings.** Ele vive no rodapé do popover, que é onde o
usuário está quando decide sair. Numa janela de configuração não faz sentido.

### 3.3 Pairs — lista unificada

A mudança de maior retorno: **uma lista só**, com uma coluna de barra de menu.
Elimina a seção "Pairs to show" inteira e torna a relação óbvia — o par
existe, e opcionalmente aparece na barra.

Colunas, nesta ordem:

```
[⠿] [EUR-BRL] [5,9713] [▾ 0,83%] [☑ Menu bar] [✕]
```

- **Handle de arrastar:** a ordem define a ordem de exibição na barra e no
  popover. Persista.
- **Rate e Change:** tabulares, alinhados à direita, formatados pela regra de
  magnitude (§1).
- **Menu bar:** checkbox. É a única fonte de verdade sobre o que aparece na
  barra; a aba Menu bar apenas reage a ela.
- **✕:** só no hover da linha, para reduzir ruído.

**Cabeçalho de colunas é obrigatório aqui.** Com cinco colunas, "Menu bar"
precisa de rótulo — um checkbox sem legenda no meio de uma lista de cotações
não se explica. (Numa lista de duas ou três colunas o cabeçalho seria ruído;
esta é a exceção.)

Abaixo da lista, a linha de ação **"Add pair"**, alinhada às demais linhas,
com ícone `+` e sem chevron.

**Nota de persistência:** o flag é propriedade do par (`PairSetting`), gravado
como JSON na chave `pairSettings`. As chaves antigas `selectedPairs` e
`menuBarPairs` são lidas uma única vez, na migração, e depois ignoradas —
continuam gravadas para que um rollback para a build anterior ainda encontre a
configuração. Como o flag viaja junto com o par, remover um par leva o flag
embora e não sobra nada para reconciliar, que era o custo permanente do modelo
de duas listas.

**Nenhum par marcado é um estado válido**, não um erro a corrigir. O modelo
antigo forçava o primeiro par quando a seleção esvaziava, o que desfazia em
silêncio a escolha de quem desmarcou tudo de propósito. A barra cai para o
rótulo `Cota`, que mantém o item clicável, e o preview em Settings explica
como voltar. É a mesma regra da §3.4.

### 3.4 Menu bar

Conteúdo definido na §6. A aba contém, nesta ordem: preview ao vivo, Format,
Change indicator, Dim when stale.

Não repita a lista de pares aqui. Se nenhum par estiver marcado na aba Pairs,
o preview mostra um estado vazio com a instrução de ir marcar lá — não um
seletor duplicado.

### 3.5 Alerts

`EUR-BRL above 6` como frase é difícil de escanear e não conversa com o
composer, que é estruturado em colunas.

Colunas fixas, iguais nos alertas existentes e no composer, para a linha de
criação parecer a próxima linha da lista:

| Coluna | Largura |
|---|---|
| Par | 84pt |
| Condição | 72pt |
| Valor | flexível |
| Toggle | fixa |
| ✕ | fixa |

**72pt na condição, não 52pt.** A largura anterior truncava "above" em
`ab...`. Se preferir `>` e `<`, a coluna pode encolher — mas então os alertas
existentes também precisam usar símbolo, ou as colunas deixam de bater.

Trocar o botão `+` por **"Add"**, mesma altura dos campos, desabilitado
enquanto par, operador e valor não estiverem preenchidos. Um `+` de 12pt é
alvo de clique ruim e não comunica que existe validação.

Valor com fonte tabular.

**O toggle é pausa, não reset.** Desligar um alerta preserva o estado de
rearme — a memória de que ele já disparou —, então religar não notifica de
novo por um limiar que continua ultrapassado. Apagar, sim, limpa tudo: um
alerta recriado com o mesmo valor é um alerta novo, e avisa se a condição já
vale. A coleta de lixo desse estado é feita contra os alertas que **existem**,
não contra os que estão **ligados**; confundir os dois foi o que fez o toggle
prometer pausa e entregar reset.

Consequência aceita: um alerta desligado enquanto disparado volta
desligado-e-disparado. Se o preço cruzou de volta e de novo durante a pausa,
ele não avisa dessa travessia — a pessoa pediu para não ser avisada naquela
janela, e um aviso retroativo sobre um evento que ela optou por não acompanhar
é pior que o silêncio.

**Ponto em aberto:** se o toggle de um alerta nunca é usado, ele é decoração e
o ✕ é o único controle real. Decidir se os dois se justificam — mas decidir
com o toggle já funcionando: enquanto ele renotificava ao religar, "ninguém
usa" media o defeito, não a utilidade do controle.

### 3.6 Consistência de controles

O painel antigo usava três linguagens para a mesma ideia: `✕` para deletar
par, checkbox quadrado para "Launch at Login", toggle + `✕` para alertas.

- **Checkbox** para seleção dentro de uma lista (coluna Menu bar em §3.3).
- **Toggle** para algo que age imediatamente: Launch at login, Dim when stale,
  ativar/desativar alerta. No macOS os dois não são intercambiáveis.
- **Todos os `✕` alinhados na mesma coluna**, com largura reservada, para o
  toggle de uma linha não empurrar o `✕` para fora do eixo das outras.

### 3.7 Refresh interval

- Segmented control ocupando **100% da largura**, com os cinco segmentos de
  largura **idêntica** — grid de 5 colunas iguais, não dimensionado pelo
  texto. Antes "30s" era mais largo que "1m" e o conjunto não alcançava a
  margem direita.
- Linha de ajuda 11px em cor terciária abaixo:
  `Values are cached between refreshes.`

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

## 5. Trabalho pendente

Nada pendente. As três superfícies estão implementadas conforme a tabela de
estado no topo.

**Ao abrir trabalho novo, liste-o aqui e marque a seção como pendente na
tabela do topo; ao concluir, faça o inverso.** Uma spec que não distingue o
feito do pendente vira uma lista de tarefas que ninguém confia.

Um ponto em aberto continua registrado, na §3.5: se o toggle de um alerta
nunca é usado, ele é decoração e o `✕` é o único controle real.

Um commit por item.

---

## 6. Barra de menu

Terceira superfície do app, e a mais restrita: ~22pt de altura, largura
disputada com todos os outros itens da barra. Mockup: seção "Item da barra
de menu" de `mockup.html`.

### 6.1 Motivação (resolvido)

Antes deste redesenho, a barra mostrava `🇪🇺 → 🇧🇷 6,01`. Registrado aqui
porque o raciocínio explica as regras da §6.2 e da §6.3.

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

Aba "Menu bar" da janela de Settings (§3.4), com **preview ao vivo no topo** —
a escolha só faz sentido se a pessoa vê o resultado enquanto decide.

**Quais pares aparecem** é definido na coluna "Menu bar" da aba Pairs (§3.3),
não aqui. Esta aba apenas reage a essa lista.

**Format** — quatro opções, cada uma com exemplo renderizado ao lado:

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

**Escopo: barra de menu apenas.** O popover sempre marca dado velho,
independentemente deste toggle. Razão: o esmaecimento incomoda justamente na
barra, que está sempre à vista; o popover foi aberto de propósito e o usuário
quer a informação completa, com espaço para explicar o que houve. Exiba a
linha de ajuda `Applies to the menu bar only. The popover always marks stale
data.` abaixo do toggle, para a diferença não parecer bug.

### 6.3 Regras de renderização

- **A cor vai no indicador, nunca no número.** Número colorido briga com o
  tint do sistema e fica ruim em fundo claro ou papel de parede colorido. A
  seta ▴/▾ carrega a direção pela forma, então funciona mesmo sem cor.
- **Dígitos tabulares mais largura reservada.** Fonte tabular não basta: se
  o valor puder ir de `9,99` para `10,01`, a contagem de caracteres muda.
  Formate com largura fixa de caracteres.
- **Abreviação para valores grandes** conforme §1: acima de 100.000, `406k`.
  Esta é a única superfície que abrevia.
- **Estado stale:** texto esmaecido (`tertiaryLabelColor`) quando o último
  fetch tem mais que 3× o intervalo configurado. Uma cotação de uma hora
  com aparência normal é pior que não mostrar nada.
- **Múltiplos pares:** separar por espaço triplo, não por vírgula ou
  bullet. Dois cabem confortavelmente; três já empurram os outros ícones.
- O código de moeda vai um ponto menor e em cor secundária, para o número
  continuar sendo o elemento dominante. O símbolo, quando `auto` o usa, fica
  no mesmo tamanho do número — é um glifo só, e reduzi-lo o deixa ilegível.
