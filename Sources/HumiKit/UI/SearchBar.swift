import SwiftUI

/// In-terminal find bar. Acts on whichever tile currently has keyboard focus
/// (`TerminalRegistry.focusedController()`); Esc or the ✕ closes it.
struct SearchBar: View {
    @Binding var isPresented: Bool
    @State private var term = ""
    @State private var summary = (index: 0, total: 0)
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Hum.Space.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Hum.ink2)

            TextField(L("search.placeholder"), text: $term)
                .textFieldStyle(.plain)
                .font(Hum.Font.mono(12))
                .focused($focused)
                .onSubmit { step(forward: true) }
                .onChange(of: term) { _, _ in refresh() }
                .frame(minWidth: 160)

            if summary.total > 0 {
                Text("\(summary.index)/\(summary.total)")
                    .font(Hum.Font.mono(11)).foregroundStyle(Hum.ink2).monospacedDigit()
            } else if !term.isEmpty {
                Text(L("search.none")).font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
            }

            Button { step(forward: false) } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.plain).disabled(term.isEmpty)
            Button { step(forward: true) } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.plain).disabled(term.isEmpty)
            Button { close() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, Hum.Space.md)
        .padding(.vertical, Hum.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Hum.Radius.input, style: .continuous)
                .fill(Hum.paper)
                .shadow(color: Hum.ink.opacity(0.18), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Hum.Radius.input, style: .continuous)
                .strokeBorder(Hum.hairline)
        )
        .onAppear { focused = true; refresh() }
    }

    private func step(forward: Bool) {
        guard let c = TerminalRegistry.shared.focusedController() else { NSSound.beep(); return }
        _ = c.find(term, forward: forward)
        summary = c.matchSummary(term)
    }

    private func refresh() {
        guard let c = TerminalRegistry.shared.focusedController() else { summary = (0, 0); return }
        summary = c.matchSummary(term)
    }

    private func close() {
        isPresented = false
    }
}
