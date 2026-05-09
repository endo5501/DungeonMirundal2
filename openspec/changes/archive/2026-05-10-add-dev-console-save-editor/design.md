## Context

DungeonMirundal2 は Wizardry 風 RPG (Godot 4.x) で、ゲームバランス調整・装備品の検証・呪文テストのために多様なキャラクター状態を素早く再現する必要がある。現状はセーブデータ JSON (`user://saves/save_NNN.json`) をテキストエディタで直接編集するしかなく、特に装備が `inventory` 配列のインデックス参照になっている構造のために手作業ではミスしやすい。

セーブデータ自体は JSON だが、`Item` / `JobData` / `RaceData` / `SpellData` などの参照先は Godot の `.tres` リソースであり、これらを正しく扱うにはGodot ランタイムが必要。したがって本ツールは Godot シーンとして動作する。本体ゲームには組み込まず、`tools/dev_console/main.tscn` を直接起動するスタンドアロン構成とする。

将来的に Phase 2 として `.tres` 形式のアイテム/呪文/モンスター定義の編集機能を追加する想定があるため、最初から複数タブを切り替えられるシェル構造で構築する。

## Goals / Non-Goals

**Goals:**
- セーブデータ (`user://saves/save_NNN.json`) の主要フィールドを GUI で編集可能にする
- 編集ロジックを UI から分離した `SaveSession` (RefCounted) に集約し、GUT で TDD 可能にする
- 本体ゲームの規則 (HP/MP 成長式、呪文進行表) と一致するレベル変更ヘルパを提供する
- 通常では到達不能な状態 (戦士に魔法剣等) も自由に作れる、validation を行わない自由編集を許容する
- 将来の Items/Spells/Monsters タブ追加に対応できるシェル構造を用意する
- リリースビルドにツールが混入しないよう export から除外する

**Non-Goals:**
- 本体ゲームへのデバッグ UI 統合 (タイトル画面等からの起動は対象外、シーン直接起動のみ)
- `.tres` リソースの編集 (Phase 2 以降)
- 走行中の `GameState` への live 編集 (本ツールはあくまで保存済み JSON ファイルを対象とする)
- セーブフォーマットのマイグレーション処理 (既存 `SaveManager` の仕様に従う)
- 操作ログの永続化、Undo/Redo
- 装備プリセット (例: 戦士の標準装備一式) の保存・適用
- 複数スロット間のキャラ移動・コピー機能
- 本体ゲームを起動した状態での同時編集 (アクティブなロック制御は行わない)

## Decisions

### D1. 起動方法はシーン直接起動 (`godot --path . res://tools/dev_console/main.tscn`)

**選択**: スタンドアロンの Godot シーンを別プロセスで起動する。本体ゲームには起動エントリを設けない。

**Why**: 本体を汚さない。本体の autoload (`GameState`, `PartyHud` 等) を初期化せずに済むので副作用がない。debug/release ビルドの判別ロジック等も不要。

**Alternatives**:
- (a) タイトル画面で F12 → debug ビルドのみ表示。→ 本体に分岐が混入し、ビルドモード判定や autoload 状態の取り扱いが複雑になる。却下。
- (b) Editor Plugin (dock)。→ Editor が開いていないと使えない、テストが書きにくい (EditorInterface 依存)。却下。

### D2. ロジック層 (`SaveSession`) と UI 層を分離する

**選択**: `tools/dev_console/tabs/saves/save_session.gd` を `RefCounted` で定義し、すべての mutation API をここに置く。UI (`save_editor_panel.gd`) は SaveSession のメソッド呼び出しと表示への反映に徹する。

**Why**: AGENTS.md の TDD 方針との整合。UI を介さずロジックだけを GUT で網羅できる。装備周りの inventory index 解決など複雑なロジックはユニットテストで保護したい。

