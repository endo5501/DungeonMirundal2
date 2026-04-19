## 1. データモデル拡張 (Item / Repository)

- [x] 1.1 `src/items/item.gd` の `ItemCategory` enum に `CONSUMABLE` を追加する
- [x] 1.2 `src/items/item.gd` に `@export var effect: ItemEffect`、`@export var context_conditions: Array[ContextCondition]`、`@export var target_conditions: Array[TargetCondition]` を追加する (既定値は null / 空配列)
- [x] 1.3 既存の `.tres` (long_sword など) が新フィールドの既定値のままロード可能であることをテストで確認する (GUT: items spec 互換テスト)
- [x] 1.4 `ItemRepository.all()` と `DataLoader.load_all_items()` が CONSUMABLE アイテムも返すことを GUT テストで確認する

## 2. Effect 階層

- [x] 2.1 `src/items/effects/item_effect.gd` を作成: `class_name ItemEffect extends Resource`、`apply(user, targets, context) -> ItemEffectResult` (仮想)
- [x] 2.2 `src/items/effects/item_effect_result.gd` (または同居) で結果型 `{success: bool, message: String}` を定義
- [x] 2.3 `src/items/effects/heal_hp_effect.gd` 実装 (`@export var power: int`)、HP を clamp して回復
- [x] 2.4 `src/items/effects/heal_mp_effect.gd` 実装 (`@export var power: int`)、MP を clamp して回復
- [x] 2.5 `src/items/effects/escape_to_town_effect.gd` 実装 (`is_in_combat` で分岐)
- [x] 2.6 GUT テスト: HealHpEffect の回復量 / clamp / 死亡者への不適用 (条件側で弾かれる想定だが効果自体の耐性確認)
- [x] 2.7 GUT テスト: HealMpEffect の回復量 / clamp
- [x] 2.8 GUT テスト: EscapeToTownEffect の非戦闘フロー (シグナル発火のみ確認、遷移は別テスト)

## 3. Condition 階層

- [x] 3.1 `src/items/conditions/item_use_context.gd` を作成 (is_in_dungeon、is_in_combat、party)
- [x] 3.2 `src/items/conditions/context_condition.gd` を作成: `class_name ContextCondition extends Resource`、`is_satisfied(ctx)` / `reason()` 仮想
- [x] 3.3 `src/items/conditions/in_dungeon_only.gd` 実装
- [x] 3.4 `src/items/conditions/not_in_combat_only.gd` 実装
- [x] 3.5 `src/items/conditions/target_condition.gd` を作成: `class_name TargetCondition extends Resource`、`is_satisfied(target, ctx)` / `reason()` 仮想
- [x] 3.6 `src/items/conditions/alive_only.gd` 実装
- [x] 3.7 `src/items/conditions/not_full_hp.gd` 実装
- [x] 3.8 `src/items/conditions/not_full_mp.gd` 実装
- [x] 3.9 `src/items/conditions/has_mp_slot.gd` 実装 (Character.job から MP 所持を判定)
- [x] 3.10 GUT テスト: 各 Context / Target Condition の成否と reason 文言

## 4. Inventory の使用 API

- [x] 4.1 `src/items/inventory.gd` に `use_item(instance, targets, context) -> ItemEffectResult` を追加 (存在確認 → context 検査 → target 検査 → effect.apply → 成功時に remove)
- [x] 4.2 GUT テスト: 成功で instance が除去される
- [x] 4.3 GUT テスト: context 失敗で instance が残る + message が返る
- [x] 4.4 GUT テスト: target 失敗で instance が残る + message が返る
- [x] 4.5 GUT テスト: instance がインベントリに存在しないとき success=false で副作用なし

## 5. 初期消費アイテム `.tres` (data/items/)

- [x] 5.1 `data/items/potion.tres` を作成 (CONSUMABLE、HealHpEffect(power=20 目安)、AliveOnly+NotFullHp、price=50)
- [x] 5.2 `data/items/magic_potion.tres` を作成 (CONSUMABLE、HealMpEffect(power=10 目安)、AliveOnly+HasMpSlot+NotFullMp、price=200)
- [x] 5.3 `data/items/escape_scroll.tres` を作成 (CONSUMABLE、EscapeToTownEffect、InDungeonOnly+NotInCombatOnly、price=500)
- [x] 5.4 `data/items/emergency_escape_scroll.tres` を作成 (CONSUMABLE、EscapeToTownEffect、InDungeonOnly、price=2000)
- [x] 5.5 GUT テスト: DataLoader ロード結果に 4 アイテムが含まれる、`escape_scroll` と `emergency_escape_scroll` が NotInCombatOnly の有無で差別化される

## 6. ショップ対応 (ShopInventory + ShopScreen)

