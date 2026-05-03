## ADDED Requirements

### Requirement: ItemUseContext と ItemEffectResult は src/items/ 直下に配置される
SHALL: `ItemUseContext` クラス(`item_use_context.gd`)と `ItemEffectResult` クラス(`item_effect_result.gd`)は `src/items/` 直下に配置される。`src/items/conditions/` サブディレクトリには TargetCondition / ContextCondition の具象実装(`has_mp_slot.gd`, `is_dead.gd` 等)のみが残る。

#### Scenario: item_use_context.gd の場所
- **WHEN** `src/items/` の直下を確認する
- **THEN** `item_use_context.gd` および `item_effect_result.gd` が直下に存在する

#### Scenario: conditions/ サブディレクトリには context.gd が含まれない
- **WHEN** `src/items/conditions/` を確認する
- **THEN** `item_use_context.gd` は存在しない(`has_mp_slot.gd`, `is_dead.gd` 等の condition 実装のみが残る)

#### Scenario: 移動後も class_name 経由の参照は壊れない
- **WHEN** 各 effect / condition のテストおよびプロダクションコードを実行する
- **THEN** `ItemUseContext` への参照はすべて class_name 経由で正常に解決される
