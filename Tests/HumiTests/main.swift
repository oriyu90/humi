// Dependency-free self-test runner for HumiKit.
// XCTest / swift-testing aren't available under Command Line Tools, so this is a
// plain executable: `swift run HumiTests`. Exit code 0 = all passed.

import Foundation
@testable import HumiKit

var failures = 0
var count = 0

func check(_ condition: Bool, _ label: String, file: StaticString = #file, line: UInt = #line) {
    count += 1
    if condition {
        print("  ✓ \(label)")
    } else {
        failures += 1
        print("  ✗ \(label)  (\(file):\(line))")
    }
}

func suite(_ name: String, _ body: () -> Void) {
    print("\n\(name)")
    body()
}

// MARK: Persistence isolation — the suite must never touch the real support dir

suite("Persistence isolation") {
    let override = ProcessInfo.processInfo.environment["HUMI_SUPPORT_DIR"] ?? ""
    check(!override.isEmpty, "HUMI_SUPPORT_DIR is set (run via Scripts/test.sh)")
    check(Persistence.baseURL.path == override,
          "Persistence.baseURL follows HUMI_SUPPORT_DIR, not ~/Library/Application Support")
    check(!Persistence.baseURL.path.contains("/Library/Application Support/Humi"),
          "not writing to the real app-support dir")
}

// MARK: Localization — every language file must carry the same keys

MainActor.assumeIsolated {
    suite("L10n") {
        let langs = ["ja", "en", "zh-Hans", "pt-BR", "es"]
        var tables: [String: [String: String]] = [:]
        for lang in langs {
            if let t = Localization.loadStrings(lang) { tables[lang] = t }
            else { check(false, "\(lang): Localizable.strings loads") }
        }
        check(tables.count == langs.count, "all 5 language files present")

        if let base = tables["ja"] {
            let baseKeys = Set(base.keys)
            check(baseKeys.count > 30, "ja has a non-trivial key set (\(baseKeys.count))")
            for (lang, table) in tables {
                let keys = Set(table.keys)
                let missing = baseKeys.subtracting(keys)
                let extra = keys.subtracting(baseKeys)
                check(missing.isEmpty, "\(lang): no missing keys" + (missing.isEmpty ? "" : " — \(missing.sorted())"))
                check(extra.isEmpty, "\(lang): no orphan keys" + (extra.isEmpty ? "" : " — \(extra.sorted())"))
                check(table.values.allSatisfy { !$0.isEmpty }, "\(lang): no empty values")
                // %d / %@ placeholder counts must match the base so String(format:) is safe.
                for key in baseKeys.intersection(keys) {
                    let bc = base[key]!.components(separatedBy: "%").count
                    let tc = table[key]!.components(separatedBy: "%").count
                    check(bc == tc, "\(lang): \(key) placeholder count matches base")
                }
            }
        }
    }
}

// MARK: ShellResolver

suite("ShellResolver") {
    // `.login` order is getpwuid → $SHELL → /bin/zsh. The passwd entry wins when it
    // points at a real shell (that's the machine's actual login shell), so this only
    // asserts the invariant: an executable shell path, login-style argv0, no extra args.
    let login = ShellResolver.resolve(config: .init(kind: .login, customPath: "", customArgs: "", useLoginArgs: true),
                                      environment: ["SHELL": "/bin/zsh"])
    check(FileManager.default.isExecutableFile(atPath: login.executable), "login: resolves an executable shell")
    check(login.execName.hasPrefix("-"), "login: argv0 has leading dash")
    check(login.execName.hasSuffix((login.executable as NSString).lastPathComponent), "login: argv0 is -<shell basename>")
    check(login.args.isEmpty, "login: no extra args")

    // With no passwd shell and no $SHELL, it must fall back to /bin/zsh.
    let loginFallback = ShellResolver.loginShellPath(environment: [:])
    check(FileManager.default.isExecutableFile(atPath: loginFallback), "login: fallback path is executable")

    let bash = ShellResolver.resolve(config: .init(kind: .bash, customPath: "", customArgs: "", useLoginArgs: true),
                                     environment: [:])
    check(bash.executable.hasSuffix("bash"), "bash: resolves a bash path")
    check(bash.args == ["-l"], "bash: adds -l when login args on")

    let noLogin = ShellResolver.resolve(config: .init(kind: .zsh, customPath: "", customArgs: "", useLoginArgs: false),
                                        environment: [:])
    check(noLogin.args.isEmpty, "zsh: no -l when login args off")

    let custom = ShellResolver.resolve(config: .init(kind: .custom, customPath: "/opt/bin/xonsh",
                                                     customArgs: "--login  -i", useLoginArgs: true),
                                       environment: [:])
    check(custom.executable == "/opt/bin/xonsh", "custom: uses custom path")
    check(custom.args == ["--login", "-i"], "custom: splits args, drops empties")
    check(custom.execName == "xonsh", "custom: argv0 is basename")

    let env = ShellResolver.childEnvironment(base: [:])
    check(env.contains("TERM=xterm-256color"), "env: TERM set")
    check(env.contains(where: { $0.hasPrefix("LANG=") }), "env: LANG present")
    check(env.contains("TERM_PROGRAM=Humi"), "env: TERM_PROGRAM=Humi")
}

