## 1. プロジェクト構造とビルド除外

- [x] 1.1 `tools/dev_console/` および `tests/dev_console/` ディレクトリを作成する
- [x] 1.2 `export_presets.cfg` の存在を確認し、存在すれば各プリセットの `exclude_filter` に `tools/*` および `tests/*` を追加する。存在しなければ README のビルド節に「プリセット作成時に `tools/*` と `tests/*` を `exclude_filter` に入れること」と注記する
- [x] 1.3 `scripts/check_scripts.gd` が `tools/` 配下を parse 検証対象に含めているか確認し、含まれていなければ拡張する

## 2. SaveSession ロジック層 (TDD)

- [x] 2.1 `tests/dev_console/test_save_session.gd` を作成し、最小ケース (空スロットを load してエラーを返す) のテストを書く。実装はまだない状態でテストが失敗することを確認する
- [x] 2.2 `tools/dev_console/tabs/saves/save_session.gd` の最小スケルトンを作成し、2.1 のテストを通す
- [x] 2.3 `load_slot(slot_number)` のテストを追加: テンポラリな `user://saves/save_999.json` を fixture として書き、ロード後に `list_characters()` がパーティ内容を返すことを検証する。テストが失敗することを確認後、実装する
- [x] 2.4 `save_to_slot(slot_number)` のラウンドトリップテスト (load → 何もしない → save → load) を追加し、JSON が同一であることを検証する。実装する
- [x] 2.5 `set_character_name`, `set_race`, `set_job` の各テストを追加し、実装する
- [x] 2.6 `set_current_hp`, `set_max_hp`, `set_current_mp`, `set_max_mp` のテストを追加し、`current_hp > max_hp` のような不整合状態が保存可能であることも検証する。実装する
- [x] 2.7 `set_base_stat(stat_key, value)` のテストを追加し、validation なしで任意整数が保存されることを検証する。実装する
- [x] 2.8 `set_accumulated_exp(exp)` のテストを追加し、実装する
- [x] 2.9 `set_level(N)` のテストを追加: Lv1 から `set_level(5)` を呼び、`max_hp` / `max_mp` / `known_spells` が本体の `level_up` を 4 回回した結果と一致することを検証する。`accumulated_exp` が `job.exp_to_reach_level(5)` と等しいこと、`current_hp == max_hp` であることも検証する。実装する
- [x] 2.10 `set_level(N)` の境界値テスト: N=1, N=最大レベル+1 (クランプ), N=0 (拒否) をカバーする
- [x] 2.11 `recompute_hp_mp_from_level(char_idx)` および `recompute_spells_from_level(char_idx)` のテストと実装を追加する
- [x] 2.12 `toggle_known_spell(char_idx, spell_id, learned)` のテストと実装を追加し、職業の `spell_progression` 外の呪文も追加できることを検証する
- [x] 2.13 `set_gold(amount)` のテストと実装を追加し、負の値も保存可能であることを検証する
- [x] 2.14 `add_item(item_id, identified)` のテストと実装を追加し、`ItemRepository` に存在する ID で末尾追加されることを検証する
- [x] 2.15 `remove_item(inv_idx)` のテストを追加: 装備中アイテムを削除すると当該キャラの装備スロットが自動でクリアされ、後続インデックスがずれた他キャラの装備が正しく追従することを検証する。実装する
- [x] 2.16 `equip(char_idx, slot, inv_idx)` のテストと実装を追加し、本来不可能なスロット型および職業要件を無視して装備できることを検証する
- [x] 2.17 `unequip(char_idx, slot)` のテストと実装を追加する
- [x] 2.18 ラウンドトリップ統合テスト: 複数操作 (キャラ編集 + アイテム追加 + 装備変更 + 削除) を行った後 save → 別の SaveSession で load し、本体 `SaveManager.load` でも問題なく読めることを検証する

## 3. Dev Console シェル UI

- [x] 3.1 `tools/dev_console/main.tscn` と `main.gd` を作成し、空のタブシェルを表示する。`godot --path . res://tools/dev_console/main.tscn` で起動できることを手動確認する (smoke test `tools/dev_console/_smoke_test.gd` で headless 起動を自動検証)
- [x] 3.2 タブの登録 API (子シーンを `instantiate()` してタブとして追加する仕組み) を実装する。タブシェル本体には Saves 固有のロジックを持たせない (`main.gd` の `_TabSpec` に scene path を加えるだけで拡張できる)
- [x] 3.3 起動時に Saves タブが既定で選択される動作を実装する (`_TabSpec` の最初のエントリが Saves、`_tabs.current_tab = 0` で選択)

