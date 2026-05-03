## ADDED Requirements

### Requirement: DungeonEntrance.setup は Guild 参照を受け取る
SHALL: `DungeonEntrance.setup(registry: DungeonRegistry, guild: Guild)` のシグネチャに変更される。引数 `has_party: bool` は廃止される。`DungeonEntrance` 内部で `_guild.has_party_members()` を必要なタイミングで呼び出し、現在のパーティ状態を fresh に判定する。

#### Scenario: Guild 参照経由で has_party が判定される
- **WHEN** `DungeonEntrance.setup(registry, guild)` が呼ばれ、その後 `_guild.has_party_members()` が `true` を返す
- **THEN** ダンジョンに入る選択肢が enabled になる

#### Scenario: 旧 has_party: bool 引数は廃止される
- **WHEN** `dungeon_entrance.gd` を grep
- **THEN** `setup(registry, has_party)` 形式の呼び出しは存在しない

#### Scenario: setup 後に party 状態が変わっても次回の判定で反映される
- **WHEN** entrance setup 後、別画面でパーティを編成し、entrance に戻る
- **THEN** `has_party_members()` が再度クエリされ、最新状態が反映される
