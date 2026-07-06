# monster-balance-curve

## ADDED Requirements

### Requirement: Balance definition file schema

The system SHALL define monster combat stats through a balance definition JSON file at `data/balance/monster_curve.json` containing:

- `curves`: an object with keys `hp`, `attack`, `defense`, `agility`, each mapping to `{ "base": float > 0, "growth": float > 0 }`
- `hp_spread`: a float in `[0.0, 1.0)` describing the half-width ratio of the HP range around the curve midpoint
- `species`: an object mapping monster id to role modifiers — an object with optional keys `hp`, `attack`, `defense`, `agility` (each a float > 0; missing keys default to `1.0`) and an optional `hp_spread` override
- `overrides`: an object mapping monster id to explicit stat values (`hp_min`, `hp_max`, `attack`, `defense`, `agility`, each int) that bypass the curve entirely for the specified stats

The loader SHALL follow the `ExpeditionConfig` error-collection pattern: unreadable files or invalid JSON return null; a structurally valid dictionary always produces a model object whose `errors` array lists every validation problem.

#### Scenario: Valid definition loads without errors

- **WHEN** a JSON file with all four curves, `hp_spread = 0.25`, and role modifiers for known species is loaded
- **THEN** the loader SHALL return a model object with an empty `errors` array

#### Scenario: Missing curve key is a validation error

- **WHEN** a definition omits `curves.defense`
- **THEN** the model's `errors` array SHALL contain an entry naming `curves.defense`

#### Scenario: Non-positive growth is a validation error

- **WHEN** a definition has `curves.attack.growth = 0.0`
- **THEN** the model's `errors` array SHALL contain an entry naming `curves.attack.growth`

#### Scenario: Unreadable file returns null

- **WHEN** the balance definition path does not exist or contains invalid JSON
- **THEN** the loader SHALL return null

### Requirement: Curve calculator derives combat stats from tier

The system SHALL provide a pure calculator that, given the balance definition, a monster id, and a tier `t`, computes:

- `raw_stat = curves[stat].base × curves[stat].growth^(t-1) × role_modifier(species, stat)` for each of `hp` (midpoint), `attack`, `defense`, `agility`
- `hp_min = round(hp_mid × (1 - spread))` and `hp_max = round(hp_mid × (1 + spread))` where `spread` is the species `hp_spread` override if present, else the global `hp_spread`
- integer rounding: round-half-up to nearest int; `hp_min`, `hp_max`, `attack` SHALL be clamped to a minimum of 1; `defense`, `agility` SHALL be clamped to a minimum of 0
- the result SHALL always satisfy `hp_min <= hp_max`

The calculation SHALL be deterministic: identical inputs produce identical outputs.

#### Scenario: Stat grows geometrically with tier

- **WHEN** `curves.attack = { base: 2.0, growth: 2.0 }` and a species with attack modifier `1.0` is computed at tiers 1, 2, 3
- **THEN** the computed attack values SHALL be 2, 4, 8

#### Scenario: Role modifier scales the curve value

- **WHEN** `curves.agility = { base: 4.0, growth: 1.0 }` and a species declares `agility: 2.0`
- **THEN** the computed agility SHALL be 8 at every tier

#### Scenario: HP range derives from spread

- **WHEN** the computed `hp_mid` is 20 and the effective `hp_spread` is 0.25
- **THEN** `hp_min` SHALL be 15 and `hp_max` SHALL be 25

#### Scenario: Defense can round down to zero

- **WHEN** the computed raw defense is 0.3
- **THEN** the resulting defense SHALL be 0 (not clamped up to 1)

#### Scenario: Missing modifier keys default to 1.0

- **WHEN** a species entry declares only `hp: 0.6`
- **THEN** attack, defense, and agility SHALL be computed with modifier `1.0`

### Requirement: Explicit overrides bypass the curve

The system SHALL apply `overrides` entries with highest precedence: for each stat key present in a species' override entry, the calculator SHALL return the override value verbatim, ignoring both the curve and the role modifiers for that stat. Stats absent from the override entry SHALL still be computed from the curve.

#### Scenario: Overridden stat ignores curve and modifiers

- **WHEN** `overrides.dragon = { "attack": 25 }` and dragon also has a role modifier `attack: 1.5`
- **THEN** the computed attack for dragon SHALL be exactly 25

#### Scenario: Non-overridden stats still follow the curve

- **WHEN** `overrides.dragon = { "attack": 25 }` and dragon's defense is not overridden
- **THEN** dragon's defense SHALL be computed from the defense curve and role modifier

### Requirement: Role modifier normalization warning

The system SHALL compute, for each species entry, the geometric mean of its four effective role modifiers (missing keys counted as 1.0). When the geometric mean deviates from 1.0 by more than a tolerance (default 0.15), the loader SHALL append a warning naming the species and the computed mean to a `warnings` array. Warnings SHALL NOT prevent loading or calculation.

#### Scenario: Balanced modifiers produce no warning

- **WHEN** a species declares `{ hp: 0.6, agility: 2.0, attack: 0.9 }` with geometric mean within tolerance of 1.0
- **THEN** no warning SHALL be emitted for that species

#### Scenario: Lopsided modifiers produce a warning but remain usable

- **WHEN** a species declares `{ hp: 2.0, attack: 2.0, defense: 2.0, agility: 2.0 }`
- **THEN** a warning naming the species SHALL be appended to `warnings` AND the calculator SHALL still compute stats for it
