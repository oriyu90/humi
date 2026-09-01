import SwiftUI
import AppKit

/// Lightweight Markdown preview: renders headings, lists, rules, code and inline styles
/// block-by-block with `AttributedString(markdown:)`. Good enough for scratch notes;
/// no external dependency.
struct MarkdownView: View {
    let text: String

    var body: some View {
        ScrollView { MarkdownBlocks(text: text) }
    }
}

/// The rendered blocks without a scroll container — so it can be dropped into a
/// `TrackingScroll` (which needs a plain, self-sizing subtree) as well as `MarkdownView`.
struct MarkdownBlocks: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Hum.Space.sm) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Hum.Space.md)
        .textSelection(.enabled)
    }

    private enum Block {
        case heading(level: Int, text: String)
        case bullet(String)
        case ordered(Int, String)
        case rule
        case code(String)
        case paragraph(String)

        @ViewBuilder var view: some View {
            switch self {
            case let .heading(level, text):
                Text(inline(text))
                    .font(Hum.Font.display(headingSize(level), weight: .bold))
                    .foregroundStyle(Hum.ink)
                    .padding(.top, level <= 2 ? Hum.Space.sm : 2)
            case let .bullet(text):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Hum.pearDeep).frame(width: 5, height: 5).offset(y: -2)
                    Text(inline(text)).font(Hum.Font.body(13)).foregroundStyle(Hum.ink)
                }
            case let .ordered(n, text):
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(n).").font(Hum.Font.mono(12)).foregroundStyle(Hum.ink2)
                    Text(inline(text)).font(Hum.Font.body(13)).foregroundStyle(Hum.ink)
                }
            case .rule:
                Rectangle().fill(Hum.hairline).frame(height: 1).padding(.vertical, 4)
            case let .code(body):
                CodeBlockView(code: body)
            case let .paragraph(text):
                Text(inline(text)).font(Hum.Font.body(13)).foregroundStyle(Hum.ink)
            }
        }

        private func headingSize(_ level: Int) -> CGFloat {
            switch level { case 1: return 22; case 2: return 18; case 3: return 15; default: return 13 }
        }

        private func inline(_ s: String) -> AttributedString {
            (try? AttributedString(markdown: s,
                                   options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                ?? AttributedString(s)
        }
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var inFence = false
        var fence: [String] = []

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inFence {
                    result.append(.code(fence.joined(separator: "\n")))
                    fence.removeAll()
                }
                inFence.toggle()
                continue
            }
            if inFence { fence.append(line); continue }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(.rule); continue
            }
            if let hashes = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                let level = trimmed.distance(from: trimmed.startIndex, to: trimmed.index(before: hashes.upperBound))
                result.append(.heading(level: level, text: String(trimmed[hashes.upperBound...])))
                continue
            }
            if let m = trimmed.range(of: #"^[-*+]\s+"#, options: .regularExpression) {
                result.append(.bullet(String(trimmed[m.upperBound...]))); continue
            }
            if let m = trimmed.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                let num = Int(trimmed[trimmed.startIndex..<trimmed.index(trimmed.startIndex, offsetBy: 1)]) ?? 1
                result.append(.ordered(num, String(trimmed[m.upperBound...]))); continue
            }
            result.append(.paragraph(trimmed))
        }
        if inFence, !fence.isEmpty { result.append(.code(fence.joined(separator: "\n"))) }
        return result
    }
}

/// A fenced code block with a Copy button. The button lives in its own strip above the
/// code — never over the selectable text, which on macOS installs a text-interaction
/// view that would otherwise swallow the button's clicks. Copy drops the block onto the
/// pasteboard verbatim (trailing newline trimmed) and flips to a "copied" check.
private struct CodeBlockView: View {
    let code: String

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Hum.Space.xs) {
            HStack {
                Spacer(minLength: 0)
                copyButton
            }
            Text(code)
                .font(Hum.Font.mono(12))
                .foregroundStyle(Hum.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Hum.Space.sm)
        .background(RoundedRectangle(cornerRadius: Hum.Radius.input).fill(Hum.paper3))
        .onHover { hovering = $0 }
    }

    private var copyButton: some View {
        Button(action: copy) {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? L("notes.code_copied") : L("notes.copy_code"))
            }
            .font(Hum.Font.body(11, weight: .medium))
            .foregroundStyle(copied ? Hum.mint : Hum.ink2)
            .padding(.horizontal, Hum.Space.sm)
            .padding(.vertical, 3)
            .background(Capsule().fill(Hum.paper))
            .overlay(Capsule().strokeBorder(Hum.hairline))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(copied || hovering ? 1 : 0.55)
        .animation(Hum.Motion.considerate(Hum.Motion.snap), value: hovering)
        .animation(Hum.Motion.considerate(Hum.Motion.snap), value: copied)
        .help(L("notes.copy_code"))
        .accessibilityLabel(L("notes.copy_code"))
    }

    private func copy() {
        let text = code.hasSuffix("\n") ? String(code.dropLast()) : code
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
    }
}
