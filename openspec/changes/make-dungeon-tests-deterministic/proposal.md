## Why

`tests/dungeon/test_dungeon_screen_encounter.gd` と `tests/dungeon/test_dungeon_screen_full_map.gd` の合計 7 箇所のテストが、ランダム生成された地形が想定通りでないとき `pending(...)` で早期に return している。GUT のデフォルト構成では `pending` は緑表示されるため、CI 上は「全テスト通過」だが実際には何も検証していない。リファクタの安全網として致命的に弱い。

加えて `tests/dungeon_scene/` という空ディレクトリが残されており、`HasMpSlot` 条件クラスには直接テストが無い。テストの信頼性に小さなノイズが積もっている。

これからリファクタを連続で行う計画なので、その前に「テストが本当に検証しているのか」を担保する必要がある。

## What Changes

- `tests/dungeon/test_dungeon_screen_encounter.gd` の `pending(...)` 早期リターン 5 箇所を、決定的フィクスチャ(手動構築 `WizMap` または検証済み seed)に置き換える
- `tests/dungeon/test_dungeon_screen_full_map.gd` の `pending(...)` 早期リターン 2 箇所を同様に置き換える
- `tests/test_helpers.gd` に「topology が確実に保証されたフィクスチャを構築するユーティリティ」を追加する(例: `make_corridor_fixture(start: Vector2i, direction: int) -> WizMap`、`make_blocked_fixture(start: Vector2i) -> WizMap`)
- 空ディレクトリ `tests/dungeon_scene/` を削除する
- `tests/items/test_has_mp_slot.gd` を新規追加し、`HasMpSlot.is_satisfied` の動作を直接検証する
- `project-setup` spec に「テストは決定的でなければならず、`pending()` を入力データの不適合理由で使ってはならない」という要件を追加する

## Capabilities

### Modified Capabilities

- `project-setup`: テストの決定性に関する要件を追加。`pending()` の用途を「未実装のテスト」のみに限定する。

## Impact

- **変更コード**:
  - `tests/dungeon/test_dungeon_screen_encounter.gd` — 5 つのテストの `pending` を削除しフィクスチャに置換
  - `tests/dungeon/test_dungeon_screen_full_map.gd` — 2 つのテストの `pending` を削除しフィクスチャに置換
  - `tests/test_helpers.gd` — フィクスチャヘルパー追加
- **追加コード**:
  - `tests/items/test_has_mp_slot.gd` — `HasMpSlot` 直接テスト
- **削除**:
  - 空ディレクトリ `tests/dungeon_scene/`
- **互換性**:
  - 製品コードへの影響はゼロ。テストの信頼性のみ向上。
- **依存関係**: なし。C1 と完全に並行可能。
