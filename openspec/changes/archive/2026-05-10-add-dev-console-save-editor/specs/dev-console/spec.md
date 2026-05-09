## ADDED Requirements

### Requirement: Dev Console は本体ゲームから独立したスタンドアロンシーンとして起動する

開発者向けデバッグツール「Dev Console」は、本体ゲームのシーンや autoload に依存せず、`tools/dev_console/main.tscn` を直接起動することで利用できる SHALL。本体ゲームのリリースビルドには Dev Console およびそのテスト群が含まれない MUST。

#### Scenario: シーン直接起動で Dev Console が立ち上がる
- **WHEN** 開発者が `godot --path . res://tools/dev_console/main.tscn` を実行する
- **THEN** Dev Console のタブシェル UI が表示され、本体ゲームのタイトル画面やダンジョンシーンは起動しない

#### Scenario: リリースビルドにツールが含まれない
- **WHEN** `godot --headless --export-release` を実行する
- **THEN** 出力されたビルド成果物に `tools/` 配下および `tests/` 配下のリソースが含まれない (`export_presets.cfg` の `exclude_filter` で除外されている)

### Requirement: タブシェル構造で複数の編集対象を切り替えられる

Dev Console のメイン画面は、上部にタブ切り替え UI を持ち、各タブが独立した編集対象を扱える拡張可能なシェル構造である SHALL。Phase 1 では Saves タブのみが実装されている MUST が、Items / Spells / Monsters 等の追加タブを後から差し込める設計になっている SHALL。

#### Scenario: Saves タブが既定で選択されている
- **WHEN** Dev Console を起動する
- **THEN** Saves タブが自動的にアクティブとなり、その中身が表示される

#### Scenario: 新しいタブの追加がシェル本体の改修を要さない
- **WHEN** 開発者が新しいタブのシーンを `tools/dev_console/tabs/<name>/` に追加し、`main.tscn` から `instantiate()` でタブシェルに登録する
- **THEN** タブシェル本体 (`main.gd`) のロジック改修なしに新タブが追加できる

### Requirement: Saves タブはセーブスロットの選択・読み込み・保存ができる

Saves タブは `user://saves/save_NNN.json` 形式の既存セーブファイル一覧を選択 UI で提示し、選択したスロットを読み込み、編集後に同じスロットへ書き戻すことができる SHALL。スキーマは本体 `SaveManager` の現行フォーマットと同一 MUST。

#### Scenario: 既存セーブの一覧が表示される
- **WHEN** Saves タブを開く
- **THEN** `user://saves/` 配下の `save_NNN.json` ファイル群がスロット選択 UI に列挙される

#### Scenario: スロットを選択するとデータが読み込まれる
- **WHEN** 開発者がスロット番号 1 を選び `Reload` を押す
- **THEN** `user://saves/save_001.json` がパースされ、パーティ・インベントリ・Gold が画面に反映される

#### Scenario: Save ボタンで JSON が同じスロットに書き戻される
- **WHEN** 開発者が任意の編集を行ったあとに `Save` ボタンを押す
- **THEN** `user://saves/save_NNN.json` が新しい内容で上書きされ、本体ゲームから問題なく読み込めるフォーマットになっている

#### Scenario: パースに失敗したスロットはエラー表示される
- **WHEN** 選択したスロットの JSON が壊れている
- **THEN** 編集 UI に値が反映されず、エラーメッセージが表示される

### Requirement: SaveSession はロジック層として UI から独立している

セーブデータの編集ロジックは `tools/dev_console/tabs/saves/save_session.gd` (RefCounted) に集約される SHALL。UI スクリプトは SaveSession の API を呼び出すだけで mutation を行う MUST。SaveSession は GUT による単体テストが可能である SHALL。

#### Scenario: SaveSession が単独で動作する
- **WHEN** GUT テストが `SaveSession.new()` を生成しスロットをロードして mutation API を呼ぶ
- **THEN** UI シーンを生成せずに編集とラウンドトリップ (load → mutate → save → load) が完了する

#### Scenario: UI は SaveSession を介してのみ mutation する
- **WHEN** UI 上の任意の編集操作が行われる
- **THEN** その実体は `save_session.<method>()` への呼び出しに帰着し、UI スクリプトが直接 JSON や Character オブジェクトを変更することはない

### Requirement: キャラクターの基本属性を編集できる

