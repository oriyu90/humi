# Humi v1.4.1

v1.4.0 のタブ式メモにあったデータ消失バグのホットフィックス。
Hotfix for a data-loss bug in the v1.4.0 tabbed notes.

---

## 日本語

### 修正
- **タブを切り替えたあとにメモを編集すると、別のメモの内容がまるごと上書きされていました。**
  SwiftUI が 1 つの `NotesEditor` をタブ間で使い回し、その coordinator が「最初に表示した
  メモ」のバインディングを握り続けていたため、以降のキー入力がすべてそのメモへ書き込まれて
  いました（`##` 入力後にスペースを足す、といった普通の編集操作で発生）。エディタとプレビューを
  メモ ID で識別し、タブ切替で作り直すようにしました。coordinator のバインディングも毎更新で
  貼り直します。`textBinding` の分離を self-test に追加。
- 何らかの理由で `notes.json` が「メモ 0 件」で読み込まれた場合、空のままにせず 1 件を作り直します。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.4.1.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.4.1.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.4.1.dmg)     = 08236ce3f71e04a516c2446a77318a502d7a6a5fbafd2e7d44160cda483023b7
SHA-256 (Humi-1.4.1.app.zip) = 748bc528b63eeff665d32344eda4b08efe4eca64e2f6a08cbd3754c3f91498d0
```

---

## English

### Fixed
- **Editing a note after switching tabs overwrote a *different* note's entire
  contents.** SwiftUI reused a single `NotesEditor` across tabs and its
  coordinator held the binding for whichever note it was first shown with, so
  every later keystroke wrote the visible editor text into that original note
  (it showed up during ordinary editing — e.g. typing `##` and then adding a
  space). The editor and the preview are now keyed by note id so a tab switch
  rebuilds them, and the coordinator's binding is refreshed on every update. A
  `textBinding` isolation self-test was added.
- A `notes.json` that decoded with an empty note list now re-seeds one note
  instead of leaving the sidebar empty.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.4.1.dmg` and drag `Humi.app`
to Applications (`Humi-1.4.1.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.4.1.dmg)     = 08236ce3f71e04a516c2446a77318a502d7a6a5fbafd2e7d44160cda483023b7
SHA-256 (Humi-1.4.1.app.zip) = 748bc528b63eeff665d32344eda4b08efe4eca64e2f6a08cbd3754c3f91498d0
```