## 4. Saves タブ UI

- [x] 4.1 `tools/dev_console/tabs/saves/save_editor.tscn` を作成し、スロット選択 OptionButton + Reload / Save ボタン + パーティリスト + キャラ編集フォーム + インベントリ表 + Gold フィールドのレイアウトを構築する
- [x] 4.2 `save_editor_panel.gd` を作成し、`SaveSession` を保持してスロット一覧の取得 (`user://saves/` 走査) と OptionButton への反映を実装する (`SaveSession.list_slots()` 経由)
- [x] 4.3 Reload ボタンで `SaveSession.load_slot()` を呼び、UI に値を反映する処理を実装する
- [x] 4.4 パーティリストでキャラを選択するとキャラ編集フォームが当該キャラの値で更新される処理を実装する
- [x] 4.5 名前 / Race / Job / Level / EXP / HP / MP / 6 能力値の入力 UI が編集を `SaveSession` の対応 setter にディスパッチする処理を実装する
- [x] 4.6 既知呪文のチェックボックス UI を `SpellRepository` の全呪文から動的生成し、`toggle_known_spell` を呼ぶ処理を実装する
- [x] 4.7 "Rebuild spells from level" / "Recompute HP/MP from level" ボタンを実装し、対応する SaveSession ヘルパを呼ぶ
- [x] 4.8 装備 6 スロットの OptionButton を実装する。選択肢はインベントリ全アイテム + `-- empty --`。validation なし。スロット選択時に `equip` / `unequip` を呼ぶ
- [x] 4.9 インベントリ表 (アイテム ID 名・identified 状態) と各行の `Remove` ボタン、末尾の Add ドロップダウン + Add ボタンを実装する
- [x] 4.10 Gold フィールドの編集が `set_gold` を呼ぶ処理を実装する
- [x] 4.11 Save ボタンで `save_to_slot()` を呼ぶ処理を実装し、成功・失敗のステータス表示を行う
- [x] 4.12 パース失敗等のエラーメッセージを画面下部に表示する仕組みを実装する (`StatusLabel` に赤色で表示)

## 5. 共有 UI コンポーネント

- [x] 5.1 `tools/dev_console/shared/repository_picker.gd` を作成し、`OptionButton` を任意の Repository (ItemRepository / SpellRepository / RaceData / JobData の `.tres` 列挙) でポピュレートするヘルパを実装する。Saves タブの Race / Job / アイテム選択 UI から利用する

## 6. 動作確認

- [x] 6.1 `scripts/run_tests.ps1` (または `.sh`) を実行して GUT が `tests/dev_console/` 配下のテストを認識・全 pass することを確認する (`.gutconfig.json` の `dirs` に追加。実行結果: 2235/2235 passed、SaveSession テスト 33/33 含む)
- [x] 6.2 手動確認: 既存のセーブを Dev Console でロード → 1 キャラのレベルを変更 → 装備を変更 → 保存。本体ゲームを起動して同セーブをロードし、編集が反映されていることを確認する (ユーザによる手動確認で OK)
- [x] 6.3 手動確認: 「戦士に魔法剣を装備」「Lv1 で MP100」のような validation 不可状態を作成して保存し、本体ゲームで該当キャラを表示してもクラッシュしないことを確認する (ユーザによる手動確認で OK)
- [x] 6.4 export 確認: デバッグエクスポートを実行し、出力された pck/exe に `tools/` および `tests/` 配下のリソースが含まれていないことを (export ログまたは pck ダンプで) 確認する (ユーザが `export_presets.cfg` を作成し、確認済み)

## 7. ドキュメント

- [x] 7.1 `tools/dev_console/README.md` を作成し、起動コマンド、編集できる項目、validation を行わない方針、本体ゲームを閉じてから利用する旨、Phase 2 拡張の差し込み方針を記述する
- [x] 7.2 リポジトリ root の `README.md` のビルド節または開発環境節に「Dev Console: 開発者向けセーブ編集ツール。`godot --path . res://tools/dev_console/main.tscn` で起動」のリンクを追記する
