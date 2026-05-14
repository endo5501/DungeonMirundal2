## Context

現状、ダンジョンエンカウントの仕組みは `EncounterTableData` に `Array[EncounterEntry]` を持たせ、各 entry が `EncounterPattern` (= `Array[MonsterGroupSpec]`) を抱えるという「パターンを手書きで列挙する」設計になっている。これは少数の階層と少数のモンスターには適していたが、以下の問題がある:

- `data/encounter_tables/` 配下に `floor_1.tres` / `floor_2.tres` の2階分しかなく、3階以降は floor_2 にフォールバックされてしまう (`encounter_coordinator.gd` の `_resolve_table_for_floor`)
- 登録モンスター12種のうち3種 (slime/goblin/bat) しか .tres から参照されておらず、9種が「データはあるが出現しない」状態
- `DungeonRegistry` は SMALL=2-4 / MEDIUM=4-7 / LARGE=8-12 floor を生成し得るが、深部の体験は2階のテーブルが流用されているだけ
- 12階分のテーブルを手で書こうとすると EncounterPattern を各階で再定義する手間が膨大

エンカウント生成の他の要素 (cooldown, probability_per_step, row bucket 振り分け、ROW_CAP=5 の truncation、テーブル fallback) は既に十分機能しているため、これらは維持する。

## Goals / Non-Goals

**Goals:**
- モンスター個体に「強さ層 (tier)」概念を導入し、12種全てに値を持たせる
- 階層ごとに tier の出現重みだけを指定する「軽量データ」方式でテーブルを記述できるようにする
- 12階分のテーブルを最小限のデータ量で作成可能にする
- 既存の生成系の安定要素 (cooldown / row bucket / ROW_CAP / fallback) は維持する
- 全モンスターをゲーム中に登場させる (tier 配置を通じて)

**Non-Goals:**
- 個別モンスターの能力値 (HP / 攻撃 / 防御 / 経験値) の再バランスはしない
- 「ボス階」「固定エンカウント」「イベント遭遇」など特殊エンカウントは導入しない (将来別 change で扱う)
- ダンジョン種別 (SMALL/MEDIUM/LARGE) ごとのテーブル切り替えはしない (引き続き floor 番号のみで決まる)
- セーブデータの後方互換性 (エンカウンタ生成結果は永続化されないため不要)
- モンスター .tres ファイルの追加・削除はしない

## Decisions

### 1. tier のスケールは 1〜5

**選んだ案**: tier は 1〜5 の整数。

**代替案**:
- (a) tier = 階層レベル (1〜12): floor と直感的に対応するが、12モンスターに対して刻みが細かすぎる
- (c) tier = 粗いティア層 (1〜3): 表現力不足

**理由**: 現在の12モンスターを5層に分けるとちょうど 2-3種ずつの分布になり、同 tier 内で uniform 抽選しても十分なバリエーションが得られる。階層が将来12を超えても、tier を増やさず weights だけで調整できる。

**初期 tier 配置**:
```
tier 1 : slime, bat                       (2種)
tier 2 : goblin, skeleton                 (2種)
tier 3 : ghost, imp, goblin_shaman        (3種)
tier 4 : witch, dark_priest, wraith       (3種)
tier 5 : lich, dragon                     (2種)
```

### 2. EncounterPattern は完全廃止 (案A)

**選んだ案**: `EncounterPattern` / `EncounterEntry` / `MonsterGroupSpec` を全て削除する。

**代替案**:
- (B) 共存: 通常エンカウントは tier 抽選、特殊エンカウントは pattern
- (C) tier メタデータ化: パターンに `tier_band` を持たせ、tier で絞ってから pattern 抽選

**理由**: 既存の EncounterPattern 系は他機能の動作確認のために最初に作られた経緯があり、現時点では「同種だけのグループ」「2種混成」程度の単純な使い方しかしていない。tier 抽選方式で同等以上の表現力が得られ、将来「特殊エンカウント・ボス」が必要になったときは別 capability として追加すればよい (このスコープには含めない)。設計を二本立てにすると保守コストが増すので、思い切って一本化する。

