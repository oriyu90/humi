# Humi v1.3.2

メモ欄と、ウィンドウまわりの小さな UI 改善。
A small UI pass over the notes sidebar and the window chrome.

---

## 日本語

### 追加
- **メモのコードブロックにコピーボタン。** プレビュー表示で ``` ``` ``` で囲んだコード
  ブロックごとに、コード上部の帯にコピーボタンが付きます。押すとブロックの中身を
  そのままクリップボードへ（末尾の改行は除去）。ボタンは選択可能テキストの上には
  重ねていません（macOS ではテキスト選択が有効な `Text` がクリックを吸ってしまうため）。
  文字列 `notes.copy_code` / `notes.code_copied` を 5 言語ぶん追加。

### 修正
- **ウィンドウ上部に「Humi」が 2 つ**表示されていました（ツールバーのブランドマークと
  OS のタイトルバー文字）。タイトルバー文字を非表示にしました。v1.3.1 では起動時に
  一度だけ隠していましたが、最初のセッションを開くと SwiftUI が `titleVisibility` を
  戻してしまうため、シーン更新のたびに隠すようにしました。
- **新規セッションシートのフォルダ行が、自分のプレースホルダを切り詰めていました。**
  等幅フォントの CJK フォールバックが想定より広く、固定幅に収まらず
  「フォルダ未選択（ホームで開く）」が中央省略されていました。パス表示にレイアウト
  優先度を与え、シートを少し広く（480 → 520）しました。
- **メモの「編集／プレビュー」切替**が固定幅 150pt で "Pré-visualizar" / "Vista previa"
  を見切れさせていたのを、内容に合わせて伸びるようにしました。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.3.2.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.3.2.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.3.2.dmg)     = c2a1621f59d8bc40f7e5a8af5527748cc354e8b828e9c999d7125c3fd0846576
SHA-256 (Humi-1.3.2.app.zip) = 53ccc569aa41c28bae842cf5fac2e08685e33a3252fa7bada2bff852623cf20f
```

---

## English

### Added
- **Copy button on fenced code blocks in the notes preview.** Every ``` ``` ```
  block gets a Copy control in a strip above the code; it puts the block on the
  pasteboard verbatim (trailing newline trimmed) and briefly confirms with a
  check. The button is kept off the selectable text on purpose — on macOS a
  `textSelection`-enabled `Text` installs a text-interaction view that swallows
  clicks landing over it. New strings `notes.copy_code` / `notes.code_copied` in
  all five languages.

### Fixed
- **The window showed "Humi" twice** — the toolbar brand mark and the OS
  title-bar text. The title-bar text is now hidden. The v1.3.1 one-shot fix at
  launch was reverted by SwiftUI re-asserting `titleVisibility = .visible` when
  the first session opened; the hider now re-applies on every scene update.
- **New-session sheet: the folder row truncated its own placeholder.** The
  monospace font's CJK fallback is wider than the fixed row width allowed, so
  「フォルダ未選択（ホームで開く）」 middle-truncated. The path label now takes layout
  priority and the sheet is slightly wider (480 → 520).
- **Notes Edit/Preview segmented control** clipped "Pré-visualizar" / "Vista
  previa" at its fixed 150 pt width; it now sizes to its content.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.3.2.dmg` and drag `Humi.app`
to Applications (`Humi-1.3.2.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.3.2.dmg)     = c2a1621f59d8bc40f7e5a8af5527748cc354e8b828e9c999d7125c3fd0846576
SHA-256 (Humi-1.3.2.app.zip) = 53ccc569aa41c28bae842cf5fac2e08685e33a3252fa7bada2bff852623cf20f
```
