import SwiftUI

/// Lightweight Markdown preview: renders headings, lists, rules, code and inline styles
/// block-by-block with `AttributedString(markdown:)`. Good enough for scratch notes;
/// no external dependency.
struct MarkdownView: View {
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Hum.Space.sm) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    block.view
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Hum.Space.md)
            .textSelection(.enabled)
        }
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
                Text(body)
                    .font(Hum.Font.mono(12))
                    .foregroundStyle(Hum.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Hum.Space.sm)
                    .background(RoundedRectangle(cornerRadius: Hum.Radius.input).fill(Hum.paper3))
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