// MARK: ShellResolver.startDirectory (deleted-folder fallback)

suite("ShellResolver.startDirectory") {
    let home = "/Users/humitest-home"
    check(ShellResolver.startDirectory(requested: nil, home: home) == home,
          "nil → home")
    check(ShellResolver.startDirectory(requested: "", home: home) == home,
          "empty → home")
    check(ShellResolver.startDirectory(requested: "/definitely/not/here-\(UUID())", home: home) == home,
          "missing folder → home")
    check(ShellResolver.startDirectory(requested: "/tmp", home: home) == "/tmp",
          "existing dir → itself")
    let file = NSTemporaryDirectory() + "humitest-\(UUID()).txt"
    FileManager.default.createFile(atPath: file, contents: Data("x".utf8))
    defer { try? FileManager.default.removeItem(atPath: file) }
    check(ShellResolver.startDirectory(requested: file, home: home) == home,
          "path is a file, not a dir → home")
}

// MARK: Persistence

suite("Persistence") {
    let name = "selftest-\(UUID().uuidString).json"
    defer { try? FileManager.default.removeItem(at: Persistence.url(name)) }

    let original = [
        Session(workingDirectory: "/tmp/a", accentIndex: 0),
        Session(workingDirectory: nil, accentIndex: 1),
    ]
    Persistence.encode(original, to: name, sync: true)
    let restored = Persistence.decode([Session].self, from: name)
    check(restored?.count == 2, "round-trip: count preserved")
    check(restored?[0].workingDirectory == "/tmp/a", "round-trip: cwd preserved")
    check(restored?[1].workingDirectory == nil, "round-trip: nil cwd preserved")
    check(restored?[0].id == original[0].id, "round-trip: id stable")
    check(Persistence.decode([Session].self, from: "missing-\(UUID().uuidString).json") == nil,
          "missing file → nil")
}

// MARK: Theme

suite("Theme") {
    check(Theme.builtIns.count == 6, "6 built-in themes")
    for th in Theme.builtIns {
        check(th.ansi.count == 16, "\(th.name): 16 ANSI colours")
        check(th.isBuiltIn, "\(th.name): marked built-in")
    }
    // HexColor round-trips through its integer encoding.
    let hc = HexColor(0x4FB7E8)
    let data = try! JSONEncoder().encode(hc)
    check((try? JSONDecoder().decode(HexColor.self, from: data)) == hc, "HexColor codec round-trip")
    check(HexColor(hexString: "#4fb7e8") == hc, "HexColor parses #rrggbb")
    check(hc.hexString == "#4fb7e8", "HexColor formats #rrggbb")
    check(hc.r == 0x4F && hc.g == 0xB7 && hc.b == 0xE8, "HexColor channel split")

    // Theme round-trips (and a partial dict still decodes).
    let full = try! JSONEncoder().encode(Theme.humDark)
    let back = try? JSONDecoder().decode(Theme.self, from: full)
    check(back?.name == "Hum Dark", "Theme codec round-trip")
    check(back?.ansi.count == 16, "Theme codec keeps 16 ANSI")
    let partial = "{\"name\":\"P\",\"background\":16777215,\"foreground\":0}".data(using: .utf8)!
    let p = try? JSONDecoder().decode(Theme.self, from: partial)
    check(p != nil, "partial .humitheme still decodes")
    check(p?.ansi.count == 16, "partial theme gets default ANSI")

    // CursorSpec → SwiftTerm mapping is total.
    for shape in CursorSpec.Shape.allCases {
        for blink in [true, false] {
            let spec = CursorSpec(shape: shape, blink: blink)
            _ = spec.swiftTerm
            check(true, "CursorSpec(\(shape), blink:\(blink)) maps")
        }
    }
}

