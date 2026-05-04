## Purpose
地上（町）マップ画面と施設選択を規定する。冒険者ギルド・商店・教会・ダンジョン入口の 4 施設への遷移、各施設のイラスト表示、カーソル選択を対象とする。
## Requirements
### Requirement: Town screen displays facility selection
TownScreen SHALL display a left column with facility buttons and a right column with an illustration placeholder area.

#### Scenario: Facility buttons are displayed
- **WHEN** the town screen is shown
- **THEN** buttons for "冒険者ギルド", "商店", "教会", "ダンジョン入口" SHALL be displayed in the left column

### Requirement: Town screen has cursor selection for facilities
TownScreen SHALL provide keyboard-based cursor navigation for facility selection. Up/Down keys SHALL move the cursor. Enter/Space SHALL select the facility.

#### Scenario: Cursor navigates between facilities
- **WHEN** the cursor is on "冒険者ギルド" and Down is pressed
- **THEN** the cursor SHALL move to "商店"

### Requirement: Illustration area updates on cursor movement
The right-side illustration area SHALL display a `TextureRect` showing the facility image associated with the currently highlighted facility, with an overlay `Label` presenting the facility name on a semi-transparent backdrop for readability. When the image resource for a facility cannot be loaded, the system SHALL fall back to displaying a `ColorRect` whose color corresponds to that facility and keep the name label visible.

#### Scenario: Illustration shows current selection image
- **WHEN** the cursor is on "冒険者ギルド"
- **THEN** the right area SHALL display the guild image (`assets/images/facilities/guild.png`) with a "冒険者ギルド" label overlaid

#### Scenario: Illustration changes on cursor move
- **WHEN** the cursor moves from "冒険者ギルド" to "ダンジョン入口"
- **THEN** the right area SHALL update to show the dungeon image (`assets/images/facilities/dungeon.png`) with a "ダンジョン入口" label overlaid

#### Scenario: Image load failure falls back to color
- **WHEN** the facility image resource for the currently highlighted facility fails to load
- **THEN** the right area SHALL display a `ColorRect` using the facility's fallback color and SHALL still display the facility name label

#### Scenario: Facility name label stays visible over the image
- **WHEN** any facility is highlighted and its image is displayed
- **THEN** the facility name label SHALL be visible on top of the image against a semi-transparent backdrop

### Requirement: Guild facility opens GuildScreen
TownScreen SHALL emit an `open_guild` signal when "冒険者ギルド" is selected.

#### Scenario: Select guild
- **WHEN** the user selects "冒険者ギルド"
- **THEN** the `open_guild` signal SHALL be emitted

### Requirement: Dungeon entrance facility opens DungeonEntrance
TownScreen SHALL emit an `open_dungeon_entrance` signal when "ダンジョン入口" is selected.

#### Scenario: Select dungeon entrance
- **WHEN** the user selects "ダンジョン入口"
- **THEN** the `open_dungeon_entrance` signal SHALL be emitted

### Requirement: Shop and Church are disabled placeholders
The system SHALL make "商店" and "教会" fully selectable on TownScreen. Selecting 「商店」 SHALL open ShopScreen; selecting 「教会」 SHALL open TempleScreen. The cursor SHALL NOT skip these entries.

#### Scenario: Shop is selectable
- **WHEN** the user moves the cursor to "商店" and presses Enter
- **THEN** ShopScreen SHALL be displayed

#### Scenario: Church is selectable
- **WHEN** the user moves the cursor to "教会" and presses Enter
- **THEN** TempleScreen SHALL be displayed

#### Scenario: Cursor no longer skips shop or church
- **WHEN** the cursor is on "冒険者ギルド" and Down is pressed
- **THEN** the cursor SHALL move to "商店" (not skip it)

### Requirement: Shop facility emits open_shop signal
TownScreen SHALL emit an `open_shop` signal when "商店" is selected, wired to navigate the main screen router to ShopScreen.

#### Scenario: Select shop
- **WHEN** the user selects "商店"
- **THEN** the `open_shop` signal SHALL be emitted

### Requirement: Church facility emits open_temple signal
TownScreen SHALL emit an `open_temple` signal when "教会" is selected, wired to navigate the main screen router to TempleScreen.

#### Scenario: Select church
- **WHEN** the user selects "教会"
- **THEN** the `open_temple` signal SHALL be emitted

### Requirement: TownScreen.select_item は MAIN_IDX_* 定数で施設を判別する
SHALL: `TownScreen.select_item(index)` の match 文または分岐は、生数値(`0`, `1`, `2`, `3`)ではなく `MAIN_IDX_GUILD`, `MAIN_IDX_SHOP`, `MAIN_IDX_TEMPLE`, `MAIN_IDX_DUNGEON_ENTRANCE` のような名前付き定数で判定する(esc_menu.gd の MAIN_IDX_* と同パターン)。

#### Scenario: select_item は名前付き定数で判定する
- **WHEN** `town_screen.gd:select_item` を grep する
- **THEN** `match index: 0:..1:..2:..3:..` 形式の生数値マッチは存在せず、`MAIN_IDX_GUILD` 等の定数で分岐している

#### Scenario: メニュー項目順を入れ替えても select_item が壊れない
- **WHEN** MENU_ITEMS の順序を変更し、対応する MAIN_IDX_* 定数値も更新する
- **THEN** `select_item` は定数経由で正しいシグナルを発行し続ける(数値直接マッチで壊れる事態を防ぐ)

