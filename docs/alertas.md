# Alertas de preço e notificações

Como o Cota decide que um alerta deve virar um banner e o que acontece em cada etapa. O código citado fica em `Sources/CotaKit`, salvo indicação.

## Peças

| Peça | Arquivo | Papel |
|---|---|---|
| `PriceAlert` | `Models/PriceAlert.swift` | O que a pessoa configurou: par, limiar, acima/abaixo, ligado/desligado |
| `AlertState` / `AlertPhase` | `Models/AlertState.swift` | Ciclo de vida de um alerta. Todas as transições ficam aqui |
| `AlertRules` | `Models/AlertState.swift` | Margem de rearme (0,3%), cooldown (15 min), idade máxima da cotação (1 h), backoff de entrega (1, 5, 15 min) |
| `DeliveryFailure` | `Models/AlertState.swift` | Recusa `transient` (tenta de novo) ou `permanent` (não tenta) |
| `AlertStateStore` | `Stores/AlertStateStore.swift` | Persiste o estado entre aberturas do app (`UserDefaults`, chave `alertStates`) |
| `NotificationService` | `Services/NotificationService.swift` | Alimenta a máquina com cotações, publica pausas, confere permissão, classifica recusas, reconcilia envios interrompidos |
| `SettingsStore` | `Stores/SettingsStore.swift` | CRUD dos alertas (`UserDefaults`, chave `priceAlerts`) e cópia do que não pôde ser lido |
| `QuoteStore` | `Stores/QuoteStore.swift` | Chama `checkAlerts` depois de cada fetch bem-sucedido e quando a lista de alertas muda |
| `AlertsSection` / `AlertRow` | `Sources/Cota/Views/` | Aba Alerts: avisos, lista com pausa por alerta, formulário |

Cada alerta tem dois registros separados. A configuração (`PriceAlert`) fica no `SettingsStore`, e o estado (`AlertState`) fica no `AlertStateStore`. Os dois são ligados pelo `id`.

## Quando os alertas são avaliados

1. Depois de cada fetch bem-sucedido do `QuoteStore`.
2. Logo depois de qualquer mudança na lista de alertas (criar, religar, desligar, remover), contra as cotações já na tela. Sem cotação na tela, nada acontece e o alerta espera o próximo fetch.

Fetch com falha não chama `checkAlerts`. Não existe timer próprio dos alertas: o único agendamento é o loop de fetch do `QuoteStore`, e o backoff de entrega usa esse mesmo ritmo.

## Fluxo de ponta a ponta

```
checkAlerts(alertas, cotações)
  0. só na primeira chamada depois do launch: reconcilia envios interrompidos
  1. remove o estado de alertas que não existem mais
  2. para cada alerta com cotação do par:
       timestamp ausente, ou mais de 5 min no futuro  → pausa .untimedQuote, pula
       timestamp com mais de 1 h                      → pausa .staleQuote, pula
       AlertState.observe(bid)                        → "devido agora?"
  3. publica as pausas e salva os estados
  4. se algum ficou devido:
       lê a permissão no sistema (agora, não no launch)
       negada → para; os alertas continuam devendo o banner
  5. para cada alerta devido:
       beginDelivery(at:)      → requesting + requestedAt, salvo antes do pedido
       UNUserNotificationCenter.add
         aceito                    → deliverySucceeded  (triggered, salva a hora)
         notificationsNotAllowed   → deliveryDeferred   (conditionMet, sem gastar tentativa)
         erro de validação do UN   → deliveryFailed(.permanent)
         qualquer outro erro       → deliveryFailed(.transient)
```

Só o `bid` é comparado. A aba Alerts diz isso: "Alerts compare the bid and are checked while Cota is running."

## Máquina de estados

```
                 atinge (ligado)                 cooldown ok + backoff ok + permissão ok
   ┌─────────┐ ──────────────────► ┌──────────────┐ ─────────────────► ┌────────────┐
   │  armed  │                     │ conditionMet │                    │ requesting │
   └─────────┘ ◄────────────────── └──────────────┘ ◄───────────────── └────────────┘
                 deixa de atingir      ▲      │       recusado / adiado       │
                 (nunca notificou)     │      │ deixa de atingir              │ aceito
                                       │      │ (já notificou)                ▼
                     atinge (ligado)   │      ▼                        ┌────────────┐
                                   ┌──────────────┐  passa da margem   │ triggered  │
                                   │   rearmed    │ ◄───────────────── └────────────┘
                                   └──────────────┘
```

