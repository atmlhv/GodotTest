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
- **ターゲット選択 UI ではメタデータに選択情報を保存して共通ハンドラで処理する**
  - `_clear_targets()` のタイミングで `_target_callback` をリセットするため、グローバル変数や一時的な `Callable` を保持しているとボタンを押しても行動が登録されなくなります。
  - 以前は `button.set_meta("target_callback", callable)` で `Callable` を保存していましたが、Godot 4.5 では押下時に `callable.is_valid()` が `false` へ変化し、攻撃対象を選択できない不具合が再発しました。
  - ターゲットボタンを生成する際は `{ "mode": "skill", "target": target, "actor": actor }` などの辞書を `button.set_meta("target_payload", payload)` で保持し、`_on_target_button_pressed()` から種別ごとの処理関数を呼び出してください。
  - メタデータに必要な情報を残しておけば UI の再描画や `_clear_targets()` 実行後でも選択内容が失われず、攻撃・アイテムともにターゲット決定が確実に機能します。
  - `BattleEntity` インスタンスをメタデータから取得した際に `payload.get("target") is BattleEntity` の判定が `false` になり、ターゲット決定が行われない事例がありました（Godot が `RefCounted` として返すため）。`as BattleEntity` でキャストした結果が `null` でないこと、`is_alive()` で有効なことを確認してから処理を進めてください。
- **シグナル接続で引数を束縛するときは `Callable` を明示する**
  - `button.pressed.connect(_on_pressed.bind(arg))` のようにメソッド参照を直接 `bind` するとコネクションが無効になり、ボタンを押しても何も起きませんでした。
  - 必ず `button.pressed.connect(Callable(self, "_on_pressed").bind(arg))` の形式で `Callable` を生成してから `bind` を使用してください。
- **スペースだけでインデントされた行を残さない**
  - `scenes/Combat.gd` の `enemy_single` 対象選択ブロックでスペースインデントのまま保存した結果、`Error at (705, 1): Expected statement, found "Indent" instead.` が発生しました。タブへ置き換えて解消しました。
  - タブでインデントされているブロックにスペースだけのインデント行が混ざると `Parse Error: Expected statement, found "Indent" instead.` が発生しました。
  - 空行を追加する場合でもタブで揃えるか、余計な空白を削除して保存してください。
- **Nullable な戻り値を `:=` で受けると `Variant` 型に推論される**
  - Godot 4.5 では `var target := _resolve_payload_entity(...)` のように `:=` で受けると、`null` を返す可能性がある関数の場合 `Variant` 型として推論されます。
  - `_handle_item_target_payload()` でこの書き方をすると `Error at (512, 9): The variable type is being inferred from a Variant value, so it will be typed as Variant.` が表示され、警告がエラー扱いになります。
  - `var target: BattleEntity = ...` のように明示的な型注釈を追加し、参照が `null` かどうかをチェックしてから処理を続けてください。
- **`weakref()` の戻り値を `:=` で受けると `Variant` 型に推論される**
  - `weakref(actor)` は `WeakRef` を返しますが、`var actor_ref := weakref(actor)` のように書くと戻り値が `Variant` 扱いになり `Error at (532, 5): The variable type is being inferred from a Variant value, so it will be typed as Variant.` が発生しました。
  - `var actor_ref: WeakRef = weakref(actor)` のように `WeakRef` 型を明記し、他のメタデータ構築処理でも同様の注釈を付けてください。

上記に違反するとスクリプトが読み込まれず、ゲーム起動時にエラーが表示されます。常に Godot の構文ルールと既存スタイルに従ってください。
