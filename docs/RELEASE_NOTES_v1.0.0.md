# Humi v1.0.0

タイル型の macOS ターミナルワークスペースの最初のリリース。
The first release of Humi — a tiled terminal workspace for macOS.

---

## 日本語

### 主な機能
- ウィンドウの `+`（または `⌘N`）で **Finder のフォルダ選択**が開き、選んだフォルダで開いた
  ターミナルセッションがウィンドウ内のタイルとして並びます。セッションは無制限、
  入るだけ列にリフローします。
- ターミナルは SwiftTerm による**内蔵エミュレータ**（実 PTY + 実シェル）。タイルごとに
  最大化・終了シェルの再起動・クローズ。
- `⌘K` でフォーカス中セッションの画面をクリア（スクロールバックも破棄、プロンプトと
  入力中コマンドは保持）。
- Markdown 対応のメモ欄。`~/Library/Application Support/Humi/` に保存され再起動後も残ります。
- セッション一覧を保存・復元。復元時にフォルダが消えていればホームで開きます。
- 設定: シェル（ログイン / zsh / bash / fish / カスタム）、スクロールバック行数、フォントサイズ。
- 終了時、すべての子シェルを同期的に確実に終了（孤児プロセスを残しません）。

### 動作環境
- macOS 14 以降（Apple Silicon / Intel）

### インストール
1. `Humi-1.0.0.app.zip` を展開し `Humi.app` を「アプリケーション」へ。
2. ad-hoc 署名のため、初回は `Humi.app` を右クリック →「開く」、または
   「システム設定 › プライバシーとセキュリティ」から実行を許可してください。

### 既知の制限
- Apple の公証（notarization）は未対応。
- アプリアイコンは未同梱。
- ダークモード非対応（ライトテーマ固定）。
- 外部の iTerm / ターミナル.app を起動するオプションは次期リリース予定です。

### チェックサム
```
SHA-256 (Humi-1.0.0.app.zip) = bc626b56619df501181f372f35edff77f5c05cd272b40ff1f9b2348227919b06
```

---

## English

### Highlights
- The toolbar `+` (or `⌘N`) opens a **Finder folder picker**; a session started in that
  folder appears as a tile in the window. Sessions are unlimited and reflow into as many
  columns as fit.
- Embedded terminal emulator via SwiftTerm (real PTY + real shell). Per tile: maximize,
  restart an exited shell in its original folder, close.
- `⌘K` clears the focused session's screen and scrollback, keeping the prompt and any
  half-typed command.
- Markdown scratch-notes sidebar, persisted under `~/Library/Application Support/Humi/`.
- Session list is saved and restored; a restored session whose folder is gone opens in
  the home directory instead of failing.
- Settings: shell (login / zsh / bash / fish / custom), scrollback lines, font size.
- On quit, every child shell is torn down synchronously — nothing is left orphaned.

### Requirements
- macOS 14 or later (Apple Silicon / Intel)

### Install
1. Unzip `Humi-1.0.0.app.zip` and move `Humi.app` to Applications.
2. Ad-hoc signed: on first launch, right-click `Humi.app` → Open, or allow it from
   System Settings › Privacy & Security.

### Known limitations
- Not notarized yet. No app icon bundled. Light theme only. Launching an external
  iTerm / Terminal.app is planned for a later release.

### Checksum
```
SHA-256 (Humi-1.0.0.app.zip) = bc626b56619df501181f372f35edff77f5c05cd272b40ff1f9b2348227919b06
```
