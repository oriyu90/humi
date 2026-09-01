# Humi v1.4.3 — テスト計画と精査結果

実施日: 2026-09-02 / 環境: macOS 15 系 (Apple Silicon), Xcode toolchain, Swift 6.3.3

メモプレビューの表示バグ（実際の症例あり）+ タブ当たり判定 + アプリアイコン。

---

## 1. 不具合と原因

### 1-1. コードブロックの表示切れ

ユーザー報告（実際のスクリーンショット付き）: 8 行以上のコードブロックを含むメモをプレビューすると、
末尾が「…」で省略される。日本語の長い行を含むケースでは、`※安全な設計（…）UIを守ること。…` の
ように途中で切れ、最後の行が完全に消えていた。

原因: `TrackingScroll`（v1.4.0 で追加、`NSHostingView` を `NSScrollView` に載せてプレビューの
スクロール位置を保持する仕組み）が、`NSHostingView` に対して SwiftUI コンテンツの高さを
実際より短く割り当てることがあった。SwiftUI 側はその制約された高さに収めようと `Text` を
省略記号で切り詰める。`.textSelection(.enabled)` を伴う `Text` が特に起きやすかった。
再現は不安定（同じ内容でも 8 行の別コードブロックが正常に描画されたケースあり）。

### 1-2. タブ／ホームボタンの当たり判定

`.buttonStyle(.plain)` のラベルに `.background`/`.overlay` で見た目の背景・下線を足していたが、
`.contentShape` を指定していなかったため、ヒットテストはグリフ（アイコン・文字）の実描画範囲に
限られ、見た目の padding 込みの領域では反応しなかった。

## 2. 修正

- **`NotesMarkdownPreview`（新規、`NotesScroll.swift`）**: プレビューを素の SwiftUI `ScrollView` に
  戻す。`NSHostingView` 経由の高さ推定に依存しない。
  - スクロール位置の保持: `MarkdownBlocks(anchored: true)` で各ブロックに `md-block-<i>` の
    `.id` を付与し、`ScrollViewReader.scrollTo` で編集側のフラクションに近いブロックへ復元。
  - 取得: `GeometryReader`（content の `.background`）でオフセットと高さを読み、
    ビューポート高さは ScrollView 自身の `.background` の `GeometryReader` から取得。
  - 復元に失敗しても「先頭で開く」だけで、表示が欠けることはない（1-1 のような切り詰めは発生しない）。
- **`MarkdownBlocks` の各テキスト（見出し・箇条書き・番号付き・段落・コード）に
  `.fixedSize(horizontal: false, vertical: true)` を追加。** コンテナに高さを圧迫されても
  省略記号で切り詰めず、必要な高さを常に主張するようにした。**この `.fixedSize` を外さない。**
- コードブロックの `Text` から冗長だった `.textSelection(.enabled)` を除去（外側の
  `MarkdownBlocks` VStack の `.textSelection(.enabled)` で選択は引き続き可能）。
- **タブ chip / ホームボタン**: `.contentShape(Rectangle())` をラベルの背景・下線描画の後に追加し、
  見た目の padding 込みの領域全体をヒットターゲットに（それより外へは広げない）。
- **タブの `×`・ホームタブ一覧行の鉛筆／`×`**: `.frame(width:height:)` + `.contentShape(Rectangle())`
  で最小 16〜22pt の当たり判定に（行の高さに収まる範囲）。

## 3. アプリアイコン

- ユーザー提供の `.ico`（256×256 PNG 内包）から `sips` で iconset を生成し `iconutil` で
  `Assets/AppIcon.icns` を作成。再生成用に `Scripts/make-icns.sh`
  （`Assets/AppIcon-source-1024.png` から iconset 生成 → `iconutil`）を追加。
  `build-app.sh` は既存のとおり `Assets/AppIcon.icns` があれば拾って同梱する。

## 4. 検証

| # | 内容 | 結果 |
|---|---|---|
| 4-1 | `bash Scripts/test.sh` | ✅ 1555 / 1555（`MarkdownBlocks` parse チェック +3） |
| 4-2 | ユーザー提供の実データ（8 行超のコードブロック、日本語長文行）をメモに再現 → プレビューで
      全行表示（「…」なし、最終行まで見える） | ✅ |
| 4-3 | 15 行コードブロック + 20 段落の長いメモ → プレビューを先頭から末尾までスクロールし
      欠落なしを確認 | ✅ |
| 4-4 | 編集⇄プレビューを 4 回連続でトグル → 毎回コードブロック全体が表示される（再現しない） | ✅ |
| 4-5 | 編集で下の方までスクロール → プレビューへ切替 → 概ね同じ位置（ブロック単位）で開く | ✅ |
| 4-6 | タブの端（padding 部分）をクリックしてもタブが切り替わる。`×` を狙って削除ダイアログが出る | ✅（コードレビュー + 目視） |
| 4-7 | `swift build -c release` | ✅ 警告 0 |
| 4-8 | `build-app.sh` → `dist/Humi.app/Contents/Resources/AppIcon.icns` 同梱、Dock にカスタムアイコン表示 | ✅ |
| 4-9 | CI（macos-15） | ⏳ push 後 |

## 5. 判定

**release 可。** 報告のあった実データで再現・修正確認済み。プレビューの実装をより単純で
壊れにくい素の `ScrollView` に戻したことで、同種の高さ推定バグが今後再発するリスクも下がった。
