# Change: アイテム＆経済

## Summary

アイテムシステム（装備・その他、MVP では消耗品は除外）、商店（購入・売却）、教会（蘇生）を実装し、combat-system で使用した `DummyEquipmentProvider` を `InventoryEquipmentProvider` に差し替える。戦闘勝利時のゴールドドロップ、パーティ共有インベントリ、パーティ共有ゴールド、キャラ毎 6 スロット装備までを本 change の MVP として含め、未鑑定 UI・呪い・宝箱ドロップ・消耗品使用は別 change に延期する。

## Scope

- アイテムデータ定義
  - Custom Resource `.tres` によるアイテム定義（`data/items/` 配下）
  - カテゴリ: 武器 / 鎧 / 兜 / 盾 / 籠手 / 装身具 / その他（MVP では消耗品を含めない）
  - アイテム属性: 表示名、未鑑定名、カテゴリ、装備タイプ、装備可能職業 `allowed_jobs`、攻撃/防御/素早さ ボーナス、価格、未鑑定フラグのデータモデル
- アイテムインスタンス
  - `ItemInstance` に `identified: bool` フラグを持つ（データモデルのみ、MVP では常に `true` で生成）
- インベントリ
  - パーティ共有（1 袋）
  - 所持数上限なし
  - パーティ共有ゴールド（初期 500G）
- 装備
  - キャラ毎 6 スロット: 武器 / 鎧 / 兜 / 盾 / 籠手 / 装身具
  - アイテム毎 `allowed_jobs` による職業制限
  - 装備による `get_attack` / `get_defense` / `get_agility` への合算
  - `InventoryEquipmentProvider` を実装し、`DummyEquipmentProvider` を置き換える
- 商店
  - 単一商店、固定在庫
  - 購入（ゴールドと引き換え）
  - 売却（買値の 1/2）
- 教会
  - 死亡キャラクター復活（100% 成功）
  - 蘇生コスト: 対象の `level × 定数`
- 戦闘連携
  - `MonsterData` に `gold_min` / `gold_max` を追加
  - 戦闘勝利時にランダム範囲でゴールドをパーティに加算
  - `EncounterOutcome` に `gained_gold` フィールドを追加
- キャラクター作成連携
  - キャラ作成時に職業に応じた初期装備を付与
- UI 連携
  - 町画面の「商店」「教会」を有効化
  - ESC メニューの「アイテム」「装備」を有効化（アイテム閲覧・装備変更）
- 永続化連携
  - セーブ/ロードにインベントリ・ゴールド・装備を含める

## Non-goals

- 消耗品の使用（ポーション等、ESC メニュー・戦闘中コマンド両方）→ 別 change
- 未鑑定 UI・商店の鑑定サービス → 別 change（データモデルの `identified` フラグのみ MVP に含める）
- 呪い装備 → 別 change
- モンスタードロップ / 宝箱システム → 別 change
- 灰 / ロスト等の高度な死亡ステート、蘇生失敗処理 → 別 change
- 戦闘中アイテム使用コマンド → 別 change
- 戦闘バランスの最終調整 → 全 change 完成後に実施
- 商店の在庫変動・多店舗化・カテゴリ別店舗 → 別 change

## Dependencies

- combat-system（archive 済）: `EquipmentProvider` インターフェース、`EncounterOutcome`、`DummyEquipmentProvider`（差し替え対象）
- save-load（archive 済）: セーブファイル仕様にインベントリ・ゴールド・装備を追加
- character-and-party-system（archive 済）: `Character` / `Guild`
- monster-and-encounter（archive 済）: `MonsterData`（`gold_min` / `gold_max` を追加）

## Risks

- `DummyEquipmentProvider` からの差し替え時、初期装備が無いキャラクターが戦闘で不利になるリスク → 初期装備を職業毎に定義して回避
- `ItemInstance` を .tres 化せず RefCounted で扱う判断が、セーブ/ロード設計に影響する → `to_dict` / `from_dict` によるシリアライズ方式で統一
- 商店の在庫固定にしたことで、最序盤の経済ループがゴールドドロップ量に強く依存 → 暫定値（例: 最弱モンスター 5〜15G）を置き、バランス調整は後続 change で
- 装備可能職業を「アイテム側に allowed_jobs」方式にした結果、職業毎のデフォルト装備可否を書き漏れるリスク → 全 8 職を明示するスペックシナリオで担保
