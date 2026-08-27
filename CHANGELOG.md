# Changelog

All notable changes to Humi are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions follow SemVer.

## [1.0.1] - 2026-08-27

Same-day follow-up from a hands-on debugging pass (settings persistence + terminal
stability). See `docs/TEST_PLAN_v1.0.0.md` § 4-B.

### Fixed
- **Idle CPU.** A `repeatForever` "breathing" animation on the character mark kept
  Core Animation and an AppKit layout pass running every frame while the window was
  open — ~9% CPU at idle regardless of session count. Removed the idle pulse (the
  new-session burst stays). Idle CPU is now ~0%.
- **The self-test suite wiped real saved sessions.** `bash Scripts/test.sh` deleted
  `~/Library/Application Support/Humi/sessions.json` because `HumiTests` removes it and
  persistence pointed at the real support dir. Persistence now honors a
  `HUMI_SUPPORT_DIR` override and `Scripts/test.sh` sets it to a throwaway directory.
- **Settings layout.** The three tabs bottom-aligned their rows and clipped long
  slider/stepper labels at the leading edge. Tabs are top-aligned now, values are
  right-aligned, and the window is a little wider.
- **`cd` title tracking.** When the shell reports its directory (OSC 7), a tile whose
  title is still the auto-generated one now follows the current folder. (Stock macOS
  zsh only emits OSC 7 for Terminal.app, so this is a no-op there — see `humi.md`.)

## [1.0.0] - 2026-08-27

Initial release.

### Added
- Tiled terminal workspace: the toolbar `+` (or `⌘N`) opens a Finder folder picker,
  then a session started in that folder appears as a tile in the window. Sessions are
  unlimited and reflow into as many columns as fit.
- Embedded terminal emulator via SwiftTerm (real PTY + real shell). Per tile: maximize,
  restart an exited shell in its original directory, close.
- `⌘K` clears the focused session's screen and drops its scrollback, keeping the current
  prompt and any half-typed command.
- Markdown scratch notes sidebar, persisted to
  `~/Library/Application Support/Humi/notes.md` across restarts.
- Session list (folder, title, accent) persisted to `sessions.json` and restored on
  launch; a restored session whose folder no longer exists falls back to the home
  directory instead of failing to launch.
- Settings: shell (login / zsh / bash / fish / custom path + args, `-l` toggle),
  scrollback lines (1,000–200,000), font size (9–22pt, applied live).
- Clean shutdown: every child shell is torn down synchronously on quit
  (SIGTERM → poll → SIGKILL → reap) so nothing is left orphaned.
- Hum visual theme (cream paper, rounded surfaces, multi-accent tiles, push buttons),
  bundled Plus Jakarta Sans + JetBrains Mono.
- Dependency-free self-test suite (`Scripts/test.sh`, 40 checks) and a no-Xcode app
  bundler (`Scripts/build-app.sh`).

### Hardening (pre-release scrutiny)
- `swift build` (no `--product`) no longer breaks on the test target.
- Synchronous child-shell teardown on quit (no orphans); bounded reaped-id set;
  a restored session whose folder was deleted opens in home.
- Added `⌘K` clear-buffer; `Package.resolved` is tracked.

### Notes
- v1.0 is embedded-only. Opening the OS-level iTerm / Terminal.app is planned for a
  later release (the code is in tree but not wired to any UI). See `humi.md`.
- Distributed with ad-hoc signing; not yet notarized.
