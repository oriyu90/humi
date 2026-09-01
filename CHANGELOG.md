# Changelog

All notable changes to Humi are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); versions follow SemVer.

## [1.4.1] - 2026-09-01

Hotfix for a data-loss bug in the new tabbed notes.

### Fixed
- **Editing a note after switching tabs overwrote a *different* note's entire
  contents.** SwiftUI reused one `NotesEditor` across tabs; its coordinator kept
  the binding for whichever note it was first shown with, so every later
  keystroke wrote the visible editor text into that original note. The editor
  (and the preview) is now identified by note id so a tab switch rebuilds it, and
  the coordinator's binding is refreshed on every update. Added a `textBinding`
  isolation self-test.
- A `notes.json` that somehow decoded with an empty note list now re-seeds one
  note instead of leaving the sidebar with nothing.

## [1.4.0] - 2026-09-01

The notes sidebar becomes multi-tab, with ZIP export/import for moving notes
between machines.

### Added
- **Tabbed notes.** The sidebar header is now a tab strip: a pinned **Home** tab
  (a house icon) plus one tab per note. Home lists every note — create
  (「新規メモ」), rename (pencil → dialog), open, delete. Each note tab has an `×`
  that asks for confirmation before deleting. New notes are named "メモ 1",
  "メモ 2", … Persistence moved from `notes.md` to `notes.json` (`{notes, activeID}`);
  a pre-1.4 `notes.md` is migrated to a single note on first launch.
- **ZIP export / import of all notes** (buttons on the Home tab). The archive is a
  plain `manifest.json` + one `NN--slug.md` per note, made with `/usr/bin/ditto`
  (no dependency). On import, a note whose **id and title both match** an existing
  one is replaced in place (the imported copy wins); anything else is added,
  keeping its id so a later re-import from the same machine updates rather than
  duplicates. A hand-made ZIP of loose `.md` files also imports (titled by
  filename). New strings `notes.list.title` / `notes.tab.new` / `notes.rename` /
  `notes.delete*` / `notes.share*` / `notes.export_zip` / `notes.import_zip` in
  all five languages.

### Changed
- **Edit ⇄ Preview keeps your scroll position.** Both panes are now backed by an
  `NSScrollView` (editor via `NSTextView`, preview via a hosted SwiftUI subtree)
  sharing one normalised scroll fraction, so toggling lands you roughly where you
  were. The fraction resets when you switch notes.

### Fixed
- **The open Settings window now follows the in-app Light/Dark mode live.**
  `.preferredColorScheme` alone didn't repaint an already-open Settings window;
  its `NSWindow.appearance` is now forced on every update pass (same trick as the
  1.3.2 title-text hider).

## [1.3.2] - 2026-09-01

A small UI pass over the notes sidebar and the window chrome.