| Fase | Significado | Sai quando |
|---|---|---|
| `armed` | Vigiando. Nunca notificou | Preço atinge o limiar com o alerta ligado → `conditionMet` |
| `conditionMet` | Condição verdadeira, banner devido mas ainda não pedido. Motivos possíveis: cooldown, backoff, falta de permissão, crossing abandonado | Cooldown, backoff e permissão ok → `requesting`. Preço deixa de atingir → `armed` (nunca notificou) ou `rearmed` (já notificou) |
| `requesting` | Banner entregue ao `UNUserNotificationCenter`, sem resposta ainda. Lido de novo no launch, significa que o app parou antes da resposta | Aceito → `triggered`. Recusado → `conditionMet` (com backoff ou abandono). Permissão negada ou envio interrompido sem rastro → `conditionMet` (sem gastar tentativa) |
| `triggered` | Sistema aceitou o banner | Preço passa da margem de rearme → `rearmed` |
| `rearmed` | Passou da margem depois de um banner. Pode disparar de novo | Preço atinge com o alerta ligado → `conditionMet` |

Campos do `AlertState`:

| Campo | Uso |
|---|---|
| `phase` | Fase atual |
| `lastNotifiedAt` | Último banner aceito. Base do cooldown |
| `failedAttempts` | Recusas no cruzamento atual |
| `retryAfter` | Sem nova tentativa antes desta data (backoff) |
| `deliveryAbandoned` | Este cruzamento não será mais tentado |
| `requestedAt` | Quando o pedido em voo foi feito. Base da reconciliação |

Os três campos de falha zeram quando o cruzamento termina ou quando um banner é aceito.

### Regras

- **Atingir.** Acima: `bid >= limiar`. Abaixo: `bid <= limiar`. Tocar o limiar já conta.
- **Rearme (histerese).** A margem é `limiar × 0,003`. Acima: rearma com `bid < limiar − margem`. Abaixo: com `bid > limiar + margem`. A comparação é estrita: ficar exatamente na linha ainda é o mesmo evento. Como a margem é proporcional, vale igual para iene (R$ 0,032 → margem R$ 0,000096) e bitcoin (R$ 400.000 → margem R$ 1.200).
- **Cooldown.** No mínimo 900 s entre dois banners aceitos do mesmo alerta, contados a partir de `lastNotifiedAt`. Pedido recusado não inicia cooldown. O cooldown é independente do rearme.
- **Nada é enfileirado.** Durante o cooldown ou o backoff, o alerta não guarda o cruzamento que o fez ficar devido. A cada fetch, a cotação atual decide de novo:
  - Se a condição continua satisfeita quando o cooldown ou o backoff termina, o banner sai com o preço atual.
  - Se o preço volta para o outro lado do limiar antes disso, o banner é descartado.
- **Alerta criado já satisfeito.** Notifica na primeira cotação válida e recente: quem pede "me avise quando o USD passar de 5" quer saber se ele já passou. Com cotação na tela, isso acontece logo depois de criar.
- **Desligar e religar.** Desligar pausa o banner, não a vigilância. Desligado, o alerta nunca fica devido, mas continua rearmando com os preços observados:
  - Disparou, foi desligado, o preço voltou além da margem e cruzou de novo: ao religar, notifica, e a avaliação é imediata.
  - Disparou, foi desligado, o preço não rearmou: ao religar, fica quieto, porque é o mesmo evento.
- **Remover.** Apaga o alerta e o estado dele. Recriar com o mesmo limiar é um alerta novo, com `id` novo.

### Idade da cotação

- Só entra na avaliação a cotação com `timestamp` da fonte (Unix seconds da AwesomeAPI, `Quote.updatedAt`) de no máximo 1 h atrás.
- **Sem `timestamp`, ou ilegível:** a idade é desconhecida e a cotação não é avaliada (`untimedQuote`). Hoje nenhuma fonte tem exceção. Se alguma fonte precisar de uma, ela deve ser explícita e justificada no código.
- **`timestamp` no futuro:** até 5 min de diferença entre relógios é aceito. Mais que isso, a cotação não é confiável (`untimedQuote`).
- **Cotação pausada** não dispara e não rearma.
- **Indicação:** `NotificationService.pauses` publica o motivo por alerta. A linha do alerta na aba Alerts mostra um ícone laranja `pause.circle`, com explicação no tooltip e na acessibilidade. O ícone some na primeira cotação válida.
- **Consequência:** no fim de semana a fonte de câmbio para de atualizar, e os alertas de moeda ficam pausados até o mercado reabrir. Cripto continua.

