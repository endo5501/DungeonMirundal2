## Why

セーブ／ロード経路にユーザに見えない静かな失敗が複数残っており、ディスクフルや書き込み権限失効、リネームされた `.tres` 参照、欠損したアセットディレクトリといった失敗が「保存しました」「ロード成功」のように成功扱いで通過してしまう。最も悲惨なケースでは、プレイヤーは自分のセーブが書けていないことに気付かないまま遊び続け、後でクラッシュや状態不整合に至る。本変更で「失敗を呼び出し元に必ず伝える」ことを契約として確立し、UI 側にエラーメッセージを表示する。

加えて `Character.from_dict` が race/job の load 失敗を null 返却で許容しているため、`ch.race.race_name` のような遠隔参照で不可解なクラッシュを起こす。データ整形の段階で検出して捨てる方針に切り替える。

## What Changes

- `SaveManager.save(slot_number)` の戻り値を `void` から `bool` に変更し、`FileAccess.open == null` 等の失敗を呼び出し元に通知する
- `SaveManager.load(slot_number)` の失敗事由を区別する `LoadResult` 列挙(または同等の戻り値拡張)を導入し、ファイル欠損 / JSON 破損 / バージョン未来 / 内部復元失敗を `SaveScreen` / `LoadScreen` / `main._load_game` で識別できるようにする
- `Character.from_dict` を `RaceData` / `JobData` の load 失敗で `null` を返すよう変更し、`Guild.from_dict` は null を `push_warning` してスキップする
- `DataLoader._load_resources` が `DirAccess.open == null` のとき `push_error` を出すよう変更する(packaging エラーは黙ってはいけない)
- `SaveScreen` の保存成功 UI(`save_completed.emit()`) を、`SaveManager.save` の戻り値で分岐させ、失敗時はエラーラベルを表示する
- `LoadScreen` / `main._load_game` のロード失敗経路を、ユーザに「ロードに失敗しました(理由)」と表示できる形に拡張する
- `tests/save_load/test_save_manager.gd` に `version > CURRENT_VERSION` ケース、JSON 破損ケース、書き込み失敗ケース(モック可能な範囲で)のテストを追加する

## Capabilities

### Modified Capabilities

- `save-manager`: `save()` 戻り値、`load()` 失敗事由の細分化、不正データ検出時の挙動を追記
- `save-screen`: 保存失敗時のフィードバック表示を追加
- `load-screen`: ロード失敗時のフィードバック表示を追加
- `serialization`: `Character.from_dict` の race/job null 検出時の挙動、`Guild.from_dict` の null character スキップ挙動を追記

## Impact

- **変更コード**:
  - `src/save_manager.gd` — `save` の戻り値変更、`load` の戻り値型変更、`get_last_slot` の整合性
  - `src/save_screen.gd` — 失敗時 UI、`_on_slot_selected` / `_handle_overwrite_input` で戻り値ハンドリング
  - `src/load_screen.gd` — 失敗時 UI、ロード失敗シグナル
  - `src/main.gd:259-263` `_load_game` — 失敗時のリストア処理と LoadScreen への通知
  - `src/dungeon/character.gd:110-131` — race/job 検証、null 返却
  - `src/dungeon/guild.gd:99-100` — null character のスキップ
  - `src/dungeon/data/data_loader.gd:43-54` — push_error 追加
- **追加テスト**:
  - `tests/save_load/test_save_manager.gd` に未来バージョン拒否、JSON 破損、書き込み失敗ケース
  - `tests/save_load/` に Character.from_dict / Guild.from_dict の null 経路テスト
- **互換性**:
  - 既存セーブデータ形式は不変。挙動変化は失敗時のみ。
  - `SaveManager.save` 戻り値変更は呼び出し元 3 箇所(SaveScreen 2 箇所 + main の auto save が将来あれば)を更新するだけ
- **依存関係**: なし(独立 change)。実装着手の前提条件はゼロ。
