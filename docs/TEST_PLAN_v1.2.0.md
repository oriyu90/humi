# Humi v1.2.0 — テスト計画と精査結果

実施日: 2026-08-28 / 環境: macOS 26.5 (Apple Silicon), Command Line Tools, Swift 6.2.3

v1.2.0 は「分割ペイン（ペインツリー）とその上に乗る機能群」。フェーズ A（A-1〜A-5）→ B → C →
D/E → F の順に、各フェーズで `swift build` + `bash Scripts/test.sh` + 実機確認を通してコミットした。

---

## 1. 自動テスト（`bash Scripts/test.sh`, 分離実行）

| スイート | 内容 | 結果 |
|---|---|---|
| Persistence isolation | `HUMI_SUPPORT_DIR` で実 dir を触らない | ✅ |
| L10n | 5 言語ファイルのキー一致・プレースホルダ数一致・空値なし（v1.2 新規文字列含む） | ✅ |
| ShellResolver / startDirectory / **OSC 7（fish 追加）** | シェル解決・home フォールバック・fish の `fish_prompt` 関数 | ✅ |
| Theme / ThemeStore | 配色・カーソルの codec、Light/Dark/System 解決 | ✅ |
| PathActioner / SessionLogger / Profile / Keymap | 既存の pure ロジック | ✅ |
| **PaneTree** | leaves / contains / depth / insert（同軸合流・交差ネスト）/ remove（単一子畳み）/ swap / setRatio（クランプ・ペア和保存）/ equalized / normalized / frames（min フロア）/ focusNeighbor（2×2 グリッド・端）/ dividers / settingRatio(at:) / 判別式 Codable（欠損 ratios 許容） | ✅ 64+ |
| **SessionStore.layout** | 初回 leaf → flat row、split(besideLeaf:axis:)、swapPanes、paneNeighbor、setPaneRatio、equalizeSplits、close 畳み、closeAll | ✅ |
| **SessionStore migration** | 旧トップレベル `[Session]` 配列 → 1 列 layout 合成、`{sessions,layout}` ラウンドトリップ、reconcile（未知 leaf の除去・孤児 session の追加） | ✅ |
| **Arrangement** | snapshot（nil layout → nil）、materialize（新規 UUID・非衝突）、Codable、ArrangementStore CRUD（同名上書き）、`SessionStore.load` | ✅ |
| **HotKeyCenter** | KeyChord → Carbon keycode / modifier マスク、未対応キー → nil、`AppSettings.globalHotkeyChord` の JSON 永続 | ✅ |
| **OutputMonitor** | ANSI（CSI/OSC）除去、チャンク跨ぎの行組み立て、CRLF/裸 CR 分割 | ✅ |
| **Trigger / TriggerEngine** | コンパイル済み regex マッチ、無効行・非コンパイル行の除外、flat action の Codable、`AppSettings.triggers` の JSON 永続 | ✅ |
| **合計** | | **✅ 1400 / 1400** |

## 2. ビルド

| 項目 | 結果 |
|---|---|
| `swift build`（product 指定なし） | ✅ 成功（HumiTests を壊していない） |
| `swift build -c release` | ✅ 成功・Humi コードの警告 0 |
| `bash Scripts/build-app.sh release` → `dist/Humi.app` + ad-hoc 署名 | ✅ v1.2.0 |
| CI（macos-15 / Swift 6） | ⏳ push 後に確認 |

## 3. 実機確認（mcp computer-use / `dist/Humi.app`）

フェーズ A（分割ペイン）は対話操作で全項目を確認。B〜F は screenshot が
`SCContentFilter failure` で不安定だったため（`humi.md` §2 既知）、起動安定性 +
ユニットテスト主体で確認した。