**API の概形** (RefCounted, 状態は `_data: Dictionary` と repository 参照を保持):
```
load_slot(slot_number: int) -> bool
save_to_slot(slot_number: int) -> bool
list_characters() -> Array[Dictionary]
get_character(char_idx: int) -> Dictionary  # 編集前のスナップショット
set_character_name(char_idx, name)
set_race(char_idx, race_id)
set_job(char_idx, job_id)
set_level(char_idx, level)                   # 後述 D4 の意味論
set_accumulated_exp(char_idx, exp)
set_current_hp(char_idx, hp)
set_max_hp(char_idx, hp)
set_current_mp(char_idx, mp)
set_max_mp(char_idx, mp)
set_base_stat(char_idx, stat_key, value)
toggle_known_spell(char_idx, spell_id, learned: bool)
recompute_hp_mp_from_level(char_idx)         # D4 ヘルパ単体実行
recompute_spells_from_level(char_idx)        # _rebuild_known_spells_through_level 相当
list_inventory() -> Array[Dictionary]
add_item(item_id: StringName, identified: bool = true)
remove_item(inv_idx: int)                    # 装備からも自動的にクリア
set_gold(amount)
equip(char_idx, slot, inv_idx)               # validation なし
unequip(char_idx, slot)
```

**Alternatives**: UI スクリプトに全ロジックを書く → テスト不能。却下。

### D3. JSON は本体の `from_dict` / `to_dict` を経由する

**選択**: `SaveSession` は読み込み時に `Inventory.from_dict` / `Character.from_dict` を呼び、書き出し時に `Inventory.to_dict` / `Character.to_dict` を呼ぶ。内部状態は (a) パース済み Dictionary そのもの、(b) ドメインオブジェクト、のどちらが適切か検討。

**採用**: 内部はドメインオブジェクト (`Character`, `Inventory`, `Equipment`) を保持する。理由:
- 装備の inventory index ↔ ItemInstance 解決が `Equipment.from_dict/to_dict` ですでに実装されているので再利用できる
- レベル変更時の `level_up()` 等本体ロジックを直接呼べる
- スキーマ変更があっても本体の (de)serialization に追従するだけで済む

**例外**: 本ツールでは validation を緩めたい (装備の `can_equip` チェックを通さず装備したい等) 操作については、`Character` / `Equipment` の API ではなく内部辞書を直接操作する方が素直なケースもある。具体的には:
- **装備**: `Equipment.equip()` は `can_equip` でフィルタするので、本ツールは `equipment._slots[slot] = inv.list()[idx]` のような直接代入を行うラッパを `SaveSession` に持つ。
- **呪文の自由付与**: `known_spells` 配列を直接編集 (`_grant_spells_for_level` を経由しない)。`SpellRepository` 検証も `Character.from_dict` 内で警告止まりなのでそのまま運用可能。

**Alternatives**:
- 内部を Dictionary のまま操作 → equipment の inventory index 計算を自前で書くことになり危険。却下。

### D4. `set_level(N)` の意味論

**選択**: 以下のシーケンスで再構築する。
```
let job, race, base_stats を維持 (キャラの定義は変更しない)
character.level = 1
character.accumulated_exp = 0
character.max_hp = job.base_hp + base_stats[VIT] / 3
character.max_mp = job.base_mp if job.is_magic_capable() else 0
character.known_spells = []
character._rebuild_known_spells_through_level(1)   # Lv1 で覚える呪文
for i in 1 .. N-1:
    character.level_up()                            # 既存ロジックを再利用
character.accumulated_exp = job.exp_to_reach_level(N)  # ぴったり N の境界値
character.current_hp = character.max_hp
character.current_mp = character.max_mp
```

**Why**:
- HP/MP/呪文を本体ロジックと完全一致で再構築できる (実プレイでの Lv N と同じ値)
- レベルダウンも一発でクリーンに表現できる
- ユーザは後から current_hp/current_mp を手動上書き可能

**Edge cases**:
- N < 1: no-op もしくはエラー。仕様としては N >= 1 を要求し、それ未満は拒否する。
- N > job.exp_table.size() + 1: 既存の `gain_experience` と同じく上限でクランプ (level_up が空回りしないよう break する)。
- job が変更された後の set_level: 当該キャラの job の規則で再構築する (set_job → set_level の順で呼ぶ)。

### D5. 装備の整合性

**選択**: `remove_item(inv_idx)` を呼んだとき、その item が equipment の任意スロットに装備されていれば自動的にクリアする (PartyMember 全員に対して走査)。理由はインデックス参照なので、削除すると後続インデックスがずれて誤った装備を指すため。

**Alternative**: 削除時に「装備中なので削除できません」と拒否する。→ 自由編集ポリシーに反する。却下。

`equip(char_idx, slot, inv_idx)` は validation なしで `_slots[slot]` を直接上書きする。`unequip(char_idx, slot)` は `_slots[slot] = null`。

### D6. UI 構成: 単一画面に主要情報を集約

