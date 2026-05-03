## ADDED Requirements

### Requirement: TownScreen.select_item は MAIN_IDX_* 定数で施設を判別する
SHALL: `TownScreen.select_item(index)` の match 文または分岐は、生数値(`0`, `1`, `2`, `3`)ではなく `MAIN_IDX_GUILD`, `MAIN_IDX_SHOP`, `MAIN_IDX_TEMPLE`, `MAIN_IDX_DUNGEON_ENTRANCE` のような名前付き定数で判定する(esc_menu.gd の MAIN_IDX_* と同パターン)。

#### Scenario: select_item は名前付き定数で判定する
- **WHEN** `town_screen.gd:select_item` を grep する
- **THEN** `match index: 0:..1:..2:..3:..` 形式の生数値マッチは存在せず、`MAIN_IDX_GUILD` 等の定数で分岐している

#### Scenario: メニュー項目順を入れ替えても select_item が壊れない
- **WHEN** MENU_ITEMS の順序を変更し、対応する MAIN_IDX_* 定数値も更新する
- **THEN** `select_item` は定数経由で正しいシグナルを発行し続ける(数値直接マッチで壊れる事態を防ぐ)
