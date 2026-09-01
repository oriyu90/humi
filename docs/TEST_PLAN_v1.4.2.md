# Humi v1.4.2 — テスト計画と精査結果

実施日: 2026-09-02 / 環境: macOS 15 系 (Apple Silicon), Xcode toolchain, Swift 6.3.3

新規セッションフローの修正 2 件 + タイトルバー二重表示の修正。3 ファイル、行数は小さい。

---

## 1. 変更点

| 種別 | 内容 | ファイル |
|---|---|---|
| 変更 | `+` を押した時に問答無用で `NSOpenPanel` を出すのをやめ、選択シートを先に出す。フォルダ選択は `NewSessionSheet` 内の `.fileImporter([.folder])`。`NewSessionSheet` が `@State folder` を自分で持つ（旧: `RootView` が `pendingFolder` を渡す）。`RootView` から `runFolderPanel()` / `pendingFolder` / `onPickFolder` 経路を削除。 | `RootView.swift` / `NewSessionSheet.swift` |
| 修正 | フォルダを選んでもホームで開くことがある。原因は旧フローの「シートを閉じる → `NSOpenPanel.runModal` → シートを開き直す」の競合で、選んだパスが `onCreate` に届かないことがあったため。`.fileImporter` はシートを開いたまま提示され、`folder` は `NewSessionSheet` の `@State` なので競合しない。 | 同上 |
| 修正 | シート／`.fileImporter` を使ったあと、タイトルバーに「Humi」が二重表示される（ツールバーのブランドマーク + OS タイトル文字）。SwiftUI が sheet の提示/解除まわりで `titleVisibility` を戻すため `TitleTextHider` の再適用が間に合わないことがある。ウィンドウを `.windowStyle(.hiddenTitleBar)` にして OS タイトル文字自体を無くした。`TitleTextHider` は保険として残置。 | `HumiApp.swift` |
| 整理 | 未使用になった `panel.choose` / `panel.message` を 5 言語から削除。 | `Resources/*.lproj` |

## 2. 静的デバッグ（コードレビュー）

- `.fileImporter(isPresented:allowedContentTypes:[.folder]:allowsMultipleSelection:false)` の結果は
  `Result<[URL], Error>`。`if case let .success(urls) = result, let url = urls.first { folder = url.path }`。
  キャンセル時（`.failure` / 空）は `folder` 不変。→ OK。
- Humi は**非サンドボックス**（ad-hoc 署名・entitlements なし）。`.fileImporter` が返す URL の
  `.path` はそのままファイルシステム API に使える。security-scoped の `startAccessing…` は不要。
  実機で `pwd` が選択フォルダを返すことを確認。
- `RootView` に `runFolderPanel` / `pendingFolder` の残参照なし（grep 0）。`import AppKit` は
  他用途（`NSApp` 等）で引き続き必要なので残す。
- `.windowStyle(.hiddenTitleBar)` はタイトルバー**文字**を消すが、`Window("Humi", …)` のタイトル文字列は
  ウィンドウメニュー / Mission Control 用に残る。信号機ボタンは従来どおり。ツールバー先頭の
  ブランドマークは信号機の右に自動でインセットされる（目視確認済み、重なりなし）。
- `panel.*` キーはコード参照ゼロ（`grep -rn` 済み）。5 言語から同時削除でパリティ維持。

## 3. 検証

| # | 内容 | 結果 |
|---|---|---|
| 3-1 | `bash Scripts/test.sh` | ✅ 1552 / 1552（`panel.*` 削除で L10n パリティ −10） |
| 3-2 | `swift build -c release` | ✅ 警告 0 |
| 3-3 | `build-app.sh release` / `make-dmg.sh` / `codesign --verify` | ✅ v1.4.2、valid |
| 3-4 | `+` / 空状態ボタン → **フォルダパネルは出ず**、選択シートが直接出る | ✅ |
| 3-5 | 「フォルダを選択…」→ `work` へ入り `humi` を選択 → 「このフォルダで開く」→ セッションの `pwd` が `…/work/humi` | ✅ |
| 3-6 | 「そのまま開く（ホーム）」→ ホームで開く | ✅ |
| 3-7 | シート／fileImporter 使用後にタイトルバーの「Humi」が二重にならない | ✅（`.hiddenTitleBar` で解消） |
| 3-8 | CI（macos-15） | ⏳ push 後 |

## 4. 判定

**release 可。** 変更は new-session フローに限局。静的レビューと実機フローで両報告事項の解消を確認、
副次的に見つかったタイトル二重表示も修正。self-test 全パス。
