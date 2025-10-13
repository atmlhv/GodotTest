# Coding Guidelines Memo

最近発生したエラーを元にしたコーディング規約メモです。作業前に確認し、同様の不具合を防いでください。

- **インデントは既存ファイルのスタイルに合わせる**
  - GDScript ファイルではタブとスペースが混在すると `Parse Error: Used space character for indentation instead of tab` が発生します。
  - 既存コードがタブでインデントされている場合は必ずタブを使用し、スペースと混在させないでください。
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
- **ターゲット選択 UI を初期化するときはコールバックを消さない**
  - `_clear_targets()` が `_target_callback` をリセットするため、ターゲット一覧表示前に呼び出すとボタンを押しても処理されなくなります。
  - `_show_target_options()` でターゲット一覧を更新する際は、ボタンのクリア処理だけを行い、コールバックは表示後に設定するかリセットしないようにしてください。
  - 生成したボタンはその時点の `Callable` を `connect` に直接渡し、後から `_target_callback` がクリアされても押下時に有効な処理が呼べるようにしてください。グローバル変数だけに依存すると、押しても反応しない不具合になります。
- **シグナル接続で引数を束縛するときは `Callable` を明示する**
  - `button.pressed.connect(_on_pressed.bind(arg))` のようにメソッド参照を直接 `bind` するとコネクションが無効になり、ボタンを押しても何も起きませんでした。
  - 必ず `button.pressed.connect(Callable(self, "_on_pressed").bind(arg))` の形式で `Callable` を生成してから `bind` を使用してください。
- **スペースだけでインデントされた行を残さない**
  - タブでインデントされているブロックにスペースだけのインデント行が混ざると `Parse Error: Expected statement, found "Indent" instead.` が発生しました。
  - 空行を追加する場合でもタブで揃えるか、余計な空白を削除して保存してください。

上記に違反するとスクリプトが読み込まれず、ゲーム起動時にエラーが表示されます。常に Godot の構文ルールと既存スタイルに従ってください。
