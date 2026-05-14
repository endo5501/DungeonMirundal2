## Why

現状のダンジョンエンカウントは `data/encounter_tables/floor_1.tres` と `floor_2.tres` の2階分しか整備されておらず、3階以降は floor_2 にフォールバックする。さらに登録モンスター12種のうちエンカウントテーブルから参照されているのは slime / goblin / bat の3種だけで、skeleton / ghost / dragon / witch / dark_priest / imp / lich / goblin_shaman / wraith はデータ上存在するがゲーム中に出会えない。一方 `DungeonRegistry` は最大12階まで生成し得るため、深部に行っても遭遇するモンスターが変わらない/弱いままという体験になっている。

階層が深いほど強いモンスターが出る「Wizardry的な深度=難度」の体験を導入するために、モンスター個体に強さ層 (tier) を持たせ、エンカウントテーブルは「重み付き tier 抽選」方式へ刷新する。これにより全モンスターを活用しつつ、12階分の出現分布を最小限のデータ追加で表現できる。

## What Changes

- **BREAKING**: `EncounterTableData` のスキーマを刷新する (`entries` を廃止し `tier_weights` / `species_count_*` / `count_per_species_*` を導入)
- **BREAKING**: `EncounterPattern` / `EncounterEntry` / `MonsterGroupSpec` のクラス・spec・テストを完全廃止する
- `MonsterData` に `tier: int (1〜5)` 必須フィールドを追加する
- `MonsterRepository.find_by_tier(tier: int) -> Array[MonsterData]` を新規追加する
- `EncounterManager.generate` を tier 抽選アルゴリズムに書き換える (species_count 抽選 → 各 species ごとに tier 抽選 → tier 内 uniform でモンスター選択 → 体数抽選)
- 既存12個の `data/monsters/*.tres` 全てに tier 値を明示記入する (tier 1: slime/bat、tier 2: goblin/skeleton、tier 3: ghost/imp/goblin_shaman、tier 4: witch/dark_priest/wraith、tier 5: lich/dragon)
- `data/encounter_tables/floor_1.tres` と `floor_2.tres` を新スキーマで刷新する
- `data/encounter_tables/floor_3.tres` 〜 `floor_12.tres` を新規作成し、tier の山なりカーブで配置する
- `EncounterCoordinator` の floor フォールバック挙動 (N以下で最も深いテーブルを使用) は現状維持する
- 行 (FRONT/BACK) バケット振り分けと ROW_CAP=5 の truncation 既存ロジックは維持する

## Capabilities

### New Capabilities

なし。既存 capability の改修のみ。

### Modified Capabilities

- `monster-data`: `MonsterData` に `tier: int` フィールドを追加し、既存 .tres 全てに値を持たせる要件を加える。`MonsterRepository` に `find_by_tier` を追加する。
- `encounter-detection`: `EncounterTableData` スキーマを `entries` ベースから `tier_weights` / `species_count_*` / `count_per_species_*` ベースに刷新する。`EncounterManager.generate` のアルゴリズムを tier 抽選方式に置き換える。`EncounterPattern` / `EncounterEntry` / `MonsterGroupSpec` 関連の要件を全て削除する。

## Impact

**変更コード**:
- `src/dungeon/data/monster_data.gd` (tier フィールド追加)
- `src/dungeon/monster_repository.gd` (find_by_tier 追加)
- `src/dungeon/data/encounter_table_data.gd` (スキーマ刷新)
- `src/dungeon/encounter_manager.gd` (生成アルゴリズム刷新)
- `src/main.gd` (テーブル登録は変更なし、生成APIの呼び出し方は同じ想定)

**削除コード**:
- `src/dungeon/data/encounter_pattern.gd`
- `src/dungeon/data/encounter_entry.gd`
- `src/dungeon/data/monster_group_spec.gd`

**変更データ**:
- `data/monsters/*.tres` × 12 (tier 追記)
- `data/encounter_tables/floor_1.tres`, `floor_2.tres` (新スキーマへ刷新)

**新規データ**:
- `data/encounter_tables/floor_3.tres` 〜 `floor_12.tres` (10ファイル)

**変更テスト**:
- `tests/dungeon/test_encounter_table_data.gd` (新スキーマ用に書き換え)
- `tests/dungeon/test_encounter_manager.gd` (tier 抽選用に書き換え)
- `tests/dungeon/test_encounter_manager_row_truncation.gd` (生成APIに合わせ調整)
- `tests/dungeon/test_encounter_coordinator.gd` (生成APIに合わせ調整)
- `tests/dungeon/test_data_loader.gd` (floor_1/2 の検証を新スキーマに対応)
- `tests/dungeon/test_encounter_pattern.gd` 等の Pattern 系テストは削除

**互換性**:
- セーブデータ互換性は不要 (エンカウンタ生成結果は永続化されない)
- 進行中セーブを持つユーザがいた場合も、ロード後の次のエンカウント生成から新ロジックに自動で切り替わる

**依存関係**: 外部ライブラリ追加なし
