## ADDED Requirements

### Requirement: STAIRS_DOWN tile triggers descend dialog
`DungeonScreen` SHALL detect when the player moves onto a `STAIRS_DOWN` tile and display the existing `ConfirmDialog` instance asking 「下の階に降りますか?」 with the default cursor on いいえ. The dialog SHALL be the same `ConfirmDialog` instance used for the START-tile return prompt (no separate per-tile dialog).

#### Scenario: Moving onto STAIRS_DOWN shows descend dialog
- **WHEN** the player moves onto a STAIRS_DOWN tile
- **THEN** the ConfirmDialog SHALL be displayed with text 「下の階に降りますか?」 and the default cursor on いいえ

#### Scenario: STAIRS_DOWN dialog appears each time the tile is entered
- **WHEN** the player moves onto STAIRS_DOWN, selects いいえ, moves away, and returns
- **THEN** the descend dialog SHALL appear again

#### Scenario: STAIRS_DOWN dialog uses the same ConfirmDialog as START-tile return
- **WHEN** examining DungeonScreen at runtime
- **THEN** the same `_return_dialog: ConfirmDialog` field SHALL be reused for both START-tile return and STAIRS_DOWN/STAIRS_UP descend/ascend prompts

### Requirement: STAIRS_UP tile triggers ascend dialog
`DungeonScreen` SHALL detect when the player moves onto a `STAIRS_UP` tile and display the existing `ConfirmDialog` instance asking 「上の階に戻りますか?」 with the default cursor on いいえ.

#### Scenario: Moving onto STAIRS_UP shows ascend dialog
- **WHEN** the player moves onto a STAIRS_UP tile
- **THEN** the ConfirmDialog SHALL be displayed with text 「上の階に戻りますか?」 and the default cursor on いいえ

#### Scenario: STAIRS_UP dialog appears each time the tile is entered
- **WHEN** the player moves onto STAIRS_UP, selects いいえ, moves away, and returns
- **THEN** the ascend dialog SHALL appear again

### Requirement: Confirming descend transitions to the next floor
When the player confirms はい on the STAIRS_DOWN dialog, `DungeonScreen` SHALL increment `player_state.current_floor` by 1 and place the player on the corresponding `STAIRS_UP` tile of the new floor. The player's facing direction SHALL be preserved across the transition.

#### Scenario: Descend places the player on the next floor's STAIRS_UP
- **WHEN** the player is on floor 0's STAIRS_DOWN at coordinates (5, 5) facing EAST and confirms はい
- **THEN** player_state.current_floor SHALL become 1, player_state.position SHALL be the coordinates of floor 1's STAIRS_UP tile, and player_state.facing SHALL remain EAST

#### Scenario: Descend triggers a screen refresh for the new floor
- **WHEN** the player descends from floor 0 to floor 1
- **THEN** DungeonScreen SHALL render floor 1's wiz_map, the minimap SHALL display floor 1, and floor 1's explored_map SHALL receive any new visibility updates

#### Scenario: Descend dialog is canceled
- **WHEN** the player is on STAIRS_DOWN and selects いいえ
- **THEN** player_state.current_floor SHALL NOT change and the player SHALL remain on the STAIRS_DOWN tile

### Requirement: Confirming ascend transitions to the previous floor
When the player confirms はい on the STAIRS_UP dialog, `DungeonScreen` SHALL decrement `player_state.current_floor` by 1 and place the player on the corresponding `STAIRS_DOWN` tile of the new floor. The player's facing direction SHALL be preserved across the transition.

#### Scenario: Ascend places the player on the previous floor's STAIRS_DOWN
- **WHEN** the player is on floor 2's STAIRS_UP at coordinates (3, 7) facing SOUTH and confirms はい
- **THEN** player_state.current_floor SHALL become 1, player_state.position SHALL be the coordinates of floor 1's STAIRS_DOWN tile, and player_state.facing SHALL remain SOUTH

