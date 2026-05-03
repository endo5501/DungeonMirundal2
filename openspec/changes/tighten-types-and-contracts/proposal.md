## Why

GDScript の型推論は強力だが、`var x = some_dict.get(...)` のような書き方をすると暗黙的に Variant になり、ホットパス(turn_engine.gd:64,98)でも型情報が失われる。型が緩いと:

- IDE の補完が効かない
- リファクタ時の影響範囲解析がコンパイラに頼れない
- 「これ何の型?」という疑問が随所で発生する

監査で 11 箇所の暗黙 Variant、1 箇所の `Array` を `Array[Vector2i]` に締めるべきパラメータ、`Array[Array]` の戻り値、untyped target、resource_path 経由の id 推測、game_state 初期化の対称性欠如、などが指摘されている。これらを 1 つの change にまとめて型と契約を固める。

`is_slot_consistent` 削除(C3 で完了)と並んで、コード全体のシグネチャを綺麗にする最後の整理。

## What Changes

- `src/dungeon/wiz_map.gd:124` の `var tmp = candidates[i]` を `var tmp: Array = candidates[i]` に
- `src/items/equipment.gd:116` の `var raw = data.get(key)` を `var raw: Variant = data.get(key)` に明示(または specific 型に)
- `src/dungeon_scene/combat_overlay.gd:234` の `var ch = pc.character if pc is PartyCombatant else pc` を `var ch: Variant = ...` で明示し、必要なら `is` チェック経由で `Character` に narrow
- `src/items/item_instance.gd:23` の暗黙型を明示
- `src/items/effects/heal_hp_effect.gd:10` および `heal_mp_effect.gd:10` の暗黙型を明示
- `src/dungeon/full_map_renderer.gd:49` の暗黙型を明示
- `src/guild_scene/party_formation.gd:126` の暗黙型を明示
- **`src/combat/turn_engine.gd:64,98` の `var cmd = _pending_commands.get(...)` を `var cmd: CombatCommand = _pending_commands.get(...) as CombatCommand` に**(ホットパス)
- `src/dungeon/explored_map.gd:12` の `mark_visible(cells: Array)` を `mark_visible(cells: Array[Vector2i])` に
- `src/dungeon/guild.gd:get_party_characters` を `Array[Array]` (typed) に変更し、`# Returns [front_row, back_row]` の不変条件をコメントとシグネチャ両方で明示
- `src/dungeon/wiz_map.gd:218,220` の冗長な `as int` キャストを削除
- `src/items/item.gd:get_target_failure_reason(target, ctx)` の `target` を `Variant` で型ヒント、コメントで「Character または CombatActor」を明示
- `src/dungeon/character.gd:97` の `race.resource_path.get_file().get_basename()` を、`RaceData.id: StringName` / `JobData.id: StringName` の明示フィールドに置き換える
- `src/data/race_data.gd` と `src/data/job_data.gd` に `@export var id: StringName` フィールドを追加
- `data/races/*.tres` と `data/jobs/*.tres` に `id` 値を埋める(各ファイルのファイル名と一致させる)
- `src/game_state.gd` の `new_game` と `_ready` を共通の `_initialize_state()` ヘルパーに統合(`item_repository` の再初期化を含めるかは仕様判断、現状 game_session 単位で持続させる方針なら `new_game` は inventory のみ再構築)

## Capabilities

### Modified Capabilities

- `serialization`: Character 保存時の race_id / job_id を `RaceData.id` / `JobData.id` 経由で取得することを明示
- `race-data`: `id: StringName` フィールド要件を追加
- `job-data`: `id: StringName` フィールド要件を追加
- `inventory`: `Inventory.spend_gold(0)` の挙動を「true 返却の no-op」に明示(F028 の footgun 解消)
- `game-state`: `new_game` と `_ready` 初期化の対称性を要件として追加

## Impact

- **変更コード**:
  - 11 ファイルの暗黙型を明示
  - `src/data/race_data.gd`, `src/data/job_data.gd` に `id` フィールド追加
  - `data/races/*.tres`, `data/jobs/*.tres` に `id` 値設定(DataLoader で id を埋める移行スクリプトでも可)
  - `src/dungeon/character.gd:to_dict` の race_id / job_id 取得ロジックを `id` フィールド参照に
  - `src/game_state.gd` の `_initialize_state` ヘルパー追加
  - `src/items/inventory.gd:spend_gold` の amount==0 を no-op true に変更
- **追加テスト**:
  - `tests/data/test_race_data.gd` / `test_job_data.gd` に `id` フィールドの要件テスト
  - `tests/items/test_inventory.gd` に `spend_gold(0)` テスト
  - `tests/game_state/test_game_state.gd` (新規 or 既存)に new_game の対称性テスト
- **互換性**:
  - 既存セーブの race_id / job_id 文字列形式は不変(現状ファイル名ベースで、`id` フィールドもファイル名と同じ値にすればロード時の参照は変わらない)
  - 既存 .tres は `id` フィールド追加が必要 — マイグレーションスクリプト(または手作業)
- **依存関係**:
  - C7 完了後に着手すると、combat_overlay の暗黙型解消が綺麗に進む
  - 他の change との衝突は少ない(独立気味)
