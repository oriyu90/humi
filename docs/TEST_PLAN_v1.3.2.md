# Humi v1.3.2 — テスト計画と精査結果

実施日: 2026-09-01 / 環境: macOS 15 系 (Apple Silicon), Xcode toolchain, Swift 6.3.3

v1.3.2 はメモ欄の小機能追加（コードブロックのコピー）＋ UI 修正 3 件。機能内部（PTY・
永続化・ペインツリー）には手を入れていない。

---

## 1. 変更点

| 種別 | 内容 | 主な変更ファイル |
|---|---|---|
| 追加 | メモのプレビューで、フェンス付きコードブロックにコピーボタン。`CodeBlockView` を新設し、`MarkdownView` の `.code` ケースがこれを描画。ボタンはコード上部の帯に置き、選択可能テキストには重ねない（macOS の text-interaction がクリックを吸うため）。 | `Sources/HumiKit/UI/MarkdownView.swift` |
| 追加 | 文字列 `notes.copy_code` / `notes.code_copied` を 5 言語へ。 | `Sources/HumiKit/Resources/*.lproj/Localizable.strings` |
| 修正 | ウィンドウの「Humi」二重表示。`RootView` に `TitleTextHider`（`NSViewRepresentable`）を追加し、`updateNSView` で毎回 `titleVisibility = .hidden` を再適用。SwiftUI がシーン更新で `.visible` に戻すため一度きりでは不十分だった。 | `Sources/HumiKit/UI/RootView.swift` |
| 修正 | 新規セッションシートのフォルダ行がプレースホルダを中央省略。パス `Text` に `.layoutPriority(1)`、シート幅 480 → 520。 | `Sources/HumiKit/UI/NewSessionSheet.swift` |
| 修正 | メモの「編集／プレビュー」セグメントが固定幅 150pt で pt/es を見切れ。`.frame(width: 150)` → `.fixedSize()`。 | `Sources/HumiKit/UI/NotesSidebarView.swift` |

## 2. 検証

| # | 内容 | 結果 |
|---|---|---|
| 2-1 | `bash Scripts/test.sh` | ✅ 1474 / 1474（新 L10n キー 2 種 × 5 言語のパリティ検査 +10） |
| 2-2 | `swift build -c release` | ✅ 警告 0 |
| 2-3 | `bash Scripts/build-app.sh release` / `make-dmg.sh` / `codesign --verify` | ✅ v1.3.2、valid |
| 2-4 | `dist/Humi.app` 起動 → ウィンドウ上部の「Humi」は **1 つだけ**（空状態・セッション有り・分割後のいずれでも） | ✅ 目視（ライト／ダーク両方） |
| 2-5 | メモ → プレビュー → コードブロックのコピーボタン押下 → クリップボードにブロック本文（末尾改行なし）、表示が「コピーしました ✓」へ一時変化 | ✅ クリップボード実値で確認 |
| 2-6 | 新規セッションシート → フォルダ行の「フォルダ未選択（ホームで開く）」が省略されず全表示 | ✅ 目視 |
| 2-7 | メモの「編集／プレビュー」切替が全言語で見切れなし | ✅ ja/en 目視、pt/es は幅計算上収まる |
| 2-8 | `⌘D` 分割、タイル最大化、設定各タブ遷移、ライト⇄ダーク切替に回帰なし | ✅ 目視 |
| 2-9 | CI（macos-15） | ⏳ push 後 |

## 3. 既知の制限（今回対象外）

- アプリの Light/Dark モードを切り替えても、**開いたままの設定ウィンドウ**が追従しないことがある
  （SwiftUI の `Settings` シーンで `.preferredColorScheme` が sticky になる既知の癖）。
  リリース直前の設定シーン改変はリスクが高いため見送り。再オープンで正しくなる。

## 4. 判定

**release 可。** 追加は局所的、修正 3 件はいずれも目視で回帰なしを確認。self-test 全パス。
