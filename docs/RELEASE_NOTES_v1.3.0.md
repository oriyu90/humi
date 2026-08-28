# Humi v1.3.0

品質リリース。ターミナル内部の安定性・安全性の精査と、カスタムコントロールの
Hallmark インタラクション状態の整備。新しいキー割り当ては 2 つだけ。
A quality release: a stability / safety pass over the terminal internals and a Hallmark
interaction-state pass over the custom controls. Only two new bindings.

---

## 日本語

### 修正
- **タイルを閉じた直後（〜1.8 秒以内）に ⌘Q すると孤児シェルが残りうる問題。** SIGKILL 回収が
  遅延実行される pid を `TerminalRegistry` が追跡し、終了時に取りこぼさず回収します。
- **出力トリガー有効時のフラッド。** 高速スクロールするログでメインスレッドが詰まりうる問題を修正。
  `OutputMonitor` をバイトベースに（pty 読み取りの境界をまたぐマルチバイト文字が壊れない）、
  1 回の処理行数と行長に上限。
- **再割り当てショートカットがテキスト編集中のキー入力を横取り**（メモ欄・名前変更・設定）。
  テキスト入力中は発火しないようにしました。
- ステータスバーのタイマーをタイルごとから 1 本の共有に。`hasLiveForegroundChild`
  （全プロセス走査）をキャッシュ。
- ステータスバーの `git` に 2 秒タイムアウト。ハングしたリポジトリで固まらない。
- ペインをクリックする前でも `⌘⌃` + 矢印のフォーカス移動が効く。
- `.login` シェルの実体が **fish** の場合、fish 用の OSC 7 スニペットを送るように。
- ペインキャンバスの不要な `ScrollViewReader` を除去。

### 新機能
- **キーボードでのペインリサイズ** — `⌃⌘]` で広げる / `⌃⌘[` で狭める。
- すべてのカスタムコントロールに Hallmark の状態: ホバー、キーボードフォーカスリング
  （`Hum.focusRing`、高コントラストのテーマ適応ブルー、3〜4pt）、無効、`HumButtonStyle` の
  loading / success / error。タイトルバーのアイコンボタンは 26pt + フォーカスリング。
  分割線はホバー強調とリークしないリサイズカーソル。「コントラストを上げる」で
  ヘアラインと色味が強まります。
- パレットの WCAG コントラスト自動試験（`suite("Contrast")`）。

### 変更
- **`maximizeTile` の既定を `⌃⌘M` に変更** — 素の `⌘M` は macOS のウィンドウ最小化に飲まれるため。
  `keymap.json` に保存済みの割り当てはそのまま。

### 動作環境・インストール
macOS 14 以降、ad-hoc 署名（公証なし）。`Humi-1.3.0.dmg` を開き `Humi.app` を Applications へドラッグ
（`Humi-1.3.0.app.zip` も添付）。初回起動は「システム設定 › プライバシーとセキュリティ」から許可。

### チェックサム
```
SHA-256 (Humi-1.3.0.dmg)     = e048fdf412a6ec9907f89f242dade2762701a582697960e362a2a4b91277424f
SHA-256 (Humi-1.3.0.app.zip) = 52cb4d8ebadf9f7e328691d72fcf061c2a44e65bcbdbbe02b598a18416772c2c
```

---

## English

### Fixed
- **Orphaned shell on close-then-quit.** A tile closed <~1.8s before ⌘Q could
  leave its shell for launchd. `TerminalRegistry` tracks pids whose deferred
  SIGKILL-reap hasn't run and finishes them on quit.
- **Output-trigger flood.** A fast-scrolling log with a trigger active could jam
  the main thread. `OutputMonitor` is byte-based now (a multi-byte character
  split across two pty reads is no longer corrupted), clips a burst, and caps
  line length before matching.
- **Rebound shortcut swallowed keystrokes** while a text field / editor had
  focus (Notes, rename, Settings). It now only fires when text isn't being edited.
- One shared 12s status-bar timer instead of one per visible tile;
  `hasLiveForegroundChild` (a whole-machine process walk) is cached.
- `git` in the status bar gets a 2s timeout so a hung repo can't wedge it.
- `⌘⌃`+arrow pane focus works before you've clicked a pane.
- A `.login` shell that is actually **fish** now gets the fish OSC 7 snippet.
- Stale `ScrollViewReader` removed from the pane canvas.

### Added
- **Keyboard pane resize** — `⌃⌘]` grows, `⌃⌘[` shrinks the focused pane.
- Hallmark states on every custom control: hover, keyboard-focus ring
  (`Hum.focusRing`, a high-contrast theme-adaptive blue, 3–4pt), disabled, and
  loading / success / error on `HumButtonStyle`. Title-bar icon buttons get
  26pt targets and a focus ring. Split handles show a hover highlight and a
  leak-proof resize cursor. `Increase Contrast` firms up hairlines and washes.
- A WCAG contrast self-test over the palette.

### Changed
- **`maximizeTile` default is now `⌃⌘M`** — plain `⌘M` is intercepted by macOS
  window-minimize. Existing `keymap.json` bindings are untouched.

### Requirements / install
macOS 14+, ad-hoc signed (not notarized). Open `Humi-1.3.0.dmg` and drag `Humi.app`
to Applications (`Humi-1.3.0.app.zip` is also attached). On first launch, allow it in
System Settings › Privacy & Security.

### Checksum
```
SHA-256 (Humi-1.3.0.dmg)     = e048fdf412a6ec9907f89f242dade2762701a582697960e362a2a4b91277424f
SHA-256 (Humi-1.3.0.app.zip) = 52cb4d8ebadf9f7e328691d72fcf061c2a44e65bcbdbbe02b598a18416772c2c
```
