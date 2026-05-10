## Why

現在の戦闘は PartyData に front/back の編成 UI だけ存在し、戦闘ロジックは flat array で「誰でも誰を狙える」状態になっている。Wizardry 系ダンジョン RPG として「前衛/後衛」「近接/遠隔武器」の戦術性が無く、編成画面で行を分けても戦闘上の意味が無い。本変更で行ベース戦闘を導入し、武器属性 × 隊列位置による可達性ルールを既存戦闘パイプラインに組み込む。

## What Changes

- **武器属性の追加**: `Item` に `weapon_data: WeaponData`(新規 Resource サブタイプ)を追加。`WeaponData.weapon_range: enum { MELEE, RANGED }` を持つ。null は MELEE フォールバック。
- **モンスター隊列の追加**: `MonsterData` に `default_row: enum { FRONT, BACK }` と `attack_range: enum { MELEE, RANGED }` を export として追加。
- **モンスターパーティ生成**: エンカウンター展開時に `default_row` で前衛 5 / 後衛 5 のバケットに振り分け、上限超過分はカット。
- **可達性ルール**: `effective_row(attacker) × weapon_range × effective_row(target)` で攻撃可達性を判定。RANGED は常に届く、MELEE は両者 effective FRONT のときのみ届く。
- **行昇格ルール**: 同サイドの FRONT が全滅すると BACK 行のアクターが effective FRONT に昇格(味方/敵 同ルール)。判定は各アクターの行動解決時に都度評価(mid-turn 昇格あり)。
- **CombatActor 拡張**: `PartyCombatant` に row 情報、`CombatActor` に `effective_row()` ヘルパを追加。
- **コマンドメニュー制御**: 後衛 + 近接武器(=届くターゲットがいない)で「攻撃」行を gray + "(届かない)" 注記で disable。
- **ターゲット選択制御**: `CombatTargetSelector` で届かない敵を gray-out。
- **モンスター AI 制御**: 後衛 MELEE モンスターで前衛が生存中 → 自動で「待機(no-op)」。"<モンスター> は様子を見ている" のログを出す。被ダメージ補正なし、status tick は通常通り。
- **モンスター AI ターゲット**: `_pick_living_party()` を可達ターゲットへフィルタ。
- **戦闘描画**: 後衛モンスターを y_offset 上方 + scale 0.85 + z_index 後ろで描画、前衛は既存 stable baseline を維持。
- **後方互換**: 既存 .tres に新 export が無い場合は FRONT / MELEE をフォールバック。既存セーブデータは変更不要(PartyData の front/back は既に持つ)。

スコープ外(将来拡張): 魔法・アイテムの行制限、大型モンスター(複数枠占有)、武器カテゴリ細分(剣/弓/杖)、Defend 中後衛のダメージ補正。

## Capabilities

### New Capabilities

(なし — 全て既存 capability の拡張で吸収)

### Modified Capabilities

- `items`: `Item` に `weapon_data: WeaponData` フィールド追加、`WeaponData` Resource を新規定義(WEAPON カテゴリの武器属性キャリア)
- `monster-data`: `MonsterData` に `default_row` と `attack_range` を export として追加、フォールバック規則を規定
- `combat-actor`: `PartyCombatant` に row 情報、`CombatActor` に `effective_row()` ヘルパ、行昇格判定ロジックを追加
- `combat-engine`: `_resolve_attack` に可達性チェック、`_pick_living_party` に reachable filter、後衛 MELEE モンスター待機分岐、TurnReport に新規 action type `wait` を追加
- `combat-equipment`: `EquipmentProvider` に `get_weapon_range(character)` 追加、`InventoryEquipmentProvider` の素手フォールバック規定
- `combat-overlay`: `CombatCommandMenu` の「攻撃」disable、`CombatTargetSelector` の gray-out、敵描画の前後表現(y_offset + scale + z_index)、CombatLog に "wait" action type のレンダリング追加
- `encounter-detection`: `EncounterPattern` 展開時の row 振り分けロジック(default_row 参照、上限 5/5 + あふれカット)を追加

## Impact

**コード**:
- `src/items/`: 新規 `weapon_data.gd`、`Item` 修正
- `src/dungeon/data/monster_data.gd`: フィールド追加
- `src/combat/combat_actor.gd`, `src/combat/party_combatant.gd`, `src/combat/monster_combatant.gd`: row + effective_row
- `src/combat/turn_engine.gd`, `src/combat/attack_command.gd`: 可達性チェック、AI フィルタ、待機分岐
- `src/combat/equipment_provider.gd`, `src/combat/inventory_equipment_provider.gd`, `src/combat/dummy_equipment_provider.gd`: weapon_range アクセサ
- `src/combat/turn_report.gd`: `add_wait` メソッド追加
- `src/dungeon_scene/combat_overlay.gd`, 配下のメニュー/セレクタ/モンスター描画: UI 制御
- `src/dungeon/monster_party.gd` または `src/dungeon/encounter_manager.gd`: 行振り分け
- `data/items/*.tres`: 既存 9 個程度の WEAPON ファイルに `weapon_data` を順次付与(短期は null フォールバックで既存挙動維持可)
- `data/monsters/*.tres`: 6 種に `default_row`/`attack_range` を付与(短期は省略で FRONT/MELEE フォールバック)

**テスト**:
- 大量にある combat 統合テストは「全員 FRONT・MELEE」の暗黙解釈で大半そのまま通る前提
- 新規テストとして可達性表、行昇格、後衛 MELEE 待機、UI gray-out、描画オフセットを追加

**API/外部**:
- 外部依存なし
- セーブデータフォーマット変更なし(後方互換クリーン)
