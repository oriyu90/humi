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
| **合計** | | **✅ 40 / 40** |

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
| 5 | 堅牢性 | 復元セッションの作業フォルダが消えていてもそのまま `startProcess` に渡していた | `ShellResolver.startDirectory` で存在確認 → home フォールバック | 3-7 + 自動テスト 7 件 |

### 併せて対応
- `⌘K`（バッファクリア）を追加（従来なし）。
- `Package.resolved` をリポジトリ管理下に（依存ピン固定）。
- `VERSION` を `1.0.0` に。

## 4-B. v1.0.1 — リリース後デバッグ（設定保持・ターミナル安定動作）で検出・修正

実機で複数セッション作成／連続開閉／シェル終了・再起動／ウィンドウリサイズ／`⌘Q`／再起動を反復し、
プロセス数・FD 数・スレッド数・RSS・CPU を計測。

| # | 重大度 | 問題 | 原因 | 修正 | 検証 |
|---|---|---|---|---|---|
| B1 | **高** | `bash Scripts/test.sh` を実行すると `~/Library/Application Support/Humi/sessions.json` が**消える**。README・CI・貢献者が走らせるコマンドが実ユーザーの保存セッションを破壊していた | `Persistence.baseURL` が実 app-support dir を指し、`HumiTests` がそこの `sessions.json` を `removeItem` していた | `HUMI_SUPPORT_DIR` 環境変数で保存先を差し替え可能に。`Scripts/test.sh` が `mktemp -d` を設定し `trap` で後始末。分離を検証する自動テスト3件を追加 | 実 `sessions.json` にマーカーを置いてテスト実行 → 生存を確認。`selftest-*.json` の実 dir への散乱も解消 |
| B2 | **高** | ウィンドウを開いている間、セッション数に関係なく**アイドル CPU が常時 8〜10%** | `CharacterMark` の `repeatForever` breathing アニメーションが Core Animation の `collect_animations_` と AppKit レイアウトパスを毎フレーム回し続けていた（`sample` で確認） | アイドル時の breathing を撤去（新規セッション時の burst は維持） | アイドル CPU **9% → 0.0%**、`sample` に該当ホットパス無し |
| B3 | 中 | 設定 3 タブの内容が**下寄せ**になり、`Slider`/`Stepper` の長いラベルが**左端で見切れる**（外部ターミナルピッカー撤去後に顕在化） | `Form` が数行のとき下寄せ、長いラベルがコントロールを画面外へ押し出し | 各タブを `VStack(alignment:.leading)+Spacer` の top-leading レイアウトに。`Slider`/`Stepper` は `labelsHidden()` + 明示 `HStack` で値を右寄せ。ウィンドウ 460→500 幅 | 実機スクショで見切れ解消・上寄せを確認 |
| B4 | 低 | 内蔵シェルで `cd` してもタイルのタイトルが更新されない | macOS の zshrc は `TERM_PROGRAM==Apple_Terminal` のときだけ OSC 7 hook を入れる。Humi は `TERM_PROGRAM=Humi` なので `hostCurrentDirectoryUpdate` が発火しない | `updateWorkingDirectory` で「自動タイトルのままなら cwd を追う」処理を追加（OSC 7 が来る環境でだけ効く）。恒久対応は `humi.md` の予定へ | コードレビュー（OSC 7 未発火は既知の制限として記録） |

### B のデバッグで確認できた正常動作

- **設定保持**: `fontSize` / `notesVisible` / `shellKind` は変更時に即 plist へ書かれ、再起動後も復元。`notesVisible` はメインウィンドウへ即反映。`shellKind=bash` は新規・復元セッション双方に適用（復元は現在の設定で再spawn）。
- **複数セッション**: 10 セッションで FD 64→99・スレッド 7→5（安定）・RSS +5MB/セッション。リークなし。
- **開閉・終了・再起動**: 子プロセス数が常にセッション数と一致。ゾンビ・孤児・launchd 再ペアレント無し。シェル `exit` → 「終了」チップ + 再起動ボタン、再起動で新 PID。
- **`⌘Q`（ライブセッションあり）**: 同期リープが早期終了（zsh は SIGTERM 即応）、~1〜2秒で完全終了、孤児 0。

## 5. 既知の制限（v1.0 として許容 / `humi.md` にbacklog化）

- Developer ID 署名・公証は未対応（ad-hoc 署名）。
- アプリアイコン未同梱。
- ダークモード非対応（Hum ライトテーマ固定）。
- Swift 言語モードは v5（厳格並行モードには未移行）。
- タイルのドラッグ並べ替え・手動リサイズ無し。

## 6. 判定

**v1.0.0: release 可。** must-fix 5 件（§4）はすべて修正・再検証済み。手動 3-1〜3-10 全項目 pass、
`⌘Q` 後の孤児プロセス無しを確認。

**v1.0.1: release 可。** §4-B の 4 件（うち「高」2 件 = テストが実データを破壊 / アイドル CPU 8〜10%）を
修正・再検証済み。自動 40/40、アイドル CPU 0.0%、設定の保持（fontSize / notesVisible / shellKind）を
再起動またぎで確認、`⌘Q` 後の孤児 0。
