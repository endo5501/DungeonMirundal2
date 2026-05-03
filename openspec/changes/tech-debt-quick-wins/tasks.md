## 1. F010: DungeonView fallback の削除 (TDD)

- [ ] 1.1 `tests/dungeon_scene/test_dungeon_scene.gd` (or 既存)で `refresh(empty_array)` を呼んでいるテストがないことを grep で確認
- [ ] 1.2 `src/dungeon_scene/dungeon_scene.gd` から `_dungeon_view: DungeonView` フィールドおよび関連の fallback 分岐を削除
- [ ] 1.3 全テスト通過を確認しコミット

## 2. F015: TempleScreen.revive の重複 gold check 削除 (TDD)

- [ ] 2.1 既存 `tests/town/test_temple_screen.gd` の「ゴールド不足で revive 失敗」テストが残ることを確認
- [ ] 2.2 `src/town_scene/temple_screen.gd:62-67` の `gold < cost` 早期 return を削除
- [ ] 2.3 `spend_gold` の戻り値だけに依存するように分岐を整理
- [ ] 2.4 全テスト通過を確認しコミット

## 3. F021: WizMap の冗長な as int キャスト削除

- [ ] 3.1 `src/dungeon/wiz_map.gd:218,220` の `as int` キャストを削除
- [ ] 3.2 全テスト通過を確認しコミット

## 4. F026: first_plan.md にバナー追加

- [ ] 4.1 `docs/reference/first_plan.md` 冒頭に「これはプロジェクト初期のスナップショット。最新仕様は `openspec/specs/` を参照」のバナーを追加
- [ ] 4.2 コミット

## 5. F027: Equipment.equip を can_equip 経由に整理 (TDD)

- [ ] 5.1 既存 `tests/items/test_equipment.gd` の equip / can_equip テストを確認
- [ ] 5.2 `src/items/equipment.gd:equip` の slot match / job allowed check を `can_equip` 呼び出しに置換
- [ ] 5.3 失敗時の FailReason 判定ロジックを保持(`can_equip` はブール返却なので、reason の判定は equip 内に残す)
- [ ] 5.4 全テスト通過を確認しコミット

## 6. F032: potion.tres → healing_potion.tres リネーム

- [ ] 6.1 Godot エディタで `data/items/potion.tres` を開き、`item_id` を `&"healing_potion"` に変更、ファイル名を `healing_potion.tres` にリネーム(エディタの "Save As" 経由が安全)
- [ ] 6.2 旧 `potion.tres` を削除
- [ ] 6.3 `data/items/potion.tres` への参照(あれば)を全て `healing_potion.tres` に置換
- [ ] 6.4 README に「v??? 以前のセーブで potion を持っている場合、復元時に欠落する」旨を追記
- [ ] 6.5 全テスト通過を確認しコミット

## 7. F040: SaveManager の JSON フォーマット圧縮 (TDD)

- [ ] 7.1 `tests/save_load/test_save_manager.gd` に「セーブファイルにタブ文字が含まれない」「旧形式(タブ含む)も読み込める」テスト追加
- [ ] 7.2 テスト Red 確認
- [ ] 7.3 `src/save_manager.gd:33` の `JSON.stringify(data, "\t")` を `JSON.stringify(data)` に変更
- [ ] 7.4 テスト Green 確認しコミット

## 8. F042: README のバージョン記述

- [ ] 8.1 `README.md` の "Godot Engine 4.6+" を "Godot Engine 4.6.x" に変更
- [ ] 8.2 コミット

## 9. F043: item_use_context.gd の移動

- [ ] 9.1 Godot エディタを開いて、`src/items/conditions/item_use_context.gd` を `src/items/item_use_context.gd` に移動(エディタの File System ドックでドラッグ or `git mv` 後にエディタを再起動)
- [ ] 9.2 同様に `item_effect_result.gd` を移動
- [ ] 9.3 `.gd.uid` ファイルも一緒に移動されていることを確認
- [ ] 9.4 全テスト通過を確認しコミット

## 10. F045: town_screen.select_item の定数化

- [ ] 10.1 `src/town_scene/town_screen.gd` を確認し、`select_item` の `match index: 0:..1:..` が生数値で書かれているか grep
- [ ] 10.2 既に定数化されていればスキップ、なければ `MAIN_IDX_GUILD = 0`, `MAIN_IDX_SHOP = 1` 等の定数を定義
- [ ] 10.3 `match index:` を `MAIN_IDX_*` で書き換える
- [ ] 10.4 全テスト通過を確認しコミット

## 11. 動作確認

- [ ] 11.1 `godot --headless -s addons/gut/gut_cmdln.gd` でフルテストスイート通過
- [ ] 11.2 ゲーム起動 → 各画面遷移を目視確認
- [ ] 11.3 既存セーブのロードが問題なく動くこと(potion を持っているセーブは欠落する点は許容)
- [ ] 11.4 新規セーブを作って `user://saves/save_*.json` が小さくなっていることを確認

## 12. 仕上げ

- [ ] 12.1 `openspec validate tech-debt-quick-wins --strict`
- [ ] 12.2 `/simplify`スキルでコードレビューを実施
- [ ] 12.3 `/opsx:verify tech-debt-quick-wins`
- [ ] 12.4 `/opsx:archive tech-debt-quick-wins`
