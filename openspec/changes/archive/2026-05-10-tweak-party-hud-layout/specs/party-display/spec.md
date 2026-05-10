## MODIFIED Requirements

### Requirement: PartyMemberPanel uses an enlarged font size for body text

`PartyMemberPanel` SHALL render body text such as HP/MP numeric values at a font size suitable for a portrait-forward card layout under the new 1600×900 design canvas. The member name SHALL continue to be rendered at a body font size of at least `21` so it remains the most prominent identifier on the card. The HP/MP row label and numeric value text MAY use a smaller dedicated bar font size of at least `14` so that two stacked HP/MP rows fit within the available vertical space without the value text of one row colliding with the next, AND so that the numeric value (`current / max`) fits in the horizontal space between the bar and the panel's right edge without clipping. The member name and level SHALL NOT be rendered as normal stacked body-text lines; they SHALL be rendered as badges over the portrait area. Text and bars SHALL fit cleanly within the panel without clipping.

#### Scenario: Member name font is enlarged for readability

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** the body font size used for the member name badge SHALL be at least `21` and at most `30`

#### Scenario: HP/MP row font is sized to avoid clipping and overlap

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** the dedicated HP/MP bar font size SHALL be at least `14`
- **AND** the rendered HP and MP numeric value strings SHALL fit horizontally between the bar's right edge and the panel's right edge without clipping
- **AND** the rendered HP value text and MP value text SHALL NOT overlap vertically

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

`PartyMemberPanel` SHALL define `PANEL_HEIGHT` and `PANEL_WIDTH` large enough to contain a character portrait placeholder, a level badge, member name, HP/MP bars with numeric values, and status/stat modifier icons with sane padding under the new 1600×900 design canvas. `PANEL_WIDTH` SHALL be `174` (matching the portrait width plus a small frame margin) and `PANEL_HEIGHT` SHALL be at least `200` so that six panels (three FRONT + three BACK) fit horizontally within the design canvas with a non-overlapping center gap, and so that the HUD does not occlude objects (stairs, chests) in the central region of the 3D dungeon view.

#### Scenario: PANEL_HEIGHT is enlarged for portrait-forward cards

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_HEIGHT` SHALL be at least `200`

#### Scenario: PANEL_WIDTH matches portrait width with frame margin

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.PANEL_WIDTH` SHALL be `174`
- **AND** `PartyMemberPanel.PANEL_WIDTH` SHALL be greater than or equal to `PartyMemberPanel.PORTRAIT_WIDTH`

#### Scenario: Six panels fit within the design canvas width with a sizeable center gap

- **WHEN** `PartyDisplay` lays out three FRONT and three BACK panels under the design canvas width of `1600`
- **THEN** the rightmost FRONT panel's right edge SHALL be strictly less than the leftmost BACK panel's left edge (i.e. the center gap remains positive and non-overlapping)
- **AND** the center gap SHALL be at least `300` pixels wide so that 3D dungeon objects in the central viewport region (stairs, chests) remain visible

## ADDED Requirements

### Requirement: PartyMemberPanel level badge is sized to fit a two-digit level

`PartyMemberPanel` SHALL render the member level inside the portrait area as a badge whose width and font size accommodate the string `LV.99` (i.e. a two-digit level prefixed with `LV.`) without clipping. The badge SHALL be drawn at the upper-right corner of the portrait rectangle, with a small inset from the portrait's edges so the badge frame does not touch the portrait border.

#### Scenario: Level badge fits LV.99 horizontally

- **WHEN** `PartyMemberPanel` renders a member with `level = 99`
- **THEN** the rendered text `LV.99` SHALL fit within the level badge rectangle without clipping
- **AND** the badge rectangle width SHALL be at least `48` pixels

#### Scenario: Level badge font is sized for the badge

- **WHEN** `PartyMemberPanel` is loaded
- **THEN** `PartyMemberPanel.BADGE_FONT_SIZE` SHALL be at most `16` so the `LV.99` string fits within the configured badge width

#### Scenario: Level badge sits inside the portrait at the upper-right

- **WHEN** `PartyMemberPanel` renders with non-null data
- **THEN** `get_level_badge_rect()` SHALL return a rect whose top-right corner is inside the rect returned by `get_portrait_rect()` with at least a 1-pixel inset from the portrait's top and right edges
