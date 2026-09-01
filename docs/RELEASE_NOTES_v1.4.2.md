# Humi v1.4.2

新規セッションの開き方まわりの修正。
Fixes to the new-session flow.

---

## 日本語

### 変更
- **`+` を押しても、いきなりフォルダ選択パネルが出ることはなくなりました。** まず
  「そのまま開く（ホーム）／フォルダを選んで開く」を選ぶシートが出ます。フォルダ選択は
  シートに重ねて出る SwiftUI の `.fileImporter` で行います。

### 修正
- **フォルダを選んでも、たどった先のフォルダではなくホームでセッションが開くことがありました。**
  旧フローはシートを閉じ → `NSOpenPanel` を出し → シートを開き直す、という流れで、
  選んだパスが競合で失われることがありました。シートは開いたままフォルダの状態を自分で
  持つようにしたので、選んだフォルダ（深くたどった先でも）が必ず作業ディレクトリになります。
- **シート操作のあと、タイトルバーに「Humi」が二重に出ることがありました。** ウィンドウを
  `.hiddenTitleBar` にして、OS のタイトル文字が戻らないようにしました。
- 未使用になったローカライズ文字列 2 件（`panel.choose` / `panel.message`）を削除。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.4.2.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.4.2.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.4.2.dmg)     = 732eaf4ec464a0e697668275516888fe7ef3baa07621979b161ca21511c030ae
SHA-256 (Humi-1.4.2.app.zip) = 25294c5fe7835392c9f909a0ffc4beb2e32694456be7d62c06a97a124ec10f88
```

---

## English

### Changed
- **The `+` flow no longer opens a folder picker unprompted.** It shows the
  choose-how sheet first (open as-is in home, or pick a folder). The folder is
  chosen with a SwiftUI `.fileImporter` layered over the sheet.

### Fixed
- **Picking a folder sometimes started the session in the home directory instead
  of the chosen folder.** The old flow dismissed the sheet, ran an `NSOpenPanel`,
  and re-presented it — a race that could drop the picked path. The sheet now
  stays mounted and owns the folder state, so the chosen (even deep-traversed)
  folder is always the session's working directory.
- **"Humi" could show twice in the title bar after using a sheet.** The window
  now uses `.hiddenTitleBar`, so SwiftUI can't restore the OS title text.
- Removed two now-unused localized strings (`panel.choose`, `panel.message`).

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.4.2.dmg` and drag `Humi.app`
to Applications (`Humi-1.4.2.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.4.2.dmg)     = 732eaf4ec464a0e697668275516888fe7ef3baa07621979b161ca21511c030ae
SHA-256 (Humi-1.4.2.app.zip) = 25294c5fe7835392c9f909a0ffc4beb2e32694456be7d62c06a97a124ec10f88
```
