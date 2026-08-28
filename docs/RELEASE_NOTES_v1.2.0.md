# Humi v1.2.0

分割ペインと、その上に乗るウィンドウ配置・グローバルホットキー・通知・正規表現トリガー。
Split panes, and everything that builds on them: window arrangements, a global hotkey,
notifications, and regex output triggers.

---

## 日本語

### 新機能
- **分割ペイン / ペインツリー** — 1 列グリッドを再帰的なペインツリーに置き換え。
  `⌘D` 左右分割 / `⌘⇧D` 上下分割 / `⌘⌃←→↑↓` で幾何ベースのフォーカス移動 /
  `⌘⌥=` で全分割を均等化。分割線ドラッグで比率変更、タイル同士のドラッグで入れ替え。
  クローズすると空いた分割は畳まれます。フォーカス中のペインはアクセントの枠で表示。
  レイアウトは保存されます（`sessions.json` は `{sessions, layout}` 形式に。旧ファイルは
  1 列レイアウトへ自動移行）。
- **ウィンドウ配置** — 「ファイル › 配置を保存…」でペインツリー・各セッションのメタデータ・
  ウィンドウ位置をスナップショット。「配置を復元」で新しいセッションとして組み直します。
  `.humiarrangement` の読み書き。
- **グローバル切替ホットキー** — Carbon 登録のシステム全体ホットキー（既定 ⌘⌥⌃T）。
  Humi を前面に出す（前面なら隠す）。アクセシビリティ許可は不要。設定 › 一般。
- **通知** — 長時間実行のコマンド完了（しきい値つき）・端末ベル・出力文字列一致で通知。
  通知をクリックすると該当ペインにフォーカス。「Humi が背面のときだけ」トグルあり。設定 › 通知。
- **正規表現トリガー** — 確定した出力行を正規表現で照合し、通知 / ビープ / タイル色変更。設定 › 通知。
- **fish の OSC 7** — fish でも cwd 追従とステータスバーが動作します。
- **キーバインドの即時反映** — 再割り当てしたショートカットはアプリ再起動なしで有効
  （メニューの表示更新には再起動が必要）。

### 変更
- `SessionGridView` / `GridLayout` を廃止し、`PaneTreeView` + `PaneTree` に置換。
- `⌥⌘←→` は引き続き「順送り」でペインを移動。方向指定のフォーカス移動は `⌘⌃` + 矢印。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.2.0.app.zip` を展開して置き換えてください。
初回起動は「システム設定 › プライバシーとセキュリティ」から許可。通知は初回利用時に許可を求めます。

### チェックサム
```
SHA-256 (Humi-1.2.0.app.zip) = 3c63a872edf20c1352fb63a7bf804697581d01e81553d7c3979fa04a77b7de45
```

---

## English

### Added
- **Split panes / pane tree** — the single-column grid is now a recursive pane tree.
  `⌘D` splits left/right, `⌘⇧D` top/bottom, `⌘⌃←→↑↓` moves focus by geometry,
  `⌘⌥=` evens out every split. Drag a divider to change the ratio, drag one tile
  onto another to swap. Closing a pane collapses the emptied split. The focused
  pane shows an accent ring. Layout is persisted (`sessions.json` is now
  `{sessions, layout}`; older files migrate to one row).
- **Window arrangements** — File › Save Arrangement… snapshots the pane tree, every
  session's metadata, and the window frame; File › Restore Arrangement rebuilds it
  with fresh sessions. `.humiarrangement` import/export.
- **Global toggle hotkey** — a Carbon-registered system-wide chord (default ⌘⌥⌃T)
  that shows Humi, or hides it when it's frontmost. No Accessibility permission.
  Settings › General.
- **Notifications** — optional alerts when a long-running command finishes (with a
  threshold), on the terminal bell, and when output contains a watch string. Taps
  focus the pane. "Only when Humi is in the background" gate. Settings › Alerts.
- **Regex output triggers** — match regular expressions against each completed
  output line and notify / beep / recolour the tile. Settings › Alerts.
- **fish OSC 7** — cwd tracking and the status bar now work under fish.
- Rebound shortcuts take effect immediately (the menu still needs a relaunch to
  redraw the shortcut, but the key works now).

### Changed
- `SessionGridView` / `GridLayout` removed, replaced by `PaneTreeView` + `PaneTree`.
- `⌥⌘←→` still cycles panes in visual order; directional focus is `⌘⌃` + arrows.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Unzip `Humi-1.2.0.app.zip` and replace.
On first launch, allow it in System Settings › Privacy & Security. Notifications ask
for permission the first time they're used.

### Checksum
```
SHA-256 (Humi-1.2.0.app.zip) = 3c63a872edf20c1352fb63a7bf804697581d01e81553d7c3979fa04a77b7de45
```