MainActor.assumeIsolated {
    suite("ThemeStore.resolve") {
        let s = ThemeStore.shared
        s.setActive("Hum Light")
        check(s.mode == .light, "picking a light family snaps mode to light")
        check(s.resolvedTheme.name == "Hum Light", "light family resolves to itself")
        s.setMode(.dark)
        check(s.resolvedTheme.appAppearance == .dark, "dark mode → a dark theme")
        check(s.resolvedTheme.name == "Hum Dark", "dark mode → paired sibling of Hum Light")
        s.setActive("Nord")
        check(s.mode == .dark, "picking a dark family snaps mode to dark")
        check(s.resolvedTheme.name == "Nord", "dark family resolves to itself")
        s.setActive("Hum Light")
        s.setMode(.dark)
        check(s.resolvedTheme.name == "Hum Dark", "Hum Light + forced dark → Hum Dark sibling")
        s.setActive("Hum Light")
        s.setMode(.system)
    }
}

// MARK: PathActioner

suite("PathActioner") {
    check(PathActioner.classify("https://example.com", relativeTo: nil) == .url, "https → url")
    check(PathActioner.classify("mailto:a@b.c", relativeTo: nil) == .url, "mailto → url")
    check(PathActioner.classify("just some text", relativeTo: nil) == .unknown, "plain text → unknown")
    // A real file for the path / path:line cases.
    let tmp = NSTemporaryDirectory() + "humi-pa-\(UUID().uuidString).txt"
    FileManager.default.createFile(atPath: tmp, contents: Data("x".utf8))
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    if case .path = PathActioner.classify(tmp, relativeTo: nil) {} else { check(false, "existing file → .path") }
    if case let .fileLine(_, line) = PathActioner.classify("\(tmp):42", relativeTo: nil) {
        check(line == 42, "path:line → .fileLine(42)")
    } else { check(false, "path:line → .fileLine") }
    check(PathActioner.classify("/no/such/file/here", relativeTo: nil) == .unknown, "missing path → unknown")
    // relative path resolved against cwd
    let dir = (tmp as NSString).deletingLastPathComponent
    let name = (tmp as NSString).lastPathComponent
    if case .path = PathActioner.classify(name, relativeTo: dir) {} else { check(false, "relative path resolves via cwd") }
}

// MARK: SessionLogger

suite("SessionLogger") {
    let inv = ShellInvocation(executable: "/bin/zsh", args: ["-l"], execName: "-zsh")
    let wrapped = SessionLogger.wrap(inv, logPath: "/tmp/x.log")
    check(wrapped.executable == "/usr/bin/script", "wrap → script")
    check(wrapped.args == ["-q", "-a", "/tmp/x.log", "/bin/zsh", "-l"], "wrap → script args")
    let p = SessionLogger.logPath(sessionTitle: "my proj", dir: NSTemporaryDirectory() + "humilogs-\(UUID())",
                                  pattern: "{name}-{date}.log")
    check(p?.contains("my_proj-") == true, "log filename substitutes {name}")
    check(p?.hasSuffix(".log") == true, "log filename ends .log")
}

// MARK: Session codec back-compat

