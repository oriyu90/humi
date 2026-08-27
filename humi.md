# humi 保守メモ

> common-rules `ルール6` に基づく備考ファイル。README や紹介サイト等の公開物には出さない
> 「次回以降の開発向けメモ」をここへ集約する。公開 Web サイトには記載しないこと。

対象バージョン: v1.0.0（内蔵ターミナルエミュレータ / タイル型 / メモ欄）

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
# 1. セルフテスト（35 チェック、全パス必須）
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

## 4. 既知の未対応事項・今後の予定

### 優先度: 高
- **Developer ID 署名 + 公証（notarization）が未対応。** 現状 ad-hoc 署名なので初回起動に
  ユーザー操作が要る。Apple Developer Program 加入後、`build-app.sh` の署名部へ
  `--options runtime` + `xcrun notarytool submit` + `xcrun stapler staple` を追加する。
- **アプリアイコンが未作成。** `Assets/AppIcon.icns` を置けば `build-app.sh` が同梱する。
  Hum テーマ（クリーム地 + 洋梨色ドット）に合わせた 1024px 原画から `iconutil` で生成。

### 優先度: 中
- **外部ターミナル連携（v1.1 予定）。** `Sources/HumiKit/Core/ExternalTerminal.swift` と
  `ExternalTerminalApp`、`AppSettings.externalTerminal` は実装済みで dormant。
  v1.0 は「内蔵のみ」の方針（オーナー確認済み）のため UI 導線を撤去してある。
  戻すのは NewSessionSheet の副ボタン / タイルのボタン / 設定のピッカーの 3 箇所。
- **ダークモード非対応。** アプリ全体を Hum のライトテーマで固定。macOS がダークだと
  ウィンドウのシステムクロームと若干競合する。`SettingsView` の外観タブに注記あり。
- **セッションのドラッグ並べ替え・タイル分割の手動リサイズは未実装。** 現在は追加順に
  リフローするだけ。
- **`⌘K` はキーウィンドウ内でフォーカスが端末にある時のみ。** それ以外は `NSSound.beep()`。
  タイルのフォーカスリングが弱いので、フォーカス表示の改善余地あり。

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
