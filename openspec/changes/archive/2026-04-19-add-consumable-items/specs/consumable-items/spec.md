## ADDED Requirements

### Requirement: ItemEffect defines a pluggable use effect

The system SHALL provide an abstract Resource class `ItemEffect` (`class_name ItemEffect extends Resource`) that declares a unified interface `apply(user, targets, context) -> ItemEffectResult`. Each concrete effect SHALL extend `ItemEffect` and implement `apply`. An `ItemEffectResult` SHALL indicate at least `success: bool` and an optional human-readable message.

#### Scenario: ItemEffect is abstract-like base
- **WHEN** code loads `ItemEffect.gd`
- **THEN** it SHALL expose a `class_name ItemEffect extends Resource` with an overridable `apply(user, targets, context) -> ItemEffectResult` method

#### Scenario: Concrete effects extend ItemEffect
- **WHEN** `HealHpEffect` / `HealMpEffect` / `EscapeToTownEffect` resources are loaded
- **THEN** each SHALL extend `ItemEffect`

### Requirement: HealHpEffect restores a character's HP by a configured power

The system SHALL provide `HealHpEffect extends ItemEffect` with an `@export var power: int` field. When applied to a single target Character, it SHALL increase that Character's `current_hp` by `power`, clamped to `max_hp`.

#### Scenario: Heal within cap
- **WHEN** a `HealHpEffect { power = 20 }` is applied to a Character with `current_hp == 10` and `max_hp == 40`
- **THEN** the Character's `current_hp` SHALL become `30`

#### Scenario: Heal clamps at max_hp
- **WHEN** a `HealHpEffect { power = 20 }` is applied to a Character with `current_hp == 35` and `max_hp == 40`
- **THEN** the Character's `current_hp` SHALL become `40` (not `55`)

### Requirement: HealMpEffect restores a character's MP by a configured power

The system SHALL provide `HealMpEffect extends ItemEffect` with an `@export var power: int` field. When applied to a single target Character that has MP slots, it SHALL increase that Character's MP by `power` (distributed or represented per the existing MP data model), clamped to the Character's current max MP capacity.

#### Scenario: Heal within cap
- **WHEN** a `HealMpEffect { power = 10 }` is applied to a caster with 2 current MP and 30 max MP
- **THEN** the caster's MP SHALL become `12`

#### Scenario: Heal clamps at max
- **WHEN** a `HealMpEffect { power = 10 }` is applied to a caster with 28 current MP and 30 max MP
- **THEN** the caster's MP SHALL become `30` (not `38`)

### Requirement: EscapeToTownEffect transitions the party to the town menu entry

The system SHALL provide `EscapeToTownEffect extends ItemEffect`. When applied:

- If the call occurs **outside combat**, the effect SHALL emit the existing `return_to_town` signal path so that the player is transitioned to the town menu entry (same destination as the START-tile return).
- If the call occurs **inside combat**, the effect SHALL end the current battle as a **successful escape** (equivalent outcome to `ESCAPED`, no gained EXP/gold) and THEN trigger the town transition.

#### Scenario: Out-of-combat use transitions to town
- **WHEN** `EscapeToTownEffect.apply` is invoked from the ESC menu item use flow while the player is in the dungeon
- **THEN** the same `return_to_town` signal path that the START-tile dialog uses SHALL be triggered, and the town menu entry SHALL appear

#### Scenario: In-combat use ends battle with ESCAPED and returns to town
- **WHEN** `EscapeToTownEffect.apply` is resolved inside CombatOverlay during turn resolution
- **THEN** the combat SHALL terminate with `EncounterOutcome.result == ESCAPED` (no EXP, no gold), and subsequently the town menu entry SHALL be displayed

### Requirement: ContextCondition gates item use by game-state context

The system SHALL provide an abstract Resource class `ContextCondition` (`class_name ContextCondition extends Resource`) with a method `is_satisfied(context: ItemUseContext) -> bool` and `reason() -> String` for UI display. Concrete conditions include `InDungeonOnly` and `NotInCombatOnly`.

`ItemUseContext` SHALL expose at least `is_in_dungeon: bool`, `is_in_combat: bool`, and `party: Array[Character]`.

#### Scenario: InDungeonOnly is satisfied in dungeon
- **WHEN** `InDungeonOnly.is_satisfied(ctx)` is called with `ctx.is_in_dungeon == true`
- **THEN** the method SHALL return `true`

#### Scenario: InDungeonOnly is not satisfied in town
- **WHEN** `InDungeonOnly.is_satisfied(ctx)` is called with `ctx.is_in_dungeon == false`
- **THEN** the method SHALL return `false`

#### Scenario: NotInCombatOnly is not satisfied during combat
- **WHEN** `NotInCombatOnly.is_satisfied(ctx)` is called with `ctx.is_in_combat == true`
- **THEN** the method SHALL return `false`

### Requirement: TargetCondition gates item use by target validity

The system SHALL provide an abstract Resource class `TargetCondition` (`class_name TargetCondition extends Resource`) with a method `is_satisfied(target: Character, context: ItemUseContext) -> bool` and `reason() -> String`. Concrete conditions include `AliveOnly`, `NotFullHp`, `NotFullMp`, and `HasMpSlot`.

