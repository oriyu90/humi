<div align="center">

# Humi

**タイル型の macOS ターミナルワークスペース。**
`+` を押してフォルダを選ぶと、そのフォルダで開いたターミナルセッションがウィンドウ内のタイルに並びます。セッションはいくつでも。

Version 1.0.0 · macOS 14+ · Apple Silicon / Intel
Author: Yuki_Orita · MIT License

</div>

---

## これは何か

Humi は、複数のターミナルセッションを 1 枚のウィンドウにタイルとして並べる macOS アプリです。

- ウィンドウの `+` を押す → **Finder のフォルダ選択**が開く
- 「このフォルダで開く」か「そのまま開く（ホーム）」を選ぶ
- 選んだフォルダを作業ディレクトリにしたターミナルセッションが、ウィンドウ内のタイルとして表示される
- `+` は常に表示され、セッションは無制限に追加できる
- 各タイルは最大化・再起動・クローズができる
- 右側に Markdown 対応のメモ欄（再起動しても内容が残る）

ターミナルは [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) による**内蔵エミュレータ**です（実 PTY + 実シェル）。外部の iTerm / ターミナル.app を Humi のウィンドウ内に埋め込むことは macOS の仕様上できないため、v1.0 は内蔵エミュレータのみを提供します。

## 使い方

| 操作 | 動作 |
|---|---|
| `+`（ツールバー）/ `⌘N` | 新しいセッション（フォルダ選択 → 開き方選択） |
| `⌘K` | フォーカス中のセッションの画面をクリア（スクロールバックも破棄） |
| タイルの `⤢` | タイルの最大化 / 復帰 |
| タイルの `⟳` | 終了したシェルを同じフォルダで再起動 |
| タイルの `✕` | セッションを閉じる（子プロセスは SIGTERM→SIGKILL で確実に回収） |
| サイドバーのトグル | メモ欄の表示 / 非表示 |

セッションの一覧（フォルダ・タイトル・アクセント色）とメモは
`~/Library/Application Support/Humi/` に保存され、次回起動時に復元されます
（プロセス自体は復元できないため、シェルは開き直されます）。

## 設定

`Humi › 設定…`（`⌘,`）

- **シェル**: ログインシェル / zsh / bash / fish / カスタム（実行パス + 引数）。`-l` の有無も選択可。
- **スクロールバック行数**: 1,000〜200,000（既定 10,000）。次に開くセッションから反映。
- **フォントサイズ**: 9〜22pt。開いているセッションへ即時反映。
- **起動時にメモを表示**。

## ビルド

Xcode は不要です（Command Line Tools + Swift 6.2 で動作）。

```bash
swift build -c release --product Humi   # ビルドのみ
bash Scripts/test.sh                    # 依存なしのセルフテスト（37 チェック）
bash Scripts/build-app.sh release       # dist/Humi.app を生成（ad-hoc 署名）
open dist/Humi.app
```

`Scripts/build-app.sh` は SwiftPM の実行ファイルから `Humi.app` を組み立て、`Assets/AppIcon.icns` があれば同梱し、ad-hoc 署名します。正式配布用の Developer ID 署名・公証（notarization）は未対応です。初回起動時は「システム設定 › プライバシーとセキュリティ」から実行を許可してください。

## アーキテクチャ

```
Sources/Humi/         @main エントリ + AppDelegate（終了時のクリーンアップ）
Sources/HumiKit/Core/
  AppSettings          UserDefaults ラッパー（手動 objectWillChange）
  ShellResolver        設定 → 実行ファイル + argv + argv0（純粋・テスト可能）
  Session / SessionStore  セッション一覧の値型と永続化
  TerminalController   1 セッション = 1 LocalProcessTerminalView + 子シェルを所有
  TerminalRegistry     セッション id → Controller のプロセス全体キャッシュ
  Persistence          ~/Library/Application Support/Humi への atomic I/O
  NotesStore           メモの永続化（デバウンス保存）
Sources/HumiKit/UI/    SwiftUI（RootView / SessionGridView / TerminalTileView …）
```

SwiftUI ビューは `TerminalRegistry` から Controller を**参照するだけ**で、生成はしません。これにより再レンダリングで PTY が二重に生成されることを防いでいます。

## ライセンス

MIT。詳細は [`LICENSE`](LICENSE)。

依存: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)（MIT） / [Plus Jakarta Sans](https://github.com/tokotype/PlusJakartaSans)（OFL） / JetBrains Mono（OFL）。
