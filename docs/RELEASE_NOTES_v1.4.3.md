# Humi v1.4.3

メモのコードブロックが途中で切れる不具合の修正、タブの押しやすさ改善、アプリアイコンの追加。
Fixes a code-block truncation bug in notes, improves tab hit areas, and adds an app icon.

---

## 日本語

### 修正
- **メモのコードブロックが 8 行以上、または折り返すほど長い行を含むと、末尾が
  「…」で切れて表示されたり、プレビュー全体が真っ白になることがありました。**
  プレビューは SwiftUI のコンテンツを `NSHostingView` 経由で `NSScrollView` に
  乗せていましたが、この方式は稀に高さを短く測ってしまい、コンテンツを強制的に
  切り詰めていました。プレビューを素の SwiftUI `ScrollView` に戻し、編集/プレビュー
  間のスクロール位置保持は `ScrollViewReader` のブロック単位アンカー方式で作り
  直しました。
- **タブ／ホームボタンなどの小さいアイコンで、見た目の範囲より当たり判定が
  狭く押しにくいことがありました。** 当たり判定を、見た目からはみ出ない範囲で
  ボタン・タブの表示領域いっぱいまで広げました。

### 追加
- アプリアイコンを設定（`Assets/AppIcon.icns`。再生成用に `Scripts/make-icns.sh` を追加）。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.4.3.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.4.3.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.4.3.dmg)     = 845ed2a25a8fe64c9fda5b76a31cdedeaad8973e7baa525c7fa1433d0953b43e
SHA-256 (Humi-1.4.3.app.zip) = 3bdc90ccb9a4fb4d77cb54e5dd1cab744da1896f2f658303a4eb0af79e1b8773
```

---

## English

### Fixed
- **A code block of 8+ lines, or one containing long wrapping lines, could be
  truncated with a trailing "…" in the notes preview — sometimes the whole
  preview went blank.** The preview hosted its SwiftUI content via an
  `NSHostingView` inside an `NSScrollView`, which could occasionally measure a
  too-short height and force-truncate the content. The preview is back to a
  plain SwiftUI `ScrollView`; scroll-position retention across Edit⇄Preview is
  reimplemented with `ScrollViewReader` block anchors instead.
- **Small icon buttons (tabs, the Home button) had a hit area smaller than
  their visible bounds**, so clicks near an edge could miss. Hit areas now
  cover the full visible chip/button, never larger than it.

### Added
- A custom app icon (`Assets/AppIcon.icns`; `Scripts/make-icns.sh` regenerates
  it from a 1024×1024 source).

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.4.3.dmg` and drag `Humi.app`
to Applications (`Humi-1.4.3.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.4.3.dmg)     = 845ed2a25a8fe64c9fda5b76a31cdedeaad8973e7baa525c7fa1433d0953b43e
SHA-256 (Humi-1.4.3.app.zip) = 3bdc90ccb9a4fb4d77cb54e5dd1cab744da1896f2f658303a4eb0af79e1b8773
```
