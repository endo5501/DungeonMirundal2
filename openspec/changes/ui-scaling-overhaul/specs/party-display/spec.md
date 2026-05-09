## MODIFIED Requirements

### Requirement: PartyMemberPanel uses an enlarged font size for body text

`PartyMemberPanel` SHALL render body text such as HP/MP numeric values at a font size suitable for a portrait-forward card layout under the new 1600×900 design canvas. The body font size SHALL be at least `21` so that text remains readable at the default launch window. The member name and level SHALL NOT be rendered as normal stacked body-text lines; they SHALL be rendered as badges over the portrait area. Text and bars SHALL fit cleanly within the panel without clipping.

#### Scenario: Body font is enlarged for readability

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** the body font size used for member name and HP/MP numbers SHALL be at least `21` and at most `30`

#### Scenario: Level is not part of the stacked body text

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the level SHALL be displayed as a badge in the portrait area instead of as a normal text line between the name and HP/MP display

#### Scenario: Member name overlays the portrait

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the member name SHALL be displayed as a badge over the portrait area instead of below the portrait

#### Scenario: Text and bars fit within panel height

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** the name, level badge, HP bar, MP bar, numeric HP/MP values, and icon row SHALL fit within `PANEL_HEIGHT` without clipping

### Requirement: PartyMemberPanel uses an enlarged panel size to accommodate body text

`PartyMemberPanel` SHALL define `PANEL_HEIGHT` and `PANEL_WIDTH` large enough to contain an enlarged character portrait placeholder, a level badge, member name, HP/MP bars with numeric values, and status/stat modifier icons with sane padding under the new 1600×900 design canvas. `PANEL_WIDTH` SHALL be `240` and `PANEL_HEIGHT` SHALL be at least `200` so that six panels (three FRONT + three BACK) fit horizontally within the design canvas with a non-overlapping center gap.

#### Scenario: PANEL_HEIGHT is enlarged for portrait-forward cards

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_HEIGHT` SHALL be at least `200`

#### Scenario: PANEL_WIDTH fits six panels in the design canvas

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_WIDTH` SHALL be `240`

#### Scenario: Six panels fit within the design canvas width with margin

- **WHEN** `PartyDisplay` lays out three FRONT and three BACK panels under the design canvas width of `1600`
- **THEN** the rightmost FRONT panel's right edge SHALL be strictly less than the leftmost BACK panel's left edge (i.e. the center gap remains positive and non-overlapping)
