import SwiftUI
import AppKit

struct PainelView: View {
    @ObservedObject var store: CotacaoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let erro = store.erro {
                errorView(erro)
            }

            cotacoes

            Divider()

            actions

            if let data = store.ultimaAtualizacao {
                Text(
                    "Atualizado às \(data.formatted(
                        date: .omitted,
                        time: .standard
                    ))"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("Cotações")
                .font(.headline)

            Spacer()

            if store.carregando {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func errorView(_ erro: String) -> some View {
        Text("Erro ao atualizar: \(erro)")
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cotacoes: some View {
        ForEach(store.cotacoes) { cotacao in
            CotacaoRow(
                cotacao: cotacao,
                bandeira: store.bandeira(cotacao.code)
            )
        }
    }

    private var actions: some View {
        HStack {
            Button {
                Task {
                    await store.atualizar()
                }
            } label: {
                Label("Atualizar", systemImage: "arrow.clockwise")
            }
            .disabled(store.carregando)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Sair", systemImage: "power")
            }
        }
        .font(.caption)
    }
}

private struct CotacaoRow: View {
    let cotacao: Cotacao
    let bandeira: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(bandeira) \(cotacao.code)/\(cotacao.codein)")
                    .font(.system(.body, design: .rounded))
                    .bold()

                Text(cotacao.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(valorFormatado)
                    .font(.system(.body, design: .monospaced))

                Text(variacaoFormatada)
                    .font(.caption)
                    .foregroundStyle(corVariacao)
            }
        }
    }

    private var valorFormatado: String {
        cotacao.bid.formatted(
            .currency(code: cotacao.codein)
                .locale(Locale(identifier: "pt_BR"))
        )
    }

    private var variacaoFormatada: String {
        let valor = cotacao.pctChange
        let sinal = valor >= 0 ? "+" : ""

        return "\(sinal)\(valor.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Locale(identifier: "pt_BR"))
        ))%"
    }

    private var corVariacao: Color {
        cotacao.pctChange >= 0 ? .green : .red
    }
}
