# Humi v1.1.0

多言語対応と、カスタマイズ機能の大幅な追加。
A large release: 5-language localization and a big batch of customization features.

---

## 日本語

### 新機能
- **5 言語対応** — 日本語 / English / 中文 / Português / Español。OS の言語で自動選択、
  設定の言語ピッカーで手動切替（再起動不要）。
- **フルテーマ** — 6 プリセット（Hum Light/Dark、Solarized Light/Dark、Nord、Terminal Basic）、
  自作テーマ、`.humitheme` の読み書き、ANSI 16 色エディタ、カーソル形状／点滅、
  等幅フォント＋日本語フォント指定、Light / Dark / **System**（アプリ本体のダークモードも）。
  変更は開いている全ターミナルへ即反映。
- **ターミナル内検索**（`⌘F`）、件数表示・前後移動・ハイライト。
- **URL / パス連携** — 出力内の URL・パス・`パス:行番号` を ⌘クリック / 右クリックで
  ブラウザ・Finder・任意のエディタ（既定 `code -g`）から開く。
- **プロファイル** — シェル・環境変数・起動コマンド・フォルダ・テーマ・スクロールバック・
  ログをまとめて保存。新規セッション時に選択、ツールバーのランチャーから一発起動。
- **キーバインド変更** — 主要操作を設定画面で再割り当て（衝突検出・リセット・`.humikeys`）。
- **セッション** — 名前変更、タイル色、終了時の動作、実行中の確認、セッションログ。
- **ステータスバー**（任意）— 作業フォルダ・シェル・Git ブランチ＋変更・時刻。
  Humi 側で OSC 7 を注入するため `cd` に追従します。
- `⌘+` / `⌘-` / `⌘0` フォントズーム、`⌥⌘←→` タイル移動、余白・選択即コピー・
  複数行ペースト確認・ベル・Option→Meta など。

### 今回含まないもの（v1.2 予定）
分割ペイン、ウィンドウ配置、グローバルホットキー、通知マトリクス、正規表現トリガー。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.1.0.app.zip` を展開して置き換えてください。
初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.1.0.app.zip) = 4f4a0a1e3217390c2afe78f6a3ea87b706631c3cca4a2909aa1360f72e3cb988
```

---

## English

### Added
- **5 languages** — Japanese, English, 中文, Português, Español. Auto-selected from
  the OS language; a live in-app picker switches without relaunch.
- **Full theming** — 6 presets (Hum Light/Dark, Solarized Light/Dark, Nord,
  Terminal Basic), custom themes, `.humitheme` import/export, ANSI-16 editor,
  cursor shape + blink, monospaced + CJK fonts, Light / Dark / **System** (the app
  chrome follows too). Applies to every live terminal instantly.
- **In-terminal search** (`⌘F`) with match count, next/prev, highlight.
- **URL / path actions** — ⌘-click or right-click to open a URL, a file/dir in
  Finder, or `path:line` in a configurable editor (`code -g` default).
- **Profiles** — shell + env + startup command + folder + theme + scrollback +
  logging bundles. Pick in the new-session sheet or one-click from a launcher.
- **Customizable keyboard shortcuts** — rebind every core action, with conflict
  detection, reset, and `.humikeys` import/export.
- **Session & tile** — rename, per-tile colour, on-exit behaviour, close
  confirmation, drag-reorder, per-session output logging.
- **Per-tile status bar** (opt-in) — working folder, shell, git branch + dirty,
  clock. Humi injects an OSC 7 emitter so it follows `cd`.
- Font zoom `⌘+` `⌘-` `⌘0`, `⌥⌘←→` tile focus, inner margin, copy-on-select,
  multi-line paste confirm, bell, option-as-Meta, and more.

### Not in this release (v1.2)
Split panes, window arrangements, global hotkey, the notification matrix, regex triggers.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Unzip `Humi-1.1.0.app.zip` and replace.
On first launch, allow it in System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.1.0.app.zip) = 4f4a0a1e3217390c2afe78f6a3ea87b706631c3cca4a2909aa1360f72e3cb988
```
