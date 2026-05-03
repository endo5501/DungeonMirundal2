## ADDED Requirements

### Requirement: TempleScreen.revive は spend_gold の戻り値だけに依存する
SHALL: `TempleScreen.revive` は `spend_gold(cost)` の戻り値のみで成功/失敗を判定する。`gold < cost` を事前に check して early return する重複ガードは存在しない。

#### Scenario: spend_gold が false ならエラーメッセージを表示する
- **WHEN** ゴールドが不足している状態で revive を実行
- **THEN** `_inventory.spend_gold(cost)` が false を返し、エラーメッセージが表示される

#### Scenario: 旧 gold < cost 重複ガードは存在しない
- **WHEN** `temple_screen.gd:revive` を grep
- **THEN** `if gold < cost: ...` のような事前 check は存在しない(spend_gold の戻り値だけが分岐に使われる)
