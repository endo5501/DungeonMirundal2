## Why

ゲームバランス調整(レベル毎の能力値上昇率の確認、装備品の使用感の検証)や呪文・装備のテストを行うには、特定の状態のキャラクター — 例えば Lv13 の Lord に Long Sword を持たせた状態、極端に MP だけ高い Mage、未習得の高位呪文を所持したキャラなど — を素早く用意したい。現状はセーブデータ JSON をテキストエディタで手で書き換えるしかなく、装備が `inventory` のインデックス参照になっている等の構造上の罠もあって試行錯誤が遅い。

開発者専用のデバッグツールとして、セーブデータを GUI で安全に編集できる仕組みを用意することで、調整サイクルを短縮する。将来的にはアイテム/呪文/モンスターなど `.tres` 編集にも拡張する想定で、最初からシェル構造で作る。

## What Changes

- **新規ツール**: `tools/dev_console/` 配下に Godot シーンとして起動する開発者向け Dev Console を追加する。本体ゲームから独立し、`godot --path . res://tools/dev_console/main.tscn` で起動する。
- **タブシェル構造**: 複数の編集対象タブを切り替えられるシェルを用意する。Phase 1 では `Saves` タブのみを実装する(`Items` / `Spells` / `Monsters` タブは Phase 2 以降の拡張ポイントとして残す)。
- **Saves タブ**: `user://saves/save_NNN.json` を直接読み書きし、以下を編集可能にする:
  - スロット選択、Reload / Save
  - 各キャラクター: 名前、Race、Job、Level、accumulated_exp、current_hp/max_hp、current_mp/max_mp、6 能力値 (STR/INT/PIE/VIT/AGI/LUC)、known_spells (チェックボックス)、Equipment 6 スロット (inventory から選択)
  - インベントリ: Gold、アイテム追加 / 削除
- **Validation を行わない**: 通常では到達不能な状態(戦士に魔法剣、Lv1 で MP100 等)も自由に作れる。デバッグ目的なので意図的。
- **ロジック層の分離**: 全ての mutation を `SaveSession` (RefCounted) に集約し、UI から独立させて GUT でテスト可能にする。
- **`set_level(N)` の意味論**: Lv1 から `level_up()` を N-1 回回して HP/MP/呪文を本体ロジックと同じ規則で再構築し、`accumulated_exp = job.exp_to_reach_level(N)` を設定する。HP/MP は `current = max` でフル回復させる(その後ユーザが手動で current を上書き可能)。
- **Export からの除外**: `export_presets.cfg` の `exclude_filter` に `tools/*` と `tests/*` を追加してリリースビルドへの混入を防ぐ。

## Capabilities

### New Capabilities
- `dev-console`: 開発者向けデバッグツールのシェルおよびセーブデータエディタ機能。`tools/dev_console/` 配下のシーンとして本体外で動作し、JSON 形式のセーブファイルを GUI で編集する操作を定義する。

### Modified Capabilities
<!-- なし: 本体仕様の振る舞いは変えない。SaveManager のセーブ JSON フォーマットは既存仕様のまま読み書きするだけ。 -->

## Impact

- **新規ファイル**:
  - `tools/dev_console/main.tscn` / `main.gd` — タブシェル
  - `tools/dev_console/tabs/saves/save_editor.tscn` / `save_editor_panel.gd` — Saves タブ UI
  - `tools/dev_console/tabs/saves/save_session.gd` — ロジック層 (RefCounted)
  - `tools/dev_console/shared/repository_picker.gd` — 共有 UI コンポーネント
  - `tests/dev_console/test_save_session.gd` — GUT テスト
- **既存ファイル変更**:
  - `export_presets.cfg` — `tools/*` と `tests/*` を `exclude_filter` に追加(プリセットが存在する場合)
- **既存コードへの依存**(読み取り専用):
  - `Character`, `Inventory`, `Equipment`, `ItemInstance`, `ItemRepository`, `SpellRepository`, `RaceData`, `JobData`, `DataLoader`
  - 既存の `SaveManager` の JSON フォーマット契約(`version`, `inventory`, `guild.characters[]`, `equipment` の inventory index 参照など)
- **依存しないもの**: 本体のシーン、autoload (`GameState`, `PartyHud` 等)、戦闘・ダンジョン関連の実行時ロジック。Dev Console は本体の autoload を必要としないスタンドアロンとして動く。
- **リスク**:
  - SaveManager の JSON スキーマが将来変わると Dev Console が追従漏れする可能性 → セーブのロード/シリアライズには可能な限り `Inventory.from_dict` / `Character.from_dict` / `Character.to_dict` 等の本体関数を再利用してドリフトを防ぐ。
