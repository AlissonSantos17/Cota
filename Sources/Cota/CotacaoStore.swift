import Foundation
import SwiftUI

@MainActor
final class CotacaoStore: ObservableObject {
    @Published private(set) var cotacoes: [Cotacao] = []
    @Published private(set) var erro: String?
    @Published private(set) var carregando = false
    @Published private(set) var ultimaAtualizacao: Date?

    let pares = [
        "EUR-BRL",
        "USD-BRL",
        "GBP-BRL",
        "BTC-BRL"
    ]

    private let service: CotacaoServiceProtocol
    private let intervalo: Duration = .seconds(300)

    private var loop: Task<Void, Never>?

    init(service: CotacaoServiceProtocol = CotacaoService()) {
        self.service = service
    }

    deinit {
        loop?.cancel()
    }

    func iniciar() {
        guard loop == nil else {
            return
        }

        loop = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                await self.atualizar()

                do {
                    try await Task.sleep(for: self.intervalo)
                } catch {
                    break
                }
            }
        }
    }

    func parar() {
        loop?.cancel()
        loop = nil
    }

    func atualizar() async {
        guard !carregando else {
            return
        }

        carregando = true
        erro = nil

        defer {
            carregando = false
        }

        do {
            let novasCotacoes = try await service.buscarCotacoes(pares: pares)
            cotacoes = novasCotacoes
            ultimaAtualizacao = .now
        } catch is CancellationError {
        } catch {
            erro = error.localizedDescription
        }
    }

    var resumoBarra: String {
        guard let primeira = cotacoes.first else {
            return "Cotações"
        }

        let valor = primeira.bid.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Locale(identifier: "pt_BR"))
        )

        return "\(bandeira(primeira.code)) \(primeira.code) \(valor)"
    }

    func bandeira(_ code: String) -> String {
        switch code {
        case "EUR":
            return "🇪🇺"
        case "USD":
            return "🇺🇸"
        case "GBP":
            return "🇬🇧"
        case "BRL":
            return "🇧🇷"
        case "ARS":
            return "🇦🇷"
        case "BTC":
            return "₿"
        case "ETH":
            return "Ξ"
        case "XRP":
            return "✕"
        default:
            return code
        }
    }
}
