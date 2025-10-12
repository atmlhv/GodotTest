# Coding Guidelines Memo

最近発生したエラーを元にしたコーディング規約メモです。作業前に確認し、同様の不具合を防いでください。

- **インデントは既存ファイルのスタイルに合わせる**
  - GDScript ファイルではタブとスペースが混在すると `Parse Error: Used space character for indentation instead of tab` が発生します。
  - 既存コードがタブでインデントされている場合は必ずタブを使用し、スペースと混在させないでください。
- **三項演算子の代わりに `if ... else` 構文を使う**
  - Godot 4 の GDScript では `condition ? a : b` 形式はサポートされません。
  - 代わりに `a if condition else b` を使用しないと `Parse Error: Unexpected "?" in source` が発生します。

上記に違反するとスクリプトが読み込まれず、ゲーム起動時にエラーが表示されます。常に Godot の構文ルールと既存スタイルに従ってください。
