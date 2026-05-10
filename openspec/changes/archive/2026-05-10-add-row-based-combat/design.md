## Context

現状、戦闘システムは `TurnEngine` が `party: Array` と `monsters: Array` の flat 配列のみを保持し、攻撃ターゲットは `AttackCommand.target: CombatActor` 1 つだけで決まる。`PartyData` には `front_row[3] / back_row[3]` の編成 UI 概念が存在するものの、戦闘ロジックには行が伝播していない。`MonsterData` には行・攻撃間合いの概念が無く、`Item` には武器属性(近接/遠隔)の概念が無い。プレイヤーから見ると「後衛に置いた魔法使いも前衛と同じ機会で殴られ、自分も誰でも殴れる」状態。

本変更は Wizardry 系の「前衛が物理戦闘を担い、後衛は遠距離武器か魔法でしか戦えない」ルールを既存パイプラインに乗せる。新しい戦闘モードを作るのではなく、既存 `TurnEngine` / `CombatOverlay` / `CombatTargetSelector` / `MonsterData` / `Item` の薄い拡張で実現する。

## Goals / Non-Goals

**Goals:**
- 武器の近接/遠隔属性 + アクターの行位置で物理攻撃の可達性を制御できる
- モンスター側にも行位置・攻撃間合いを持たせ、AI が自分の届く相手を狙う
- 前衛が全滅したら後衛が前衛扱いに昇格する自然な戦闘進行
- UI で「届かない攻撃」を事前に視覚化(攻撃 disable + ターゲット gray-out)
- 後衛モンスターが手前のモンスターより奥に小さく描画され、視覚的にも前後関係がわかる
- 既存セーブデータ・既存 `.tres` ファイルが壊れない後方互換

**Non-Goals:**
- 魔法・アイテム使用への行制限導入(将来拡張)
- 大型モンスター(複数枠占有)
- 武器カテゴリ細分(剣/弓/杖)
- Defend 中後衛のダメージ補正
- パーティ前衛/後衛を戦闘中に入れ替える操作(Wizardry でいう「いれかえ」コマンド)
- 隊列上限の動的変更(味方は 3+3、敵は 5+5 で固定)

## Decisions

### D1. 武器属性は `WeaponData` サブリソースとして持つ(Q1 案 2)

**Decision**: `Item.weapon_data: WeaponData` を新設。`WeaponData` は `class_name WeaponData extends Resource` で、最初は `weapon_range: enum { MELEE, RANGED }` の 1 フィールドのみ。

**Rationale**:
- 案 1 (Item に `weapon_range` 直生やし) より柔軟。将来 dual-wield / ammo / element / damage_dice などを足すとき、`WeaponData` を太らせるだけで済む。
- 案 3 (`Weapon extends Item` 別クラス) は既存の WEAPON `.tres` を全部書き換える破壊的変更が必要。本変更ではコスト過大。
- WEAPON カテゴリ以外の Item は `weapon_data = null` のまま使う。アクセスする箇所は WEAPON カテゴリ前提なのでガードは緩い。

**Alternatives considered**: 上記のとおり案 1, 案 3。

### D2. 素手 / `weapon_data` 未設定は MELEE 扱い(Q2)

**Decision**: 
- `WEAPON` スロットが空、または装備中 Item の `weapon_data == null` の場合、`weapon_range = MELEE` として扱う。
- アクセサは `EquipmentProvider.get_weapon_range(character) -> WeaponRange`。`InventoryEquipmentProvider` は装備武器の `weapon_data.weapon_range` を返し、無ければ MELEE。`DummyEquipmentProvider` は常に MELEE を返す。

**Rationale**: 直感的(素手は近接)。既存武器 `.tres` をマイグレーションせずに「全部 MELEE」スタートにできる。

### D3. モンスターは `default_row` + `attack_range` の 2 フィールド(Q4 / E)

**Decision**: 
- `MonsterData.default_row: Row` (新規 enum) で生成時の配置を決める。
- `MonsterData.attack_range: WeaponRange` で AI の攻撃間合いを決める。
- 両方 export、未設定は FRONT / MELEE フォールバック。

**Rationale**: モンスターは武器を装備しないので、武器属性ではなく直接 `attack_range` をデータで持つのが素直。`Item.weapon_data` と enum 型 (`WeaponRange`) を共有することで、`can_reach` 判定ロジックは攻撃者がパーティかモンスターかを意識しなくて済む。

### D4. 隊列上限は味方 3+3 / 敵 5+5 の非対称(Q4)

**Decision**: 
- パーティ: FRONT 3 / BACK 3 (既存 `PartyData` のまま、変更なし)
- モンスター: FRONT 5 / BACK 5 (新規)
- モンスター生成で同じ row が上限超過 → あふれた個体はカット(エンカウンター生成器側で truncate)

