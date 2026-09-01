// Dependency-free self-test runner for HumiKit.
// XCTest / swift-testing aren't available under Command Line Tools, so this is a
// plain executable: `swift run HumiTests`. Exit code 0 = all passed.

import AppKit
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

    // OSC 7 snippets (v1.2: fish now covered)
    check(ShellResolver.osc7Snippet(for: .zsh)?.contains("add-zsh-hook") == true, "osc7: zsh hook")
    check(ShellResolver.osc7Snippet(for: .bash)?.contains("PROMPT_COMMAND") == true, "osc7: bash hook")
    let fish = ShellResolver.osc7Snippet(for: .fish)
    check(fish?.contains("--on-event fish_prompt") == true, "osc7: fish uses a fish_prompt event function")
    check(fish?.contains("]7;file://") == true, "osc7: fish emits the OSC 7 sequence")
    check(ShellResolver.osc7Snippet(for: .custom) == nil, "osc7: custom shell has no snippet")
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

// MARK: Notes (tabs + ZIP archive)

MainActor.assumeIsolated {
    suite("Notes") {
        // NoteDoc decodes with defaults for missing fields.
        let sparse = #"{"title":"x"}"#.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(NoteDoc.self, from: sparse)
        check(decoded?.title == "x", "NoteDoc: decodes with only a title")
        check(decoded?.text == "", "NoteDoc: missing text → empty")

        // MarkdownBlocks parsing (drives the preview scroll-restore anchors).
        let md = "# H\n\npara one\n\n```\na\nb\nc\n```\n\npara two\n"
        check(MarkdownBlocks.blockCount(of: md) == 4, "MarkdownBlocks: heading+para+code+para = 4 blocks")
        check(MarkdownBlocks.blockCount(of: "") == 0, "MarkdownBlocks: empty text → 0 blocks")
        check(MarkdownBlocks.anchorID(2) == "md-block-2", "MarkdownBlocks: stable anchor id")

        // Disk round-trips through Persistence.
        let name = "selftest-notes-\(UUID().uuidString).json"
        defer { try? FileManager.default.removeItem(at: Persistence.url(name)) }
        let n1 = NoteDoc(title: "Claude Code")
        let n2 = NoteDoc(title: "Gemini", text: "# hi\n\nbody")
        Persistence.encode(NotesStore.Disk(notes: [n1, n2], activeID: n2.id), to: name, sync: true)
        let back = Persistence.decode(NotesStore.Disk.self, from: name)
        check(back?.notes.count == 2, "Disk round-trip: two notes")
        check(back?.notes[1].text.contains("body") == true, "Disk round-trip: body preserved")
        check(back?.activeID == n2.id, "Disk round-trip: activeID preserved")

        // merge() rule: same id+title replaces; id collision w/ new title → fresh id;
        // brand-new → appended keeping id.
        let store = NotesStore.shared
        let base = store.notes.count
        let a = NoteDoc(title: "Task A", text: "one")
        let b = NoteDoc(title: "Task B", text: "two")
        let r1 = store.merge(imported: [a, b])
        check(r1 == (added: 2, replaced: 0), "merge: two new notes appended")
        check(store.notes.count == base + 2, "merge: count grew by 2")

        var a2 = a; a2.text = "one-updated"
        let r2 = store.merge(imported: [a2])
        check(r2 == (added: 0, replaced: 1), "merge: same id+title replaces in place")
        check(store.note(a.id)?.text == "one-updated", "merge: imported body won")
        check(store.notes.count == base + 2, "merge: replace did not grow the list")

        let collide = NoteDoc(id: a.id, title: "Renamed elsewhere", text: "z")
        let r3 = store.merge(imported: [collide])
        check(r3.added == 1, "merge: id collision + different title → added as new")
        check(store.notes.filter { $0.id == a.id }.count == 1, "merge: no duplicate ids")

        // textBinding is per-note: writing through one never touches another
        // (the contract the tab editor relies on — a stale editor binding was
        // overwriting the wrong note before v1.4.1).
        let bindA = store.textBinding(for: a.id)
        let bindB = store.textBinding(for: b.id)
        bindA.wrappedValue = "A only"
        bindB.wrappedValue = "B only"
        bindA.wrappedValue = "A again"
        check(store.note(a.id)?.text == "A again", "textBinding: A writes reach A")
        check(store.note(b.id)?.text == "B only", "textBinding: B untouched by A writes")

        // ZIP archive: export → read round-trips notes, ids and order.
        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("humi-selftest-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: zipURL) }
        let src = [NoteDoc(title: "First / slashy", text: "alpha"),
                   NoteDoc(title: "第二", text: "beta\ngamma")]
        do {
            try NotesArchive.export(src, to: zipURL)
            let round = try NotesArchive.read(from: zipURL)
            check(round.count == 2, "archive: two notes back")
            check(round[0].id == src[0].id && round[1].id == src[1].id, "archive: ids + order preserved")
            check(round[1].text == "beta\ngamma", "archive: multi-line body preserved")
        } catch {
            check(false, "archive round-trip threw: \(error)")
        }
        check(NotesArchive.slug("Claude Code 用!!") == "Claude-Code", "archive: slug is filesystem-safe")
    }
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

        // v1.2 pane actions — default chords + no collision with the v1.1 set
        check(store.chord(for: .splitH) == KeyChord(key: "d", modifiers: KeymapStore.cmd), "splitH defaults to ⌘D")
        check(store.chord(for: .splitV) == KeyChord(key: "d", modifiers: KeymapStore.cmdShift), "splitV defaults to ⌘⇧D")
        check(store.chord(for: .splitV).display == "⇧⌘D", "splitV chord display")
        check(store.chord(for: .focusPaneDown).display == "⌃⌘↓", "focusPaneDown chord display")
        let paneActions: [HumiAction] = [.splitH, .splitV, .focusPaneLeft, .focusPaneRight,
                                         .focusPaneUp, .focusPaneDown, .equalizeSplits]
        for a in paneActions {
            check(store.conflicts(store.chord(for: a), excluding: a).isEmpty,
                  "\(a.rawValue) default chord doesn't collide")
        }
    }
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

    // dividers — renderer drag-handle specs (v1.2 phase A-3)
    let box2 = CGRect(x: 0, y: 0, width: 200, height: 100)
    check(PaneNode.leaf(a).dividers(in: box2).isEmpty, "dividers: a bare leaf has none")
    let flatDivs = flat.dividers(in: box2)
    check(flatDivs.count == 2, "dividers: an n-child split has n-1 handles")
    check(flatDivs.allSatisfy { $0.axis == .horizontal && $0.path == [] }, "dividers: rooted at the top split")
    check(flatDivs.map(\.index) == [0, 1], "dividers: indexed by the earlier child")
    check(flatDivs[0].rect.midX > 0 && flatDivs[0].rect.midX < flatDivs[1].rect.midX,
          "dividers: handles ordered left to right")
    check(flatDivs.map(\.id).count == Set(flatDivs.map(\.id)).count, "dividers: ids are unique")
    let nestedDivs = grid.dividers(in: box2)
    check(nestedDivs.contains { $0.path == [0] } && nestedDivs.contains { $0.path == [1] },
          "dividers: nested splits contribute their own handles with a path")

    // settingRatio(at:) — path-addressed divider drag
    let deepTuned = grid.settingRatio(at: [0], dividerIndex: 0, to: 0.75)
    let deepFrames = deepTuned.frames(in: CGRect(x: 0, y: 0, width: 400, height: 400))
    check(deepFrames[a]!.height > deepFrames[c]!.height, "settingRatio(at:): drag inside a nested split resizes it")
    check(approx(deepFrames[a]!.height + deepFrames[c]!.height, 400), "settingRatio(at:): the pair still fills the column")
    check(grid.settingRatio(at: [9], dividerIndex: 0, to: 0.5) == grid, "settingRatio(at:): bad path is a no-op")
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

    suite("SessionStore.layout") {
        try? FileManager.default.removeItem(at: Persistence.url(SessionStore.fileName))
        let store = SessionStore()
        check(store.layout == nil, "layout: nil with no sessions")

        let a = store.add(workingDirectory: "/a")
        check(store.layout == .leaf(a.id), "layout: first add is a bare leaf")
        let b = store.add(workingDirectory: "/b")
        let c = store.add(workingDirectory: "/c")
        check(store.layout?.leaves() == [a.id, b.id, c.id], "layout: adds append in order")
        check(store.layout?.depth == 1, "layout: plain adds stay a single flat row")

        // ⌘D-style split: new pane nests beside the target on the requested axis
        let d = store.split(besideLeaf: b.id, axis: .vertical, workingDirectory: "/d")
        check(store.sessions.count == 4, "split: registers the new session")
        check(store.layout?.leaves() == [a.id, b.id, d.id, c.id], "split: new pane sits next to its target")
        check(store.layout?.depth == 2, "split: a cross-axis split adds nesting")

        store.swapPanes(a.id, c.id)
        check(store.layout?.leaves() == [c.id, b.id, d.id, a.id], "swapPanes: exchanges two panes")
        store.swapPanes(a.id, c.id) // put them back

        check(store.paneNeighbor(of: a.id, .left) == nil, "paneNeighbor: nothing left of the first column")
        check(store.paneNeighbor(of: a.id, .right) == b.id || store.paneNeighbor(of: a.id, .right) == d.id,
              "paneNeighbor: a's right neighbour is the split column")

        store.setPaneRatio(besideLeaf: b.id, dividerIndex: 0, to: 0.8)
        check(store.layout != nil, "setPaneRatio: layout survives a divider drag")

        store.equalizeSplits()
        if case .split(_, _, let r)? = store.layout {
            check(r.allSatisfy { abs($0 - r[0]) < 0.001 }, "equalizeSplits: top-level ratios evened out")
        } else { check(false, "equalizeSplits: still a split") }

        store.close(d.id)
        check(store.layout?.leaves() == [a.id, b.id, c.id], "close: leaf leaves the tree")
        check(store.layout?.depth == 1, "close: emptied nested split folds away")
        store.close(a.id); store.close(b.id); store.close(c.id)
        check(store.layout == nil, "close: last pane clears the layout")

        _ = store.add(workingDirectory: "/x")
        store.closeAll()
        check(store.layout == nil && store.sessions.isEmpty, "closeAll: wipes layout and registry")
    }

    suite("SessionStore migration") {
        let url = Persistence.url(SessionStore.fileName)

        // Pre-1.2 file: a bare top-level [Session] array, no layout key.
        try? FileManager.default.removeItem(at: url)
        let id1 = UUID(), id2 = UUID()
        let legacy = """
        [{"id":"\(id1.uuidString)","title":"one","accentIndex":0,"createdAt":0},
         {"id":"\(id2.uuidString)","title":"two","accentIndex":1,"createdAt":0}]
        """
        try! Data(legacy.utf8).write(to: url)
        let migrated = SessionStore()
        check(migrated.sessions.map(\.id) == [id1, id2], "migration: legacy array still loads")
        check(migrated.layout?.leaves() == [id1, id2], "migration: synthesizes a linear layout")
        check(migrated.layout?.depth == 1, "migration: synthesized layout is one flat row")

        // v1.2 file: {sessions, layout} round-trips exactly.
        try? FileManager.default.removeItem(at: url)
        let src = SessionStore()
        let a = src.add(workingDirectory: "/a")
        let b = src.add(workingDirectory: "/b")
        src.split(besideLeaf: a.id, axis: .vertical, workingDirectory: "/c")
        let savedLayout = src.layout
        src.persistNow()
        let reloaded = SessionStore()
        check(reloaded.layout == savedLayout, "migration: {sessions,layout} round-trips")
        check(reloaded.sessions.count == 3, "migration: leaf registry round-trips")
        _ = b

        // Reconcile: a layout that references a vanished leaf, and a session with no leaf.
        try? FileManager.default.removeItem(at: url)
        let ghost = UUID(), orphan = UUID()
        let skewed = """
        {"sessions":[{"id":"\(orphan.uuidString)","title":"orphan","accentIndex":0,"createdAt":0}],
         "layout":{"type":"split","axis":"horizontal","ratios":[0.5,0.5],
           "children":[{"type":"leaf","id":"\(orphan.uuidString)"},{"type":"leaf","id":"\(ghost.uuidString)"}]}}
        """
        try! Data(skewed.utf8).write(to: url)
        let fixed = SessionStore()
        check(fixed.layout?.leaves() == [orphan], "reconcile: unknown leaf pruned, orphan session kept")
    }

    suite("Arrangement") {
        try? FileManager.default.removeItem(at: Persistence.url(SessionStore.fileName))
        try? FileManager.default.removeItem(at: Persistence.url(ArrangementStore.fileName))
        let store = SessionStore()
        let a = store.add(workingDirectory: "/a")
        _ = store.add(workingDirectory: "/b")
        store.split(besideLeaf: a.id, axis: .vertical, workingDirectory: "/c")
        let arr = ArrangementStore.shared

        let frame = CGRect(x: 10, y: 20, width: 800, height: 600)
        guard let snap = arr.snapshot(name: "Work", layout: store.layout,
                                      sessions: store.sessions, windowFrame: frame) else {
            check(false, "snapshot: produced an arrangement"); return
        }
        check(snap.leaves.count == 3, "snapshot: one LeafSpec per pane")
        check(snap.layout.leaves() == store.layout?.leaves(), "snapshot: layout captured verbatim")
        check(snap.windowFrame == frame, "snapshot: window frame captured")
        check(arr.snapshot(name: "x", layout: nil, sessions: [], windowFrame: .zero) == nil,
              "snapshot: nil layout → nil")

        // materialize → brand-new session ids, same shape
        let (fresh, layout) = arr.materialize(snap)
        check(fresh.count == 3, "materialize: rebuilds every session")
        check(Set(fresh.map(\.id)).isDisjoint(with: Set(store.sessions.map(\.id))),
              "materialize: fresh UUIDs, no collision with live sessions")
        check(layout.leaves().count == 3 && Set(layout.leaves()) == Set(fresh.map(\.id)),
              "materialize: layout points at the new sessions")
        check(fresh.first?.workingDirectory == "/a", "materialize: leaf metadata carried over")

        // Codable round-trip
        let data = try! JSONEncoder().encode(snap)
        let back = try? JSONDecoder().decode(Arrangement.self, from: data)
        check(back == snap, "codec: Arrangement round-trips")

        // store CRUD + same-name overwrite
        arr.add(snap)
        check(arr.arrangements.contains { $0.id == snap.id }, "store: add")
        var snap2 = snap; snap2.id = UUID()
        arr.add(snap2)   // same name "Work"
        check(arr.arrangements.filter { $0.name == "Work" }.count == 1, "store: same name overwrites")
        arr.rename(id: arr.arrangements[0].id, to: "Home")
        check(arr.arrangements.contains { $0.name == "Home" }, "store: rename")
        arr.delete(id: arr.arrangements[0].id)
        check(arr.arrangements.isEmpty, "store: delete")

        store.load(sessions: fresh, layout: layout)
        check(store.sessions.count == 3 && store.layout?.leaves().count == 3, "SessionStore.load: swaps everything in")
    }

    suite("HotKeyCenter + global hotkey pref") {
        // key-token → Carbon virtual keycode
        check(HotKeyCenter.carbonKeyCode(for: "t") != nil, "carbonKeyCode: letters map")
        check(HotKeyCenter.carbonKeyCode(for: "5") != nil, "carbonKeyCode: digits map")
        check(HotKeyCenter.carbonKeyCode(for: "left") != nil, "carbonKeyCode: arrows map")
        check(HotKeyCenter.carbonKeyCode(for: "space") != nil, "carbonKeyCode: space maps")
        check(HotKeyCenter.carbonKeyCode(for: "😀") == nil, "carbonKeyCode: unmappable → nil")

        // modifier flags → Carbon mask (non-zero, and grows with more modifiers)
        let one = HotKeyCenter.carbonModifiers(.command)
        let many = HotKeyCenter.carbonModifiers([.command, .option, .control])
        check(one != 0, "carbonModifiers: single modifier is non-zero")
        check(many != one && many != 0, "carbonModifiers: combined mask differs")
        check(HotKeyCenter.carbonModifiers([]) == 0, "carbonModifiers: no modifiers → 0")

        // AppSettings chord round-trips through its JSON-string backing
        let s = AppSettings.shared
        let saved = s.globalHotkeyEnabled
        let savedChord = s.globalHotkeyChord
        s.globalHotkeyChord = KeyChord(key: "j", modifiers: KeymapStore.cmdOpt)
        check(s.globalHotkeyChord == KeyChord(key: "j", modifiers: KeymapStore.cmdOpt),
              "globalHotkeyChord: persists via UserDefaults JSON")
        s.globalHotkeyChord = savedChord
        s.globalHotkeyEnabled = saved
    }
}

