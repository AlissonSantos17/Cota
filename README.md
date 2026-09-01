# Cota

Aplicativo de barra de menus para macOS que acompanha cotações de câmbio e cripto em real (BRL). Vive só na barra — sem ícone no Dock — e atualiza sozinho em segundo plano.

Os dados vêm da [AwesomeAPI](https://docs.awesomeapi.com.br/api-de-moedas). Não há dependências externas: SwiftUI, AppKit e frameworks do sistema.

## O que o Cota faz

Três superfícies, uma fonte de verdade:

| Superfície | Papel |
|---|---|
| **Barra de menus** | Olhada rápida: valor, tendência e o par que você escolheu mostrar |
| **Painel** | Clique na barra: lista completa, sparkline, variação e faixa do período |
| **Settings** | Janela própria, em quatro abas: intervalo, pares, formato da barra e alertas |

Na primeira abertura, a barra mostra o nome **Cota** por dois segundos e depois faz o fade para a cotação. Assim o ícone não “pula” quando o fetch chega cedo demais.

## Features

### Barra de menus

- Um ou mais pares, na ordem que você arranjou em Settings
- Formato do rótulo:
  - **Automatic** — símbolo da moeda; cai para o código se dois pares compartilham o mesmo glifo (`$` em USD, CAD, AUD…)
  - **Currency code** — `USD 5,19`
  - **Flag** — bandeira; cripto sem país cai no símbolo ou no código
  - **Value only** — só o número; disponível com um par só, senão `6,02 5,19` não dá para distinguir
- Indicador de variação: nenhum, seta (`▴` / `▾`) ou percentual
- Números mais compactos que no painel: duas casas e abreviação acima de 100.000 (`398k`)
- Opção de escurecer o rótulo quando o dado está velho (o painel sempre marca stale)

### Painel de cotações

- Lista dos pares acompanhados, com símbolo, valor, variação e faixa (mín–máx)
- Sparkline do período escolhido — **24h**, **7d** ou **30d** — com linha de referência no valor de abertura
- Clique numa cotação copia o valor
- Estados explícitos: skeleton no primeiro load, vazio, falha sem fallback, e dados antigos **escurecidos** (nunca apagados)
- Rodapé com “Updated just now / N min ago”, refresh, Settings e sair
- Atalhos: `⌘R` atualiza, `⌘,` abre Settings, `⌘Q` encerra

### Pares e preferências

Pares disponíveis (todos cotados em BRL):

| | | | |
|---|---|---|---|
| EUR | USD | GBP | BTC |
| ARS | CAD | AUD | JPY |
| CHF | CNY | ETH | XRP |

Padrão: EUR, USD, GBP e BTC.

- Adicionar e remover pares
- Reordenar por arrastar ou pelas setas
- Checkbox **Menu bar** em cada linha — é a única lista que decide o que aparece na barra
- Intervalo de atualização: 30s, 1m, 2m, 5m ou 10m (padrão: 5 minutos)
- Abrir no login (`SMAppService`)

### Alertas de preço

- Notificação quando o bid passa **acima** ou **abaixo** de um limiar
- Liga e desliga sem perder o estado de armamento
- Não dispara em loop: margem de 0,3% para rearmar e cooldown de 15 minutos
- Banner mesmo com o app em primeiro plano

## Como funciona

```
AwesomeAPI  ──►  QuoteService  ──►  QuoteStore  ──►  painel / barra / alertas
                                      ▲
                                      └── SettingsStore (UserDefaults)
```

1. O `QuoteStore` busca as cotações dos pares ativos e agenda o próximo ciclo.
2. Em paralelo, hidrata o histórico: fechamentos diários (até 30 dias) e ticks intraday (até 100 pontos) para desenhar a sparkline já na abertura.
3. Cada bid ao vivo entra na série de 24h. Os períodos de 7 e 30 dias usam os fechamentos, com o bid atual no fim.
4. Depois de cada fetch bem-sucedido, o `NotificationService` avalia os alertas.
5. Se o último update tem mais de **três intervalos** de idade, o dado é tratado como stale.

A API é chamada em três endpoints:

| Endpoint | Uso |
|---|---|
| `/json/last/{pares}` | Cotação atual (bid e variação do dia) |
| `/json/daily/{par}/{dias}` | Fechamentos para 7d / 30d |
| `/json/{par}/{n}` | Ticks recentes para a janela de 24h |

Falhas de rede tentam de novo até 3 vezes, com backoff. Timeout de 15s. Sem cache local da resposta HTTP — o que está na tela é o último fetch que deu certo.

Preferências (pares, intervalo, período, formato da barra, alertas) ficam no `UserDefaults`. Não há conta nem servidor próprio.

## Arquitetura

Pacote Swift (SPM), sem arquivo `.xcodeproj`. Dois targets e um de testes:

```
Sources/
  Cota/                 # app: SwiftUI + AppKit
    CotaApp.swift
    Views/              # painel, Settings, barra, sparklines
  CotaKit/              # domínio testável, sem UI
    Models/             # Quote, Currency, PriceAlert, períodos, formatos
    Services/           # QuoteService, QuoteFormat, MenuBarLabel, notificações
    Stores/             # QuoteStore, SettingsStore
Tests/CotaKitTests/
```

`CotaKit` concentra regras que a UI só consome: formatação de números (`QuoteFormat`), montagem do rótulo da barra (`MenuBarLabel`) e o loop de fetch. A UI não inventa um segundo formato.

O `.app` é montado à mão (`rebuild.sh`): copia o binário para `Cota.app/Contents/MacOS`, assina ad-hoc e abre. `LSUIElement` está ligado — o Cota não aparece no Dock.

## Requisitos

- macOS 13+
- Xcode 15+ / Swift 5.9+
- [SwiftLint](https://github.com/realm/SwiftLint) só para `make lint`: `brew install swiftlint`

## Rodar

```bash
open Package.swift          # Xcode
make rebuild               # build, codesign e abre o .app
```

Ou, no Xcode, execute o target `Cota`.

## Comandos

```bash
make test      # testes (CotaKit)
make build     # build debug
make format    # swift-format
make lint      # format + SwiftLint
make rebuild   # build, codesign e abre o app
```

CI no GitHub Actions: teste, build (debug e release) e lint a cada push/PR em `main`.
