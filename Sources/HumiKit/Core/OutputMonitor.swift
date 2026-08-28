import Foundation

/// Turns a stream of raw pty output into completed, ANSI-stripped text lines for
/// substring / regex matching. The owner only feeds bytes in while something is
/// actually watching, so idle cost is zero.
struct OutputMonitor {
    private var pending = ""
    /// Cap the unterminated tail so a process that never emits a newline can't grow this
    /// without bound.
    private static let maxPendingLine = 8192

    /// Append `text`, then return every line that just completed (newline-terminated),
    /// ANSI-stripped and whitespace-trimmed. Blank lines are dropped.
    mutating func ingest(_ text: String) -> [String] {
        pending += text
        guard pending.contains("\n") || pending.contains("\r") else {
            if pending.count > Self.maxPendingLine {
                pending = String(pending.suffix(Self.maxPendingLine))
            }
            return []
        }
        let normalized = pending
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let parts = normalized.components(separatedBy: "\n")
        pending = parts.last ?? ""
        return parts.dropLast().compactMap { raw in
            let clean = OutputMonitor.stripANSI(raw).trimmingCharacters(in: .whitespaces)
            return clean.isEmpty ? nil : clean
        }
    }

    /// Strip CSI (`ESC [ … final`) and OSC (`ESC ] … BEL/ST`) sequences plus stray C0
    /// control bytes, leaving readable text.
    static func stripANSI(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "\u{1B}" {
                let n = s.index(after: i)
                guard n < s.endIndex else { break }
                if s[n] == "[" {
                    var j = s.index(after: n)
                    while j < s.endIndex, !("@" ... "~").contains(s[j]) { j = s.index(after: j) }
                    i = j < s.endIndex ? s.index(after: j) : j
                } else if s[n] == "]" {
                    var j = s.index(after: n)
                    while j < s.endIndex, s[j] != "\u{07}", s[j] != "\u{1B}" { j = s.index(after: j) }
                    i = j < s.endIndex ? s.index(after: j) : j
                } else {
                    i = s.index(after: n)
                }
                continue
            }
            if let a = c.asciiValue, a < 32, a != 9 {   // keep tab, drop other C0
                i = s.index(after: i)
                continue
            }
            out.append(c)
            i = s.index(after: i)
        }
        return out
    }
}