// MARK: OutputMonitor + Triggers (v1.2 phase D/E)

suite("OutputMonitor") {
    func bytes(_ s: String) -> ArraySlice<UInt8> { Array(s.utf8)[...] }

    check(OutputMonitor.stripANSI("\u{1B}[31mred\u{1B}[0m") == "red", "stripANSI: CSI colour codes removed")
    check(OutputMonitor.stripANSI("a\u{1B}]0;title\u{07}b") == "ab", "stripANSI: OSC sequence removed")
    check(OutputMonitor.stripANSI("plain text") == "plain text", "stripANSI: plain text untouched")

    var m = OutputMonitor()
    check(m.ingest(bytes("no newline yet")) == [], "ingest: buffers until a newline")
    check(m.ingest(bytes(" still\nfirst done\n")) == ["no newline yet still", "first done"],
          "ingest: joins the buffered tail and splits completed lines")
    check(m.ingest(bytes("carriage\r\nreturn\rlf\n")) == ["carriage", "return", "lf"],
          "ingest: CRLF and bare CR both split")
    check(m.ingest(bytes("\u{1B}[32mBUILD OK\u{1B}[0m\n")) == ["BUILD OK"], "ingest: strips ANSI from completed lines")

    // v1.3 S3: a multi-byte character split across two ingests is not corrupted
    var b = OutputMonitor()
    let ao: [UInt8] = Array("あ".utf8)   // E3 81 82
    check(b.ingest(ao[0..<2]) == [], "ingest: holds a partial UTF-8 sequence")
    check(b.ingest(ao[2..<3] + Array("!\n".utf8)) == ["あ!"], "ingest: reassembles the split character")

    // v1.3 S3: a huge burst is clipped, not evaluated line-by-line forever
    var c = OutputMonitor()
    let flood = String(repeating: "x\n", count: 5000)
    let got = c.ingest(bytes(flood))
    check(got.count == OutputMonitor.maxLinesPerIngest, "ingest: burst clipped to maxLinesPerIngest")
    check(c.droppedLines == 5000 - OutputMonitor.maxLinesPerIngest, "ingest: dropped count tracked")

    // v1.3 S3: an over-long line is truncated before matching
    var d = OutputMonitor()
    let long = String(repeating: "z", count: OutputMonitor.maxLineLength + 500)
    check(d.ingest(bytes(long + "\n")).first?.count == OutputMonitor.maxLineLength,
          "ingest: line capped at maxLineLength")
}

