# Humi v1.3.1 — テスト計画と精査結果

実施日: 2026-08-29 / 環境: macOS 26.5 (Apple Silicon), Command Line Tools, Swift 6.2.3

v1.3.1 は起動時クラッシュ 1 件のホットフィックス（+ フォーカス移動の決定性）。

---

## 1. 不具合と原因

`/Applications/Humi.app` を起動すると毎回 SIGTRAP（ウィンドウ表示前）。ターミナル直実行のスタック:

```
HumiKit/resource_bundle_accessor.swift:12: Fatal error: could not load resource bundle:
from /Applications/Humi.app/Humi_HumiKit.bundle
or  /Users/yuki/適当フォルダ/humi/.build/arm64-apple-macosx/release/Humi_HumiKit.bundle
```

`HumiApp.init()` → `Hum.registerFonts()` → `Bundle.module`。Command Line Tools ツールチェーンが
生成する `resource_bundle_accessor.swift` は最小版で、探索先が **2 つだけ**:

1. `Bundle.main.bundleURL/Humi_HumiKit.bundle`（`.app` の**直下**。`Contents/Resources/` ではない）
2. ビルドマシンの固定パス `…/.build/.../release/Humi_HumiKit.bundle`

`Scripts/build-app.sh` はリソースバンドルを `Contents/Resources/` に置くため 1 は一致せず、
2 はビルドマシンにしか無い（= 手元では偶然動いていた。配布先で必ず落ちる）。

## 2. 修正

- **`Sources/HumiKit/Core/HumiBundle.swift` 新規**: `Bundle.humiResources` — `Bundle.main.resourceURL`
  （= `Contents/Resources/`）→ `.app` 直下 → フレームワーク bundle の順で解決。存在チェック付き。
- `L10n.swift`（3 箇所）と `DesignSystem.swift`（`registerFonts`）の `Bundle.module` を
  `Bundle.humiResources` に置換。`Bundle.module` はもうどこからも参照しない（= lazy init が走らない）。
- `Scripts/build-app.sh`: バンドルは従来どおり `Contents/Resources/`（`codesign --deep` でシールできる
  標準配置）。`.app` 直下に置くと `codesign` が "bundle format unrecognized" で失敗するため。
  署名後に `codesign --verify` を出力。
- `PaneNode.focusNeighbor`: 候補を `Dictionary` の並び順ではなく `leaves()` の読み順で走査。
  スラックを rect サイズ相対（2%）に。`⌘⌃`+矢印の結果が実行ごとに変わる可能性を排除。

## 3. 検証

| # | 内容 | 結果 |
|---|---|---|
| 3-1 | `bash Scripts/test.sh` | ✅ 1464 / 1464（`paneNeighbor` フレーク 5 連続で解消） |
| 3-2 | `swift build -c release` / `build-app.sh` / `make-dmg.sh` | ✅ v1.3.1（警告 0、`codesign --verify` valid） |
| 3-3 | **クリーンマシン相当の再現テスト**: `.build/.../release/*.bundle` を退避 → `dist/Humi.app` を直実行 | ✅ 生存（従来はここで SIGTRAP） |
| 3-4 | `dist/Humi.app` 起動 → UI 表示、**日本語文字列 + Plus Jakarta Sans フォントが正しくロード** | ✅ 目視（`Bundle.humiResources` がフォント・`.lproj` 両方を解決） |
| 3-5 | CI（macos-15） | ⏳ push 後 |

## 4. 判定

**release 可。** 原因を実機で特定・修正・クリーンマシン相当で再現テスト済み。