#### Scenario: AliveOnly rejects dead targets
- **WHEN** `AliveOnly.is_satisfied(target, ctx)` is called on a Character whose `current_hp <= 0` or whose status is dead/ashes
- **THEN** the method SHALL return `false`

#### Scenario: NotFullHp rejects full-HP targets
- **WHEN** `NotFullHp.is_satisfied(target, ctx)` is called on a Character with `current_hp == max_hp`
- **THEN** the method SHALL return `false`

#### Scenario: HasMpSlot rejects fighter-class targets without MP
- **WHEN** `HasMpSlot.is_satisfied(target, ctx)` is called on a Character whose job does not provide MP slots
- **THEN** the method SHALL return `false`

### Requirement: Item exposes effect and condition fields for consumables

The system SHALL extend `Item` with three optional fields that consumable items populate:
- `effect: ItemEffect` (null for non-consumable items)
- `context_conditions: Array[ContextCondition]` (empty for items without context gates)
- `target_conditions: Array[TargetCondition]` (empty for items without target gates, which means "no-target" usage)

For non-consumable items (category != CONSUMABLE), these fields SHALL default to null / empty and have no runtime effect.

#### Scenario: Consumable item exposes effect
- **WHEN** an Item with `category == CONSUMABLE` is loaded
- **THEN** its `effect` field SHALL be a non-null `ItemEffect` instance

#### Scenario: Weapon item effect is null
- **WHEN** an Item with `category == WEAPON` is loaded
- **THEN** its `effect` field MAY be null and `context_conditions`/`target_conditions` SHALL be empty arrays

### Requirement: Consumable use flow consumes the instance on success

The system SHALL provide a use path on `Inventory` (e.g., `use_item(instance: ItemInstance, targets: Array[Character], context: ItemUseContext) -> ItemEffectResult`) that:

1. Verifies the instance is currently in the inventory; otherwise returns `{success: false}` without side effects.
2. Verifies every `context_conditions` entry's `is_satisfied(context)` is `true`; otherwise returns `{success: false, message: <reason>}` without side effects.
3. For each `target_conditions` entry, verifies it is satisfied for every target in `targets`; otherwise returns `{success: false, message: <reason>}` without side effects.
4. Invokes `item.effect.apply(user_or_party, targets, context)`.
5. On `result.success == true`, removes the instance from the inventory.
6. On `result.success == false`, leaves the inventory unchanged.

#### Scenario: Successful use consumes the instance
- **WHEN** `Inventory.use_item(potion_instance, [alive_wounded_char], ctx)` returns `{success: true}`
- **THEN** `Inventory.contains(potion_instance)` SHALL return `false`

#### Scenario: Context failure does not consume
- **WHEN** `Inventory.use_item(escape_scroll_instance, [], ctx_in_town)` returns `{success: false}` due to `InDungeonOnly`
- **THEN** the instance SHALL remain in the inventory

#### Scenario: Target failure does not consume
- **WHEN** `Inventory.use_item(potion_instance, [full_hp_char], ctx)` returns `{success: false}` due to `NotFullHp`
- **THEN** the potion instance SHALL remain in the inventory

### Requirement: Initial consumable data files are shipped

The system SHALL ship four initial consumable `.tres` items under `data/items/`:

| item_id | item_name | category | effect | context_conditions | target_conditions | price |
|---|---|---|---|---|---|---|
| `potion` | ポーション | CONSUMABLE | HealHpEffect | [] | [AliveOnly, NotFullHp] | 50 |
| `magic_potion` | マジックポーション | CONSUMABLE | HealMpEffect | [] | [AliveOnly, HasMpSlot, NotFullMp] | 200 |
| `escape_scroll` | 脱出の巻物 | CONSUMABLE | EscapeToTownEffect | [InDungeonOnly, NotInCombatOnly] | [] | 500 |
| `emergency_escape_scroll` | 緊急脱出の巻物 | CONSUMABLE | EscapeToTownEffect | [InDungeonOnly] | [] | 2000 |

The numeric `power` for HealHp / HealMp SHALL be a tunable balance value set in the `.tres` files (initial values are adjustable without code changes).

#### Scenario: Four consumables are loadable
- **WHEN** `DataLoader.load_all_items()` is invoked on the shipped `data/items/` directory
- **THEN** the resulting ItemRepository SHALL contain items with `item_id` equal to each of `potion`, `magic_potion`, `escape_scroll`, `emergency_escape_scroll`, each with `category == CONSUMABLE`

#### Scenario: Escape scrolls differ only by NotInCombatOnly
- **WHEN** `escape_scroll` and `emergency_escape_scroll` are inspected
- **THEN** both SHALL use `EscapeToTownEffect`, `escape_scroll.context_conditions` SHALL include both `InDungeonOnly` and `NotInCombatOnly`, and `emergency_escape_scroll.context_conditions` SHALL include `InDungeonOnly` but NOT `NotInCombatOnly`
