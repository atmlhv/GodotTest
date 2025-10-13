# Coding Guidelines Memo

最近発生したエラーを元にしたコーディング規約メモです。作業前に確認し、同様の不具合を防いでください。

- **インデントは既存ファイルのスタイルに合わせる（GDScript はタブ専用）**
  - GDScript ファイルではタブとスペースが混在すると `Parse Error: Used space character for indentation instead of tab` が発生します。
  - 既存コードがタブでインデントされている場合は必ずタブを使用し、スペースと混在させないでください。
  - 例: `scenes/Combat.gd` の `_initialize_battle()` 内でスペースを混ぜた結果、`Mixed use of tabs and spaces for indentation.` が出力されました。
  - 例: 同じく `scenes/Combat.gd` の `_show_target_options()` で `if target_scroll == null or target_list == null:` 以下の行をスペースだけでインデントすると、`Error at (420, 103): Mixed use of tabs and spaces for indentation.` が発生しました。ブロック全体をタブのみで揃えてください。
- **三項演算子の代わりに `if ... else` 構文を使う**
  - Godot 4 の GDScript では `condition ? a : b` 形式はサポートされません。
  - 代わりに `a if condition else b` を使用しないと `Parse Error: Unexpected "?" in source` が発生します。
  - 例: `scenes/Combat.gd` の AI ターゲット選択処理で `?` を使うと今回のエラーが再発しました。
- **`sort_custom` には `Callable` を渡す**
  - Godot 4 の `Array.sort_custom` は 1 つの `Callable` 引数のみを受け取ります。
  - `sort_custom(self, "method")` のように 2 引数で呼び出すと `Too many arguments for "sort_custom()" call` エラーになります。
  - メソッド参照を渡したい場合は `array.sort_custom(Callable(self, "method"))` のように記述してください。
- **差分やマージ時のマーカーを残さない**
  - `*** End Patch` や `<<<<<<<` などのマーカーがファイルに残ると `Parse Error: Unexpected "**" in class body` のような構文エラーになります。
  - 編集後は不要なマーカーが残っていないか必ず確認し、クリーンな状態で保存してください。
- **データ読み込み完了前に参照しない**
  - `Data.get_skill_by_id()` などのデータ取得系関数は、JSON のロードが完了する前に呼び出すと空の辞書を返します。
  - その状態で攻撃コマンドを生成すると「有効なスキルがない」と判定され、行動を選択できなくなります。
  - バトル開始前に `Data.data_loaded` を待つか、フォールバックデータを用意して例外を回避してください。
- **ターゲット選択 UI のボタンには実行用コールバックを直接接続する**
  - `_clear_targets()` のタイミングで `_target_callback` をクリアしてしまう実装だと、攻撃対象の一覧を開いた直後にコールバックが無効化され、ボタンを押してもコマンドが確定しない不具合が発生しました。
  - ターゲット一覧を構築する際は `Callable(self, "_on_skill_target_selected").bind(...)` のように、その場で引数付きの `Callable` を生成して `button.pressed.connect` に渡してください。グローバル変数に格納したコールバックへ委譲すると再描画時に失われます。
  - `Callable` を別の `Callable` の引数としてバインドすると `is_valid()` が `false` になり、ターゲットボタンが常に無効化されました。メソッド本体の `Callable` と引数配列を別々に保持し、シグナル側ではローカルターゲットのみをバインドするようにしてください。
- **ターゲットボタンの `Callable` はメタデータ経由で保持する**
  - ターゲット候補の辞書に格納した `Callable` をそのまま `button.pressed.connect(callback)` したところ、押下時に何も起きず攻撃対象を選択できませんでした。
  - ボタン生成時に `button.set_meta("target_callback", callable)` で保持し、シグナルは `Callable(self, "_on_target_button_pressed").bind(button)` のように共通ハンドラへ接続して `callable.call()` を実行してください。
- **シグナル接続で引数を束縛するときは `Callable` を明示する**
  - `button.pressed.connect(_on_pressed.bind(arg))` のようにメソッド参照を直接 `bind` するとコネクションが無効になり、ボタンを押しても何も起きませんでした。
  - 必ず `button.pressed.connect(Callable(self, "_on_pressed").bind(arg))` の形式で `Callable` を生成してから `bind` を使用してください。
- **スペースだけでインデントされた行を残さない**
  - タブでインデントされているブロックにスペースだけのインデント行が混ざると `Parse Error: Expected statement, found "Indent" instead.` が発生しました。
  - 空行を追加する場合でもタブで揃えるか、余計な空白を削除して保存してください。

上記に違反するとスクリプトが読み込まれず、ゲーム起動時にエラーが表示されます。常に Godot の構文ルールと既存スタイルに従ってください。
