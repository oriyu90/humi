# Humi v1.4.1 — テスト計画と精査結果

実施日: 2026-09-01 / 環境: macOS 15 系 (Apple Silicon), Xcode toolchain, Swift 6.3.3

v1.4.0 で入ったタブ式メモの**データ消失バグ**のホットフィックス。1 ファイルの構造修正 +
永続化のガード 1 件。

---

## 1. 不具合

タブが 2 つ以上ある状態で、片方のタブに切り替えてから編集すると、**もう片方のメモの本文が
編集中タブの内容でまるごと置き換わる**。ユーザー報告では `##` を打ってから `#` の後ろに
スペースを入れた時に顕在化（＝通常のキー入力で毎回発生していた）。

### 原因

`NotesSidebarView.noteTab` は `if settings.notesPreview { ... } else { NotesEditor(...) }` を
構造上同じ位置に置いており、`activeID` が変わっても SwiftUI は `NotesEditor`（`NSViewRepresentable`）
を**使い回して** `updateNSView` を呼ぶ。`Coordinator` は生成時の `parent`（＝最初のノートの
`textBinding`）を保持し続け、`textDidChange` が `parent.text = s` でその**最初のノート**へ全文を
書き込んでいた。タブ切替後の最初の編集で、表示中ノートの全文が旧ノートへ上書きされる。

## 2. 修正

- `NotesSidebarView`: エディタとプレビューに **`.id(note.id)`** を付与。ノートが変われば
  SwiftUI が破棄→再生成し、`makeNSView` が正しい初期テキスト・新しい `Coordinator`・新しい
  `ScrollSync` で作り直す（スクロール位置が先頭に戻る挙動も自然に得られる）。
- `NotesEditor`: `Coordinator.parent` を `var` にし、`updateNSView` の先頭で
  `context.coordinator.parent = self` を実行（多重防御）。`textDidChange` は
  `let current = parent` でその時点のバインディングをスナップショットしてから async 書き込み。
- `NotesStore.init`: `notes.json` が**空配列**でデコードされた場合も seed 経路に落ちるよう
  `!d.notes.isEmpty` を条件に追加。サイドバーが「メモ 0 件」で固まるのを防ぐ。

## 3. 検証

| # | 内容 | 結果 |
|---|---|---|
| 3-1 | `bash Scripts/test.sh` | ✅ 1562 / 1562（`textBinding` 分離チェック +2） |
| 3-2 | `swift build -c release` | ✅ 警告 0 |
| 3-3 | `build-app.sh release` / `make-dmg.sh` / `codesign --verify` | ✅ v1.4.1、valid |
| 3-4 | 目視: AAA / BBB の 2 タブ。AAA に切替 → 先頭へ `## Heading text` を挿入 → BBB に切替 → BBB は元のまま（上書きなし） | ✅ |
| 3-5 | 目視: BBB に切替 → 先頭へ `## B-heading` 挿入 → AAA に切替 → AAA は `## Heading text` 版のまま | ✅ |
| 3-6 | 目視: AAA でプレビュー⇄編集トグル後に編集 → BBB 無傷 | ✅ |
| 3-7 | 目視: select-all → 全置換を各タブで繰り返し、相互汚染なし | ✅ |
| 3-8 | `{ "notes": [] }` を置いて起動 → メモ 1 件が seed される | ✅ |
| 3-9 | CI（macos-15） | ⏳ push 後 |

## 4. 判定

**release 可（ホットフィックス）。** データ消失の回帰なので即時リリース。原因を特定し、
`.id` による再生成 + coordinator バインディング更新の二重で対処。相互汚染なしを複数パターンで確認。