**Rationale**: 
- Wizardry 系は 1 グループあたりの数が多く、5+5 のほうが「ゴブリン 5 体 + コウモリ 3 体」みたいな典型エンカウンターを表現しやすい。
- 味方を 5+5 に拡張するのは PartyFormation UI / セーブデータ / Guild 管理など波及が大きすぎる。本変更スコープ外。

**Alternatives considered**: 双方 3+3、双方 5+5、上限緩和(あふれ BACK 流し)。あふれカットは「データ作成者がエンカウンターパターンを設計する責任」を明示するため。

### D5. 行昇格は mid-turn evaluate(Q8 = A 案)

**Decision**: 
- `effective_row(actor)` は呼び出された時点での生存状況で都度計算。snapshot しない。
- 同じターン内で前衛が死ねば、後の行動順の後衛は即座に effective FRONT に昇格。

**Rationale**: プレイヤーの状況把握と一致する(「前衛が今死んだから、次の後衛は前に出られる」)。コマンド入力時は全員生きてる前提なのでメニューの disable 判定は問題なし。

**Risks**: monster AI のターゲット計算が `effective_row` に依存するので、ターン中に値が変わると想定外の挙動が出る可能性 → 各 actor 解決の冒頭で都度評価することで一貫性を担保。

### D6. 後衛 MELEE モンスターは "wait" で turn を消費(Q3 = C-2)

**Decision**: 
- TurnEngine 内で「後衛 MELEE モンスターで届く敵がいない」場合、`actor_action_started.emit(actor, &"wait")` の後、`report.add_wait(actor)` のみで何もしない。
- 被ダメージ補正なし(Defend ではない)。
- status tick は通常通り(ターン頭の `_tick_statuses_for_all` パスで処理される)。
- `TurnReport` に新 action type `wait` を追加: `{ type: "wait", actor_name }`。
- CombatLog の表示: "<モンスター> は様子を見ている"。

**Rationale**: 
- Defend 半減を付けるとモンスター強化になりバランスを崩す。
- 完全に turn を skip するとログが寂しく、プレイヤーに「なぜ攻撃してこないか」が伝わらない。
- "wait" 専用 action type にすることで CombatLog で一貫した表示が可能、将来的に「待機 → 前進」みたいな AI 拡張の余地もある。

**Alternatives considered**: Defend 適用(C-1, バランス影響大)、no-op + ログ無し(C-2 純粋版)、flavor だけ Defend(C-3, 実装複雑)。

### D7. 描画は y_offset + scale + z_index(Q6 = 案 R)

**Decision**: 
- 後衛: `y_offset = -<固定 px>` (前衛 baseline からの相対上方), `scale = 0.85`, `z_index = 前衛 - 1`
- 前衛: 既存 stable baseline、scale 1.0、通常 z_index
- 横方向は後衛 5 / 前衛 5 を等間隔で auto-fit
- 具体ピクセル数は実装時に手作業で詰める(design.md には指針のみ、spec.md には「FRONT より小さく、上、奥に描画される SHALL」のような相対要件で書く)

**Rationale**: 「後衛 = 奥」を最も直感的に表す表現。Z 順だけ(案 P)では小さい敵が大きい敵に完全に隠れて存在感が消える。Y オフセットだけ(案 Q)では空間的奥行きが弱い。

**Risks**: 既存 combat-overlay spec の "Monster visuals sit lower with stable baseline" シナリオを書き換える必要あり。

### D8. CommandMenu の Attack disable 表示(Q5 = 案 X)

**Decision**: 
- 後衛 + 近接武器(= 届くターゲットなし)で `CombatCommandMenu` の「攻撃」行を gray + "(届かない)" 注記で表示。Enter で no-op。
- Mage の祈り行省略パターンとは異なる扱い(行数が一定)。

**Rationale**: プレイヤーが「なぜ攻撃できないか」を学習できる教育効果。攻撃は他コマンドより重要なので、消すより gray のほうが情報量が多い。

### D9. ターゲット可達性の判定は AttackCommand 解決パスでも防御する

**Decision**: 
- UI が gray-out しても、外部入力やデバッグコンソール経由で不正なターゲット選択が来る可能性がある。
- `_resolve_attack` の冒頭で `engine.can_reach(attacker, target)` をチェックし、不可なら `add_miss` 相当の "unreachable" ログ(または attack を no-op + 警告)で fail-safe。
- ただし通常運用では UI が事前に弾くので、この防御コードのテストは別途用意する。

**Rationale**: スペック違反を engine で握り潰さず、明示的に処理する。

### D10. Encounter 生成で row 振り分け + truncate

**Decision**: 
- `EncounterPattern` 展開時に、各 `MonsterGroupSpec` から生成した個体を `default_row` でバケット振り分け。
- FRONT バケット 5 体超過 → あふれた個体はその場で破棄(spawn しない)。BACK も同様。
- truncate は警告ログを出してデータ作成者に気づかせる(`push_warning` 相当)。

