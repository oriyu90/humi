# Humi v1.4.4

メニューバーの多言語対応と、狭いペインでの上下分割。
Localised menu bar, and top/bottom splits for tall-narrow panes.

---

## 日本語

### 修正
- **メニューバーが常に英語表示でした。** 手組みのアプリバンドルがローカライズ言語を
  宣言していなかったため、AppKit/SwiftUI が標準メニュー（ファイル / 編集 / 表示 /
  ウインドウ / ヘルプ、切り取り / コピー / ペースト、Humi について / 隠す / 終了 など）を
  ローカライズしていませんでした。`CFBundleLocalizations` と空の `.lproj` マーカーを
  バンドルに書き込むようにしたので、メニューバー全体が言語に追従します（Humi 独自の
  項目は元から `L(...)` 対応）。

### 変更
- **`+` でセッションを追加するとき、ペインが縦長なら上下に分割します。** これまでは
  常に新しい列（左右分割）でしたが、分割対象のペインを実測し、「新しいペインの短い方の
  辺がより長く残る」向きを選ぶようにしました。縦長のペイン（下に余裕、横に余裕なし）は
  行（上下）に、横長のペインは従来どおり新しい列（左右）に分かれます。`⌘D` / `⌘⇧D` の
  明示分割は従来の向きのままです。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.4.4.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.4.4.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.4.4.dmg)     = 571856e3c28dc83ddfe528c2cc3776296b7acc815ddbc47ee938544be358b77a
SHA-256 (Humi-1.4.4.app.zip) = 730f35d82c2f75a7d3f4bd9677106a2b3822c5152f7cb84c74bcf439a0eac531
```

---

## English

### Fixed
- **The menu bar was always English.** The hand-assembled bundle never declared
  its localizations, so AppKit/SwiftUI never localized the standard menus (File /
  Edit / View / Window / Help, Cut / Copy / Paste, About / Hide / Quit …).
  `CFBundleLocalizations` plus empty `.lproj` markers are now written into the
  bundle, so the whole menu bar follows the language. Humi's own menu items
  already used `L(...)`.

### Changed
- **`+` now splits top/bottom when the pane is tall and narrow.** Instead of
  always adding a new column, the new-session flow measures the pane it is about
  to split and picks whichever axis keeps the new pane's *smaller* side larger.
  A portrait pane (room below, none beside) splits into a row; a landscape pane
  still gets a new column. `⌘D` / `⌘⇧D` keep their explicit axis.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.4.4.dmg` and drag `Humi.app`
to Applications (`Humi-1.4.4.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.4.4.dmg)     = 571856e3c28dc83ddfe528c2cc3776296b7acc815ddbc47ee938544be358b77a
SHA-256 (Humi-1.4.4.app.zip) = 730f35d82c2f75a7d3f4bd9677106a2b3822c5152f7cb84c74bcf439a0eac531
```
