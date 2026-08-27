<div align="center">

# Humi

**タイル型の macOS ターミナルワークスペース。**
`+` を押してフォルダを選ぶと、そのフォルダで開いたターミナルセッションがウィンドウ内のタイルに並びます。セッションはいくつでも。

Version 1.1.0 · macOS 14+ · Apple Silicon / Intel
Author: Yuki_Orita · MIT License
日本語 / English / 中文 / Português / Español（OS 言語で自動選択）

</div>

---

## これは何か

Humi は、複数のターミナルセッションを 1 枚のウィンドウにタイルとして並べる macOS アプリです。

- ウィンドウの `+` を押す → **Finder のフォルダ選択**が開く
- 「このフォルダで開く」か「そのまま開く（ホーム）」を選ぶ（プロファイルも選択可）
- 選んだフォルダを作業ディレクトリにしたターミナルセッションが、ウィンドウ内のタイルとして表示される
- `+` は常に表示され、セッションは無制限に追加できる
- 各タイルは最大化・再起動・クローズ・ドラッグ並べ替えができる
- 右側に Markdown 対応のメモ欄（再起動しても内容が残る）

ターミナルは [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) による**内蔵エミュレータ**です（実 PTY + 実シェル）。外部の iTerm / ターミナル.app を Humi のウィンドウ内に埋め込むことは macOS の仕様上できないため、内蔵エミュレータのみを提供します。

## v1.1 の新機能

- **多言語対応（5 言語）** — 日本語 / English / 中文 / Português / Español。OS 言語で自動選択、設定で手動切替（再起動不要）。
- **フルテーマ** — 6 プリセット（Hum Light/Dark、Solarized Light/Dark、Nord、Terminal Basic）、自作テーマ、`.humitheme` の読み書き、ANSI 16 色エディタ、カーソル形状／点滅、等幅フォント＋日本語フォント指定、Light / Dark / **System** モード（アプリ本体のダークモードも含む）。
- **ターミナル内検索**（`⌘F`）— 件数表示・前後移動・ハイライト。
- **URL / パス連携** — 出力内の URL・ファイルパス・`パス:行番号` を、⌘クリックまたは右クリックメニューでブラウザ / Finder / 任意のエディタ（既定 `code -g`）で開く。
- **プロファイル** — シェル・環境変数・起動コマンド・フォルダ・テーマ・スクロールバック・ログをまとめて保存。新規セッション時に選択、ツールバーのランチャーから一発起動。`.humiprofile` の読み書き。
- **キーバインド** — 主要操作のショートカットを設定画面で変更・リセット・`.humikeys` 読み書き。
- **セッション** — 名前変更、タイルごとの色、終了時の動作（残す／自動再起動／自動クローズ）、実行中の確認、セッションログ（`script` 経由）。
- **ステータスバー**（任意）— タイル下部に 作業フォルダ・シェル名・Git ブランチ＋変更・時刻。Humi 側で OSC 7 を注入するため、`cd` でタイトル・cwd・Git 表示が追従します。
- その他: `⌘+` / `⌘-` / `⌘0` フォントズーム、`⌥⌘←→` タイル移動、ターミナル余白、選択即コピー、複数行ペースト確認、ベル（音／視覚）、Option→Meta、マウスレポート、スクロール感度など。

## 使い方（既定のショートカット）

| 操作 | 動作 |
|---|---|
| `⌘N` | 新しいセッション |
| `⌘W` / `⌘R` / `⌘M` | フォーカス中タイルを 閉じる / 再起動 / 最大化 |
| `⌘K` | 画面クリア（スクロールバック破棄） |
| `⌘F` | ターミナル内検索 |
| `⌘+` / `⌘-` / `⌘0` | フォント 拡大 / 縮小 / リセット |
| `⌥⌘←` / `⌥⌘→` | 前 / 次のタイルへフォーカス |
| `⌥⌘S` / `⌥⌘P` | メモ表示切替 / 既定プロファイルで開く |

ショートカットは `Humi › 設定… › ショートカット` で変更できます（変更後はアプリ再起動で反映）。

## 設定

`Humi › 設定…`（`⌘,`）: 一般 / 外観 / ターミナル / プロファイル / ショートカット / ステータスバー / シェル。

保存先は `~/Library/Application Support/Humi/`（`sessions.json` / `notes.md` / `themes.json` / `profiles.json` / `keymap.json`）と `UserDefaults`。次回起動時に復元されます（プロセスは復元できないためシェルは開き直し）。

## ビルド

Xcode は不要です（Command Line Tools + Swift 6.2 で動作）。

```bash
swift build -c release --product Humi   # ビルドのみ
bash Scripts/test.sh                    # 依存なしのセルフテスト（1000+ チェック）
bash Scripts/build-app.sh release       # dist/Humi.app を生成（ad-hoc 署名）
open dist/Humi.app
```

`Scripts/build-app.sh` は SwiftPM の実行ファイルから `Humi.app` を組み立て、`Assets/AppIcon.icns` があれば同梱し、ad-hoc 署名します。Developer ID 署名・公証（notarization）は未対応です。初回起動時は「システム設定 › プライバシーとセキュリティ」から実行を許可してください。

## アーキテクチャ

```
Sources/Humi/         @main エントリ + AppDelegate（終了時のクリーンアップ）
Sources/HumiKit/Core/
  AppSettings          UserDefaults ラッパー（手動 objectWillChange）
  ThemeStore / Theme   テーマ・プリセット・Light/Dark/System 解決
  ProfileStore / Profile  セッションプロファイル
  KeymapStore / Keymap    アクション → キーチョード
  ShellResolver        設定 → 実行ファイル + argv + argv0 + OSC 7 スニペット（純粋）
  Session / SessionStore  セッション一覧の値型と永続化
  TerminalController   1 セッション = 1 HumiTerminalView + 子シェルを所有
  TerminalRegistry     セッション id → Controller のプロセス全体キャッシュ
  PathActioner / GitStatus / SessionLogger
Sources/HumiKit/UI/    SwiftUI（RootView / SessionGridView / TerminalTileView / Settings/*Pane …）
Sources/HumiKit/Resources/{ja,en,zh-Hans,pt-BR,es}.lproj/
```

SwiftUI ビューは `TerminalRegistry` から Controller を**参照するだけ**で、生成はしません。これにより再レンダリングで PTY が二重に生成されることを防いでいます。

## ライセンス

MIT。詳細は [`LICENSE`](LICENSE)。

依存: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm)（MIT） / [Plus Jakarta Sans](https://github.com/tokotype/PlusJakartaSans)（OFL） / JetBrains Mono（OFL）。
