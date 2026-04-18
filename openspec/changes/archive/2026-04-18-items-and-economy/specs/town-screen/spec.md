## MODIFIED Requirements

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

## ADDED Requirements

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
