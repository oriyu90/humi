# Humi v1.4.0 — テスト計画と精査結果

実施日: 2026-09-01 / 環境: macOS 15 系 (Apple Silicon), Xcode toolchain, Swift 6.3.3

v1.4.0 はメモ欄のタブ化 + ZIP 入出力 + 編集/プレビューのスクロール保持 + 設定ウィンドウの
Light/Dark 追従。ターミナル本体（PTY・ペインツリー・永続化）には手を入れていない。

---

## 1. 変更点

| 種別 | 内容 | 主な変更ファイル |
|---|---|---|
| 追加 | `NoteDoc`（id/title/text/timestamps）と、`notes: [NoteDoc]` + `activeID` を持つ `NotesStore` の書き直し。`notes.json` に保存。旧 `notes.md` を初回起動時に 1 件へ移行。 | `Core/NotesStore.swift` |
| 追加 | `NotesArchive` — `/usr/bin/ditto` で ZIP を作成/展開。`manifest.json` + `NN--slug.md`。手動の loose `.md` ZIP もフォールバックで読める。 | `Core/NotesArchive.swift` |
| 追加 | タブ UI 全面書き直し（ホームタブ + 各メモタブ、`×` 削除は確認ダイアログ、ホームでリネーム/作成/ZIP 入出力）。 | `UI/NotesSidebarView.swift` |
| 追加 | `NotesEditor`（`NSTextView`）/ `TrackingScroll`（SwiftUI ホスト）+ `ScrollSync` — 正規化スクロール位置を共有し、編集⇄プレビューで維持。 | `UI/NotesScroll.swift` |
| 変更 | `MarkdownView` から `MarkdownBlocks`（スクロール無し本体）を分離。`TrackingScroll` に入れる。 | `UI/MarkdownView.swift` |
| 修正 | `SettingsAppearanceSync` を追加。開いている設定ウィンドウの `NSWindow.appearance` を毎更新で在り方に合わせる。 | `UI/SettingsView.swift` |
| 追加 | L10n キー 14 種 × 5 言語。 | `Resources/*.lproj/Localizable.strings` |

## 2. マージ規則（インポート、オーナー指定）

incoming の各メモについて:
- 既存に **id と title が両方一致**するものがあれば → その場で置き換え（インポート優先）。
- id は一致するが title が違う → 新しい id を振って追加。
- どちらも該当なし → id を保持したまま追加（同一端末からの再インポートで重複しない）。

## 3. 検証

| # | 内容 | 結果 |
|---|---|---|
| 3-1 | `bash Scripts/test.sh` | ✅ 1560 / 1560（新 `Notes` スイート 16 + L10n パリティ +70） |
| 3-2 | `Notes` スイート: NoteDoc デコード既定値 / Disk round-trip / merge 3 分岐 / 重複 id なし / `NotesArchive` export→read（ditto 実行）/ slug | ✅ |
| 3-3 | `swift build -c release` | ✅ 警告 0 |
| 3-4 | `build-app.sh release` / `make-dmg.sh` / `codesign --verify` | ✅ v1.4.0、valid |
| 3-5 | 目視: タブ作成 → 3 タブ、`×` で確認ダイアログ → 削除、ホームでリネーム（「Claude Code用」）が反映 | ✅ |
| 3-6 | 目視: 編集で中ほどまでスクロール → プレビューへ切替 → ほぼ同じ位置。戻しても同じ位置。メモ切替で先頭へ | ✅ |
| 3-7 | ZIP 書き出し → 中身確認（`manifest.json` + `01--Claude-Code.md`、CJK タイトルは manifest に保持、slug は ASCII） | ✅ |
| 3-8 | 同じ ZIP を再インポート → タブは増えず置き換え（id+title 一致）。別 id の ZIP → 新タブ追加。`__MACOSX` 入りの手製 ZIP も読める | ✅ |
| 3-9 | 起動 → 終了 → 再起動でタブ・本文・アクティブタブが復元 | ✅ |
| 3-10 | 設定を開いたまま Light/Dark 切替 → 設定ウィンドウも即時に反転（1.3.2 の既知問題を修正） | ✅ |
| 3-11 | 旧 `notes.md`（非空）だけがある状態から起動 → 1 件のメモへ移行 | ✅（コード経路確認。空 md では新規シード 1 件） |
| 3-12 | CI（macos-15） | ⏳ push 後 |

## 4. 判定

**release 可。** 追加は notes 周辺に限局。self-test 全パス、ditto 経由の ZIP round-trip も CI で走る。
編集/プレビューのスクロール保持は「だいたい同じ位置」（高さが変わるため厳密一致ではない）で仕様どおり。
