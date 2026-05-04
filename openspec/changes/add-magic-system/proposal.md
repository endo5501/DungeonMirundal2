## Why

このプロジェクトはWizardry風ターン制戦闘を備えるが、現状コマンドは「攻撃／防御／アイテム／逃げる」の4つに限定され、戦闘に戦術的な選択肢がほぼ無い。MP プールと `JobData.has_magic` の枠は既にあるが、肝心の「呪文」そのものが未定義のため、Mage / Priest / Bishop / Samurai / Lord といった魔法職と非魔法職の差が事実上無い。本変更は、魔法職を魔法職として成立させる最小限の魔法システム v1 を導入する。

## What Changes

- 新規 `SpellData` リソース（.tres）を追加し、計 8 つの呪文を初期データとして同梱する
  - MAGE 系: ファイア / フロスト / フレイム / ブリザード（呪文Lv1×2 + 呪文Lv2×2、即時ダメージのみ）
  - PRIEST 系: ヒール / ホーリー / ヒーラ / オールヒール（呪文Lv1×2 + 呪文Lv2×2、即時回復＋単体攻撃）
- 新規 `SpellRepository` と `DataLoader.load_all_spells()` を追加し、起動時に全 SpellData を読み込む
- 戦闘内に「魔術」「祈り」コマンドを追加し、職に応じて表示／非表示を切り替える
  - 呪文選択 → ターゲット選択 → MP 消費 → 効果適用 のフロー
  - ターゲット種別: 敵単体 / 敵グループ（種類） / 味方単体 / 味方全体
- ESC メニューのパーティサブメニューに「じゅもん」を追加し、戦闘外で回復系呪文を詠唱可能にする
- 自動習得モデル: 職レベル到達時に SpellProgression テーブルに従って呪文を取得する
  - Mage / Priest: Lv1 → 呪文Lv1 全部 / Lv3 → 呪文Lv2 全部
  - Bishop: Lv2 → 両系統呪文Lv1 / Lv5 → 両系統呪文Lv2
  - Samurai: Lv4 → MAGE 呪文Lv1 / Lv8 → MAGE 呪文Lv2
  - Lord: Lv4 → PRIEST 呪文Lv1 / Lv8 → PRIEST 呪文Lv2
- **BREAKING**: `JobData.has_magic: bool` を廃止し、`mage_school: bool` と `priest_school: bool` の 2 フィールドに分割する
  - 既存 8 つの `.tres`（mage/priest/bishop/samurai/lord/fighter/thief/ninja）を全て更新
- `JobData.spell_progression: Dictionary` を追加し、職レベルごとの取得呪文 ID リストを保持する
- `Character` に `known_spells: Array[StringName]` を追加し、習得済み呪文を保持する
  - `Character.gain_experience` / `level_up` 経路でレベルアップ時に新規呪文を取得する
  - `Character.create` 経路で Lv1 初期呪文を付与する
- セーブ／ロード形式を拡張し、`known_spells` を Character 辞書に含める。古いセーブの `known_spells` 不在は許容し、JobData から再導出する後方互換を持つ
- MP 回復は既存の「町に戻る = 宿屋扱いで全回復」を踏襲する（追加実装なし）
- v1 の境界（**今回は対象外、将来の別 change で扱う**）:
  - 状態異常呪文（睡眠など）／ バフ・デバフ呪文 ／ ユーティリティ呪文（脱出・位置など）
  - 呪文失敗・抵抗判定 ／ 属性弱点 ／ 呪文Lv3 以上 ／ 戦闘外で攻撃呪文を撃てる導線
  - 戦闘外詠唱から ESC メニューを経由しない直接 UI（v1 は ESC メニュー経由のみ）

## Capabilities

### New Capabilities

- `spell-data`: `SpellData` リソース（id / display_name / school / level / mp_cost / target_type / scope / effect）と `SpellRepository` の定義、および `DataLoader.load_all_spells()` の規定。
- `spell-casting`: 「呪文の詠唱」を表すドメイン操作の規定。MP 消費、ターゲット種別ごとのターゲット解決、効果適用（ダメージ／回復）、戦闘内コマンド `Cast` の解決、戦闘外詠唱の解決を含む。

### Modified Capabilities

- `job-data`: `has_magic: bool` を廃止し、`mage_school: bool` / `priest_school: bool` / `spell_progression: Dictionary[int, Array[StringName]]` を追加。既存 8 つの .tres とテストを更新。
- `combat-engine`: 戦闘コマンドに `Cast` を追加。Cast の解決手順、ターゲット解決、MP 消費の挙動、MP 不足時のフォールバックを規定。
- `combat-actor`: `CombatActor` に `current_mp` / `max_mp` / `spend_mp(amount)` を統一インターフェースとして加え、`PartyCombatant` は `Character` の MP を proxy する。
- `combat-overlay`: 戦闘 UI のコマンドメニューに「魔術」「祈り」を追加し、職に応じて表示出し分け。Bishop は両方表示。呪文選択／ターゲット選択／結果ログのフローを規定。
- `esc-menu-overlay`: メニューに「じゅもん」を追加し、戦闘外で回復系呪文を詠唱可能にする UI フローを規定。
- `serialization`: `Character.to_dict` / `from_dict` に `known_spells` を含める。古いセーブには `known_spells` が無いケースを許容し、JobData から再導出する。
- `character-creation`: 魔法職（mage_school または priest_school が true の職）で作成された Character は、Lv1 初期呪文を `known_spells` に持って生成される。

## Impact

- **影響コード（変更）**:
  - `src/dungeon/data/job_data.gd`（スキーマ）
  - `src/dungeon/character.gd`（known_spells、習得処理、save 経路）
  - `src/combat/turn_engine.gd`（Cast コマンド、MP 消費）
  - `src/dungeon_scene/combat_overlay.gd`、`src/dungeon_scene/combat/combat_command_menu.gd`（UI）
  - `src/esc_menu/esc_menu.gd`（ESC メニューに「じゅもん」追加）
  - `src/save_manager.gd`（known_spells シリアライズ／デシリアライズ）
  - 既存 `data/jobs/*.tres` 8 ファイル（has_magic 削除、新フィールド追加、spell_progression 設定）
- **影響コード（新規）**:
  - `src/dungeon/data/spell_data.gd`（`SpellData` クラス）
  - `src/dungeon/data/spell_repository.gd`（リポジトリ）
  - `src/combat/spells/`（呪文効果スクリプト群、`item_effect.gd` 系統と並列の構造）
  - `src/dungeon_scene/combat/combat_spell_selector.gd`（呪文選択 UI）
  - `src/dungeon_scene/combat/combat_target_selector.gd`（ターゲット選択 UI）
  - `src/esc_menu/flows/spell_use_flow.gd`（戦闘外詠唱フロー、`item_use_flow.gd` と並列）
  - `data/spells/*.tres`（8 つの呪文リソース）
- **影響データ**: セーブ形式に新フィールド `known_spells`（後方互換あり）。
- **依存**: 状態異常／バフシステム未実装に依存。本 v1 はそれらを必要としない呪文のみを含めることでスコープを制御。
