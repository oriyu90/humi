import SwiftUI
import AppKit

/// The session area from v1.2 on: a recursive `PaneNode` tree instead of a reflowing
/// grid. Panes are laid out absolutely from `layout.frames(in:gap:)` inside one eager
/// `ZStack` — every leaf keeps a stable `.id(session.id)` and is never removed from the
/// view tree while it exists, so the shared terminal `NSView` is never recycled. Split
/// boundaries are drawn as our own draggable handles.
struct PaneTreeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var settings: AppSettings
    var onNew: () -> Void

    @State private var focusedID: UUID?

    private static let canvasSpace = "humi.paneCanvas"
    private let gap = Hum.Space.md

    var body: some View {
        Group {
            if store.sessions.isEmpty || store.layout == nil {
                emptyState
            } else if let maxID = store.maximizedID,
                      let session = store.sessions.first(where: { $0.id == maxID }) {
                TerminalTileView(session: session, isMaximized: true, isFocused: true,
                                 store: store, settings: settings)
                    .id(session.id)
                    .padding(gap)
                    .transition(.opacity)
            } else if let layout = store.layout {
                canvas(layout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Hum.paper2)
        .onAppear { focusedID = TerminalRegistry.shared.lastFocusedID }
        .onReceive(NotificationCenter.default.publisher(for: .humiFocusChanged)) { note in
            focusedID = note.object as? UUID
        }
    }

    // MARK: canvas

    private func canvas(_ layout: PaneNode) -> some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: gap, dy: gap)
            let frames = layout.frames(in: rect, gap: gap)
            let dividers = layout.dividers(in: rect, gap: gap, thickness: 12)

            ZStack(alignment: .topLeading) {
                // Leaves — always present, stable id, positioned absolutely.
                ForEach(store.sessions) { session in
                    if let f = frames[session.id] {
                        TerminalTileView(session: session, isMaximized: false,
                                         isFocused: focusedID == session.id,
                                         store: store, settings: settings)
                            .frame(width: max(1, f.width), height: max(1, f.height))
                            .position(x: f.midX, y: f.midY)
                            .id(session.id)
                            .onDrag { NSItemProvider(object: session.id.uuidString as NSString) }
                            .onDrop(of: [.text], isTargeted: nil) { providers in
                                handleDrop(providers, onto: session.id)
                            }
                    }
                }
                // Split handles on top.
                ForEach(dividers, id: \.id) { spec in
                    DividerHandle(spec: spec, coordinateSpace: Self.canvasSpace) { fraction in
                        store.setPaneRatio(atPath: spec.path, dividerIndex: spec.index, to: fraction)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(name: Self.canvasSpace)
            // A freshly added / split pane takes the focus ring so the eye lands on it.
            .onChange(of: store.lastAddedID) { _, id in
                if let id { focusedID = id }
            }
        }
    }

    /// Drop one tile onto another → swap the two panes.
    private func handleDrop(_ providers: [NSItemProvider], onto targetID: UUID) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String, let dragged = UUID(uuidString: s), dragged != targetID else { return }
            Task { @MainActor in
                withAnimation(Hum.Motion.considerate(Hum.Motion.spring)) {
                    store.swapPanes(dragged, targetID)
                }
            }
        }
        return true
    }

    // MARK: empty state

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

/// A single split boundary. A thin visible rule inside a wider transparent hit area;
/// dragging reports the earlier pane's new fraction of the resized pair (0.05–0.95).
private struct DividerHandle: View {
    let spec: PaneNode.DividerSpec
    let coordinateSpace: String
    var onChange: (CGFloat) -> Void

    private var isHorizontal: Bool { spec.axis == .horizontal }

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear).contentShape(Rectangle())
            Rectangle()
                .fill(Hum.hairline)
                .frame(width: isHorizontal ? 1 : spec.rect.width,
                       height: isHorizontal ? spec.rect.height : 1)
        }
        .frame(width: spec.rect.width, height: spec.rect.height)
        .position(x: spec.rect.midX, y: spec.rect.midY)
        .onHover { inside in
            if inside {
                (isHorizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpace))
                .onChanged { value in
                    let p = spec.pairRect
                    let fraction = isHorizontal
                        ? (value.location.x - p.minX) / max(1, p.width)
                        : (value.location.y - p.minY) / max(1, p.height)
                    onChange(min(max(fraction, 0.05), 0.95))
                }
        )
    }
}