- [x] 6.1 `src/items/shop_inventory.gd` のフィルタを「装備品 OR CONSUMABLE」に書き換える (既存の `equip_slot != NONE` を拡張)
- [x] 6.2 `src/shop/shop_screen.gd` にカテゴリタブ UI ([装備品]/[消費アイテム]) を追加、現在タブに応じて一覧をフィルタ
- [x] 6.3 Buy フローが消費アイテム購入でも identified=true の ItemInstance を生成することを確認 (既存コード流用)
- [x] 6.4 Sell フローが消費アイテムを売却可能にし、装備中チェックは装備品のみに適用されることを確認
- [x] 6.5 GUT テスト: ShopInventory が CONSUMABLE を含む
- [x] 6.6 GUT テスト: 消費アイテム購入で identified=true の instance がインベントリに追加される
- [x] 6.7 GUT テスト: 消費アイテムを売却すると gold が price/2 増加する (scene テストまたは shop_screen 単体)
- [ ] 6.8 手動確認: ShopScreen でタブ切替、装備品のみ/消費アイテムのみの表示を確認

## 7. ESC メニュー: アイテム使用フロー

- [x] 7.1 `src/esc_menu/esc_menu.gd` のアイテムビューに「使う」アクションを追加 (消費アイテム行のみ)
- [x] 7.2 Context 条件失敗時の行グレーアウト表示 + reason 表示を実装
- [x] 7.3 対象条件ありの消費アイテムに対して対象選択サブビューを実装 (パーティメンバーを列挙、target_conditions 失敗はグレーアウト)
- [x] 7.4 対象条件なしの消費アイテムに「使いますか？」確認ダイアログを表示
- [x] 7.5 確定時に `Inventory.use_item(instance, targets, ctx)` を呼び出し、結果に応じて一覧を refresh / メッセージ表示
- [x] 7.6 `escape_scroll` 成功時に `return_to_town` シグナル経路を発火する
- [x] 7.7 GUT テスト: 消費アイテム行に使用アクションが現れる / 装備品行には現れない
- [x] 7.8 GUT テスト: ポーション使用で HP が回復し、成功時にインベントリから除去される
- [ ] 7.9 手動確認: ダンジョン内で脱出の巻物を使用して町に戻れる
- [ ] 7.10 手動確認: 町で脱出の巻物を使おうとするとグレー表示で理由が出る

## 8. 戦闘コマンド「アイテム」の追加

- [ ] 8.1 `src/dungeon_scene/combat/combat_command_menu.gd` の `OPTIONS` を `["こうげき", "ぼうぎょ", "アイテム", "にげる"]` に変更
- [ ] 8.2 「アイテム」選択時のフロー: 消費アイテム一覧 → context 失敗はグレーアウト → 対象選択 or 即確定 → ItemCommand コミット
- [ ] 8.3 消費アイテム 0 のときに「アイテムがありません」メッセージを表示しコマンド未確定のまま CommandMenu に戻る
- [ ] 8.4 `src/dungeon_scene/combat/commands/item_command.gd` を新規作成 (actor、item_instance、target、cancelled フラグ)
- [ ] 8.5 TurnEngine の解決ループに ItemCommand を組み込む (すばやさ順、行動前 KO 判定でキャンセル、成功時 instance 削除 + ログ追加)
- [ ] 8.6 EscapeToTownEffect 成功時は戦闘を ESCAPED で即終了し、残コマンドを破棄する
- [ ] 8.7 GUT テスト: ItemCommand がすばやさ順で解決される (特別補正なし)
- [ ] 8.8 GUT テスト: 使用者が行動前に KO → ItemCommand キャンセル、instance 残留、ログに記録
- [ ] 8.9 GUT テスト: 戦闘中 emergency_escape_scroll → EncounterOutcome.ESCAPED、EXP/gold 0、instance 消費
- [ ] 8.10 GUT テスト: 戦闘中の escape_scroll (NotInCombatOnly) はリストでグレーアウト
- [ ] 8.11 手動確認: 戦闘でポーションを使って仲間を回復できる
- [ ] 8.12 手動確認: 戦闘で緊急脱出の巻物を使うと戦闘終了 → 町メニュー入り口へ

## 9. 帰還遷移の共通化 (dungeon-return)

- [ ] 9.1 `src/dungeon_scene/dungeon_screen.gd` の `return_to_town` 発火経路が EscapeToTownEffect からも呼ばれるようにフックを用意
- [ ] 9.2 START タイル経路が無変更で機能することを GUT / scene テストで確認 (既存シナリオを維持)
- [ ] 9.3 GUT テスト: EscapeToTownEffect (非戦闘) が `return_to_town` シグナルと同等の遷移を引き起こす
- [ ] 9.4 GUT テスト: EscapeToTownEffect (戦闘中) は combat-overlay の ESCAPED 経由で同じ遷移先に到達する

## 10. 統合確認 + クリーンアップ

- [ ] 10.1 プロジェクト全体の GUT テスト (`gut`) が通ることを確認
- [ ] 10.2 `openspec validate add-consumable-items --strict` が通ることを確認
- [ ] 10.3 既存セーブファイル (あれば) でロードしてインベントリが破損しないことを手動確認
- [ ] 10.4 E2E 手動確認シナリオ: ショップで 4 アイテム購入 → 非戦闘でポーション/マジックポーション/脱出の巻物を使用 → ダンジョンで戦闘 → 戦闘中にポーション/緊急脱出の巻物を使用
- [ ] 10.5 変更をコミット (英語コミットメッセージ、TDD の流れでテスト先行の区切りでコミット)