選択中のキャラクターについて、以下の基本属性を編集できる SHALL: 名前 (`character_name`)、種族 (`race_id`)、職業 (`job_id`)、レベル、`accumulated_exp`、`current_hp`、`max_hp`、`current_mp`、`max_mp`、6 能力値 (STR/INT/PIE/VIT/AGI/LUC)。

#### Scenario: 名前を編集できる
- **WHEN** 開発者が名前フィールドに新しい文字列を入力し Save する
- **THEN** 当該キャラの `character_name` が新しい値で保存される

#### Scenario: Race / Job を変更できる
- **WHEN** 開発者が Race のドロップダウンから別の種族を選ぶ
- **THEN** 当該キャラの `race_id` が更新される (`base_stats` は自動再計算しない: 種族基礎値の差分はユーザが手で調整する)

#### Scenario: HP / MP の current と max を独立に編集できる
- **WHEN** 開発者が `current_hp` を 1、`max_hp` を 999 に設定する
- **THEN** 両方の値がそのまま保存され、`current_hp > max_hp` のような不整合状態でも書き戻し可能

#### Scenario: 能力値を任意の整数で編集できる
- **WHEN** 開発者が STR を 25 に設定する
- **THEN** 種族基礎値や職業要件のチェックを行わず、その値が `base_stats[STR]` として保存される

### Requirement: `set_level(N)` ヘルパが本体ロジックと一致して HP/MP/呪文を再構築する

レベル変更操作 `set_level(char_idx, N)` は、当該キャラのレベルを N に設定すると同時に、本体ゲームの `level_up()` ロジックと完全に一致する手順で `max_hp` / `max_mp` / `known_spells` を再構築する SHALL。`accumulated_exp` は `job.exp_to_reach_level(N)` の値に設定される SHALL。`current_hp` と `current_mp` はそれぞれ `max_hp` / `max_mp` に揃えられる (フル回復) SHALL。

#### Scenario: Lv5 への変更で HP/MP/呪文が再構築される
- **WHEN** Lv1 のキャラに対して `set_level(5)` を呼ぶ
- **THEN** Lv1 から `level_up()` を 4 回回したのと同じ `max_hp` / `max_mp` 値になり、`known_spells` には Lv1〜Lv5 の `spell_progression` がすべて含まれる

#### Scenario: ゲームが許容する最大レベルでクランプする
- **WHEN** 開発者が `job.exp_table.size() + 2` 以上のレベル値を要求する
- **THEN** `set_level` は最大レベル (`job.exp_table.size() + 1`) でクランプし、`accumulated_exp` も対応する境界値に設定される

#### Scenario: N < 1 の指定はエラー
- **WHEN** 開発者が `set_level(0)` または負の値を要求する
- **THEN** SaveSession は変更を行わずエラーを返す

#### Scenario: フル回復される
- **WHEN** `current_hp = 1` の状態で `set_level(5)` を呼ぶ
- **THEN** 操作完了後の `current_hp` は新しい `max_hp` と等しくなる (その後ユーザが手動で current を下げることは可能)

### Requirement: 既知呪文をチェックボックスで自由に編集できる

選択中のキャラクターの `known_spells` を、`SpellRepository` に存在する全呪文のチェックボックス UI で編集できる SHALL。職業の `spell_progression` 等の制約は適用しない (validation なし)。

#### Scenario: 呪文を任意に追加できる
- **WHEN** 開発者が Mage キャラの未習得呪文 `allheal` (Priest 系呪文) のチェックを ON にする
- **THEN** その呪文が `known_spells` に追加され、職業適性チェックでブロックされない

#### Scenario: 呪文を任意に削除できる
- **WHEN** 開発者が習得済みの呪文のチェックを OFF にする
- **THEN** その呪文が `known_spells` から削除される

#### Scenario: レベルから既知呪文を再構築するヘルパが利用できる
- **WHEN** 開発者が "Rebuild spells from level" ボタンを押す
- **THEN** `known_spells` が `_rebuild_known_spells_through_level(level)` の結果で置き換えられる

### Requirement: インベントリと Gold を編集できる

選択中のセーブのインベントリについて、Gold の値変更、アイテムの追加 / 削除を行える SHALL。アイテムは `ItemRepository` から ID で選択できる SHALL。

