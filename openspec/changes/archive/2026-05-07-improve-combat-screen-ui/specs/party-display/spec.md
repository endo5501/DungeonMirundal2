## MODIFIED Requirements

### Requirement: PartyMemberPanel uses an enlarged font size for body text

`PartyMemberPanel` SHALL render body text such as HP/MP numeric values at a compact font size suitable for a portrait-forward card layout. The member name and level SHALL NOT be rendered as normal stacked body-text lines; they SHALL be rendered as badges over the portrait area. Text and bars SHALL fit cleanly within the panel without clipping.

#### Scenario: Body font is compact

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** the body font size used for member name and HP/MP numbers SHALL be less than `20`

#### Scenario: Level is not part of the stacked body text

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the level SHALL be displayed as a badge in the portrait area instead of as a normal text line between the name and HP/MP display

#### Scenario: Member name overlays the portrait

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the member name SHALL be displayed as a badge over the portrait area instead of below the portrait

#### Scenario: Text and bars fit within panel height

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the name, level badge, HP bar, MP bar, numeric HP/MP values, and icon row SHALL fit within `PANEL_HEIGHT` without clipping

### Requirement: PartyMemberPanel uses an enlarged panel height to accommodate body text

`PartyMemberPanel` SHALL define `PANEL_HEIGHT` large enough to contain an enlarged character portrait placeholder, a level badge, member name, HP/MP bars with numeric values, and status/stat modifier icons with sane padding. `PANEL_WIDTH` SHALL remain at `180` for this change.

#### Scenario: PANEL_HEIGHT is enlarged for portrait-forward cards

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_HEIGHT` SHALL be greater than `130`

#### Scenario: PANEL_WIDTH is unchanged

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_WIDTH` SHALL be `180`

## ADDED Requirements

### Requirement: PartyMemberPanel renders an enlarged portrait placeholder with a level badge

`PartyMemberPanel` SHALL reserve a centered character image placeholder larger than the previous 48x48 icon area, using the vertical space above the HP bar with minimal dead gap. Until real character art exists, this area SHALL continue to use a dummy or placeholder rendering. The member level SHALL be rendered as a small badge at the upper-right of the portrait area.

#### Scenario: Portrait placeholder is larger than the previous icon

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the portrait placeholder area SHALL be larger than `48x48`

#### Scenario: Portrait placeholder is centered

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the portrait placeholder area SHALL be horizontally centered within the panel

#### Scenario: Portrait uses space above HP bar

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the bottom of the portrait placeholder SHALL sit close to the HP bar rather than leaving a large unused gap

#### Scenario: Level badge appears at portrait upper-right

- **WHEN** `PartyMemberPanel` renders a member at level 3
- **THEN** the panel SHALL show `LV.3` or equivalent level text in a badge positioned at the upper-right of the portrait area

### Requirement: PartyMemberPanel renders HP and MP as bars with numeric values

`PartyMemberPanel` SHALL render HP and MP using color-coded bars plus numeric current/max values. HP SHALL use the existing HP color family and MP SHALL use the existing MP color family. Bar fill ratios SHALL be computed from `current / max` and clamped to a safe range.

#### Scenario: HP bar reflects current HP ratio

- **WHEN** a member has `current_hp = 8` and `max_hp = 10`
- **THEN** the HP bar SHALL render approximately 80 percent filled and the numeric HP value SHALL display `8 / 10` or equivalent text

#### Scenario: MP bar reflects current MP ratio

- **WHEN** a member has `current_mp = 5` and `max_mp = 20`
- **THEN** the MP bar SHALL render approximately 25 percent filled and the numeric MP value SHALL display `5 / 20` or equivalent text

#### Scenario: Zero maximum value is safe

- **WHEN** a member has `max_mp = 0`
- **THEN** the MP bar ratio calculation SHALL NOT divide by zero and SHALL still render a numeric MP value

### Requirement: PartyMemberPanel preserves combat feedback in the new card layout

`PartyMemberPanel` SHALL continue to render persistent status icons, combat stat modifier icons, incapacitated dimming, heal flash overlay, shake animation, lift animation, and death fade behavior in the portrait-forward card layout. Status and stat modifier icons SHALL be drawn in a reserved area and SHALL NOT collide with the HP/MP bars.

#### Scenario: Status icons do not collide with HP and MP bars

- **WHEN** a member has one or more persistent statuses and the panel renders HP/MP bars
- **THEN** the status icons SHALL be drawn inside panel bounds without overlapping the HP or MP bar rectangles

#### Scenario: Stat modifier icons do not collide with HP and MP bars

- **WHEN** a combat-bound member has one or more stat modifier icons and the panel renders HP/MP bars
- **THEN** the stat modifier icons SHALL be drawn inside panel bounds without overlapping the HP or MP bar rectangles

#### Scenario: Incapacitated dimming covers the full new panel

- **WHEN** a member is incapacitated
- **THEN** the dim overlay SHALL cover the entire enlarged `PartyMemberPanel`

### Requirement: PartyDisplay renders FRONT and BACK as framed row windows

`PartyDisplay` SHALL render the FRONT and BACK row labels inside framed row windows that enclose their corresponding three `PartyMemberPanel` cards.

#### Scenario: FRONT label appears inside the front row window

- **WHEN** `PartyDisplay` renders the party HUD
- **THEN** the FRONT label SHALL be inside the framed front row window

#### Scenario: BACK label appears inside the back row window

- **WHEN** `PartyDisplay` renders the party HUD
- **THEN** the BACK label SHALL be inside the framed back row window

#### Scenario: Row windows enclose party panels

- **WHEN** `PartyDisplay` lays out the party HUD
- **THEN** each row window SHALL enclose the three `PartyMemberPanel` cards in that row
