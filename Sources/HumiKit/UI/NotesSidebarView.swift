import SwiftUI

/// Right-hand Markdown scratchpad. Persists across restarts (NotesStore).
/// Toggle between edit and preview.
struct NotesSidebarView: View {
    @ObservedObject var notes: NotesStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Hum.hairline)
            if settings.notesPreview {
                MarkdownView(text: notes.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                editor
            }
        }
        .background(Hum.paper)
    }

    private var header: some View {
        HStack(spacing: Hum.Space.sm) {
            Text("メモ")
                .font(Hum.Font.display(13, weight: .bold))
                .foregroundStyle(Hum.ink)
            Spacer()
            Picker("", selection: settings.bind(\.notesPreview)) {
                Text("編集").tag(false)
                Text("プレビュー").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
        }
        .padding(.horizontal, Hum.Space.md)
        .padding(.vertical, Hum.Space.sm)
    }

    private var editor: some View {
        TextEditor(text: $notes.text)
            .font(Hum.Font.mono(12.5))
            .foregroundStyle(Hum.ink)
            .scrollContentBackground(.hidden)
            .background(Hum.paper)
            .padding(Hum.Space.sm)
    }
}