#### Scenario: Gold を任意の整数に設定できる
- **WHEN** 開発者が Gold フィールドに新しい値を入力する
- **THEN** `inventory.gold` がそのまま保存される (validation なし、負の値も許容)

#### Scenario: アイテムをドロップダウンから追加できる
- **WHEN** 開発者がアイテム選択 UI から `long_sword` を選び `Add` を押す
- **THEN** `inventory.items` の末尾に `{item_id: long_sword, identified: true}` が追加される

#### Scenario: アイテムを削除すると装備からも外れる
- **WHEN** 開発者がインベントリから装備中のアイテムを削除する
- **THEN** そのアイテムを装備しているキャラの該当スロットが自動的に空になり、削除に伴うインデックスのずれによる装備の指し違いが発生しない

### Requirement: 装備を validation なしで自由に変更できる

選択中のキャラクターの 6 装備スロット (`weapon`, `armor`, `helmet`, `shield`, `gauntlet`, `accessory`) について、インベントリ上の任意のアイテムを装備できる SHALL。`Equipment.can_equip` のスロット型および職業適性チェックは適用しない MUST。

#### Scenario: スロット型に合わないアイテムも装備できる
- **WHEN** 開発者が Weapon スロットに `leather_armor` (本来は ARMOR スロット用) を設定する
- **THEN** 当該キャラの weapon スロットに `leather_armor` が割り当てられ、保存される

#### Scenario: 職業に許可されていないアイテムも装備できる
- **WHEN** 開発者が Mage に `long_sword` (Mage は通常装備不可) を装備させる
- **THEN** 警告なしに装備が確定し、保存される

#### Scenario: スロットを空にできる
- **WHEN** 開発者が Weapon スロットの選択を `-- empty --` にする
- **THEN** 当該スロットは null となり、保存後の JSON では `equipment.weapon = null` となる

### Requirement: ItemInstance は同時に複数のキャラクターの装備スロットに存在できない

`equip(char_idx, slot, inv_idx)` を呼ぶとき、SaveSession は当該 `ItemInstance` を保持している他のキャラクターおよび同一キャラクターの他スロットから自動的に取り外す MUST。これは `validation` ではなく **データ整合性** の制約であり、validation 不要 (slot 型・職業適性) のポリシーを適用しない MUST。本体 `equipment_flow.gd:_unequip_from_other_holders` の振る舞いと一致する SHALL。

#### Scenario: 別キャラクターから装備が外れる
- **WHEN** Hero (idx 0) の WEAPON スロットに装備されている `long_sword` (inv idx 0) を Mira (idx 1) の WEAPON スロットに `equip(1, WEAPON, 0)` で割り当てる
- **THEN** Hero の WEAPON スロットは null になり、Mira の WEAPON スロットだけが当該 `ItemInstance` を持つ

#### Scenario: 同一キャラクターの旧スロットから外れる
- **WHEN** Hero の WEAPON スロットに装備されている `long_sword` を、Hero 自身の ARMOR スロットに `equip(0, ARMOR, 0)` で割り当てる (validation バイパスにより異なるスロット型でも装備できる)
- **THEN** Hero の WEAPON スロットは null になり、ARMOR スロットだけが当該 `ItemInstance` を持つ

#### Scenario: 同じスロットへの再装備は冪等
- **WHEN** Hero の WEAPON に `long_sword` が既にある状態で `equip(0, WEAPON, 0)` を再度呼ぶ
- **THEN** 装備状態は変わらず、`long_sword` は Hero の WEAPON スロットに残り続ける

### Requirement: 装備の serialization は本体ゲームと互換である

`Equipment` は inventory 配列のインデックスとして JSON に保存される現行仕様に従う MUST。Dev Console で保存した JSON は本体 `SaveManager.load` で問題なく読み込める SHALL。

#### Scenario: 編集後のセーブを本体がロードできる
- **WHEN** Dev Console でアイテム追加・装備変更を行ったセーブを本体ゲームでロードする
- **THEN** インベントリの内容と各キャラの装備が Dev Console での編集結果と一致して復元される

#### Scenario: アイテム削除後のインデックスが正しく振り直される
- **WHEN** Dev Console でインベントリ中ほどのアイテムを削除した後、別キャラがその後ろのアイテムを装備している
- **THEN** 保存される equipment スロットのインデックスは新しい inventory 配列に対する正しい位置に再計算されている
