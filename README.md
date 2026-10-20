# Cota

Aplicativo de barra de menus para macOS que acompanha cotações de câmbio e cripto em real (BRL). Vive só na barra — sem ícone no Dock — e atualiza sozinho em segundo plano.

Os dados vêm da [AwesomeAPI](https://docs.awesomeapi.com.br/api-de-moedas). Não há dependências externas: SwiftUI, AppKit e frameworks do sistema.

O visual segue as cores do ícone — menta sobre quase-preto — em modo escuro. A especificação está em [`Design/Rebrand/`](Design/Rebrand/README.md). O app fala **Português (Brasil)** e **English**, escolhido em Settings → Geral.

## O que o Cota faz

Três superfícies, uma fonte de verdade:

| Superfície | Papel |
|---|---|
| **Barra de menus** | Olhada rápida: valor, tendência e o par que você escolheu mostrar |
| **Painel** | Clique na barra: lista completa; cada linha abre no lugar com gráfico, conversor e ações |
| **Settings** | Janela própria, com barra lateral: Geral, Pares, Barra de menus e Alertas |

Na primeira abertura, a barra mostra o nome **Cota** por dois segundos e depois faz o fade para a cotação. Assim o ícone não “pula” quando o fetch chega cedo demais.

## Features

### Barra de menus

- Um ou mais pares, na ordem que você arranjou em Settings
- Formato do rótulo:
  - **Símbolo** — símbolo da moeda; cai para o código se dois pares compartilham o mesmo glifo (`$` em USD, CAD, AUD…)
  - **Código** — `USD 5,19`
  - **Bandeira** — bandeira; cripto sem país cai no símbolo ou no código
  - **Só o valor** — só o número; disponível com um par só, senão `6,02 5,19` não dá para distinguir
- Indicador de variação: nenhum, seta (`▴` / `▾`) ou percentual
- Números mais compactos que no painel: duas casas e abreviação acima de 100.000 (`398k`)
- Opção de escurecer o rótulo quando o dado está velho (o painel sempre marca stale)
- Ponto menta depois do valor quando o par tem alerta ligado

### Painel de cotações

- Lista dos pares acompanhados, com nome da moeda, valor no símbolo do destino, variação e sparkline
- Clique numa linha abre o detalhe no lugar (uma por vez):
  - gráfico grande do período — **24h**, **7d** ou **30d** — com abertura tracejada, mín/máx e a linha do alerta
  - conversor (valor e sentido valem para todos os pares)
  - **Copiar** o valor e **Novo alerta** / **Remover alerta**
- Estados explícitos: skeleton no primeiro load, vazio, falha sem fallback, e dados antigos **escurecidos** (nunca apagados)
- Rodapé com status (“Atualizado agora”, ou âmbar quando o dado está velho), refresh, Settings e sair
- Atalhos: `⌘R` atualiza, `⌘,` abre Settings, `⌘Q` encerra

### Pares e preferências

Pares disponíveis (todos cotados em BRL):

| | | | |
|---|---|---|---|
| EUR | USD | GBP | BTC |
| ARS | CAD | AUD | JPY |
| CHF | CNY | ETH | XRP |

Padrão: EUR, USD, GBP e BTC.

- Adicionar pares numa folha com busca, sugestões e colunas De/Para que só combinam pares do catálogo
- Remover e reordenar por arrastar (ou pelo menu de contexto)
- **Alfinete** em cada linha — é a única lista que decide o que aparece na barra
- Idioma: Sistema, Português (Brasil) ou English — textos, nomes das moedas e formato dos números
- Intervalo de atualização: 30s, 1m, 2m, 5m ou 10m (padrão: 5 minutos)
- Abrir no login (`SMAppService`)

### Alertas de preço

- Alerta escrito como frase: “Avise quando EUR/BRL passar de R$ 5,70”, com a distância ao vivo
- Notificação quando o bid passa **acima** ou **abaixo** de um limiar
- Liga e desliga sem perder o estado de armamento
- Não dispara em loop: margem de 0,3% para rearmar e cooldown de 15 minutos
- Só marca como notificado depois que o macOS aceita o banner; permissão relida a cada banner
- Recusa temporária do macOS: nova tentativa com backoff de 1, 5 e 15 minutos
- Ignora cotações com mais de 1 hora ou sem timestamp, e mostra o alerta como pausado
- Avalia na hora ao criar ou religar um alerta, se houver cotação recente
- Avaliados só com o app aberto (não há servidor)
- Banner mesmo com o app em primeiro plano

Máquina de estados e regras completas em [docs/alertas.md](docs/alertas.md).

## Como funciona

```
AwesomeAPI  ──►  QuoteService  ──►  QuoteStore  ──►  painel / barra / alertas
                                      ▲
                                      └── SettingsStore (UserDefaults)
```

1. O `QuoteStore` busca as cotações dos pares ativos e agenda o próximo ciclo.
2. Em paralelo, hidrata o histórico: fechamentos diários (até 30 dias) e ticks intraday (até 100 pontos) para desenhar a sparkline já na abertura.
3. Cada bid ao vivo entra na série de 24h. Os períodos de 7 e 30 dias usam os fechamentos, com o bid atual no fim.
4. Depois de cada fetch bem-sucedido, o `NotificationService` avalia os alertas (ver [docs/alertas.md](docs/alertas.md)).
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
    L10n.swift          # idioma escolhido e busca de textos
    Resources/          # pt-BR.lproj e en.lproj (Localizable.strings)
    Models/             # Quote, Currency, PriceAlert, períodos, formatos
    Services/           # QuoteService, QuoteFormat, MenuBarLabel, notificações
    Stores/             # QuoteStore, SettingsStore
Tests/CotaKitTests/
```

`CotaKit` concentra regras que a UI só consome: formatação de números (`QuoteFormat`), montagem do rótulo da barra (`MenuBarLabel`) e o loop de fetch. A UI não inventa um segundo formato.

O `.app` é montado à mão (`rebuild.sh`): copia o binário para `Cota.app/Contents/MacOS` e o bundle de textos `Cota_CotaKit.bundle` para `Contents/Resources`, assina ad-hoc e abre. O ícone (`Cota.app/Contents/Resources/AppIcon.icns`) é versionado; as fontes ficam em `Design/`. `LSUIElement` está ligado — o Cota não aparece no Dock.

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
make icon      # regera o AppIcon.icns a partir de Design/*.svg
make dmg       # build release e gera dist/Cota-<versão>.dmg
```

CI no GitHub Actions: teste, build (debug e release) e lint a cada push/PR em `main`.