## Entrega

- O alerta só vira `triggered` depois que `UNUserNotificationCenter.add` termina sem erro. Isso confirma que o sistema aceitou o pedido. Se a pessoa viu o banner, o sistema não informa.
- Enquanto um pedido está em `requesting`, outro fetch não pede de novo.
- Alerta removido durante o pedido: a resposta chega e não recria o estado.
- Banner: título `"<bandeira> Threshold Reached"`, corpo `"Price is now X (above|below your Y alert)."`, som padrão. Aparece mesmo com o app em primeiro plano. Identificador: `"<uuid do alerta>-<valor>"`.

### Classificação das recusas (`NotificationService.classify`)

| Erro | Tratamento |
|---|---|
| `UNError.notificationsNotAllowed` | Problema de permissão, não de pedido: `authorizationDenied = true`, alerta continua devendo, nenhuma tentativa gasta |
| Erros de validação do `UNError` (anexos, `notificationInvalidNoContent`, `notificationInvalidNoDate`, `contentProviding*`, `badgeInputInvalid`) | `permanent`: o pedido é montado sempre igual, então falharia sempre igual. Abandona o cruzamento |
| Qualquer outro erro (outro domínio, código novo) | `transient`: na dúvida, o alerta não é abandonado por engano |

Códigos conferidos no `UNError.h` dos SDKs MacOSX26.5 e MacOSX27.0 (idênticos): `NotificationsNotAllowed = 1`, anexos `100…105`, `NotificationInvalidNoDate = 1400`, `NotificationInvalidNoContent = 1401`, `ContentProvidingObjectNotAllowed = 1500`, `ContentProvidingInvalid = 1501`, `BadgeInputInvalid = 1600`. O `switch` cobre todos, e `default` trata como `transient` qualquer código futuro.

O centro entrega os erros como `NSError` no domínio `UNErrorDomain`. O teste `refusalsArrivingAsNSErrorAreClassifiedTheSame` confirma que o cast `as? UNError` reconhece essa forma. Ainda não foi verificado em execução real se o macOS de fato responde ao `add` com `NotificationsNotAllowed` quando a permissão está negada. A leitura de permissão antes de cada banner cobre esse caso de qualquer forma.

### Backoff

- Depois de recusas `transient`, as esperas são 60 s, 300 s e 900 s (`AlertRules.deliveryRetryDelays`). A partir da terceira recusa, toda nova espera é de 900 s. A tentativa acontece no primeiro fetch depois da espera, com a cotação daquele momento.
- O limite é de ritmo, não de quantidade: no máximo 4 pedidos por hora por alerta enquanto a condição valer. Uma recusa temporária pode sumir a qualquer momento, e o preço pode ficar além do limiar por dias. Desistir depois do último passo deixaria o alerta mudo todo esse tempo.
- Recusa `permanent` bloqueia o cruzamento só nesta execução (`deliveryAbandoned`, que não é salvo). Depois de reabrir o app, há uma nova tentativa. Só um build ou um sistema diferente muda a resposta para o mesmo pedido, e as duas coisas passam por reabrir o app. Se a recusa se repetir, o cruzamento fica bloqueado de novo até a próxima abertura.
- Quando o preço deixa de atingir o limiar, as falhas zeram e o próximo cruzamento é tratado normalmente. O alerta nunca é apagado.
- O backoff (`failedAttempts`, `retryAfter`) é salvo: reabrir o app não tenta antes do tempo.
- Permissão negada não gasta passo do backoff.

Estado salvo em cada situação:

| Situação | `phase` | `failedAttempts` | `retryAfter` | `deliveryAbandoned` (só em memória) | Como sai |
|---|---|---|---|---|---|
| Recusa temporária nº n | `conditionMet` | n | agora + 60/300/900 s | `false` | Próximo fetch depois de `retryAfter`, se a condição ainda valer |
| Recusa permanente | `conditionMet` | n | `nil` | `true` | Preço deixa de atingir, ou reabertura do app |
| Sem permissão | `conditionMet` | inalterado | inalterado | inalterado | Permissão liberada, no próximo fetch |
| Aceito | `triggered` | 0 | `nil` | `false` | Rearme pela margem |

### Encerramento inesperado

