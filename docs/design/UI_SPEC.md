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
5. Estados de erro, stale, loading e vazio (§2.5).

Um commit por bloco.
