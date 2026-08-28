# humi 保守メモ

> common-rules `ルール6` に基づく備考ファイル。README や紹介サイト等の公開物には出さない
> 「次回以降の開発向けメモ」をここへ集約する。公開 Web サイトには記載しないこと。

対象バージョン: v1.2.0（分割ペイン / ウィンドウ配置 / グローバルホットキー / 通知 / 正規表現トリガー）

---

## 1. バージョンアップ時に必ず更新する箇所

| ファイル | 箇所 | 備考 |
|---|---|---|
| `VERSION` | 全体 | `Scripts/build-app.sh` が `CFBundleShortVersionString` / `CFBundleVersion` に流し込む唯一の source |
| `CHANGELOG.md` | 新セクション追加 | |
| `docs/RELEASE_NOTES_vX.Y.Z.md` | 新規作成（日英併記） | SHA-256 はビルド後に差し替え |
| `docs/TEST_PLAN_vX.Y.Z.md` | 新規作成 | 精査結果を記録してから release へ（common-rules のオーナー方針） |
| `README.md` | 冒頭 `Version x.y.z`、機能表 | |
| `oriyu90/studio-rizi` `website/projects/humi/index.html` | `softwareVersion`、動作環境、手順の zip 名（**4 言語**） | studio-rizi 側が公開の一次情報 |
| `oriyu90/studio-rizi` `website/content.js` | Humi カードの `releaseVersion` / `releaseDate` | |

`Info.plist` は `build-app.sh` が生成するので直接編集しない。バージョンは `VERSION` の 1 箇所だけ。

## 2. リリース手順

```bash
# 1. セルフテスト（1000+ チェック、全パス必須。HUMI_SUPPORT_DIR で分離される）
bash Scripts/test.sh

# 2. 既定ビルドが通ること（--product なしでも通る = HumiTests を壊していない）
swift build -c release

# 3. アプリ生成（ad-hoc 署名）
bash Scripts/build-app.sh release

# 4. 動作確認（TEST_PLAN の手動項目）
open dist/Humi.app

# 5. 配布アーカイブ + チェックサム
cd dist && ditto -c -k --sequesterRsrc --keepParent Humi.app Humi-X.Y.Z.app.zip
shasum -a 256 Humi-X.Y.Z.app.zip > Humi-X.Y.Z.app.zip.sha256 && cd ..

# 6. コミット・タグ・push
git tag -a vX.Y.Z -m "Humi vX.Y.Z"
git push origin main && git push origin vX.Y.Z

# 7. GitHub Release（zip + sha256 を添付）
gh release create vX.Y.Z dist/Humi-X.Y.Z.app.zip dist/Humi-X.Y.Z.app.zip.sha256 \
  --title "Humi vX.Y.Z" --notes-file docs/RELEASE_NOTES_vX.Y.Z.md

# 8. 紹介サイト（common-rules ルール1: 実装完了後の最終工程）
#    oriyu90/studio-rizi の website/projects/humi/ と content.js を更新し main へ push。
#    Cloudflare Pages が自動デプロイ。手動 wrangler は使わない。
```

## 3. 実装上の注意（次に触るとき用）

- **`TerminalRegistry` が PTY の唯一の所有者。** SwiftUI ビュー（`TerminalEmulatorView`）は
  `controller(for:)` で**参照するだけ**。ここで生成すると再レンダリングごとにシェルが増える。
- **終了時のリープは同期でやる。** `applicationWillTerminate` → `terminateAllSync()`。
  非同期 `DispatchQueue.asyncAfter` の `waitpid` はプロセスが先に落ちて実行されない。
  個別タイルのクローズ (`terminate()`) は UI を止めないため非同期のままでよい。
- **SwiftTerm の `terminate()` は SIGTERM のみ。** リープ（`waitpid`）も SIGKILL も自前。
  `TerminalController.terminate()` / `terminateSync()` の 2 経路にそれぞれ実装。
- **⌘K は `clearScrollback()` + Ctrl-L (`\u{0C}`) の送出。** `clearScrollback()` だけだと
  画面に見えている行は消えない（Terminal.app の「画面を消去」と挙動が違う）。Ctrl-L で
  シェルの line editor がプロンプトを再描画し、入力中のコマンドも保持される。