### 3. 混成は同 tier から複数種を独立抽選 (案i)

**選んだ案**: 1エンカウンタ内で `species_count` 体の「種類スロット」を抽選し、各スロットで独立に tier → モンスター を抽選する。

**代替案**:
- (ii) 1エンカウンタ = 1種のみ。混成は廃止
- (iii) 確率で混成にする (条件分岐が増える)

**理由**: 「同 tier 内の異種が混じる」(例: tier3 の ghost と imp が同じ群れに) は Wizardry 的にも違和感がなく、ロジックも素直 (条件分岐なし)。`species_count_min=1, species_count_max=2` 程度に設定すれば自然に「単一種が主、たまに混成」というバランスになる。

**生成アルゴリズム (擬似コード)**:
```gdscript
func generate(rng) -> MonsterParty:
    var party := MonsterParty.new()
    if _table == null:
        return party
    var n_species := rng.randi_range(_table.species_count_min, _table.species_count_max)
    var spawned_per_row := {Row.FRONT: 0, Row.BACK: 0}
    for i in n_species:
        var tier := _pick_tier_weighted(_table.tier_weights, rng)
        var candidates := _repository.find_by_tier(tier)
        if candidates.is_empty():
            continue
        var monster_data := candidates[rng.randi() % candidates.size()]
        var count := rng.randi_range(_table.count_per_species_min, _table.count_per_species_max)
        # 既存の row bucket cap (ROW_CAP=5) を適用しながら個体を生成
        _spawn_with_truncation(party, monster_data, count, spawned_per_row, rng)
    return party
```

### 4. floor → tier_weights カーブは手書き

**選んだ案**: 12階分の重みを `.tres` ファイルに手で書き下す。

**代替案**: GDScript で動的に生成 / テンプレ関数

**理由**: 階数は12と限定的で、しかも各階のバランスは「いま遊んでみてのチューニング」を頻繁にやりたい。コードで生成すると数値修正のたびにビルド・再起動が必要になる。Custom Resource なら Godot エディタから直接調整可能。

**初期カーブ**:
```
floor   w1  w2  w3  w4  w5    prob
  1      6   1   0   0   0    0.10
  2      4   3   0   0   0    0.11
  3      2   5   1   0   0    0.12
  4      1   4   3   0   0    0.13
  5      0   2   5   1   0    0.13
  6      0   1   4   3   0    0.14
  7      0   0   3   4   1    0.14
  8      0   0   2   4   2    0.15
  9      0   0   1   4   3    0.15
 10      0   0   0   3   4    0.16
 11      0   0   0   2   5    0.16
 12      0   0   0   1   6    0.17
```

「ピーク移動 + 隣接 tier の薄い重なり」で急激な強度変化を避ける。

### 5. tier_weights の表現は `Dictionary[int, int]`

**選んだ案**: `@export var tier_weights: Dictionary = {}` で `{ tier_int: weight_int }` を保持する。

**代替案**: `Array[int]` で固定長5 (`[w1, w2, w3, w4, w5]`)

**理由**: Dictionary なら「weight 0 の tier は省略可能」「将来 tier が増えても破壊変更にならない」「キーが何を意味するか自明 (integer key そのまま)」。Godot エディタでは Dictionary も視覚的に編集可能。

**検証**: `EncounterTableData.is_valid()` で tier_weights のキーが 1〜5 の整数か、値が正の整数か、最低1つ正値があるかをチェックする。

### 6. `MonsterRepository.find_by_tier(tier)` API

**選んだ案**: 単純な線形フィルタを毎回計算する。

**代替案**: tier ごとにインデックスを事前構築

**理由**: モンスター12種、エンカウンタは数十秒に1回程度の頻度。毎回 `O(N)` フィルタしてもコスト無視できる。インデックスを持つと register/unregister 時に同期が必要になり複雑化する。後から最適化が必要になった場合のみインデックス化を検討する。

