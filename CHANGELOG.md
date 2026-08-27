# Changelog

All notable changes to Humi are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions follow SemVer.

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
- Dependency-free self-test suite (`Scripts/test.sh`, 37 checks) and a no-Xcode app
  bundler (`Scripts/build-app.sh`).

### Notes
- v1.0 is embedded-only. Opening the OS-level iTerm / Terminal.app is planned for a
  later release (the code is in tree but not wired to any UI). See `humi.md`.
- Distributed with ad-hoc signing; not yet notarized.
