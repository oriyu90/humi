import SwiftUI
import AppKit

/// Click to arm, then press a modifier + key to capture a `KeyChord`.
struct KeyRecorder: NSViewRepresentable {
    @Binding var chord: KeyChord
    var onCapture: (KeyChord) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let b = RecorderButton()
        b.onCapture = { c in chord = c; onCapture(c) }
        b.refresh(chord.display)
        return b
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        nsView.onCapture = { c in chord = c; onCapture(c) }
        if !nsView.armed { nsView.refresh(chord.display) }
    }

    final class RecorderButton: NSButton {
        var onCapture: ((KeyChord) -> Void)?
        private(set) var armed = false

        override init(frame: NSRect) {
            super.init(frame: frame)
            bezelStyle = .roundRect
            setButtonType(.momentaryPushIn)
            target = self
            action = #selector(arm)
            widthAnchor.constraint(equalToConstant: 110).isActive = true
        }
        required init?(coder: NSCoder) { fatalError() }

        func refresh(_ text: String) { title = text }

        @objc private func arm() {
            armed = true
            title = "…"
            window?.makeFirstResponder(self)
        }

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard armed else { super.keyDown(with: event); return }
            if event.keyCode == 53 {   // Esc cancels
                armed = false
                onCapture.map { _ in }
                return
            }
            if let c = KeyChord.from(event: event) {
                armed = false
                title = c.display
                onCapture?(c)
            }
        }

        override func flagsChanged(with event: NSEvent) { /* wait for the key */ }
    }
}