**選択**: タブシェル直下に Saves タブのみ常駐。Saves タブは:
- 上部: スロット選択 (`OptionButton`) + Reload / Save ボタン
- 左カラム: パーティリスト (`ItemList`) + Add character (Phase 1 では既存キャラの選択のみで OK、Add は Phase 1.5 以降)
- 中央カラム: 選択キャラの編集フォーム
- 下部: インベントリ表 + Gold

**Add character** は今回のスコープには含めない (proposal で「キャラ追加」を明記していない)。各キャラの値編集と装備変更が主目的。アイテム追加は必要なのでスコープ内。

### D7. Repository / data の取得経路

`DataLoader.new()` で各 Repository を取得する。`Character.from_dict` 内部では `SpellRepository` をオプショナルに受ける形になっているので、SaveSession ロード時に Repository を作っておき以降使い回す:
```
_item_repo = DataLoader.new().load_item_repository()
_spell_repo = DataLoader.new().load_spell_repository()
```
`RaceData` / `JobData` は `load("res://data/races/<id>.tres")` 形式で必要時に取得する (`Character.from_dict` 内ですでに実装済の方式と同じ)。

### D8. テスト戦略

`tests/dev_console/test_save_session.gd` (GUT) で `SaveSession` の各 API をユニットテスト。`user://` への一時ファイル経由でのラウンドトリップ (load → mutate → save → load → assert) を主要ケースで実施。UI レイヤは Phase 1 では UI の自動テストを作らない (操作層に責務を寄せたため)。

`scripts/run_tests.ps1` の pre-flight (parse 検証) で `tools/` 配下の `.gd` も対象になるよう、必要なら `check_scripts.gd` のパスに `tools/` を追加する (現状の正確な対象は実装時に確認)。

### D9. Export からの除外

`export_presets.cfg` の各プリセットの `exclude_filter` に以下を追加:
```
tools/*, tests/*
```
プリセットがまだ存在しない場合は `README.md` のビルド節にこの除外設定を行う旨をメモ追加で済ませる (要追記)。

### D10. ファイル構造

```
tools/dev_console/
├── main.tscn
├── main.gd                       # タブシェル (Control)
├── tabs/
│   └── saves/
│       ├── save_editor.tscn
│       ├── save_editor_panel.gd  # UI binding
│       └── save_session.gd       # RefCounted; ロジック層
└── shared/
    └── repository_picker.gd      # OptionButton ラッパ
tests/dev_console/
└── test_save_session.gd
```

## Risks / Trade-offs

- **[セーブフォーマット変更への追従漏れ]** → SaveSession 内部はドメインオブジェクト (Character / Inventory / Equipment) を保持し、(de)serialization は本体の `from_dict` / `to_dict` を必ず経由することで自動追従する。Equipment などツール側で直接いじる箇所はあるが、形は本体クラスのプロパティに従う。
- **[本体側のクラス API 変更でツールが壊れる]** → ツールの単体テスト (GUT) を CI ラッパに含めれば、本体改修時に検出できる。
- **[validation 無しゆえ無効な状態を作って本体がロード時に落ちる]** → `Character.from_dict` 等は欠落 race/job 等を `null` を返してハンドリング済み。known_spells は無効 ID を drop。HP マイナスや MP > max などはゲーム本体が許容するか不明だが、これはユーザの自己責任とする (本ツールの目的そのもの)。
- **[起動コマンドのプラットフォーム差]** → README に Windows (PowerShell) / Linux 双方の起動コマンド例を追記。
- **[Phase 2 拡張時のシェル設計のミスマッチ]** → タブを `Control` ノードとしてシーン単位で切り出しておけば、新しいタブは新しいシーンを作って main.tscn から `instantiate()` して追加するだけで済む。シェル側に重いロジックを持たせない。
- **[本体ゲームと同時編集してデータ競合]** → 仕様として「本体ゲームを閉じてから Dev Console で編集する」をドキュメント化。ロックは行わない。

## Migration Plan

新規ツール追加のみで既存システムに変更なし。Migration 不要。

ロールバック: `tools/dev_console/` と `tests/dev_console/` を削除、`export_presets.cfg` の除外設定を戻すだけ。

## Open Questions

- export_presets.cfg が現時点でリポジトリに存在するか未確認 (実装時に確認し、無ければ「プリセット作成時に exclude を入れること」を README に明記する)。
- `scripts/check_scripts.gd` が `tools/` 配下を parse 検証しているかは実装時に確認し、必要なら拡張する。
