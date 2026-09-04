# Humi v1.5.0

ターミナルのマウス選択コピー、ドイツ語対応、安定性監査の修正。
Mouse-selection copy, German localization, and stability audit fixes.

---

## 日本語

### 追加
- ターミナル出力をマウスでドラッグ選択し、`⌘C` または右クリックの
  **「選択部分をコピー」**でコピーできます。設定の「選択したらコピー」も引き続き利用できます。
  mouse reporting を使う TUI では Shift を押しながらドラッグしてください。
- Deutsch を追加し、日本語 / English / 中文 / Português / Español / Deutsch の 6 言語に対応しました。

### 安定性・操作性
- メモ ZIP 処理の stdout を破棄し stderr を並行して読み取ることで、パイプ詰まりによる停止を防止。
  30 秒タイムアウトと強制終了も追加しました。失敗時は理由を画面に表示します。
- 出力監視の未終端バッファが、どの PTY chunk 形状でも 8 KB を超えないよう修正しました。
- ステータスバー時計の購読を冪等化し、不要になったタイマーが確実に停止します。
- ウィンドウリサイズ中に RootView 全体を毎フレーム再評価していた処理を除去しました。
- ノートを作成／開いたとき、選択タブが自動で表示範囲へ移動します。
- 新規セッションシートは Return で主ボタンを実行できます。
- 言語設定に、標準メニューとシステムダイアログは再起動後に反映される旨を追記しました。
- 空の選択をコピーしても、既存のクリップボード内容を消しません。
- 配布アプリを arm64 + x86_64 のユニバーサルバイナリとして生成するようにしました。

### 動作環境・インストール
macOS 14 以降、Apple Silicon / Intel。ad-hoc 署名（公証なし）。`Humi-1.5.0.dmg` を開き
`Humi.app` を Applications へドラッグしてください（`Humi-1.5.0.app.zip` も添付）。
初回起動は「システム設定 › プライバシーとセキュリティ」から許可してください。

### チェックサム
```text
SHA-256 (Humi-1.5.0.dmg)     = d6f5188be5f23e060a614b93cbdb648ef9e523cd0b6f90405b05a3a831571ff9
SHA-256 (Humi-1.5.0.app.zip) = 69cb9466c6c40610fda94bc80f14f53d7dfe385431c688e62f0d51c35edab44c
```

---

## English

### Added
- Drag across terminal output and copy it with `⌘C` or **Copy Selection** in the tile's
  context menu. Copy-on-select remains available. Hold Shift while dragging when a TUI
  has enabled mouse reporting.
- Added German, bringing Humi to six languages: Japanese, English, Simplified Chinese,
  Brazilian Portuguese, Spanish, and German.

### Stability and usability
- Notes ZIP operations now discard unused stdout, drain stderr concurrently, and time
  out after 30 seconds, preventing pipe deadlocks or indefinite hangs. Failures show an alert.
- Output monitoring keeps its unterminated buffer below 8 KB for every PTY chunk shape.
- Status-bar clock subscriptions are idempotent, so the shared timer stops when unused.
- Window resizing no longer invalidates the entire RootView on every frame.
- Creating or opening a note automatically scrolls its tab into view.
- Return activates the primary action in the new-session sheet.
- The language setting explains that standard menus and system dialogs update after restart.
- Copying an empty selection no longer erases existing clipboard contents.
- Release apps are now universal arm64 + x86_64 binaries.

### Requirements / install
macOS 14+, Apple Silicon / Intel, ad-hoc signed (not notarized). Open `Humi-1.5.0.dmg`
and drag `Humi.app` to Applications (`Humi-1.5.0.app.zip` is also attached). On first
launch, allow it in System Settings › Privacy & Security.

### Checksums
```text
SHA-256 (Humi-1.5.0.dmg)     = d6f5188be5f23e060a614b93cbdb648ef9e523cd0b6f90405b05a3a831571ff9
SHA-256 (Humi-1.5.0.app.zip) = 69cb9466c6c40610fda94bc80f14f53d7dfe385431c688e62f0d51c35edab44c
```
