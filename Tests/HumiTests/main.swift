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

// MARK: GridLayout

suite("GridLayout") {
    check(GridLayout.columnCount(width: 400, minTileWidth: 380, spacing: 16) == 1, "narrow → 1 column")
    check(GridLayout.columnCount(width: 820, minTileWidth: 380, spacing: 16) == 2, "wide → 2 columns")
    check(GridLayout.columnCount(width: 0, minTileWidth: 380, spacing: 16) == 1, "zero width → 1 column")
    check(GridLayout.chunk([1, 2, 3, 4, 5], into: 2) == [[1, 2], [3, 4], [5]], "chunk: uneven split")
    check(GridLayout.chunk([Int](), into: 3) == [], "chunk: empty → empty")
    check(GridLayout.chunk([1, 2], into: 0) == [[1, 2]], "chunk: size 0 → single row")
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