MainActor.assumeIsolated {
    suite("Session codec") {
        // A pre-1.1 record has no customTitle/onExit/logging keys.
        let old = "{\"id\":\"\(UUID().uuidString)\",\"title\":\"t\",\"accentIndex\":0,\"createdAt\":0}"
        let s = try? JSONDecoder().decode(Session.self, from: Data(old.utf8))
        check(s != nil, "pre-1.1 session still decodes")
        check(s?.onExit == .keep, "missing onExit → .keep")
        check(s?.logging == false, "missing logging → false")
        check(s?.customTitle == nil, "missing customTitle → nil")
        // v1.1 round-trip
        var full = Session(workingDirectory: "/tmp", accentIndex: 2, onExit: .restart, logging: true)
        full.customTitle = "Build"
        full.accentOverride = 3
        let data = try! JSONEncoder().encode(full)
        let back = try? JSONDecoder().decode(Session.self, from: data)
        check(back?.customTitle == "Build", "customTitle round-trips")
        check(back?.onExit == .restart, "onExit round-trips")
        check(back?.effectiveAccent == 3, "accentOverride wins in effectiveAccent")
    }

    suite("SessionStore.move") {
        try? FileManager.default.removeItem(at: Persistence.url(SessionStore.fileName))
        let store = SessionStore()
        let a = store.add(workingDirectory: "/a")
        let b = store.add(workingDirectory: "/b")
        let c = store.add(workingDirectory: "/c")
        store.move(id: c.id, before: a.id)
        check(store.sessions.map(\.workingDirectory) == ["/c", "/a", "/b"], "move c before a")
        store.move(from: 0, to: 3)
        check(store.sessions.map(\.workingDirectory) == ["/a", "/b", "/c"], "move first to end")
        _ = b
    }
}

// MARK: Profile

suite("Profile codec") {
    var p = Profile(name: "Dev", icon: "hammer", colorIndex: 2, env: ["FOO": "bar"],
                    startupCommand: "npm run dev", cwd: "/tmp", themeName: "Nord",
                    scrollback: 5000, loggingDefault: true)
    p.shellKind = ShellKind.bash.rawValue
    let data = try! JSONEncoder().encode(p)
    let back = try? JSONDecoder().decode(Profile.self, from: data)
    check(back?.name == "Dev", "profile round-trips name")
    check(back?.env["FOO"] == "bar", "profile round-trips env")
    check(back?.startupCommand == "npm run dev", "profile round-trips startup")
    check(back?.themeName == "Nord", "profile round-trips theme")
    check(back?.shellConfig.kind == .bash, "profile shellConfig maps kind")
    // Partial JSON still decodes.
    let partial = "{\"name\":\"Min\"}".data(using: .utf8)!
    let m = try? JSONDecoder().decode(Profile.self, from: partial)
    check(m?.name == "Min" && m?.shellConfig.kind == .login, "partial profile → login default")

    // childEnvironment merges profile env over the base.
    let env = ShellResolver.childEnvironment(base: ["PATH": "/bin"], extra: ["FOO": "bar", "PATH": "/x"])
    check(env.contains("FOO=bar"), "childEnvironment adds profile var")
    check(env.contains("PATH=/x"), "childEnvironment: profile overrides base")
    check(env.contains { $0.hasPrefix("TERM=") }, "childEnvironment still sets TERM")
}

// MARK: Keymap

MainActor.assumeIsolated {
    suite("Keymap") {
        let cmd = KeymapStore.cmd
        let n = KeyChord(key: "n", modifiers: cmd)
        // Codable round-trip
        let data = try! JSONEncoder().encode(["newSession": n])
        let back = try? JSONDecoder().decode([String: KeyChord].self, from: data)
        check(back?["newSession"] == n, "KeyChord codec round-trip")
        check(n.display == "⌘N", "KeyChord display")
        check(KeyChord(key: "right", modifiers: KeymapStore.cmdOpt).display == "⌥⌘→", "arrow chord display")
        check(n.keyEquivalent != nil, "letter chord → KeyEquivalent")
        check(KeyChord(key: "left", modifiers: cmd).keyEquivalent != nil, "arrow chord → KeyEquivalent")

        let store = KeymapStore.shared
        store.resetAll()
        check(store.chord(for: .newSession) == n, "default newSession = ⌘N")
        check(store.map.isEmpty, "resetAll clears overrides")
        // every action has a default
        for a in HumiAction.allCases {
            check(KeymapStore.defaults[a] != nil, "\(a.rawValue) has a default chord")
            check(a.notification.rawValue.hasPrefix("humi."), "\(a.rawValue) maps to a humi.* notification")
        }
        // conflict detection
        store.set(.find, n)   // collide with newSession
        check(store.conflicts(n, excluding: .find).contains(.newSession), "conflict detected")
        store.resetAll()
    }
}

// MARK: GridLayout