- Antes de chamar `add`, o estado é salvo como `requesting`, com `requestedAt` igual ao `clock()` daquele momento. O mesmo instante é usado na reconciliação.
- O identificador do banner é `NotificationService.requestIdentifier(for:value:)`, igual a `"<UUID do alerta>-<valor>"`. A reconciliação procura pelo prefixo `"<UUID do alerta>-"`. As duas pontas usam o mesmo `uuidString`.
- Na primeira avaliação depois do launch, o serviço consulta `deliveredNotifications()` uma única vez:
  - **Há banner do alerta com data a partir de `requestedAt`:** o pedido saiu. Vira `triggered` com aquela data, sem reenviar.
  - **Não há:** volta a `conditionMet` sem gastar tentativa e é reenviado se a condição ainda valer.
- Banner de um cruzamento anterior, com data anterior a `requestedAt`, não conta.
- Não há garantia de entrega exatamente uma vez. Na dúvida, o sistema prefere repetir um banner a perder um.

Quando pode haver **duplicação** (o banner saiu, mas a reconciliação não o encontra):

1. A pessoa apagou o banner da Central de Notificações antes de reabrir o app.
2. O macOS descartou o banner da lista: limite de itens por app, ou estilo de alerta configurado como "None". O comportamento da lista nesse caso não foi verificado.
3. O relógio do sistema voltou entre o pedido e a entrega (`date < requestedAt`).

Quando pode haver **perda**:

1. A condição deixa de valer antes da próxima avaliação depois do launch. Por regra, o banner é descartado: nada é enfileirado.
2. O `add` aceitou o pedido, mas o banner nunca apareceu (modo Foco, estilo "None"). Para o app, o banner foi entregue. O sistema não informa se foi visto.

Falso positivo (marcar como enviado sem ter saído) exigiria outro banner do mesmo alerta com data a partir de `requestedAt`. Com o app parado não sai nenhum, então só aconteceria com duas cópias do Cota rodando ao mesmo tempo com os mesmos dados.

### Estados que podem ficar parados

| Estado | Duração | Motivo |
|---|---|---|
| `conditionMet` sem permissão | Até liberar a permissão | Intencional: o banner continua devido |
| `conditionMet` com recusa permanente | Até a condição acabar ou o app reabrir | Repetir o mesmo pedido inválido não ajuda |
| `requesting` em memória | Até `add` responder ou o app reabrir | `add` sempre chama o completion; não há timeout próprio |
| Pausado por cotação velha ou sem timestamp | Até chegar cotação válida | Intencional (decisões 2 e 3) |

## Permissão

- Lida no launch (`requestPermission`), sempre que o app fica ativo (`applicationDidBecomeActive`), e antes de cada banner devido.
- Negada: os alertas devidos ficam em `conditionMet`, sem consumo. A aba Alerts mostra o aviso laranja.
- Liberada de novo com o app aberto: o próximo fetch entrega, sem reabrir o app.
- Revogada com o app aberto: a leitura antes do banner percebe. Se mudar entre a leitura e o `add`, o erro `notificationsNotAllowed` tem o mesmo efeito.

## Persistência

| Chave | Conteúdo |
|---|---|
| `priceAlerts` | `[PriceAlert]` em JSON |
| `priceAlerts.unreadable` | Cópia dos bytes originais quando algum alerta não pôde ser lido |
| `alertStates` | `[uuid: AlertState]` em JSON. Campos novos são opcionais na leitura |
| `triggeredAlerts`, `alertLastNotified` | Formato antigo. Lido uma vez para migrar (`triggered` / `rearmed`) e mantido para rollback |

### Alertas ilegíveis: diagnóstico e recuperação

- A leitura é feita alerta por alerta: um registro ilegível não derruba os outros.
- Se algo não pôde ser lido, os bytes originais vão para `priceAlerts.unreadable`. Isso acontece uma vez só, antes de qualquer save sobrescrever a lista.
- O app nunca apaga esse backup.
- A aba Alerts mostra "Some saved alerts could not be read. The original data was kept." com o botão **Save Copy…**. O botão grava os bytes num arquivo escolhido pela pessoa (`NSSavePanel`), e a cópia interna continua no lugar.
- Limite conhecido: só a primeira ocorrência é guardada. Uma segunda corrupção, diferente da primeira, não ganha backup próprio.

## Limites

- Sem servidor e sem push: os alertas só são avaliados com o Cota aberto.
- A resolução é o intervalo de atualização (padrão 5 min). Um pico entre dois fetches não é visto.
- Mercado de câmbio fechado: alertas de moeda pausados (ver "Idade da cotação").

## Testes

