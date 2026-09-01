import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Right-hand Markdown scratchpad, now tabbed. A pinned **Home** tab lists every
/// note (create / rename / delete / ZIP export-import); each other tab is one note
/// with an Edit/Preview toggle. Persists across restarts (`NotesStore`).
struct NotesSidebarView: View {
    @ObservedObject var notes: NotesStore
    @ObservedObject var settings: AppSettings

    @State private var scrollFraction: CGFloat = 0
    @State private var deletingID: UUID?
    @State private var renamingID: UUID?
    @State private var draftTitle = ""

    private var editorFont: NSFont {
        NSFont(name: Hum.Font.monoName, size: 12.5) ?? .monospacedSystemFont(ofSize: 12.5, weight: .regular)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            Divider().overlay(Hum.hairline)
            if let id = notes.activeID, let note = notes.note(id) {
                noteTab(id: id, note: note)
            } else {
                homeTab
            }
        }
        .background(Hum.paper)
        .onChange(of: notes.activeID) { _, _ in scrollFraction = 0 }
        .confirmationDialog(
            L("notes.delete.confirm.title"),
            isPresented: Binding(get: { deletingID != nil }, set: { if !$0 { deletingID = nil } }),
            titleVisibility: .visible,
            presenting: deletingID
        ) { id in
            Button(L("notes.delete.confirm.delete"), role: .destructive) {
                notes.delete(id); deletingID = nil
            }
            Button(L("common.cancel"), role: .cancel) { deletingID = nil }
        } message: { id in
            Text(L("notes.delete.confirm.message", notes.note(id)?.title ?? ""))
        }
        .alert(L("notes.rename"), isPresented: Binding(
            get: { renamingID != nil }, set: { if !$0 { renamingID = nil } })
        ) {
            TextField(L("notes.rename.prompt"), text: $draftTitle)
            Button(L("common.cancel"), role: .cancel) { renamingID = nil }
            Button(L("notes.rename")) {
                if let id = renamingID { notes.rename(id, to: draftTitle) }
                renamingID = nil
            }
        }
    }

    // MARK: tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            tabChip(
                selected: notes.activeID == nil,
                label: { Image(systemName: "square.grid.2x2").font(.system(size: 12, weight: .semibold)) },
                action: { withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) { notes.open(nil) } }
            )
            .help(L("notes.list.title"))
            .accessibilityLabel(L("notes.list.title"))
            .padding(.leading, Hum.Space.sm)

            Divider().frame(height: 16).padding(.horizontal, Hum.Space.xs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Hum.Space.xs) {
                    ForEach(notes.notes) { note in
                        tabChip(
                            selected: notes.activeID == note.id,
                            label: {
                                HStack(spacing: 5) {
                                    Text(note.title)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: 150)
                                        .font(Hum.Font.body(12, weight: .medium))
                                    Button {
                                        deletingID = note.id
                                    } label: {
                                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Hum.ink2)
                                    .help(L("notes.delete"))
                                    .accessibilityLabel(L("notes.delete"))
                                }
                            },
                            action: { withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) { notes.open(note.id) } }
                        )
                    }
                }
                .padding(.trailing, Hum.Space.sm)
            }
        }
        .padding(.vertical, Hum.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tabChip<Label: View>(selected: Bool,
                                      @ViewBuilder label: () -> Label,
                                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(selected ? Hum.ink : Hum.ink2)
                .padding(.horizontal, Hum.Space.sm)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Hum.Radius.input, style: .continuous)
                        .fill(selected ? Hum.paper3 : Color.clear)
                )
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Hum.pear)
                        .frame(height: 2)
                        .padding(.horizontal, Hum.Space.xs)
                        .opacity(selected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: home tab

    private var homeTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Hum.Space.md) {
                HStack {
                    Text(L("notes.list.title"))
                        .font(Hum.Font.display(14, weight: .bold))
                        .foregroundStyle(Hum.ink)
                    Spacer()
                    Button(action: { withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) { _ = notes.newNote() } }) {
                        Label(L("notes.tab.new"), systemImage: "plus")
                    }
                    .buttonStyle(.hum(.outline, accent: Hum.accent(1), size: 13))
                }

                if notes.notes.isEmpty {
                    Text(L("notes.list.empty"))
                        .font(Hum.Font.body(12))
                        .foregroundStyle(Hum.ink2)
                        .padding(.vertical, Hum.Space.sm)
                } else {
                    VStack(spacing: Hum.Space.xs) {
                        ForEach(notes.notes) { note in noteRow(note) }
                    }
                }

                Divider().overlay(Hum.hairline)

                Text(L("notes.share"))
                    .font(Hum.Font.display(12, weight: .bold))
                    .foregroundStyle(Hum.ink2)
                HStack(spacing: Hum.Space.sm) {
                    Button(action: exportNotes) { Label(L("notes.export_zip"), systemImage: "square.and.arrow.up") }
                        .buttonStyle(.hum(.soft, size: 12))
                        .disabled(notes.notes.isEmpty)
                    Button(action: importNotes) { Label(L("notes.import_zip"), systemImage: "square.and.arrow.down") }
                        .buttonStyle(.hum(.soft, size: 12))
                }
                Text(L("notes.share.hint"))
                    .font(Hum.Font.body(11))
                    .foregroundStyle(Hum.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Hum.Space.md)
        }
    }

    private func noteRow(_ note: NoteDoc) -> some View {
        HStack(spacing: Hum.Space.sm) {
            Button(action: { withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) { notes.open(note.id) } }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(Hum.Font.body(13, weight: .medium))
                        .foregroundStyle(Hum.ink)
                        .lineLimit(1)
                    Text(snippet(note.text))
                        .font(Hum.Font.mono(10))
                        .foregroundStyle(Hum.ink2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { renamingID = note.id; draftTitle = note.title } label: {
                Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Hum.ink2)
            .help(L("notes.rename"))
            .accessibilityLabel(L("notes.rename"))

            Button { deletingID = note.id } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Hum.ink2)
            .help(L("notes.delete"))
            .accessibilityLabel(L("notes.delete"))
        }
        .padding(Hum.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Hum.Radius.input, style: .continuous).fill(Hum.paper2)
        )
    }

    private func snippet(_ text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let clean = firstLine.trimmingCharacters(in: CharacterSet(charactersIn: "#-*> `"))
        return clean.isEmpty ? " " : clean
    }

    // MARK: note tab

    @ViewBuilder
    private func noteTab(id: UUID, note: NoteDoc) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("", selection: settings.bind(\.notesPreview)) {
                    Text(L("notes.edit")).tag(false)
                    Text(L("notes.preview")).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, Hum.Space.md)
            .padding(.vertical, Hum.Space.sm)

            Divider().overlay(Hum.hairline)

            if settings.notesPreview {
                TrackingScroll(scrollFraction: $scrollFraction) {
                    MarkdownBlocks(text: note.text)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NotesEditor(text: notes.textBinding(for: id),
                            scrollFraction: $scrollFraction,
                            font: editorFont,
                            textColor: NSColor(Hum.ink))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Hum.Space.xs)
            }
        }
        .background(Hum.paper)
    }

    // MARK: ZIP export / import

    private func exportNotes() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "\(L("notes.export.filename")).zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try NotesArchive.export(notes.notes, to: url) }
        catch {
            NSSound.beep()
            NSLog("Humi: notes export failed — \(error.localizedDescription)")
        }
    }

    private func importNotes() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let incoming = try NotesArchive.read(from: url)
            let result = notes.merge(imported: incoming)
            if result.added == 0 && result.replaced == 0 { NSSound.beep() }
        } catch {
            NSSound.beep()
            NSLog("Humi: notes import failed — \(error.localizedDescription)")
        }
    }
}
