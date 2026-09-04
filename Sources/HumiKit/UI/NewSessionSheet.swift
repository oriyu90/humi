import SwiftUI
import UniformTypeIdentifiers

/// The `+` flow. Opens straight away with two choices — open as-is (home), or pick a
/// folder to open in. The folder is chosen with a SwiftUI `.fileImporter` layered over
/// this sheet (no nested `NSOpenPanel` / dismiss-and-re-present, which used to drop the
/// picked path). An optional profile applies to either choice.
struct NewSessionSheet: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var profiles = ProfileStore.shared
    /// workingDirectory?, profileID? — nil dir == "open as-is"; nil profile == global
    var onCreate: (String?, UUID?) -> Void
    var onCancel: () -> Void

    @State private var folder: String?
    @State private var profileID: UUID?
    @State private var choosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: Hum.Space.lg) {
            VStack(alignment: .leading, spacing: Hum.Space.xs) {
                Text(L("sheet.new.title"))
                    .font(Hum.Font.display(20, weight: .bold))
                    .foregroundStyle(Hum.ink)
                Text(L("sheet.new.subtitle"))
                    .font(Hum.Font.body(13))
                    .foregroundStyle(Hum.ink2)
            }

            HStack(spacing: Hum.Space.sm) {
                Image(systemName: folder == nil ? "house" : "folder")
                    .foregroundStyle(Hum.ink2)
                Text(folder.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? L("sheet.new.no_folder"))
                    .font(Hum.Font.mono(12))
                    .foregroundStyle(folder == nil ? Hum.ink2 : Hum.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                Spacer(minLength: Hum.Space.sm)
                Button(folder == nil ? L("sheet.new.choose_folder") : L("sheet.new.change_folder")) {
                    choosingFolder = true
                }
                .buttonStyle(.hum(.outline, accent: Hum.accent(1)))
            }
            .padding(Hum.Space.md)
            .background(RoundedRectangle(cornerRadius: Hum.Radius.input, style: .continuous).fill(Hum.paper2))

            if !profiles.profiles.isEmpty {
                HStack {
                    Text(L("sheet.new.profile")).foregroundStyle(Hum.ink2)
                    Spacer()
                    Picker("", selection: $profileID) {
                        Text(L("sheet.new.profile.none")).tag(UUID?.none)
                        ForEach(profiles.profiles) { p in Text(p.name).tag(UUID?.some(p.id)) }
                    }
                    .labelsHidden().frame(width: 220)
                }
            }

            Divider().overlay(Hum.hairline)

            Button {
                onCreate(folder, profileID)
            } label: {
                actionLabel(title: folder == nil ? L("sheet.new.open_home") : L("sheet.new.open_here"),
                            subtitle: L("sheet.new.open_caption"),
                            systemImage: "square.split.2x2")
            }
            .buttonStyle(.hum(.push, accent: Hum.accent(0)))
            .keyboardShortcut(.defaultAction)

            HStack {
                Spacer()
                Button(L("sheet.new.cancel")) { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Hum.ink2)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Hum.Space.xl)
        .frame(width: 520)
        .background(Hum.paper)
        .onAppear { if profileID == nil { profileID = profiles.defaultProfileID } }
        .fileImporter(isPresented: $choosingFolder,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                folder = url.path
            }
        }
    }

    private func actionLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: Hum.Space.sm) {
            Image(systemName: systemImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Hum.Font.display(14, weight: .semibold))
                Text(subtitle).font(Hum.Font.body(11)).foregroundStyle(Hum.ink2)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