### Added
- **Copy button on fenced code blocks in the notes Markdown preview.** Each
  ```` ``` ```` block gets a Copy control in its own strip above the code; it puts
  the block on the pasteboard verbatim (trailing newline trimmed) and briefly
  confirms with a check. The button sits outside the selectable text on purpose —
  on macOS a `textSelection`-enabled `Text` installs a text-interaction view that
  swallows clicks landing on top of it. New strings `notes.copy_code` /
  `notes.code_copied` in all five languages.

### Fixed
- **The window showed "Humi" twice** — once as the toolbar brand mark and once as
  the OS title-bar text. The title-bar text is now hidden. The previous one-shot
  fix at launch was reverted by SwiftUI re-asserting `titleVisibility = .visible`
  when the first session opened; the hider now re-applies on every scene update.
- **New-session sheet: the folder row truncated its own placeholder.** CJK text in
  the monospace font falls back wider than the fixed row width allowed, so
  「フォルダ未選択（ホームで開く）」 middle-truncated. The path label now takes layout
  priority and the sheet is a touch wider (480 → 520).
- **Notes Edit/Preview segmented control clipped** "Pré-visualizar" / "Vista
  previa" at its fixed 150 pt width. It now sizes to its content.

## [1.3.1] - 2026-08-29

### Fixed
- **App crashed on launch (SIGTRAP before the window) on any machine other than
  the one it was built on.** SwiftPM's generated `Bundle.module` accessor (the
  Command Line Tools toolchain's minimal variant) only checks the `.app` *root*
  and a hardcoded build-machine path — never `Contents/Resources/`, where
  `Scripts/build-app.sh` puts the resource bundles. `registerFonts()` hit the
  `fatalError`. HumiKit now resolves its fonts + `.lproj` tables via
  `Bundle.humiResources`, which checks `Contents/Resources/` first.
- `PaneNode.focusNeighbor` now visits candidates in reading order instead of
  `Dictionary` hash order, so `⌘⌃`+arrow lands on the same pane every time.

## [1.3.0] - 2026-08-28

A quality release: a stability/safety pass over the terminal internals and a
Hallmark interaction-state pass over the custom controls. See
`docs/AUDIT_2026-08-28.md` and `docs/TEST_PLAN_v1.3.0.md`. Only two new bindings.

### Fixed
- **Orphaned shell on close-then-quit.** A tile closed less than ~1.8s before
  ⌘Q could leave its shell for launchd to adopt. `TerminalRegistry` now tracks
  pids whose deferred SIGKILL-reap hasn't run and finishes them on quit.
- **Output-trigger flood.** A fast-scrolling log with a trigger active could jam
  the main thread; `OutputMonitor` is byte-based now (a multi-byte character
  split across two pty reads is no longer corrupted), clips a burst, and caps
  line length before matching.
- **Rebound shortcut swallowed keystrokes** while a text field / editor had
  focus (Notes, rename, Settings). It now only fires when text isn't being edited.
- One shared 12s status-bar timer instead of one per visible tile;
  `hasLiveForegroundChild` (a whole-machine process walk) is cached.
- `git` in the status bar gets a 2s timeout so a hung repo can't wedge it.
- `⌘⌃`+arrow pane focus works before you've clicked a pane.
- A `.login` shell that is actually **fish** now gets the fish OSC 7 snippet.
- Stale `ScrollViewReader` removed from the pane canvas.

### Added
- **Keyboard pane resize** — `⌃⌘]` grows, `⌃⌘[` shrinks the focused pane.
- Hallmark states on every custom control: hover, keyboard-focus ring
  (`Hum.focusRing`, a high-contrast theme-adaptive blue, 3–4pt), disabled, and
  loading/success/error on `HumButtonStyle`. Title-bar icon buttons get 26pt
  targets and a focus ring. Split handles show a hover highlight and a
  leak-proof resize cursor. `Increase Contrast` firms up hairlines and washes.
- A WCAG contrast self-test over the palette (`suite("Contrast")`).

### Changed
- **`maximizeTile` default is now `⌃⌘M`** — plain `⌘M` is intercepted by macOS
  window-minimize. Existing `keymap.json` bindings are untouched.

## [1.2.0] - 2026-08-28

Split panes and everything that builds on them, plus a global hotkey, notifications,
and regex output triggers. See `docs/TEST_PLAN_v1.2.0.md`.

### Added
- **Split panes / pane tree.** The flat tile grid is now a recursive `PaneNode`
  layout: `⌘D` splits left/right, `⌘⇧D` top/bottom, `⌘⌃←→↑↓` moves focus by
  geometry, `⌘⌥=` evens out every split. Drag a divider to change the ratio; drag
  one tile onto another to swap. A close collapses the emptied split. The focused
  pane gets an accent ring. Layout persists (`sessions.json` is now
  `{sessions, layout}`; pre-1.2 files migrate to a single row).
- **Window arrangements.** File › Save Arrangement… snapshots the pane tree, every
  session's metadata, and the window frame; File › Restore Arrangement rebuilds it
  with fresh sessions. `.humiarrangement` import/export.
- **Global toggle hotkey.** A Carbon-registered system-wide chord (default ⌘⌥⌃T)
  that shows Humi, or hides it when it's frontmost. No Accessibility permission.
  Settings › General.
- **Notifications.** Optional alerts when a long-running command finishes (with a
  threshold), on the terminal bell, and when output contains a watch string. Taps
  focus the pane. "Only when Humi is in the background" gate. Settings › Alerts.
- **Regex output triggers.** Per completed output line, match regular expressions
  and notify / beep / recolour the tile. Settings › Alerts.
- **fish OSC 7.** cwd tracking and the status bar now work under fish.
- Rebound shortcuts take effect immediately (menu shortcuts still need a relaunch
  to redraw, but the key works now).

### Changed
- `SessionGridView` / `GridLayout` removed, replaced by `PaneTreeView` + `PaneTree`.
- `⌥⌘←→` still cycles panes in visual order; directional focus is `⌘⌃` + arrows.

## [1.1.0] - 2026-08-28

A large feature release: 5-language localization plus the "Priority A + B" items
from the customization backlog. See `docs/TEST_PLAN_v1.1.0.md`.

### Added
- **Localization (5 languages).** Japanese, English, 中文 (简体), Português, Español.
  Auto-selected from the OS language; a live in-app picker (Settings › General)
  switches without relaunch.
- **Full theming.** `Theme` model + 6 built-in presets (Hum Light/Dark, Solarized
  Light/Dark, Nord, Terminal Basic), custom themes, `.humitheme` import/export,
  ANSI-16 colour editor, cursor shape + blink, monospaced + CJK font pickers,
  Light / Dark / **System** mode. The app chrome follows the theme's light/dark too.
  Changes apply to every live terminal instantly.
- **In-terminal search** (`⌘F`): match count, next/prev, highlight.
- **URL / path actions.** ⌘-click or a right-click menu opens a URL in the browser,
  a file/dir in Finder, or `path:line` in a configurable editor (`code -g` default).
- **Profiles.** Named bundles of shell + environment + startup command + working
  directory + theme + scrollback + logging. Picked in the new-session sheet, or
  one-click from a toolbar launcher. `.humiprofile` import/export.
- **Customizable keyboard shortcuts.** Every core action is rebindable in
  Settings › Shortcuts, with conflict detection, reset, and `.humikeys` import/export.
- **Session & tile.** Rename, per-tile colour, on-exit behaviour (keep / auto-restart
  / auto-close), close confirmation when a process is running, drag-to-reorder,
  per-session output logging (via `script`).
- **Per-tile status bar** (opt-in): working folder, shell, git branch + dirty dot,
  clock. Humi now injects an OSC 7 emitter for zsh/bash so the tile title, status-bar
  cwd, and git panel follow `cd`.
- Terminal behaviour prefs: option-as-Meta, mouse reporting, scroll sensitivity,
  scrollbar style, copy-on-select, multi-line paste confirmation, unlimited
  scrollback, inner margin, bell (off / sound / visual). Font zoom `⌘+` `⌘-` `⌘0`;
  `⌥⌘←→` moves focus between tiles.

### Not in this release (v1.2 roadmap, see `humi.md`)
- Split panes / pane-tree layout, window arrangements, global hotkey / Quake window,
  the full notification matrix, regex triggers.

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
