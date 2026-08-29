# Humi v1.3.1

起動時クラッシュのホットフィックス。
A hotfix for a launch crash.

---

## 日本語

### 修正
- **ビルドしたマシン以外で起動時に必ずクラッシュしていた**（ウィンドウが出る前に SIGTRAP）。
  SwiftPM が生成する `Bundle.module`（Command Line Tools 版）は `.app` 直下とビルドマシンの
  固定パスしか見ず、`Scripts/build-app.sh` がリソースバンドルを置く `Contents/Resources/` を
  探しません。そのため `registerFonts()` が `fatalError` していました。HumiKit は
  フォントと `.lproj` を `Bundle.humiResources`（`Contents/Resources/` を先に見る）経由で
  解決するようにしました。
- `⌘⌃` + 矢印のペインフォーカス移動が、`Dictionary` の並び順に依存して結果が変わることが
  あったのを、読み順（左→右・上→下）に固定しました。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.3.1.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.3.1.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.3.1.dmg)     = 9aa0a20fd41d6a9be2e8c987e4d4579c799c6e8a5864951546ce3db3e2a045ee
SHA-256 (Humi-1.3.1.app.zip) = 1ef60056a48935c220ca4fc9cb6d537ea8c17dc0bedb4f3d136bb813ee9f55bd
```

---

## English

### Fixed
- **The app crashed on launch on any machine other than the one it was built
  on** (SIGTRAP before the window). SwiftPM's generated `Bundle.module` accessor
  (the Command Line Tools toolchain's minimal variant) only checks the `.app`
  *root* and a hardcoded build-machine path — never `Contents/Resources/`, where
  `Scripts/build-app.sh` puts the resource bundles, so `registerFonts()` hit the
  `fatalError`. HumiKit now resolves its fonts + `.lproj` tables via
  `Bundle.humiResources`, which checks `Contents/Resources/` first.
- `⌘⌃`+arrow pane focus now visits candidates in reading order instead of
  `Dictionary` hash order, so it lands on the same pane every time.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.3.1.dmg` and drag `Humi.app`
to Applications (`Humi-1.3.1.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.3.1.dmg)     = 9aa0a20fd41d6a9be2e8c987e4d4579c799c6e8a5864951546ce3db3e2a045ee
SHA-256 (Humi-1.3.1.app.zip) = 1ef60056a48935c220ca4fc9cb6d537ea8c17dc0bedb4f3d136bb813ee9f55bd
```
