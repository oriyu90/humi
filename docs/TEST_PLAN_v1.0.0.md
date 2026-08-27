# Humi v1.0.0 — テスト計画と精査結果

実施日: 2026-08-27 / 環境: macOS 26.5 (Apple Silicon), Command Line Tools, Swift 6.2.3

リリース前に「動作の安定性・メモリ安全性・UI の完全性」の観点で精査し、
検出した問題をプラン化して修正したうえで release へ移る（オーナー方針）。

---

## 1. 自動テスト（`bash Scripts/test.sh`）

`XCTest` / `swift-testing` は CLT に無いため依存なしの実行ファイルで検証。

| スイート | 内容 | 結果 |
|---|---|---|
| ShellResolver | login/zsh/bash/fish/custom の実行ファイル・argv・argv0 解決、子環境変数 | ✅ 12 |
| ShellResolver.startDirectory | 消えたフォルダ / ファイル指定 / nil → home フォールバック | ✅ 5 |
| Persistence | Session 配列の JSON ラウンドトリップ、欠損ファイル → nil | ✅ 5 |
| GridLayout | 列数計算、行チャンク分割の境界 | ✅ 6 |
| SessionStore | 追加・アクセント回転・最大化トグル・終了コード・クローズ | ✅ 7 |
| **合計** | | **✅ 35 / 35** |

## 2. ビルド

| 項目 | 結果 |
|---|---|
| `swift build`（product 指定なし） | ✅ 成功（修正前は HumiTests のコンパイルで失敗） |
| `swift build -c release`（product 指定なし） | ✅ 成功 |
| `swift build -c release --product Humi` の警告 | ✅ 0 件（Humi コード） |
| `bash Scripts/build-app.sh release` → `dist/Humi.app` 生成 + ad-hoc 署名 | ✅ v1.0.0 |

## 3. 手動・実機確認

| # | シナリオ | 期待 | 結果 |
|---|---|---|---|
| 3-1 | 起動（セッション 0 件） | 空状態 + 大きな `+`、メモ欄復元 | ✅ |
| 3-2 | ツールバー `+` → Finder フォルダ選択 → 「このフォルダで開く」 | 選択フォルダを cwd にしたタイルが出現、タイトル = フォルダ名 | ✅（`~/Documents/KiCad`） |
| 3-3 | `+` →「そのまま開く（ホーム）」 | home で開くタイル | ✅ |
| 3-4 | タイル内でコマンド実行 | `echo` / `pwd` / `date` が正しく出力 | ✅ |
| 3-5 | 複数セッション | 追加順にタイルがリフロー、各タイル独立動作、アクセント色が回る | ✅（2 枚を縦積み確認） |
| 3-6 | `⌘K` | フォーカス中タイルの画面クリア + スクロールバック破棄、プロンプトと入力中コマンドは保持 | ✅ |
| 3-7 | 復元セッションのフォルダが削除済み | 起動失敗せず home で開く | ✅（"gone" タイルが home で起動） |
| 3-8 | メモ欄に追記 → アプリ再起動 | 追記が残る | ✅ |
| 3-9 | `⌘Q` で終了 | 子シェルが残らない（orphan / launchd 再ペアレント無し） | ✅ |
| 3-10 | 個別タイルの `✕` | セッション削除、子プロセス回収、exit code クリア | ✅（コード確認 + orphan 無し） |

## 4. 精査で検出した問題と修正（must-fix）

| # | 分類 | 問題 | 修正 | 検証 |
|---|---|---|---|---|
| 1 | ビルド | `swift build`（product 指定なし）が HumiTests の `-enable-testing` 欠如で失敗。CI・貢献者が詰まる | HumiKit / HumiTests の `-enable-testing` を無条件化 | §2 |
| 2 | スコープ | 「v1.0 内蔵のみ」方針に反し外部ターミナル UI が 3 箇所生きていた | NewSessionSheet 副ボタン / タイルボタン / 設定ピッカーを撤去。`ExternalTerminal.swift` はコード保持（v1.1） | 3-2〜3-3 のスクショで外部導線無し |
| 3 | 安定性 | `applicationWillTerminate` の子プロセス回収が非同期 `asyncAfter` 依存で、終了時に実行されず孤児化しうる | `terminateAllSync()`（SIGTERM→ポーリング→SIGKILL→`waitpid`）を同期実行 | 3-9 |
| 4 | メモリ | `TerminalRegistry.reaped` が閉じたセッション id を無制限保持 | `[UUID: Date]` + 120 秒 TTL prune、`terminateAllSync` でクリア | コードレビュー |
| 5 | 堅牢性 | 復元セッションの作業フォルダが消えていてもそのまま `startProcess` に渡していた | `ShellResolver.startDirectory` で存在確認 → home フォールバック | 3-7 + 自動テスト 5 件 |

### 併せて対応
- `⌘K`（バッファクリア）を追加（従来なし）。
- `Package.resolved` をリポジトリ管理下に（依存ピン固定）。
- `VERSION` を `1.0.0` に。

## 5. 既知の制限（v1.0 として許容 / `humi.md` にbacklog化）

- Developer ID 署名・公証は未対応（ad-hoc 署名）。
- アプリアイコン未同梱。
- ダークモード非対応（Hum ライトテーマ固定）。
- Swift 言語モードは v5（厳格並行モードには未移行）。
- タイルのドラッグ並べ替え・手動リサイズ無し。

## 6. 判定

**release 可。** must-fix 5 件はすべて修正・再検証済み。自動 35/35、手動 3-1〜3-10 全項目 pass、
`⌘Q` 後の孤児プロセス無しを確認。