| # | シナリオ | 結果 |
|---|---|---|
| 3-1 | 空状態から最初のセッション作成 → 単一ペインが全域を占める | ✅ |
| 3-2 | `⌘D` 左右分割 / `⌘⇧D` 上下分割（ネスト含む）。新ペインは対象の隣、シェルは同 cwd | ✅ |
| 3-3 | `⌘⌃←→↑↓` 方向フォーカス移動。ネスト分割の境界を跨いで移動、フォーカスリングが追従 | ✅ |
| 3-4 | 分割線ドラッグでリサイズ。端末が再フローし空ペインなし。`⌘⌥=` で均等化 | ✅ |
| 3-5 | ペインのクローズで空いたネスト分割が畳まれる | ✅ |
| 3-6 | タイルボタンで maximize / restore | ✅ |
| 3-7 | `⌘Q` → 再起動でペインツリーが復元（`sessions.json` が `{sessions, layout}` 形式で保存） | ✅ |
| 3-8 | 起動: HotKeyCenter / HumiNotifier / KeymapStore ローカルモニタ / 全 v1.2 設定既定 の初期化でクラッシュなし | ✅ |
| 3-9 | `⌘Q` 後の孤児プロセス 0、孤児シェル 0 | ✅ |

## 4. 安定性

| 項目 | 結果 |
|---|---|
| クリーン起動（多ペイン layout の復元含む） | ✅ クラッシュなし |
| `⌘Q` 終了 | ✅ 完全終了、孤児 `-zsh` / `login` 0 |
| アイドルで回るアニメ / タイマーの追加 | なし（分割線ドラッグ中のみ更新。通知の出力監視は watcher があるときだけ接続） |

## 5. 設計判断・精査で対応した点

- **`PaneTreeView` は絶対配置 ZStack**。`layout.frames(in:gap:)` から各葉を `.position` で配置し、
  葉ごとに安定した `.id(session.id)` を付ける。ツリー再構成で端末 NSView が作り直されない。
- **`focusNeighbor` は「最近傍 → 重なり大」でタイブレーク**。当初「重なり最大」優先だと全高の葉が
  隣接列より優先されてしまい、隣のペインへ移れなかった（ユニットテストで検出・修正）。
- **`sessions.json` の後方互換**。`loadFile()` が `{sessions,layout}` を試し、失敗したら旧
  トップレベル `[Session]` 配列を読んで 1 列 layout を合成。`reconcile()` でツリーと
  レジストリが食い違わないよう常に整える。
- **Arrangement の葉 id はローカル**。`materialize` で新規 UUID に振り直すため、復元した配置が
  既存セッションと衝突しない。
- **グローバルホットキーは Carbon**（`RegisterEventHotKey`）。アクセシビリティ許可不要。
  登録失敗（衝突・未対応キー）は設定 UI に注記を出す。
- **出力監視フックは `dataReceived(slice:)` の override**（SwiftTerm 1.20 で `open`）。
  watch 文字列もトリガーも無いときは `onOutput` を張らない＝アイドルコスト 0。
- **再割り当てしたショートカットの即時反映は `NSEvent` ローカルモニタ**。既定値のままの
  チョードはメニュー（`.commands`）に任せて二重発火を避ける。メニュー表示の更新は従来どおり再起動が必要。
- `RootView.handle` の引数を `Notification.Name` から `Notification` に変更（配置復元で `object` の
  arrangement id を読むため）。

## 6. 既知の制限 / v1.3 以降へ

- Quake（ドロップダウン）ウィンドウは未実装（グローバルホットキーは MVP: activate / hide トグルのみ）。
- 通知・トリガーはグローバル設定（プロファイル単位ではない）。Snippets、設定 Import/Export/Reset、
  外部ターミナル起動オプションの復帰は未着手（`humi.md` のロードマップに残す）。
- ショートカット変更のメニュー表示反映は依然アプリ再起動が必要（動作は即時）。
- `⌘M`（tile 最大化の既定）は macOS のウィンドウ最小化に飲まれる。タイルの最大化ボタンは正常。
- Developer ID 署名・公証は未対応（ad-hoc）。アプリアイコン未同梱。

## 7. 判定

**release 可。** 自動 1400/1400、フェーズ A の実機シナリオ 3-1〜3-7 全 pass、起動安定性 3-8/3-9、
`⌘Q` 後の孤児 0、`{sessions,layout}` のラウンドトリップ確認。B〜F は追加的な機能で、pure ロジックは
ユニットテストで厚く覆っている。