```gdscript
func find_by_tier(tier: int) -> Array[MonsterData]:
    var results: Array[MonsterData] = []
    for m in _monsters.values():
        if m.tier == tier:
            results.append(m)
    return results
```

### 7. MonsterData の tier フィールド

**選んだ案**: `@export var tier: int = 1` (デフォルト1)。**ただし shipped .tres は全て明示記入する。**

**代替案**: デフォルト値なしで必須化 → 既存 .tres の事前マイグレーション必須

**理由**: 既存 .tres を全て更新するが、新規モンスターを追加するときに tier 未設定でも tier 1 でひとまず動く方が開発しやすい。バリデーション (`is_valid()`) で `1 <= tier <= 5` を強制する。

### 8. row バケット truncation の維持

既存の `ROW_CAP=5` / 早い者勝ち / `push_warning` ログ出力は新アルゴリズムにそのまま移植する。これは「画面に出せる体数の上限」という UI 由来の制約で、生成アルゴリズム変更とは無関係。

## Risks / Trade-offs

- **[同 tier 内の uniform 抽選なので、tier 内で出現頻度に差をつけられない]** → 必要になったら `MonsterData` に `spawn_weight` のような追加フィールドを後付けする。現状は tier 5 が dragon と lich の2種なので uniform でも違和感はない。
- **[species_count_min=1, species_count_max=2 だと「同種2スロット = 重複モンスター」が発生し得る]** → 重複抽選を許容するか弾くか。実装では「同種が選ばれたら count を足す」の方が自然なので、簡易的に「同じ monster_id が引かれたら count をマージ」する。ただし最初のリリースでは「重複OK = 別グループとして並ぶ」のシンプル動作で進め、違和感があれば後で調整する。
- **[tier_weights に登録の無いモンスターは絶対に出現しない]** → 12種全てに tier をつけ、全 tier に最低1種のモンスターが居ることを保証する。テストでもこれを担保する。
- **[既存 EncounterPattern の .tres を手で書いていたユーザフローを潰す]** → 影響範囲はこの単一プロジェクトのみで、git で履歴は残るので問題ない。
- **[テストの大幅書き換え]** → `test_encounter_pattern.gd` 等は削除、`test_encounter_manager.gd` / `test_encounter_table_data.gd` は新スキーマで書き直し。TDD を守るので、新仕様のテストを先に書いて red を確認してから実装する。
- **[Godot エディタで Dictionary 型 @export を編集するときに int キーが str として保存されることがある]** → 読み込み時に `int(key)` で正規化、`is_valid()` で型チェックする。

## Migration Plan

1. **テストファースト**: 新スキーマの `EncounterTableData` と新 `generate` アルゴリズムのテストを書く (red 確認)
2. **MonsterData.tier 追加**: フィールド追加 → 既存 12 .tres に tier 値を明示記入 → `is_valid` 更新 → テスト
3. **MonsterRepository.find_by_tier 追加**: 実装 + テスト
4. **EncounterTableData 刷新**: 新スキーマ実装 → `is_valid` 更新 → 旧 `entries` 系を削除 → 旧テスト削除 + 新テスト追加
5. **EncounterManager.generate 刷新**: tier 抽選アルゴリズムを実装 → 既存の cooldown / row truncation テストを維持
6. **EncounterPattern / EncounterEntry / MonsterGroupSpec 削除**: ファイル削除 → 参照しているコードを修正
7. **新 .tres 作成**: `floor_1.tres` / `floor_2.tres` を新スキーマで上書き → `floor_3.tres` 〜 `floor_12.tres` を新規作成
8. **統合テスト**: `test_data_loader.gd` / `test_encounter_coordinator.gd` を新スキーマで検証
9. **手動確認**: ゲームを起動し各階で実際にエンカウントを発生させ、tier 配置が機能していることをログで確認

**Rollback**: git で簡単に戻せる。リリース前なのでデプロイ後の rollback は考慮不要。

## Open Questions

なし (探索フェーズで全ての主要決定は確定済み)。
