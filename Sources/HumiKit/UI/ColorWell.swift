import SwiftUI
import AppKit

/// A compact `NSColorWell` bound to a `HexColor`. Opaque sRGB only.
struct ColorWellView: NSViewRepresentable {
    @Binding var color: HexColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell()
        well.isBordered = true
        if #available(macOS 13.0, *) { well.colorWellStyle = .minimal }
        well.color = color.nsColor
        well.target = context.coordinator
        well.action = #selector(Coordinator.changed(_:))
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: 42).isActive = true
        well.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return well
    }

    func updateNSView(_ well: NSColorWell, context: Context) {
        context.coordinator.parent = self
        let want = color.nsColor
        if well.color.usingColorSpace(.sRGB) != want.usingColorSpace(.sRGB) {
            well.color = want
        }
    }

    final class Coordinator: NSObject {
        var parent: ColorWellView
        init(_ p: ColorWellView) { parent = p }

        @objc func changed(_ sender: NSColorWell) {
            parent.color = HexColor(sender.color)
        }
    }
}
