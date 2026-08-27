import SwiftUI

/// The tiled session area. Reflows into as many columns as fit; one session can be
/// maximised to fill the area. Empty state carries the big `+`.
struct SessionGridView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var settings: AppSettings
    var onNew: () -> Void

    private let minTileWidth: CGFloat = 380
    private let spacing = Hum.Space.md

    var body: some View {
        Group {
            if store.sessions.isEmpty {
                emptyState
            } else if let maxID = store.maximizedID,
                      let session = store.sessions.first(where: { $0.id == maxID }) {
                TerminalTileView(session: session, isMaximized: true, store: store, settings: settings)
                    .id(session.id)
                    .padding(spacing)
                    .transition(.opacity)
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Hum.paper2)
    }

    private var grid: some View {
        GeometryReader { geo in
            let columns = GridLayout.columnCount(width: geo.size.width, minTileWidth: minTileWidth, spacing: spacing)
            let rows = GridLayout.chunk(store.sessions, into: columns)
            // Eager VStack (not LazyVGrid): terminal NSViews must be created once and
            // never recycled on scroll, or the shared view stops rendering in old tiles.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: spacing) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            let padded: [Session?] = row + Array(repeating: nil, count: max(0, columns - row.count))
                            HStack(spacing: spacing) {
                                ForEach(Array(padded.enumerated()), id: \.offset) { _, slot in
                                    if let session = slot {
                                        TerminalTileView(session: session, isMaximized: false, store: store, settings: settings)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: tileHeight(for: rows.count, in: geo.size.height))
                                            .id(session.id)
                                    } else {
                                        Color.clear.frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                    .padding(spacing)
                }
                .onChange(of: store.lastAddedID) { _, id in
                    guard let id else { return }
                    withAnimation(Hum.Motion.considerate(Hum.Motion.snap)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func tileHeight(for rowCount: Int, in available: CGFloat) -> CGFloat {
        let usable = available - spacing * CGFloat(rowCount + 1)
        let perRow = usable / CGFloat(max(1, rowCount))
        return max(240, perRow)
    }


    private var emptyState: some View {
        VStack(spacing: Hum.Space.lg) {
            CharacterMark(burstTrigger: store.sessions.count)
                .scaleEffect(2.2)
                .padding(.bottom, Hum.Space.sm)

            Text(L("empty.title"))
                .font(Hum.Font.display(22, weight: .bold))
                .foregroundStyle(Hum.ink)
            Text(L("empty.body"))
                .font(Hum.Font.body(13))
                .foregroundStyle(Hum.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onNew()
            } label: {
                Label(L("empty.button"), systemImage: "plus")
            }
            .buttonStyle(.hum(.push, accent: Hum.accent(0), size: 15))
        }
        .padding(Hum.Space.xl)
        .frame(maxWidth: 460)
    }
}
