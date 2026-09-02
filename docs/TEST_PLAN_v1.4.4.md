# Humi v1.4.4 — テスト計画と精査結果

実施日: 2026-09-02 / 環境: macOS 15 系 (Apple Silicon), Xcode toolchain, Swift 6.3.3

メニューバーの多言語対応 + `+` の分割軸を可変に。

---

## 1. 変更点

| 種別 | 内容 | ファイル |
|---|---|---|
| 修正 | `build-app.sh` の Info.plist に `CFBundleDevelopmentRegion` = `en` と `CFBundleLocalizations`（en/ja/zh-Hans/pt-BR/es）を追加。さらに `Contents/Resources/<lang>.lproj/` の空ディレクトリを作成。これで AppKit/SwiftUI が**メインバンドル**をローカライズ済みとみなし、標準メニュー（ファイル/編集/表示/ウインドウ/ヘルプ、切り取り/コピー/ペースト、Humi について/隠す/終了 等）を言語に合わせる。Humi 独自項目は元から `L(...)`。 | `Scripts/build-app.sh` |
| 変更 | `SessionStore.add(...)` に `paneAreaSize: CGSize` を追加。`nonisolated static func appendAxis(for:in:paneAreaSize:)` が分割対象ペインの実 rect を `layout.frames(in:)` で求め、`min(w/2, h)`（新列）と `min(w, h/2)`（新行）の大きい方の軸を選ぶ。size 不明時は従来どおり `.horizontal`。`⌘D` / `⌘⇧D`（`split(besideLeaf:axis:)`）は不変。 | `Core/SessionStore.swift` |
| 変更 | `PaneTreeView` に `onPaneAreaSize: (CGSize) -> Void`。`.background(GeometryReader)` でペイン領域サイズを RootView に渡す。 | `UI/PaneTreeView.swift` |
| 変更 | `RootView`: `@State paneAreaSize` を保持し、3 つの `store.add(...)` 呼び出し（ツールバーのプロファイルメニュー / 新規セッションシート / `humiProfileLauncher`）へ渡す。 | `UI/RootView.swift` |

## 2. 精査（コードレビュー）

- `appendAxis` は純関数（引数のみ依存）なので `nonisolated` に指定。`SessionStore` は
  `@MainActor` だがこの static は self-test（非分離文脈）からも呼べる。
- `paneAreaSize` 既定値 `.zero` → 既存呼び出し・`split()` は完全に従来動作。互換性 OK。
- `frames(in:gap:)` に渡す gap は `Hum.Space.md`（= 16、レンダラと同じ）。軸判定なので厳密さは不要。
- `CFBundleLocalizations` は `Humi_HumiKit.bundle` の `.lproj`（`L()` の解決元）とは独立。
  `Localization` / `L10n` self-test への影響なし。空 `.lproj` は `codesign --deep` でも無害。
- `onPaneAreaSize` の `GeometryReader` は `.background` 配置なのでレイアウトに影響しない。
  空状態（セッション 0 件）でも size が届く。最初の 1 セッション目は軸不問（単一 leaf）。

## 3. 検証

| # | 内容 | 結果 |
|---|---|---|
| 3-1 | `bash Scripts/test.sh` | ✅ 1561 / 1561（`appendAxis` 6 ケース追加） |
| 3-2 | `appendAxis`: 縦長 260×900 → `.vertical` / 横長 1300×320 → `.horizontal` / 正方 600×600 → `.horizontal` / `.zero` → `.horizontal` / 2 列（広）→ `.horizontal` / 2 列（狭）→ `.vertical` | ✅ 全パス |
| 3-3 | `swift build -c release` | ✅ 警告 0 |
| 3-4 | `build-app.sh` → Info.plist に `CFBundleLocalizations`、`Contents/Resources/{en,ja,zh-Hans,pt-BR,es}.lproj` 生成 | ✅ |
| 3-5 | 目視: OS 日本語で起動 → メニューバーが「Humi ファイル 編集 表示 ウインドウ ヘルプ」。編集メニュー = 取り消す/やり直す/カット/コピー/ペースト/削除/すべてを選択 + Humi 項目（バッファをクリア/検索…/セッションを閉じる/セッションを再起動）すべて日本語 | ✅ |
| 3-6 | 目視: ほぼ正方のペインで `+` → **上下**分割。下段が横長になった状態で `+` → 下段が**左右**分割 | ✅ |
| 3-7 | CI（macos-15） | ⏳ push 後 |

## 4. 判定

**release 可。** メニュー多言語化は Info.plist の宣言のみ（挙動リスク低）、分割軸は既定引数で
完全後方互換。実データ相当の geometry で上下/左右の切り替わりを目視確認。self-test 全パス。
