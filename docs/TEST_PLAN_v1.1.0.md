# Humi v1.1.0 — テスト計画と精査結果

実施日: 2026-08-28 / 環境: macOS 26.5 (Apple Silicon), Command Line Tools, Swift 6.2.3

v1.1.0 は「多言語化 + 優先度 A/B の機能追加」。実装は 8 フェーズに分け、フェーズごとに
`swift build` + `bash Scripts/test.sh` + 実機確認を通してからコミットした。

---

## 1. 自動テスト（`bash Scripts/test.sh`, 分離実行）

| スイート | 内容 | 結果 |
|---|---|---|
| Persistence isolation | `HUMI_SUPPORT_DIR` で実 dir を触らない | ✅ |
| L10n | 5 言語ファイルのキー一致・プレースホルダ数一致・空値なし | ✅ |
| ShellResolver / startDirectory | シェル解決・home フォールバック | ✅ |
| Theme / HexColor / CursorSpec | 配色・カーソルの codec と SwiftTerm マッピング、部分 JSON の許容 | ✅ |
| ThemeStore.resolve | Light/Dark/System 解決、ファミリ選択で mode スナップ | ✅ |
| PathActioner | URL / path / `path:line` / 相対パス の分類 | ✅ |
| SessionLogger | `script` ラップ、ログファイル名の置換 | ✅ |
| Session codec | pre-1.1 セッションの復号、v1.1 フィールドのラウンドトリップ | ✅ |
| SessionStore.move | ドラッグ並べ替え | ✅ |
| Profile codec | プロファイルのラウンドトリップ、部分 JSON、env マージ | ✅ |
| Keymap | KeyChord codec / display、既定の網羅、衝突検出 | ✅ |
| GridLayout / SessionStore（既存） | | ✅ |
| **合計** | | **✅ 1072 / 1072** |

## 2. ビルド

| 項目 | 結果 |
|---|---|
| `swift build`（product 指定なし） | ✅ 成功（HumiTests を壊していない） |
| `swift build -c release` | ✅ 成功・Humi コードの警告 0 |
| `bash Scripts/build-app.sh release` → `dist/Humi.app` + ad-hoc 署名 | ✅ v1.1.0 |
| CI（macos-15 / Swift 6） | ✅ 緑（`swift build` / self-tests / assemble / verify） |

## 3. 実機確認（mcp computer-use）

| # | シナリオ | 結果 |
|---|---|---|
| 3-1 | 多言語: OS=English で自動的に英語表示、設定の言語ピッカーで ja→es を**再起動なし**で切替。ja/en/es の各ペインを目視、キー欠落・見切れなし | ✅ |
| 3-2 | テーマ: Nord を選ぶと全ターミナル + アプリクロームが即ダーク化。Light/Dark/System 切替、ANSI・カーソルの反映 | ✅ |
| 3-3 | `⌘F` 検索: "alpha" で 6 件 → Enter で 2/6・当該一致をハイライト | ✅ |
| 3-4 | タイル右クリックメニュー: 名前変更 / 色（coral に変更 → アクセント即反映・永続）/ 終了時の動作 / ログ / 選択を開く / 閉じる | ✅ |
| 3-5 | プロファイル: ランチャーから起動 → タイトル=プロファイル名、起動コマンド実行、注入 env（`HUMI_PROFILE_TEST=yes`）反映、プロファイルのテーマ適用 | ✅ |
| 3-6 | ショートカット: Find を `⇧⌘E` に再割り当て → レコーダ表示更新 + `keymap.json` に永続 | ✅ |
| 3-7 | ステータスバー: `cd <repo>` でタイトル "humi"、バーに `~/…/humi · zsh · feat/v1.1.0 ●(dirty) · 時刻` | ✅ |
| 3-8 | 設定の永続: themes(active/mode/custom) / keymap / profiles(+default) / 各スカラー（言語・optionAsMeta・bell・confirmClose）が 起動→終了 サイクルで保持 | ✅ |

## 4. 安定性・メモリ・CPU

| 項目 | 結果 |
|---|---|
| アイドル CPU（4 セッション + ステータスバー ON + 12s Git tick + OSC7 注入） | **0.0%**（20 秒連続）。`sample` にホットパスなし |
| RSS | 0 セッション 102MB / 4 セッション 139MB（≈ 9MB/セッション） |
| スレッド / FD | 4 / 58〜71（安定） |
| 子プロセス数 == セッション数 | ✅ 4 == 4、ゾンビ・孤児なし |
| `⌘Q` 終了（4 セッション + Git サブプロセス走行中） | ✅ ~0.2s で完全終了、孤児 `-zsh` 0、`git -C` の残留 0 |

## 5. 精査で対応した点（フェーズ内で修正・再検証済み）

- SwiftPM が `.lproj` の地域サフィックスを小文字化（`zh-Hans` → `zh-hans`）→ バンドル探索を大小無視に。
- テーマ「モード」と「ファミリ選択」の UX が噛み合わず → ファミリ選択で `mode` をそのテーマの外観へスナップ。
- `⌘F` が検索バーにフォーカスが移ると対象ターミナルを見失う → `HumiTerminalView.mouseDown` で「最後に触ったターミナル」を記録し `focusedController()` がフォールバック。
- OSC 7 のペイロードが `file://host/path` のまま `currentDirectory` に入り Git 照会が失敗 → `normalizeDirectory` でプレーンパスへ。
- OSC 7 注入で `$HOME` にいるセッションのタイトルがユーザ名になる → home は自動タイトル（ローカライズ既定）を維持。
- RootView の body が型チェック不能になるほど肥大 → 全アクションを 1 本の Merge publisher + `handle(_:)` に集約。

## 6. 既知の制限 / v1.2 へ先送り（`humi.md` にロードマップ化）

- 分割ペイン（ペインツリー）、ウィンドウ配置（Arrangement）、グローバルホットキー / Quake ウィンドウ、
  通知マトリクス、正規表現トリガー。
- ショートカット変更はメニュー表示への反映にアプリ再起動が必要（SwiftUI Scene の再評価）。動作自体は保存済み。
- ステータスバーの Git / cwd は OSC 7 に依存（zsh/bash は注入で対応、fish/カスタムは未対応）。
- Developer ID 署名・公証は未対応（ad-hoc）。アプリアイコン未同梱。

## 7. 判定

**release 可。** 自動 1072/1072、実機 3-1〜3-8 全 pass、アイドル CPU 0.0%、`⌘Q` 後の孤児 0、
全永続ストアのラウンドトリップ確認。優先度 A + ステータスバー(優先度 B) を収録し、残る優先度 B の
重量級項目は v1.2 ロードマップへ明記して先送り。
