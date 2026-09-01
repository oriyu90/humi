# Humi v1.4.0

メモ欄がタブ式になり、ZIP で端末間の持ち運びができるようになりました。
The notes sidebar is now multi-tab, with ZIP export/import for moving notes between machines.

---

## 日本語

### 追加
- **タブ式のメモ。** サイドバーのヘッダーがタブバーになりました。左端は消せない
  **ホームタブ**（家アイコン）で、すべてのメモの一覧・作成（「新規メモ」）・
  リネーム（鉛筆 → ダイアログ）・削除ができます。各メモのタブには `×` があり、
  削除前に確認します。新規メモの名前は「メモ 1」「メモ 2」…。保存先は
  `notes.md` から `notes.json`（`{notes, activeID}`）に変わりました。旧 `notes.md` は
  初回起動時に 1 件のメモへ自動移行します。
- **すべてのメモを ZIP で書き出し・読み込み**（ホームタブのボタン）。書庫は
  `manifest.json` ＋ メモごとの `NN--slug.md` という素朴な構成で、`/usr/bin/ditto`
  で作ります（追加の依存なし）。読み込み時、**名前と ID が両方一致する**メモは
  読み込んだ内容で置き換わり（インポート優先）、それ以外は追加されます。追加分は
  ID を保持するので、同じ端末から再度読み込んでも重複しません。`.md` ファイルだけを
  手動で固めた ZIP も読み込めます（ファイル名がメモ名になります）。

### 変更
- **編集 ⇄ プレビュー切替でスクロール位置を保持。** どちらも `NSScrollView` ベースに
  なり（編集は `NSTextView`、プレビューは SwiftUI をホスト）、正規化したスクロール
  位置を共有します。切り替えてもだいたい同じ位置に留まります。メモを切り替えると
  先頭に戻ります。

### 修正
- **開いたままの設定ウィンドウが、アプリの Light/Dark 切替に即追従。**
  `.preferredColorScheme` だけでは開いている設定ウィンドウが塗り替わらなかったため、
  `NSWindow.appearance` を毎更新で明示するようにしました（1.3.2 のタイトル文字非表示と
  同じ手法）。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.4.0.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.4.0.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.4.0.dmg)     = 0cc98fcf13fda3f9fa25a9abfb072fba5a4f234e8be29e52d26fec7d030c5fce
SHA-256 (Humi-1.4.0.app.zip) = c3b4afd52e5a2f125f5b3e51245ae74fd6a8f5e5212d6e21a607a022d6950f52
```

---

## English

### Added
- **Tabbed notes.** The sidebar header is now a tab strip: a pinned **Home** tab
  (a house icon) that lists every note — create (“New note”), rename (pencil →
  dialog), open, delete — plus one tab per note. Each note tab has an `×` that
  confirms before deleting. New notes are named “メモ 1”, “メモ 2”, … Persistence
  moved from `notes.md` to `notes.json` (`{notes, activeID}`); a pre-1.4
  `notes.md` is migrated to one note on first launch.
- **Export / import all notes as a ZIP** (buttons on the Home tab). The archive is
  a plain `manifest.json` + one `NN--slug.md` per note, built with `/usr/bin/ditto`
  (no dependency). On import, a note whose **id and title both match** an existing
  one is replaced in place (imported copy wins); anything else is added, keeping
  its id so re-importing from the same machine updates rather than duplicates. A
  hand-made ZIP of loose `.md` files imports too (titled by filename).

### Changed
- **Edit ⇄ Preview keeps your scroll position.** Both panes are `NSScrollView`
  backed (editor via `NSTextView`, preview hosts the SwiftUI subtree) and share a
  normalised scroll fraction, so toggling lands you roughly where you were. The
  fraction resets when you switch notes.

### Fixed
- **The open Settings window now follows the in-app Light/Dark mode live.**
  `.preferredColorScheme` alone didn't repaint an already-open Settings window;
  its `NSWindow.appearance` is now forced on every update pass.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.4.0.dmg` and drag `Humi.app`
to Applications (`Humi-1.4.0.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.4.0.dmg)     = 0cc98fcf13fda3f9fa25a9abfb072fba5a4f234e8be29e52d26fec7d030c5fce
SHA-256 (Humi-1.4.0.app.zip) = c3b4afd52e5a2f125f5b3e51245ae74fd6a8f5e5212d6e21a607a022d6950f52
```