suite("Trigger + TriggerEngine") {
    let t1 = Trigger(pattern: "ERROR|FAIL", action: TriggerAction(kind: .notify))
    let t2 = Trigger(pattern: "warning:", action: TriggerAction(kind: .color, colorIndex: 2))
    let disabled = Trigger(pattern: "never", action: TriggerAction(kind: .bell), enabled: false)
    let bad = Trigger(pattern: "([", action: TriggerAction(kind: .bell))

    let engine = TriggerEngine([t1, t2, disabled, bad])
    check(!engine.isEmpty, "engine: keeps the valid enabled rows")
    check(engine.matches("BUILD FAILED with 3 errors").map(\.id) == [t1.id], "engine: regex alternation matches")
    check(engine.matches("main.swift:1: warning: unused").map(\.id) == [t2.id], "engine: second rule matches")
    check(engine.matches("all good").isEmpty, "engine: non-matching line → nothing")
    check(TriggerEngine([disabled, bad]).isEmpty, "engine: disabled + uncompilable rows → empty")

    // codec round-trips through the flat action shape
    let data = try! JSONEncoder().encode([t1, t2])
    let back = try? JSONDecoder().decode([Trigger].self, from: data)
    check(back == [t1, t2], "codec: Trigger list round-trips")
    check((try? JSONDecoder().decode(TriggerAction.self, from: Data(#"{}"#.utf8)))?.kind == .notify,
          "codec: empty action object defaults to .notify")
}

MainActor.assumeIsolated {
    suite("AppSettings.triggers") {
        let s = AppSettings.shared
        let saved = s.triggers
        s.triggers = [Trigger(pattern: "\\bpanic\\b", action: TriggerAction(kind: .bell))]
        check(s.triggers.count == 1 && s.triggers[0].pattern == "\\bpanic\\b",
              "triggers: persist via UserDefaults JSON")
        s.triggers = saved
    }
}

// MARK: v1.3 stability track

MainActor.assumeIsolated {
    suite("v1.3 — stability fixes") {
        // S4: rebound-shortcut monitor must not swallow keys while text is being edited
        check(KeymapStore.responderIsTextInput(NSTextView()) == true, "S4: NSTextView counts as text input")
        check(KeymapStore.responderIsTextInput(NSView()) == false, "S4: a plain NSView doesn't")
        check(KeymapStore.responderIsTextInput(nil) == false, "S4: nil responder → not text")

        // S8: a `.login` shell that's really fish gets the fish OSC 7 snippet
        check(ShellResolver.osc7Kind(forShellBasename: "fish") == .fish, "S8: basename fish → .fish")
        check(ShellResolver.osc7Kind(forShellBasename: "bash") == .bash, "S8: basename bash → .bash")
        check(ShellResolver.osc7Kind(forShellBasename: "zsh") == .zsh, "S8: basename zsh → .zsh")
        check(ShellResolver.osc7Kind(forShellBasename: "xonsh") == .zsh, "S8: unknown basename → .zsh default")
        check(ShellResolver.effectiveKindForOSC7(
                config: ShellConfig(kind: .fish, customPath: "", customArgs: "", useLoginArgs: false),
                environment: [:]) == .fish, "S8: an explicit kind is passed through")
        // .login resolves to *some* real dialect (this machine's passwd shell)
        let loginKind = ShellResolver.effectiveKindForOSC7(
            config: ShellConfig(kind: .login, customPath: "", customArgs: "", useLoginArgs: true))
        check([.zsh, .bash, .fish].contains(loginKind), "S8: .login resolves to a concrete dialect")

        // S1: pending-reap bookkeeping
        let reg = TerminalRegistry.shared
        reg.notePendingReap(999_991)
        reg.notePendingReap(0)                    // ignored
        reg.clearPendingReap(999_991)             // no crash, idempotent
        check(true, "S1: notePendingReap / clearPendingReap don't crash")

        // S7: materialize ignores a LeafSpec that isn't in the layout
        let live = UUID(), ghostSpec = UUID()
        let arr = Arrangement(
            name: "x", windowFrame: .zero,
            layout: .leaf(live),
            leaves: [
                .init(localID: live, workingDirectory: "/a", profileID: nil, customTitle: nil,
                      accentIndex: 0, accentOverride: nil, onExit: .keep, logging: false),
                .init(localID: ghostSpec, workingDirectory: "/ghost", profileID: nil, customTitle: nil,
                      accentIndex: 1, accentOverride: nil, onExit: .keep, logging: false),
            ])
        let (mats, matLayout) = ArrangementStore.shared.materialize(arr)
        check(mats.count == 1 && matLayout.leaves().count == 1, "S7: out-of-tree LeafSpec dropped on materialize")

        // R1: ⌘M default moved to ⌃⌘M (macOS eats plain ⌘M)
        let km = KeymapStore.shared
        km.resetAll()
        check(km.chord(for: .maximizeTile) == KeyChord(key: "m", modifiers: KeymapStore.cmdCtrl),
              "R1: maximizeTile default is ⌃⌘M")
        check(km.chord(for: .growPane).display == "⌃⌘]", "H5: growPane default ⌃⌘]")
        check(km.chord(for: .shrinkPane).display == "⌃⌘[", "H5: shrinkPane default ⌃⌘[")
        for a: HumiAction in [.growPane, .shrinkPane, .maximizeTile] {
            check(km.conflicts(km.chord(for: a), excluding: a).isEmpty, "\(a.rawValue) default doesn't collide")
        }
    }

    suite("PaneTree.adjustingRatio (H5)") {
        let a = UUID(), b = UUID(), c = UUID()
        let row = PaneNode.split(axis: .horizontal, children: [.leaf(a), .leaf(b), .leaf(c)],
                                 ratios: [1.0/3, 1.0/3, 1.0/3])
        func approx(_ x: CGFloat, _ y: CGFloat) -> Bool { abs(x - y) < 0.001 }

        if case .split(_, _, let r) = row.adjustingRatio(forLeaf: a, delta: 0.1) {
            check(approx(r[0], 1.0/3 + 0.1), "grow: target pane gains delta")
            check(approx(r[1], 1.0/3 - 0.1), "grow: its neighbour loses delta")
            check(approx(r[2], 1.0/3), "grow: other siblings untouched")
        } else { check(false, "adjustingRatio: still a split") }

        // last child grows against the divider on its left
        if case .split(_, _, let r) = row.adjustingRatio(forLeaf: c, delta: 0.1) {
            check(approx(r[2], 1.0/3 + 0.1) && approx(r[1], 1.0/3 - 0.1), "grow: last pane uses the left divider")
        } else { check(false, "adjustingRatio: last child still a split") }

        // clamp: can't shove a neighbour below 5% of the pair
        if case .split(_, _, let r) = row.adjustingRatio(forLeaf: a, delta: 5) {
            check(r[0] / (r[0] + r[1]) <= 0.95 + 0.001, "grow: clamped at 95% of the pair")
        } else { check(false, "adjustingRatio: clamp still a split") }

        check(PaneNode.leaf(a).adjustingRatio(forLeaf: a, delta: 0.1) == .leaf(a), "adjustingRatio: bare leaf is a no-op")
    }
}

// MARK: v1.3 Hallmark — palette contrast

suite("Contrast (WCAG)") {
    // sanity on the math
    check(abs(Hum.contrastRatio(0xFFFFFF, 0x000000) - 21.0) < 0.1, "contrast: white/black ≈ 21")
    check(abs(Hum.contrastRatio(0x777777, 0x777777) - 1.0) < 0.001, "contrast: same colour = 1")

    let R = Hum.RGB.self
    // (name, fg, bg, minimum). Body text ≥ 4.5, large/secondary ≥ 3.0, non-text ≥ 3.0.
    let pairs: [(String, UInt32, UInt32, Double)] = [
        ("ink / paper (light)",       R.inkL,  R.paperL,  4.5),
        ("ink / paper (dark)",        R.inkD,  R.paperD,  4.5),
        ("ink / paper2 (light)",      R.inkL,  R.paper2L, 4.5),
        ("ink / paper2 (dark)",       R.inkD,  R.paper2D, 4.5),
        ("ink2 / paper (light)",      R.ink2L, R.paperL,  4.5),
        ("ink2 / paper (dark)",       R.ink2D, R.paperD,  4.5),
        ("ink2 / paper2 (light)",     R.ink2L, R.paper2L, 4.0),
        ("ink2 / paper2 (dark)",      R.ink2D, R.paper2D, 4.0),
        ("focusRing / paper (light)", R.focusRingL, R.paperL, 3.0),
        ("focusRing / paper (dark)",  R.focusRingD, R.paperD, 3.0),
    ]
    for (name, fg, bg, minRatio) in pairs {
        let r = Hum.contrastRatio(fg, bg)
        check(r >= minRatio, "\(name): \(String(format: "%.2f", r)) ≥ \(minRatio)")
    }
}

print("\n\(count - failures)/\(count) checks passed")
if failures > 0 {
    print("FAILED")
    exit(1)
}
print("OK")
