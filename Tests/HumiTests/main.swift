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
