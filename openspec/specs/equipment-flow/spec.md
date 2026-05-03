## Purpose
EquipmentFlow Control: 装備変更フロー(キャラクター選択 → スロット選択 → 候補選択)を独立 Control として規定。

## Requirements

### Requirement: EquipmentFlow は独立した Control として動作する
SHALL: `EquipmentFlow extends Control` クラスを `src/esc_menu/flows/equipment_flow.gd` に定義する。本 Control は `setup(party: Array[Character], inventory: Inventory)` メソッドで初期化され、内部に 3 つのサブビュー(`CHARACTER`, `SLOT`, `CANDIDATE`)を持つ。フロー完了時に `flow_completed` シグナルを発行する。

#### Scenario: setup でフローが初期化される
- **WHEN** `EquipmentFlow.new()` をインスタンス化し `setup(party, inventory)` を呼ぶ
- **THEN** CHARACTER サブビューが表示され、パーティのキャラクター一覧が列挙される

#### Scenario: キャラクター選択後にスロット選択に進む
- **WHEN** CHARACTER サブビューでキャラクターを選択して ui_accept
- **THEN** SLOT サブビューに遷移し、6 個の装備スロット(WEAPON〜ACCESSORY)が表示される

#### Scenario: スロット選択後に候補選択に進む
- **WHEN** SLOT サブビューでスロットを選択して ui_accept
- **THEN** CANDIDATE サブビューに遷移し、当該スロットに装備可能(`Equipment.can_equip(item, slot, character)` が true)なアイテム一覧 + 「外す」が表示される

#### Scenario: 装備変更が反映される
- **WHEN** CANDIDATE サブビューでアイテム(または「外す」)を選択して ui_accept
- **THEN** `Equipment.equip(slot, instance, character)` または `Equipment.unequip(slot)` が呼ばれ、SLOT サブビューに戻る

#### Scenario: ui_cancel で前サブビューに戻る
- **WHEN** SLOT または CANDIDATE サブビューで ui_cancel が押される
- **THEN** 1 つ前のサブビューに戻る

#### Scenario: CHARACTER での ui_cancel はフロー終了
- **WHEN** CHARACTER サブビューで ui_cancel が押される
- **THEN** `flow_completed` シグナルが発行される

### Requirement: EquipmentFlow は単体でテスト可能である
SHALL: EquipmentFlow は EscMenu 全体をセットアップせずに直接インスタンス化してテストできる。

#### Scenario: 単体テストでフロー全体を駆動できる
- **WHEN** テスト内で `EquipmentFlow.new()` を作り setup と handle_input だけで操作する
- **THEN** EscMenu は不要で、フローの全 3 サブビューを通せる

### Requirement: EquipmentFlow は他キャラ装備のスワップに対応する
SHALL: 既存挙動の維持。CANDIDATE サブビューで他キャラクターが既に装備しているアイテムを選んだ場合、当該キャラクターからアイテムを外して選択中キャラに装備する。

#### Scenario: 他キャラが装備中のアイテムをスワップ
- **WHEN** Alice が WEAPON に長剣を装備しており、Bob の CANDIDATE で長剣を選択
- **THEN** Alice の WEAPON が空になり、Bob の WEAPON が長剣になる
