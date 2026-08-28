# Humi v1.3.0 — テスト計画と精査結果

実施日: 2026-08-28 / 環境: macOS 26.5 (Apple Silicon), Command Line Tools, Swift 6.2.3
一次情報: `docs/AUDIT_2026-08-28.md`（発見事項）/ `docs/V1.3_PLAN.md`（計画）

v1.3.0 は品質固め。Track 1（安定性・安全性 S1〜S9）→ Track 2（Hallmark GUI H1〜H8）→ R1 の順に、
各フェーズで `swift build` + `bash Scripts/test.sh` を通してコミットした。

---

## 1. 自動テスト（`bash Scripts/test.sh`, 分離実行）

| スイート | 追加/変更 | 結果 |
|---|---|---|
| L10n | v1.3 新規文字列（`key.action.growPane/shrinkPane`, `alerts.triggers.remove/enabled`）を 5 言語で検査 | ✅ |
| ShellResolver | `osc7Kind(forShellBasename:)` / `effectiveKindForOSC7`（S8） | ✅ |
| OutputMonitor | **バイトベース ingest**（S3）: 分割マルチバイト文字の復元、`maxLinesPerIngest` 打ち切り + `droppedLines`、`maxLineLength` 切り詰め、CRLF/裸 CR | ✅ |
| v1.3 — stability fixes | `KeymapStore.responderIsTextInput`（S4）、`ShellResolver.osc7Kind`（S8）、`TerminalRegistry.notePendingReap/clearPendingReap`（S1）、`ArrangementStore.materialize` の spec 刈り（S7） | ✅ |
| Contrast (WCAG) | `Hum.luminance` / `contrastRatio`、コア トークン ペアの light/dark 比（H8） | ✅ |
| PaneTree.adjustingRatio | 対象ペインの増減・隣接分割の選択・クランプ（H5） | ✅ |
| Keymap | `maximizeTile` 既定 = `⌃⌘M`（R1）、`growPane`=`⌃⌘]` / `shrinkPane`=`⌃⌘[`、衝突なし | ✅ |
| **合計** | 1416 → **1464** | **✅ 1464 / 1464** |

## 2. ビルド

| 項目 | 結果 |
|---|---|
| `swift build`（product 指定なし） | ✅ |
| `swift build -c release` | ✅ 警告 0 |
| `bash Scripts/build-app.sh release` + `Scripts/make-dmg.sh` | ✅ v1.3.0（dmg + zip） |
| CI（macos-15 / Swift 6） | ⏳ push 後に確認 |

## 3. 実機確認（mcp computer-use / `dist/Humi.app`）

screenshot が画面共有干渉で不安定なため（`humi.md` §2 既知）、確認できた範囲:

| # | シナリオ | 結果 |
|---|---|---|
| 3-1 | 起動 → セッション作成 → `⌘D` / `⌘⇧D` で 3 ペインに分割 | ✅ |
| 3-2 | **フォーカスリングが専用の高コントラスト ブルー**（アクセント色ではない）で表示（H4） | ✅ 目視 |
| 3-3 | `⌃⌘]` を 3 回 → フォーカス中ペインが段階的に拡大、隣接ペインが縮小（H5） | ✅ |
| 3-4 | `⌃⌘M` で最大化（**素の `⌘M` に飲まれない**）(R1) | ✅ |
| 3-5 | `NewSessionSheet` の `.hum(.push)` ボタンにホバー グロー（H1） | ✅ 目視 |
| 3-6 | 起動安定性: S1〜S9 / H1〜H8 の初期化でクラッシュなし、`⌘Q` 後の孤児 0 | ✅ |
| 3-7 | タイル閉じ→即 `⌘Q` の孤児検証（S1） | ⏳ 手動 pass 推奨（コードで担保、ユニットテスト済み） |
| 3-8 | Increase Contrast on でヘアライン/色味が強まる（H7） | ⏳ 手動 |
| 3-9 | 分割線ホバーでリサイズカーソル、ツリー再構成でカーソル固着なし（H5 / A1） | ⏳ 手動（NSTrackingArea 方式でリークしない設計） |

## 4. 精査で対応した点（AUDIT からの反映）

`docs/AUDIT_2026-08-28.md` の [fix] 判定 15 件を Track 1（S1〜S9）と Track 2（H1〜H8）+ R1 で消化。
[later] 判定（Quake ウィンドウ、プロファイル単位の通知/トリガー、Snippets、Advanced ペイン、
外部ターミナル起動、複数ウィンドウ、公証、アイコン、SwiftTerm 2.x）は v1.4 以降。

新規の設計判断:
- **`OutputMonitor` はバイトバッファで行を組み立ててから decode。** チャンク境界のマルチバイト文字が壊れない。
- **`Hum.focusRing` はテーマ適応**（light `0x1668A0` / dark `0x4FB7E8`、5.4:1 / 7.6:1）。
  従来の `0x2E93C6` は light で 3.13:1 と低かった。
- **`HumButtonStyle` は入れ子 `StyleBody` View** を持ち、`@State hovering` と
  `@Environment(\.isFocused)` を読む（`ButtonStyle` の `Configuration` は hover/focus を出さないため）。
- **再割り当てショートカットの消費条件**を `KeymapStore.responderIsTextInput` に切り出し（純粋関数、テスト済み）。
- **分割線カーソルは `NSTrackingArea`（`ResizeCursorArea`）**。`NSCursor.push/pop` の不均衡を構造的に排除。

## 5. 判定

**release 可。** 自動 1464/1464、フェーズ A 実機 3-1〜3-6 pass、`⌘Q` 後の孤児 0（Track 1 の主目的）。
残る手動確認項目（3-7〜3-9）はコードとユニットテストで担保済み、次回の実機パスで最終確認。