suite("GridLayout") {
    check(GridLayout.columnCount(width: 400, minTileWidth: 380, spacing: 16) == 1, "narrow → 1 column")
    check(GridLayout.columnCount(width: 820, minTileWidth: 380, spacing: 16) == 2, "wide → 2 columns")
    check(GridLayout.columnCount(width: 0, minTileWidth: 380, spacing: 16) == 1, "zero width → 1 column")
    check(GridLayout.chunk([1, 2, 3, 4, 5], into: 2) == [[1, 2], [3, 4], [5]], "chunk: uneven split")
    check(GridLayout.chunk([Int](), into: 3) == [], "chunk: empty → empty")
    check(GridLayout.chunk([1, 2], into: 0) == [[1, 2]], "chunk: size 0 → single row")
}

// MARK: PaneTree — pure recursive layout model (v1.2 phase A-1)

suite("PaneTree") {
    let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()

    func approx(_ x: CGFloat, _ y: CGFloat, _ eps: CGFloat = 0.001) -> Bool { abs(x - y) <= eps }

    // Queries
    let flat = PaneNode.split(axis: .horizontal, children: [.leaf(a), .leaf(b), .leaf(c)],
                              ratios: [1.0 / 3, 1.0 / 3, 1.0 / 3])
    check(PaneNode.leaf(a).leaves() == [a], "leaves: bare leaf")
    check(flat.leaves() == [a, b, c], "leaves: split order preserved")
    check(flat.contains(b) && !flat.contains(d), "contains: hit and miss")
    check(PaneNode.leaf(a).depth == 0, "depth: leaf is 0")
    check(flat.depth == 1, "depth: one split is 1")

    // insert beside a bare leaf → two-child split, order follows `after`
    let iAfter = PaneNode.leaf(a).insert(besideLeaf: a, axis: .horizontal, newLeaf: b, after: true)
    check(iAfter.leaves() == [a, b], "insert: after puts new leaf second")
    let iBefore = PaneNode.leaf(a).insert(besideLeaf: a, axis: .vertical, newLeaf: b, after: false)
    check(iBefore.leaves() == [b, a], "insert: before puts new leaf first")
    if case .split(let ax, _, let r) = iBefore {
        check(ax == .vertical, "insert: axis honoured")
        check(approx(r.reduce(0, +), 1), "insert: fresh split ratios sum to 1")
    } else { check(false, "insert: bare leaf becomes a split") }

    // insert into a split that already runs along the same axis → joins it, siblings stay put
    let joined = flat.insert(besideLeaf: b, axis: .horizontal, newLeaf: d, after: true)
    check(joined.leaves() == [a, d, b, c] || joined.leaves() == [a, b, d, c], "insert: joins same-axis split")
    check(joined.leaves() == [a, b, d, c], "insert: new leaf lands right after target")
    if case .split(_, let ch, let r) = joined {
        check(ch.count == 4 && r.count == 4, "insert: no extra nesting for same axis")
        check(approx(r[0], 1.0 / 3), "insert: untouched sibling keeps its ratio")
        check(approx(r[1] + r[2], 1.0 / 3), "insert: target's slot is halved in place")
    } else { check(false, "insert: still a split") }

    // insert with a different axis → nested split replaces the target leaf
    let nested = flat.insert(besideLeaf: b, axis: .vertical, newLeaf: d, after: true)
    check(nested.leaves() == [a, b, d, c], "insert: cross-axis keeps visual order")
    check(nested.depth == 2, "insert: cross-axis adds a nesting level")

    // insert guards
    check(flat.insert(besideLeaf: e, axis: .horizontal, newLeaf: d, after: true) == flat,
          "insert: unknown target is a no-op")
    check(flat.insert(besideLeaf: a, axis: .horizontal, newLeaf: b, after: true) == flat,
          "insert: duplicate new leaf is a no-op")

    // remove
    let removed = flat.remove(leaf: b)
    check(removed?.leaves() == [a, c], "remove: drops the target leaf")
    let downToOne = PaneNode.split(axis: .horizontal, children: [.leaf(a), .leaf(b)], ratios: [0.5, 0.5])
        .remove(leaf: b)
    check(downToOne == .leaf(a), "remove: single-child split collapses to the leaf")
    check(PaneNode.leaf(a).remove(leaf: a) == nil, "remove: last leaf yields nil")
    check(flat.remove(leaf: e) == flat, "remove: unknown leaf is a no-op")
    let deepRemoved = nested.remove(leaf: d)
    check(deepRemoved?.leaves() == [a, b, c], "remove: collapses nested split when it empties out")
    check(deepRemoved?.depth == 1, "remove: nesting level folds away")

    // swap
    let swapped = flat.swap(a, c)
    check(swapped.leaves() == [c, b, a], "swap: exchanges two leaves")
    check(flat.swap(a, e) == flat, "swap: unknown id is a no-op")
    check(flat.swap(a, a) == flat, "swap: same id is a no-op")

    // setRatio — clamps and preserves the divider pair's combined share
    let tuned = flat.setRatio(atSplitContaining: a, dividerIndex: 0, to: 0.7)
    if case .split(_, _, let r) = tuned {
        check(approx(r[0] + r[1], 2.0 / 3), "setRatio: pair sum preserved")
        check(approx(r[0] / (r[0] + r[1]), 0.7), "setRatio: earlier child gets the fraction")
        check(approx(r[2], 1.0 / 3), "setRatio: other siblings untouched")
    } else { check(false, "setRatio: still a split") }
    let clamped = flat.setRatio(atSplitContaining: a, dividerIndex: 0, to: 5)
    if case .split(_, _, let r) = clamped {
        check(r[0] / (r[0] + r[1]) <= 0.95 + 0.001, "setRatio: over-large fraction clamps to 0.95")
    } else { check(false, "setRatio: clamp still a split") }

    // equalized
    let uneven = PaneNode.split(axis: .horizontal, children: [.leaf(a), .leaf(b), .leaf(c)],
                                ratios: [0.7, 0.2, 0.1])
    if case .split(_, _, let r) = uneven.equalized() {
        check(r.allSatisfy { approx($0, 1.0 / 3) }, "equalized: every child gets an equal share")
    } else { check(false, "equalized: still a split") }

    // normalized — repairs drifted ratios and arity
    if case .split(_, _, let r) = (PaneNode.split(axis: .horizontal,
        children: [.leaf(a), .leaf(b)], ratios: [4, 4]).normalized()) {
        check(approx(r[0], 0.5) && approx(r[1], 0.5), "normalized: ratios rescaled to sum 1")
    } else { check(false, "normalized: still a split") }
    if case .split(_, _, let r) = (PaneNode.split(axis: .horizontal,
        children: [.leaf(a), .leaf(b), .leaf(c)], ratios: [0.5, 0.5]).normalized()) {
        check(r.count == 3, "normalized: ratio count repaired to match children")
    } else { check(false, "normalized: count repair still a split") }
    check(PaneNode.split(axis: .horizontal, children: [.leaf(a)], ratios: [1]).normalized() == .leaf(a),
          "normalized: single-child split collapses")

    // frames — partition geometry
    let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
    check(PaneNode.leaf(a).frames(in: rect)[a] == rect, "frames: leaf fills the rect")
    let hFrames = flat.frames(in: rect)
    check(approx(hFrames[a]!.width, 100) && approx(hFrames[b]!.width, 100), "frames: even horizontal thirds")
    check(approx(hFrames[a]!.minX, 0) && approx(hFrames[b]!.minX, 100) && approx(hFrames[c]!.minX, 200),
          "frames: children tile left to right")
    check(hFrames.values.allSatisfy { approx($0.height, 200) }, "frames: cross axis spans full height")
    let widthsSum = [a, b, c].compactMap { hFrames[$0]?.width }.reduce(0, +)
    check(approx(widthsSum, 300), "frames: widths sum to the container")

    // frames — gap + min-length floor
    let gapped = flat.frames(in: rect, gap: 6)
    check(approx([a, b, c].compactMap { gapped[$0]?.width }.reduce(0, +), 300 - 12), "frames: gap removed from total")
    let squeeze = PaneNode.split(axis: .horizontal, children: [.leaf(a), .leaf(b)], ratios: [0.98, 0.02])
        .frames(in: CGRect(x: 0, y: 0, width: 300, height: 100))
    check(squeeze[b]!.width >= PaneNode.minLeafLength - 0.5 || approx(squeeze[b]!.width, 150),
          "frames: tiny slice floored at minLeafLength")

    // focusNeighbor — 2×2 grid: outer H [ left=V[a,c] , right=V[b,d] ]
    let grid = PaneNode.split(axis: .horizontal, children: [
        .split(axis: .vertical, children: [.leaf(a), .leaf(c)], ratios: [0.5, 0.5]),
        .split(axis: .vertical, children: [.leaf(b), .leaf(d)], ratios: [0.5, 0.5]),
    ], ratios: [0.5, 0.5])
    let box = CGRect(x: 0, y: 0, width: 100, height: 100)
    check(grid.focusNeighbor(of: a, direction: .right, in: box) == b, "focusNeighbor: right across the column")
    check(grid.focusNeighbor(of: a, direction: .down, in: box) == c, "focusNeighbor: down within the column")
    check(grid.focusNeighbor(of: d, direction: .left, in: box) == c, "focusNeighbor: left across the column")
    check(grid.focusNeighbor(of: d, direction: .up, in: box) == b, "focusNeighbor: up within the column")
    check(grid.focusNeighbor(of: a, direction: .left, in: box) == nil, "focusNeighbor: nothing to the left of an edge")
    check(grid.focusNeighbor(of: a, direction: .up, in: box) == nil, "focusNeighbor: nothing above an edge")
    check(grid.focusNeighbor(of: e, direction: .right, in: box) == nil, "focusNeighbor: unknown id → nil")

    // Codable — discriminated round trips + forgiving decode
    let enc = JSONEncoder()
    let dec = JSONDecoder()
    func roundTrip(_ node: PaneNode) -> PaneNode? { try? dec.decode(PaneNode.self, from: try! enc.encode(node)) }
    check(roundTrip(.leaf(a)) == .leaf(a), "codec: leaf round-trips")
    check(roundTrip(grid) == grid, "codec: nested tree round-trips exactly")
    let looseJSON = Data(#"{"type":"split","axis":"vertical","children":[{"type":"leaf","id":"\#(a.uuidString)"},{"type":"leaf","id":"\#(b.uuidString)"}]}"#.utf8)
    if let loose = try? dec.decode(PaneNode.self, from: looseJSON), case .split(_, _, let r) = loose {
        check(loose.leaves() == [a, b], "codec: split without ratios still decodes")
        check(approx(r[0], 0.5) && approx(r[1], 0.5), "codec: missing ratios default to equal shares")
    } else { check(false, "codec: ratio-less split decodes to a split") }
    let mismatchJSON = Data(#"{"type":"split","axis":"horizontal","ratios":[0.9],"children":[{"type":"leaf","id":"\#(a.uuidString)"},{"type":"leaf","id":"\#(b.uuidString)"}]}"#.utf8)
    if let fixed = try? dec.decode(PaneNode.self, from: mismatchJSON), case .split(_, _, let r) = fixed {
        check(r.count == 2 && approx(r.reduce(0, +), 1), "codec: mismatched ratio count normalized on decode")
    } else { check(false, "codec: mismatched ratios decode to a split") }
}

// MARK: SessionStore (main actor — top-level main.swift already runs on it)

MainActor.assumeIsolated {
    suite("SessionStore") {
        try? FileManager.default.removeItem(at: Persistence.url(SessionStore.fileName))
        let store = SessionStore()
        let a = store.add(workingDirectory: "/tmp")
        let b = store.add(workingDirectory: nil)
        check(store.sessions.count == 2, "add: two sessions")
        check(a.accentIndex != b.accentIndex, "add: accent index rotates")

        store.toggleMaximize(a.id)
        check(store.maximizedID == a.id, "maximize: toggles on")
        store.toggleMaximize(a.id)
        check(store.maximizedID == nil, "maximize: toggles off")

        store.markExited(a.id, code: 0)
        check(store.exitCodes[a.id] == 0, "exit: code recorded")

        store.close(a.id)
        check(store.sessions.map(\.id) == [b.id], "close: removes only target")
        check(store.exitCodes[a.id] == nil, "close: clears exit code")
    }
}

print("\n\(count - failures)/\(count) checks passed")
if failures > 0 {
    print("FAILED")
    exit(1)
}
print("OK")