- **`reaped` は `[UUID: Date]` で 120 秒 TTL。** 閉じたセッションの再生成を 1 アニメーション
  ぶん防げれば十分。無制限 `Set` にすると長時間起動で伸び続ける。
- **復元セッションの作業フォルダが消えていたら home にフォールバック**（`ShellResolver.startDirectory`）。
  そのまま `startProcess` に渡すと起動失敗 or `/` で開く。
- **`Package.swift` の `-enable-testing` は無条件。** debug 限定にすると `swift build`
  （product 指定なし）が HumiTests のコンパイルで落ちる。CI が緑にならなくなる。
- **言語モードは Swift 5（`.swiftLanguageMode(.v5)`）。** v1.0 では厳格並行に上げていない。
  `nonisolated` なデリゲートコールバックは `Task { @MainActor in }` で hop 済み。
  上げるなら `TerminalController` のデリゲート境界と `AppDelegate` の
  `MainActor.assumeIsolated` を先に見直すこと。
- **テストは実 app-support dir を触らせない。** `Persistence.baseURL` は環境変数
  `HUMI_SUPPORT_DIR` があればそちらを使う。`Scripts/test.sh` が `mktemp -d` を設定する。
  これを外すと `bash Scripts/test.sh` が `~/Library/Application Support/Humi/sessions.json`
  を消す（`HumiTests` が `removeItem` するため）。CI でも実行されるので絶対に戻さない。
- **アイドル時に `repeatForever` アニメーションを置かない。** `CharacterMark` の breathing を
  入れたら常時 8〜10% CPU になった（CA `collect_animations_` が毎フレーム回る）。
  「生きてる感」は新規セッション時の burst だけで出す。
- **`cd` でタイトルが変わらないのは仕様。** macOS の zshrc は `TERM_PROGRAM==Apple_Terminal`
  のときだけ OSC 7 を出す。追従させたいなら `TERM_PROGRAM=Apple_Terminal` にするか
  precmd hook を注入する（副作用注意。§4 参照）。
- **設定タブは `VStack(alignment:.leading)+Spacer` で top-leading に固定。** `Form` に数行だけ
  置くと下寄せになり、`Slider`/`Stepper` の長いラベルがコントロールを画面外へ押し出す。
  値は `labelsHidden()` + 明示 `HStack` で右寄せする。

### v1.1 で増えた構造・注意

- **永続ストア（すべて `Persistence` 経由 = `~/Library/Application Support/Humi/`）**
  - `themes.json` … `ThemeStore`（active名 / mode / 自作テーマ）。組み込み 6 プリセットはコード。
  - `profiles.json` … `ProfileStore`（プロファイル配列 + defaultProfileID）。
  - `keymap.json` … `KeymapStore`（アクション rawValue → `KeyChord`。未登録は `defaults`）。
  - スカラーは従来どおり `AppSettings`（`UserDefaults`）。
  - モデルはすべて **カスタム `init(from:)`** を持ち、旧 JSON / 部分 JSON でも復号できる。壊さない。
- **多言語化。** `Sources/HumiKit/Resources/{ja,en,zh-Hans,pt-BR,es}.lproj/Localizable.strings`。
  文字列は `L("key")` / `T("key")`（`Sources/HumiKit/UI/L10n.swift`）経由。**新規文字列は必ず 5 言語へ。**
  `bash Scripts/test.sh` の `L10n` スイートがキー一致・プレースホルダ数一致を検査する。
  SwiftPM は `.lproj` の地域サフィックスを小文字化する（`zh-Hans`→`zh-hans`）ので `Localization.lprojBundle`
  は大小無視で探す。言語切替は `AppSettings.appLanguage` → `Localization.shared.apply()` で**即時**（再起動不要）。
- **アプリ本体のダークモード。** `Hum.paper` などは `dyn(light:dark:)` で作る動的 `NSColor`。
  ウィンドウ側で `preferredColorScheme` を `ThemeStore.resolvedTheme.appAppearance` から与える。
  トークンを `@MainActor` 計算プロパティにしない（`HumButtonStyle` 等へ isolation が波及する）。
