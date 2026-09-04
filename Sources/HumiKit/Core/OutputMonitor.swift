import Foundation

/// Turns a stream of raw pty output bytes into completed, ANSI-stripped text lines for
/// substring / regex matching. Byte-based so a multi-byte character split across two pty
/// chunks is never corrupted (only whole, newline-terminated lines are decoded). The
/// owner only feeds bytes in while something is actually watching, so idle cost is zero.
struct OutputMonitor {
    /// Undecoded tail (bytes seen since the last newline).
    private var pending: [UInt8] = []
    /// Internal diagnostic used by the self-test to keep the memory bound enforceable.
    var pendingByteCount: Int { pending.count }
    /// Lines dropped because a single ingest produced more than `maxLinesPerIngest`.
    /// Diagnostic only — never surfaced in the UI.
    private(set) var droppedLines = 0

    /// Cap the unterminated tail so a process that never emits a newline can't grow this.
    static let maxPendingBytes = 8192
    /// Longest line handed to a matcher; longer lines are truncated first.
    static let maxLineLength = 4096
    /// Most lines one `ingest` call will return; a huge paste is clipped so the caller
    /// never does thousands of regex evaluations synchronously on the main actor.
    static let maxLinesPerIngest = 200

    /// Append `bytes`, then return every line that just completed (newline-terminated),
    /// ANSI-stripped, whitespace-trimmed, and length-capped. Blank lines are dropped.
    mutating func ingest(_ bytes: ArraySlice<UInt8>) -> [String] {
        pending.append(contentsOf: bytes)
        guard pending.contains(0x0A) || pending.contains(0x0D) else {
            if pending.count > Self.maxPendingBytes {
                pending.removeFirst(pending.count - Self.maxPendingBytes)
            }
            return []
        }

        // Split on \n, treating \r\n and bare \r as line breaks too.
        var lines: [String] = []
        var start = pending.startIndex
        var i = pending.startIndex
        var lastBreakEnd = pending.startIndex
        while i < pending.endIndex {
            let b = pending[i]
            if b == 0x0A || b == 0x0D {
                let slice = pending[start ..< i]
                if lines.count < Self.maxLinesPerIngest {
                    if let line = Self.finish(slice) { lines.append(line) }
                } else {
                    droppedLines += 1
                }
                // step over a \r\n pair
                var next = pending.index(after: i)
                if b == 0x0D, next < pending.endIndex, pending[next] == 0x0A {
                    next = pending.index(after: next)
                }
                start = next
                lastBreakEnd = next
                i = next
            } else {
                i = pending.index(after: i)
            }
        }
        pending.removeSubrange(pending.startIndex ..< lastBreakEnd)
        // A chunk can contain an early newline followed by an enormous unterminated
        // tail. The no-newline fast path above does not cover that case, so enforce the
        // same bound after consuming completed lines as well.
        if pending.count > Self.maxPendingBytes {
            pending.removeFirst(pending.count - Self.maxPendingBytes)
        }
        return lines
    }

    private static func finish(_ slice: ArraySlice<UInt8>) -> String? {
        let capped = slice.count > maxLineLength ? slice.prefix(maxLineLength) : slice
        let text = String(decoding: capped, as: UTF8.self)
        let clean = stripANSI(text).trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? nil : clean
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
