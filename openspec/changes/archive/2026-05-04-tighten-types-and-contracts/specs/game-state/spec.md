## ADDED Requirements

### Requirement: GameState は _initialize_state ヘルパーで初期化対称性を保つ
SHALL: `GameState` の `_ready` と `new_game` は、共通の `_initialize_state(reset_for_new_game: bool = false)` ヘルパーを呼ぶ形に統合される。`_ready` は `_initialize_state(false)` を呼び、`item_repository` と `inventory` の null フィールドのみを初期化する(既存値は保持)。`new_game` は `_initialize_state(true)` を呼び、`guild`, `dungeon_registry`, `inventory`, `gold`, `game_location`, `current_dungeon_index` をすべてリセットする。`item_repository` はセッション単位でキャッシュされ、`new_game` でも再構築されない。

#### Scenario: 新フィールド追加時に 1 箇所のみ触れば良い
- **WHEN** GameState に新規 autoload フィールドを追加する
- **THEN** `_initialize_state` メソッド内に初期化ロジックを書くだけで `_ready` / `new_game` 両方の経路で初期化される(2 箇所への重複が不要)

#### Scenario: new_game は item_repository を保持する
- **WHEN** `new_game()` が呼ばれる(2 度目以降を含む)
- **THEN** `GameState.item_repository` は最初に `_ready` でロードされた値が保持される

#### Scenario: _ready は idempotent
- **WHEN** `_ready` が複数回呼ばれる(autoload の reload など)
- **THEN** 既存の guild / dungeon_registry / inventory は再構築されず、null フィールドのみ初期化される
