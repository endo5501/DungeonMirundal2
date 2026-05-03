## MODIFIED Requirements

### Requirement: Inventory holds party-shared gold
The system SHALL expose `Inventory.gold: int` representing a party-shared currency pool. `add_gold(amount: int)` SHALL increment `gold`. `spend_gold(amount: int) -> bool` SHALL decrement `gold` by `amount` and return `true` only if the balance was sufficient (or `amount == 0`); otherwise it SHALL leave `gold` unchanged and return `false`.

`spend_gold(0)` is treated as a successful no-op and SHALL return `true` without modifying `gold`. This eliminates the previous footgun where callers passing zero would receive `false` despite the operation being conceptually free.

#### Scenario: add_gold increases balance
- **WHEN** an Inventory with `gold == 100` receives `add_gold(50)`
- **THEN** `inventory.gold` SHALL equal `150`

#### Scenario: spend_gold succeeds when balance is sufficient
- **WHEN** an Inventory with `gold == 100` receives `spend_gold(40)`
- **THEN** the method SHALL return `true` and `inventory.gold` SHALL equal `60`

#### Scenario: spend_gold fails when balance is insufficient
- **WHEN** an Inventory with `gold == 30` receives `spend_gold(50)`
- **THEN** the method SHALL return `false` and `inventory.gold` SHALL still equal `30`

#### Scenario: spend_gold(0) is a successful no-op
- **WHEN** an Inventory with any balance receives `spend_gold(0)`
- **THEN** the method SHALL return `true` and `gold` SHALL be unchanged

#### Scenario: Negative amount is rejected
- **WHEN** `add_gold(-10)` or `spend_gold(-10)` is called
- **THEN** the method SHALL leave `gold` unchanged (spend_gold returning `false`)