- **テーマ適用は `TerminalRegistry.applyTheme()`。** `HumiApp` が `ThemeStore.shared.onChange` に接続。
  ファミリ選択で `mode` をそのテーマの外観へスナップ（`setActive`）。System は明示選択のみ。
- **`HumiTerminalView`（`LocalProcessTerminalView` サブクラス）。** `requestOpenLink` / `selectionChanged`
  / `mouseDown` をオーバーライド。SwiftTerm 1.20 は `becomeFirstResponder` / `keyDown` が `open` でないので
  触らない。「最後に触ったターミナル」は `mouseDown` → `TerminalRegistry.noteFocused`。`focusedController()`
  はライブ first responder → lastFocused → 単一なら唯一、の順。
- **OSC 7 は Humi が注入する。** `ShellResolver.osc7Snippet(for:)`（zsh/bash のみ）を `startProcess` 直後に
  送り、`clearScrollback`+Ctrl-L でノイズを消してから起動コマンドを送る。ログセッションでは注入しない
  （`script` のログが汚れる）。`TerminalController.normalizeDirectory` が `file://host/path` をプレーンパスへ。
  home にいるセッションは自動タイトル（ローカライズ既定）を維持する（ユーザ名にしない）。
- **キーバインドのメニュー反映はアプリ再起動が必要。** SwiftUI の `Scene`/`.commands` は `@ObservedObject`
  変更に追従しきらない。`keymap.json` への保存と `KeyRecorder` の表示は即時。動作は保存値ベース。
- **ステータスバーの Git は `GitStatus`（actor, 5s/dir キャッシュ）。** `StatusBarView` の 12s タイマーは
  ビューが載っている間だけ。CPU/メモリ系コンポーネントは入れていない（表示中のみサンプリングする設計に留める）。
- **`RootView` のアクションは 1 本の Merge publisher + `handle(_:)`。** `.onReceive` を並べると body が
  型チェック不能になる。新アクションは `Notification.Name.humiAllActions` に足して `handle` に分岐を足す。
  `handle` は `Notification`（`.name` と `.object` 両方）を受け取る。

### v1.2 で増えた構造・注意

- **ペインツリー。** `PaneTree.swift` の `PaneNode { case leaf(UUID); case split(axis, [PaneNode], [CGFloat]) }`
  が構造の真実。`SessionStore.layout: PaneNode?`。`sessions: [Session]` は葉レジストリ（メタデータ）に降格。
  純粋操作（`insert/remove/swap/setRatio/equalized/normalized/frames/focusNeighbor/dividers/settingRatio`）は
  すべて `PaneNode` 上でユニットテスト済み。**すべての操作の出口で `normalized()`。**
- **`PaneTreeView` は絶対配置の単一 ZStack。** `layout.frames(in:gap:)` の矩形へ各葉を `.position` で置き、
  葉ごとに安定した `.id(session.id)`。Lazy 禁止・eager は v1.1 と同じ。分割線は自前の `DividerHandle`
  （`PaneNode.DividerSpec` / `.dividers(in:)` / `.settingRatio(at:path)`）。`SessionGridView` / `GridLayout` は削除。
- **`sessions.json` は `{sessions, layout}`（`SessionsFile`）。** `SessionStore.loadFile()` が旧トップレベル
  `[Session]` 配列にフォールバックして 1 列 layout を合成。`reconcile()` がツリーとレジストリの食い違いを常に補正。
- **`arrangements.json` = `ArrangementStore`。** `Arrangement { windowFrame, layout, leaves:[LeafSpec] }`。
  葉 id はローカル、`materialize` で新規 UUID に振り直す。`SessionStore.load(sessions:layout:)` で丸ごと差し替え。
- **グローバルホットキーは `HotKeyCenter`（Carbon `RegisterEventHotKey`）。** `AppSettings.globalHotkeyChord`
  は `keymap.json` とは別、UserDefaults に `KeyChord` の JSON 文字列。`HotKeyCenter.bootstrap()` を `HumiApp.init` で呼ぶ。
- **通知は `HumiNotifier`（`UNUserNotificationCenter`）+ `OutputMonitor` + `Trigger`/`TriggerEngine`。**
  出力監視は `HumiTerminalView.dataReceived(slice:)` の override（SwiftTerm 1.20 で `open`）。
  watch 文字列もトリガーも無ければ `onOutput` を張らない＝アイドルコスト 0。設定は `AlertsPane`（グローバル）。