**Rationale**: あふれ BACK 流しよりもデータ責任を明示。エンカウンターパターン設計時に「FRONT 過剰」が即発見できる。

## Risks / Trade-offs

- **既存戦闘テスト全滅リスク** → 既存テストは flat な `party` / `monsters` 配列で構築されている。`PartyCombatant` / `MonsterCombatant` のコンストラクタで row を任意化(default = FRONT)し、既存テストは何も指定しなくても通るようにする。新規追加分のみ row 指定。
- **mid-turn 昇格の race condition** → 同じ resolve_turn 内で「先に死んだ前衛」と「同じターンに行動する後衛」の評価順が重要。`for actor in order` ループ内で各 actor の冒頭に `effective_row` を再計算することで保証。テストで「FRONT 戦士が AGI 15、BACK 盗賊が AGI 10、戦士が enemy に殺された後で盗賊が attack するとき昇格判定通る」を厳密に検証。
- **後衛 MELEE モンスターが多いエンカウンターでテンポダウン** → "wait" だらけで戦闘が冗長になる懸念。データ設計責任で「後衛は基本 RANGED」を慣習化する(モンスターデータレビュー時のチェック項目とする)。spec 上は規定しない。
- **描画オフセットでクリックヒット領域がずれる** → 現状モンスター個体クリック判定は無く、enemy graphics は装飾扱い、ターゲット選択は CombatTargetSelector(リスト UI)経由。よって描画変更でヒット判定への影響は無い。確認必須。
- **WeaponData が WEAPON 以外の Item に誤設定された場合** → `weapon_data` を読むのは `EquipmentProvider.get_weapon_range` だけで、それは `Equipment.WEAPON` slot のみを参照する。よって誤設定があっても無害だが、データ検証テストで「WEAPON 以外の Item は weapon_data == null」を assert することを推奨(本変更スコープ外、後続改善)。

## Migration Plan

1. **データモデル拡張**: `weapon_data.gd`, `WeaponRange` enum, `Row` enum を新設。`Item` に `weapon_data` を追加(default null)。`MonsterData` に `default_row` (default FRONT) と `attack_range` (default MELEE) を追加。
2. **CombatActor 拡張**: `PartyCombatant` / `MonsterCombatant` に `original_row` を追加(default FRONT)、コンストラクタで受け取る。
3. **TurnEngine ヘルパ**: `effective_row(actor)`, `can_reach(attacker, target)`, `_pick_living_party_reachable(attacker, rng)` を追加。
4. **AttackCommand 解決**: `_resolve_attack` 冒頭に `can_reach` ガード。Monster AI で `_pick_living_party` 呼び出しを attacker-aware 版に置き換え。後衛 MELEE 待機分岐を追加。
5. **TurnReport**: `add_wait(actor)` 追加。CombatLog に `wait` レンダリング追加。
6. **EquipmentProvider**: `get_weapon_range(character)` メソッドを 3 実装(interface, Inventory, Dummy)に追加。
7. **EncounterPattern 展開**: row 振り分け + truncate 実装。
8. **PartyCombatant 構築経路**: `CombatOverlay.start_encounter` で `PartyData` の front/back から row を引き継いで `PartyCombatant` を生成。
9. **CombatCommandMenu**: 「攻撃」行の reach 判定 + gray 表示。
10. **CombatTargetSelector**: ターゲットの reach 判定 + gray-out。
11. **CombatOverlay モンスター描画**: row でレイアウトを分岐。
12. **データ更新**: 既存 6 種モンスター `.tres` に `default_row` / `attack_range` を順次設定。既存 9 種程度の WEAPON `.tres` に `weapon_data` を設定(初期は全部 MELEE で OK、後続データ作業で弓を RANGED に格上げ)。
13. **既存テスト整合**: row default = FRONT で既存テストは pass する想定。落ちたら個別対応。
14. **新規テスト**: 可達性表 8 ケース、行昇格 4 ケース、後衛 MELEE 待機、UI gray、描画オフセット。

ロールバック: 機能フラグは設けない。問題があれば revert で一括戻し。データ追加は後方互換なので revert で `.tres` も問題なし(新フィールドが無視されるだけ)。

## Open Questions

- **後衛 MELEE モンスター "wait" の AI 拡張**: 将来「前衛が薄くなったら後衛 MELEE モンスターが前進する」みたいな behavior を入れたい場合、`wait` action type が下準備になる。今回はスコープ外。
- **データ検証テスト**: 「WEAPON 以外の Item は `weapon_data == null` であるべき」という invariant を asset 検証テストで確認するか? 本変更ではスコープ外。
- **モンスター個別 row オーバーライド**: 同じ `monster_id` でもエンカウンターパターンによっては「今回は前衛、今回は後衛」で出したい場合がある? 現状は `default_row` 1 つしか持たないので、欲しくなったら `EncounterMonsterEntry` に `row_override` を追加する設計で対応可。本変更ではスコープ外。