| Suíte | O que cobre |
|---|---|
| `AlertStateTests` | Tabela de histerese nos dois sentidos, igualdade no limiar e na margem, escala da margem, cooldown, cruzamento descartado, criação já satisfeita, desligar/religar, backoff 1/5/15 min, backoff fixo no último passo, falha permanente e nova tentativa depois de reabrir, cruzamento seguinte limpo, adiamento sem custo, pedido em voo, persistência de `requesting` e do backoff |
| `NotificationServiceTests` | Permissão negada, liberada e revogada em runtime. Retry depois do backoff com o preço atual. Erro de validação sem retry. `notificationsNotAllowed` tratado como permissão. Classificação das recusas, também na forma `NSError` em que chegam. Pedido em voo. Remoção durante o pedido. Conteúdo do banner |
| `NotificationLifecycleTests` | Cotação velha não avalia nem rearma, sem `timestamp` ou com `timestamp` futuro não avalia, pausa publicada e limpa, cooldown com relógio controlado, reabertura do app, migração do formato antigo, reconciliação de envio interrompido (saiu, não saiu, banner antigo) |
| `QuoteStoreAlertTests` | Avaliação imediata ao criar e ao religar. Espera o fetch quando a cotação na tela é velha ou quando não há cotação |
| `SettingsStoreTests` | Leitura tolerante dos alertas, backup do que não pôde ser lido, backup não substituído, backup oferecido para recuperação |
| `QuoteServiceTests` | `timestamp` da fonte vira `Quote.updatedAt`; ausente ou ilegível vira `nil` |
| `QuoteFormatTests` | Parser do limiar: `350.000,50`, `6.02`, `5.123`, zero e negativos |

O serviço recebe por injeção:
- o relógio (`clock`);
- o armazenamento (`AlertStateStore`);
- as regras (`AlertRules`);
- a entrega (`deliver`);
- a permissão (`resolveAuthorization`);
- a lista da Central de Notificações (`deliveredRequests`).

O `QuoteStore` recebe o `NotificationService` por injeção.

### Ainda exige teste manual no macOS

Nada abaixo foi executado. Os testes automatizados substituem o `UNUserNotificationCenter` por dublês.

1. Banner real aparece com título, corpo e som, com o app em primeiro plano e em segundo plano.
2. Primeira abertura: o diálogo de permissão aparece. Negar mostra o aviso laranja na aba Alerts.
3. Liberar a permissão em System Settings com o app aberto, voltar ao app: o aviso some e o próximo cruzamento notifica.
4. Revogar com o app aberto: o cruzamento seguinte não é consumido e notifica depois de liberar.
5. Criar um alerta já satisfeito com cotação na tela: banner logo após clicar Add.
6. Encerrar o app à força (`kill -9`) logo depois de um banner. Ao reabrir, o mesmo cruzamento não repete se o banner ainda estiver na Central de Notificações, e repete se tiver sido apagado.
7. Fim de semana (ou relógio adiantado): ícone de pausa na linha do alerta de moeda, tooltip legível.
8. Corromper `priceAlerts` com `defaults write` e abrir a aba Alerts: aviso, **Save Copy…** grava o arquivo, e o backup continua em `defaults read`.
9. Com a permissão negada, forçar um `add` (por exemplo, revogando entre a leitura e o envio) e conferir no Console o domínio e o código do erro.
10. Estilo de alerta "None" e modo Foco: ver o que `deliveredNotifications()` lista e se a reconciliação evita a repetição.

## Rodando os testes localmente

Com só as Command Line Tools selecionadas, o build alterna entre duas descrições de build, mesmo sem mudança no código. Numa delas o caminho do plugin do swift-testing (`usr/lib/swift/host/plugins/testing`) não é passado ao compilador, e os arquivos de teste falham com `plugin for module 'TestingMacros' not found`.

Medido em 2026-10-16 numa cópia limpa do `HEAD` (`git archive`, sem as mudanças dos alertas):

| Comando | Builds com falha |
|---|---|
| `swift build --build-tests`, sem mudanças | 5 de 8 |
| O mesmo, com `touch` num teste antes de cada build | 6 de 8 |
| O mesmo, com `-Xswiftc -plugin-path -Xswiftc <plugins/testing>` | 0 de 8 |

Por isso o `scripts/test.sh` passa o caminho quando as Command Line Tools estão selecionadas. Com Xcode, que é o caso do CI (`swift test` em `macos-15`), nada é acrescentado. Os testes nunca falharam: as falhas aconteceram na compilação.
