# Humi v1.5.0 — テスト計画と精査結果

実施日: 2026-09-04 / 環境: macOS 26.5 (Apple Silicon), Apple Swift 6.2.3

ターミナルのマウス選択コピー、ドイツ語対応、および
`AUDIT_2026-09-02.md` の `[fix]` 8 件を対象とする。

## 1. コード精査

| 項目 | 確認内容 | 結果 |
|---|---|---|
| 選択コピー | nil／空選択では pasteboard を変更せず、実選択は完全一致でコピー。SwiftTerm の標準 `⌘C` と drag selection を維持 | ✅ self-test |
| 多言語 | 6 `.lproj` のキー・空値・`%@`/`%d` 数を比較。Info.plist 宣言と main bundle marker に de を含める | ✅ 244 キー × 6 言語 |
| 出力監視 | 改行後に巨大な未終端 tail がある経路でも pending buffer を 8 KB 以下に制限 | ✅ 回帰テスト |
| ZIP subprocess | stdout は null device、stderr は起動中から drain。30 秒で terminate、0.5 秒後に SIGKILL | ✅ 128 KB stderr + timeout 再現テスト |
| ZIP UX | import/export 例外をローカライズ済み alert へ表示 | ✅ コードレビュー |
| 時計 | UUID の Set による subscribe/unsubscribe 冪等化 | ✅ 重複購読／解除テスト |
| リサイズ | pane size を非 publish の参照型に保持し、GeometryReader の毎フレーム報告で RootView を invalidate しない | ✅ コードレビュー |
| UI | active note tab の自動 scroll、new-session sheet の default action、言語反映注記、TitleTextHider 撤去 | ✅ コードレビュー |

## 2. 自動検証

| # | 内容 | 結果 |
|---|---|---|
| 2-1 | `bash Scripts/test.sh` | ✅ 1852 / 1852 |
| 2-2 | `swift build -c debug` | ✅ 警告 0 |
| 2-3 | `swift build -c release` | ✅ 警告 0 |
| 2-4 | 6 言語の `Localizable.strings` を `plutil -lint` | ✅ 全ファイル OK |
| 2-5 | release app bundle の署名、version、localizations、resource bundle | ✅ `codesign --deep --strict`、v1.5.0、6言語 |
| 2-5a | release executable が arm64 + x86_64 の Universal binary | ✅ `lipo -archs` = `x86_64 arm64` |
| 2-6 | 分離した `HUMI_SUPPORT_DIR` で app を起動し、2 秒後も生存 | ✅ |
| 2-7 | DMG / app.zip 生成、SHA-256 検証 | ✅ |

## 3. リリース後確認

| # | 内容 | 結果 |
|---|---|---|
| 3-1 | GitHub Actions (macos-15) | PUSH_PENDING |
| 3-2 | GitHub Release のタグ・添付 4 ファイル・本文 | RELEASE_PENDING |
| 3-3 | studio-rizi 4 言語ページ、canonical / hreflang、公開 URL | DEPLOY_PENDING |

## 4. 判定

**ローカル成果物は release 可。** GitHub Actions、Release 添付、公開サイトは push 後に確認する。
