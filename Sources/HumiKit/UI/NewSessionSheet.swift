import SwiftUI

/// Step 2 of the `+` flow: the folder was already chosen (or skipped) via an
/// `NSOpenPanel` run by `RootView`. Here the user picks *where* the session opens.
/// No `NSOpenPanel` is run from inside this sheet (that would nest modals).
struct NewSessionSheet: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var profiles = ProfileStore.shared
    let folder: String?
    var onPickFolder: () -> Void
    /// workingDirectory?, profileID? — nil dir == "open as-is"; nil profile == global
    var onCreate: (String?, UUID?) -> Void
    var onCancel: () -> Void

    @State private var profileID: UUID?

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
                Spacer(minLength: Hum.Space.sm)
                Button(folder == nil ? L("sheet.new.choose_folder") : L("sheet.new.change_folder")) { onPickFolder() }
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

            HStack {
                Spacer()
                Button(L("sheet.new.cancel")) { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Hum.ink2)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Hum.Space.xl)
        .frame(width: 480)
        .background(Hum.paper)
        .onAppear { if profileID == nil { profileID = profiles.defaultProfileID } }
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