- **再割り当てショートカットの即時反映は `KeymapStore.installLocalMonitor()`（`NSEvent` ローカルモニタ）。**
  既定値のままのチョードはメニュー（`.commands`）に任せて二重発火を回避。メニュー表示の更新は依然再起動が必要。
- **`⌘M`（`maximizeTile` 既定）は macOS のウィンドウ最小化に飲まれる。** タイルの最大化ボタンは正常。
  直すなら別チョードに変えるか §5-F の案 2 と統合。

## 4. 既知の未対応事項・今後の予定

### 優先度: 高
- **Developer ID 署名 + 公証（notarization）が未対応。** 現状 ad-hoc 署名なので初回起動に
  ユーザー操作が要る。Apple Developer Program 加入後、`build-app.sh` の署名部へ
  `--options runtime` + `xcrun notarytool submit` + `xcrun stapler staple` を追加する。
- **アプリアイコンが未作成。** `Assets/AppIcon.icns` を置けば `build-app.sh` が同梱する。
  Hum テーマ（クリーム地 + 洋梨色ドット）に合わせた 1024px 原画から `iconutil` で生成。

### v1.3 以降ロードマップ（v1.2 で骨格は入ったが MVP 止まり / 未着手）

- ~~分割ペイン / ペインツリー~~ → **v1.2 で対応**（`PaneTree` + `PaneTreeView`）。
- ~~ウィンドウ配置（Arrangement）~~ → **v1.2 で対応**（`ArrangementStore`）。
- **Quake ウィンドウ。** v1.2 のグローバルホットキーは MVP（activate / hide トグルのみ）。
  画面上端に貼るボーダレス + スライドインは未実装。
- **通知・トリガーのプロファイル単位化。** v1.2 は `AppSettings` にグローバル。
  `Profile.notify: NotifyPrefs` / `Profile.triggers: [Trigger]` へ移す。
- **Snippets**（`⌘⇧V` パレット）、**設定 Import/Export/Reset**（Advanced ペイン）、
  **外部ターミナル起動オプション**の復帰（`ExternalTerminal.swift` は dormant のまま）。
- **`⌘M` 問題。** `maximizeTile` の既定 `⌘M` が macOS のウィンドウ最小化に飲まれる。別チョードへ。
- 複数ウィンドウ、メニューバー常駐、Directory/Command 履歴 UI、SwiftTerm 2.x 系
  （Metal / インライン画像 / Sixel / 録画）。

### 優先度: 中（v1.1 で対応済み or 部分対応）

- ~~ダークモード非対応~~ → v1.1 で対応（動的トークン + `preferredColorScheme`）。
- ~~ドラッグ並べ替え~~ → v1.1 で対応（`.onDrag`/`.onDrop` → `SessionStore.move`）。
  ~~タイルの手動リサイズ~~ → v1.2 のペインツリーで分割線ドラッグに対応。
- ~~`cd` 追従（OSC 7）~~ → v1.1 で Humi 側注入（zsh/bash）、**v1.2 で fish も対応**。カスタムは未対応。
- **外部ターミナル連携。** `ExternalTerminal.swift` / `ExternalTerminalApp` / `AppSettings.externalTerminal`
  は dormant のまま。今のところ需要待ち。
- ~~キーバインドのメニュー即時反映~~ → **v1.2 で動作は即時**（`KeymapStore.installLocalMonitor`）。
  メニューの**表示**更新は依然再起動要。

### 優先度: 低
- スクロールバック上限 200,000 行 × 多数セッションはメモリを食う。既定 10,000 は妥当。
- `NotesStore` / `SessionStore` は単一ウィンドウ前提（`Window` シーン）。複数ウィンドウを
  許すなら共有ストアの排他を入れること。

## 5. 連絡先・外部リンク（README / 紹介サイトと揃える）

- 開発者: Yuki_Orita / 折田悠希 / おりたゆうき
- 公式サイト: https://studio-rizi.pages.dev/
- Discord（バグ報告・告知）: https://discord.gg/x7KXhNTD8M
- X: https://x.com/InovateofRIZI
- 正規紹介 URL: https://studio-rizi.pages.dev/projects/humi/