#### Scenario: Ascend triggers a screen refresh for the new floor
- **WHEN** the player ascends from floor 2 to floor 1
- **THEN** DungeonScreen SHALL render floor 1's wiz_map and the minimap SHALL display floor 1

#### Scenario: Ascend dialog is canceled
- **WHEN** the player is on STAIRS_UP and selects いいえ
- **THEN** player_state.current_floor SHALL NOT change and the player SHALL remain on the STAIRS_UP tile

### Requirement: Floor transitions do not emit step_taken
When `DungeonScreen` performs a stair-based floor transition, the `step_taken` signal SHALL NOT be emitted for the destination position. The encounter system SHALL therefore NOT roll for an encounter as a direct result of the transition itself.

#### Scenario: Descending does not roll an encounter
- **WHEN** the player confirms はい on STAIRS_DOWN and is teleported to the next floor's STAIRS_UP
- **THEN** step_taken SHALL NOT be emitted, and EncounterCoordinator SHALL NOT trigger an encounter due to this transition alone

#### Scenario: Ascending does not roll an encounter
- **WHEN** the player confirms はい on STAIRS_UP and is teleported to the previous floor's STAIRS_DOWN
- **THEN** step_taken SHALL NOT be emitted

### Requirement: Encounter trigger takes priority over stair transition prompts
When both a stair transition prompt (STAIRS_DOWN or STAIRS_UP) and an encounter would fire on the same step, the system SHALL present the encounter first. The stair prompt SHALL only appear after the encounter is resolved if the player is still on the stair tile.

#### Scenario: Step onto STAIRS_DOWN with triggered encounter
- **WHEN** the player moves onto a STAIRS_DOWN tile and the encounter roll also triggers
- **THEN** the encounter overlay SHALL be shown first and the descend dialog SHALL NOT be shown until the encounter is resolved

#### Scenario: Stair prompt re-checks after encounter resolution
- **WHEN** an encounter that triggered on a stair tile is resolved and the player is still on the stair tile
- **THEN** the corresponding stair dialog SHALL appear after the encounter resolves

## MODIFIED Requirements

### Requirement: ダンジョン帰還ダイアログは ConfirmDialog で構築される
SHALL: ダンジョンスクリーンで START / STAIRS_DOWN / STAIRS_UP タイル上で起動される確認ダイアログは、`ConfirmDialog` の子インスタンスを利用して構築される。`DungeonScreen` 内でインライン実装する `_build_return_dialog` のような per-screen UI 構築コードは存在しない。`DungeonScreen` は `_return_dialog: ConfirmDialog` フィールドを保持し、START タイル上では `setup("町に戻りますか？", default_index)`、STAIRS_DOWN タイル上では `setup("下の階に降りますか?", default_index)`、STAIRS_UP タイル上では `setup("上の階に戻りますか?", default_index)` を呼ぶ。

#### Scenario: 帰還ダイアログ表示時に ConfirmDialog が使われる
- **WHEN** プレイヤーが START タイル上で `check_start_tile_return()` をトリガする
- **THEN** `_return_dialog.setup("町に戻りますか？", ...)` が呼ばれ、ConfirmDialog が visible になる

#### Scenario: 階段ダイアログでも同じ ConfirmDialog が再利用される
- **WHEN** プレイヤーが STAIRS_DOWN タイルへ進入する
- **THEN** START 帰還で使われるのと同じ `_return_dialog` インスタンスが `setup("下の階に降りますか?", ...)` で再利用され visible になる

#### Scenario: 「はい」確定で町に戻る
- **WHEN** ConfirmDialog が `confirmed` シグナルを発行（START タイル文脈）
- **THEN** ダンジョンスクリーンが町画面に遷移する

#### Scenario: 「いいえ」または ESC でダイアログが閉じてダンジョンに残る
- **WHEN** ConfirmDialog が `cancelled` シグナルを発行
- **THEN** ダイアログが閉じ、ダンジョンスクリーンに残る(プレイヤーは元のタイル上のまま)
