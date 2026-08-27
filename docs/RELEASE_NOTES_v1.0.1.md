# Humi v1.0.1

v1.0.0 と同日、実機デバッグ（設定の保持・ターミナルの安定動作）で見つけた不具合の修正。
Same-day fixes from a hands-on debugging pass over v1.0.0 (settings persistence and
terminal stability).

---

## 日本語

### 修正
- **アイドル時 CPU。** ウィンドウを開いている間、セッション数に関係なく CPU を常時 8〜10% 使っていました。
  キャラクターマークの常時アニメーションが原因で、これを止めてアイドル CPU を約 0% にしました。
- **セルフテストが保存済みセッションを消していた。** `bash Scripts/test.sh` を実行すると
  `~/Library/Application Support/Humi/sessions.json` が削除されていました。テストは専用の
  一時ディレクトリを使うようにし、実際の保存データに触れないようにしました。
- **設定画面のレイアウト。** 3 つのタブの内容が下に寄り、スライダー／ステッパーの長いラベルが
  左端で見切れていたのを、上寄せ・値を右寄せに直しました。
- **`cd` でのタイトル追従。** シェルが作業ディレクトリを通知する環境（OSC 7）では、
  自動タイトルのタイルが現在のフォルダ名に追従するようにしました。

### 動作環境・インストール
v1.0.0 と同じ（macOS 14 以降、ad-hoc 署名）。`Humi-1.0.1.app.zip` を展開して置き換えてください。

### チェックサム
```
SHA-256 (Humi-1.0.1.app.zip) = 32aee30eac4c4682c2fb9df484d0bf7afa5323292c68d7d3ade484619b45d581
```

---

## English

### Fixed
- **Idle CPU.** With the window open, Humi used ~8–10% CPU at idle regardless of how
  many sessions were open. A perpetual animation on the character mark was the cause;
  removing it brings idle CPU to ~0%.
- **The self-test suite deleted saved sessions.** Running `bash Scripts/test.sh` wiped
  `~/Library/Application Support/Humi/sessions.json`. Tests now run against a throwaway
  directory and never touch real data.
- **Settings layout.** The three tabs bottom-aligned their content and clipped long
  slider/stepper labels; they are top-aligned now, with values right-aligned.
- **`cd` title tracking.** Where the shell reports its working directory (OSC 7), a
  tile with an auto-generated title now follows the current folder.

### Requirements / install
Same as v1.0.0 (macOS 14+, ad-hoc signed). Unzip `Humi-1.0.1.app.zip` and replace.

### Checksum
```
SHA-256 (Humi-1.0.1.app.zip) = 32aee30eac4c4682c2fb9df484d0bf7afa5323292c68d7d3ade484619b45d581
```
