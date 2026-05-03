## MODIFIED Requirements

### Requirement: SaveManagerはゲーム状態をJSONファイルに保存する
SaveManager SHALL provide a `save(slot_number: int) -> bool` method that serializes the current GameState to a JSON file at `user://saves/save_NNN.json` (zero-padded 3 digits) and returns whether the save succeeded. On failure (file open failure, write failure, last_slot pointer write failure), the method SHALL emit a `push_error` describing the cause and SHALL return `false`. On success, the method SHALL return `true`.

#### Scenario: ゲーム状態を保存
- **WHEN** save(1) を呼び出す
- **THEN** `user://saves/save_001.json` にゲーム状態のJSONが書き出され、`true` が返る

#### Scenario: 保存時にlast_slot.txtを更新
- **WHEN** save(3) を呼び出す
- **THEN** `user://saves/last_slot.txt` に "3" が書き込まれ、`true` が返る

#### Scenario: savesディレクトリが存在しない場合は作成する
- **WHEN** `user://saves/` ディレクトリが存在しない状態でsave()を呼び出す
- **THEN** ディレクトリが自動作成されセーブファイルが書き出され、`true` が返る

#### Scenario: 書き込み失敗時にfalseを返す
- **WHEN** `user://saves/save_001.json` への書き込みが OS エラー(権限不足、ディスクフル等)で失敗する状況で save(1) を呼び出す
- **THEN** `false` が返り、`push_error` が呼ばれる

#### Scenario: last_slot 書き込み失敗時もfalseを返す
- **WHEN** セーブファイル本体は書けたが last_slot.txt の書き込みが失敗する状況で save(1) を呼び出す
- **THEN** `false` が返り、`push_error` が呼ばれる(セーブ本体は成功しているが pointer が一貫しないので失敗扱い)

## ADDED Requirements

### Requirement: SaveManager exposes structured load failure reasons
SaveManager SHALL define a public enum `LoadResult { OK, FILE_NOT_FOUND, PARSE_ERROR, VERSION_TOO_NEW, RESTORE_FAILED }`. The `load(slot_number: int)` method SHALL return one of these enum values, allowing callers to distinguish between the failure causes and surface differentiated UI messages. `push_error` SHALL accompany every non-OK result.

#### Scenario: ファイルが存在しない場合
- **WHEN** save_001.json が存在しない状態で `load(1)` を呼び出す
- **THEN** `LoadResult.FILE_NOT_FOUND` が返る

#### Scenario: JSON が壊れている場合
- **WHEN** save_001.json は存在するが内容がパースできない状態で `load(1)` を呼び出す
- **THEN** `LoadResult.PARSE_ERROR` が返る

#### Scenario: バージョンが新しすぎる場合
- **WHEN** save_001.json の `version` が `CURRENT_VERSION + 1` 以上の状態で `load(1)` を呼び出す
- **THEN** `LoadResult.VERSION_TOO_NEW` が返る

#### Scenario: 復元中に致命的失敗
- **WHEN** JSON は読めたがフィールドの型が想定外で `Inventory.from_dict` 等が破綻する場合
- **THEN** `LoadResult.RESTORE_FAILED` が返る(GameState は安全な状態に保たれる)

#### Scenario: 成功時
- **WHEN** 正常な save_001.json で `load(1)` を呼び出す
- **THEN** `LoadResult.OK` が返り、GameState が復元される

## MODIFIED Requirements

### Requirement: セーブデータにはバージョン番号を含む
SaveManager SHALL include a "version" field (value: 1) in every save file. `load()` SHALL verify the version and reject save files with a version higher than `CURRENT_VERSION` by returning `LoadResult.VERSION_TOO_NEW` (forward compatibility: older versions are accepted for future migration support).

#### Scenario: バージョン番号の記録
- **WHEN** save()を呼び出す
- **THEN** JSONファイルに "version": 1 が含まれる

#### Scenario: 未来のバージョンのロード拒否
- **WHEN** version値がCURRENT_VERSIONより大きいセーブデータをロードする
- **THEN** ロードが失敗し `LoadResult.VERSION_TOO_NEW` が返り、GameStateは変更されない

#### Scenario: 過去のバージョンのロード許可
- **WHEN** version値がCURRENT_VERSION以下のセーブデータをロードする
- **THEN** ロードが成功し `LoadResult.OK` が返る(将来のマイグレーション対応のため前方互換性を維持)
