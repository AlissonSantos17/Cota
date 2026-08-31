import SwiftUI
import AppKit
import CotaKit

struct PanelView: View {
    @ObservedObject var store: QuoteStore
    @ObservedObject var settings: SettingsStore
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let error = store.error {
                errorView(error)
            }

            quotes

            Divider()

            actions

            if let date = store.lastUpdate {
                Text(
                    "Updated at \(date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute()))"
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
            Text("Quotes")
                .font(.headline)

            Spacer()

            if store.loading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        Text("Update error: \(error)")
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var quotes: some View {
        ForEach(store.quotes) { quote in
            QuoteRow(
                quote: quote,
                flag: store.flag(quote.code),
                history: store.priceHistory[quote.id, default: []]
            )
        }
    }

    private var actions: some View {
        HStack {
            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh quotes")
            .keyboardShortcut("r", modifiers: .command)
            .disabled(store.loading)

            Button {
                showSettings.toggle()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityLabel("Open settings")
            .keyboardShortcut(",", modifiers: .command)
            .popover(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .accessibilityLabel("Quit Cota")
            .keyboardShortcut("q", modifiers: .command)
        }
        .font(.caption)
    }
}

private struct QuoteRow: View {
    let quote: Quote
    let flag: String
    let history: [Decimal]
    @State private var copied = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(flag) \(quote.code)/\(quote.codein)")
                    .font(.system(.body, design: .rounded))
                    .bold()

                Text(quote.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SparklineView(data: history, color: changeColor)

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedValue)
                    .font(.system(.body, design: .monospaced))

                Text(formattedChange)
                    .font(.caption)
                    .foregroundStyle(changeColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quote.code) to \(quote.codein)")
        .accessibilityValue("\(formattedValue), change \(formattedChange)")
        .accessibilityHint("Click to copy value")
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(formattedValue, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }
        .overlay(alignment: .topTrailing) {
            if copied {
                Text("Copied!")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    .transition(.opacity)
                    .offset(y: -14)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    private var formattedValue: String {
        quote.bid.formatted(
            .currency(code: quote.codein)
                .locale(Locale(identifier: "pt_BR"))
        )
    }

    private var formattedChange: String {
        let value = quote.pctChange
        let sign = value >= 0 ? "+" : ""

        let formatted = value.formatted(
            .number
                .precision(.fractionLength(2))
                .locale(Locale(identifier: "pt_BR"))
        )
        return "\(sign)\(formatted)%"
    }

    private var changeColor: Color {
        quote.pctChange >= 0 ? .green : .red
    }
}
