# Change: セーブ/ロード

## Summary

ゲームの状態をJSON形式で保存・復元する仕組みを実装する。町・ダンジョンどちらの状態でもセーブ可能とし、スタート画面およびESCメニューからセーブ/ロード操作を行えるようにする。

## Scope

- セーブデータ構造設計（JSON形式）
  - パーティ情報（Guild: キャラクター一覧、パーティ編成）
  - キャラクター情報（ステータス、race/jobはファイル名をIDとして参照）
  - ダンジョン状態（seed_valueのみ保存し再生成、explored_map、player_state）
  - ゲーム進行状態（game_location: town/dungeon、現在のダンジョンindex）
  - メタ情報（version、保存日時）
- シリアライズ層
  - 各クラスに to_dict() / static from_dict() を実装
  - 対象: Character, Guild, DungeonData, PlayerState, ExploredMap, DungeonRegistry
- 保存・読込ロジック（SaveManager）
  - user://saves/ ディレクトリへのJSON保存
  - 連番ファイル管理（save_001.json, save_002.json, ...）
  - セーブスロットは自由作成（上限なし）
  - last_slot.txt による最終セーブスロット記録
- セーブ画面UI
  - スロット一覧表示（番号、保存日時、パーティ名、最大レベル、現在地）
  - 新規保存
  - 既存スロットへの上書き確認
- ロード画面UI
  - スロット一覧表示（同上）
  - 選択してロード
- スタート画面との統合
  - 「前回から」有効化（last_slot.txtで最終セーブを特定し自動ロード）
  - 「ロード」有効化（ロード画面を表示）
- ESCメニューとの統合
  - 「ゲームを保存」有効化（セーブ画面を表示）
  - 「ゲームをロード」有効化（ロード画面を表示）
- 画面復元ロジック
  - ロード時にgame_locationに応じて町画面またはダンジョン画面を復元
  - ダンジョン復元時はseedからWizMap再生成 + explored_map/player_state復元

## Design Decisions

- **保存形式**: JSON（人間が読める、デバッグ容易、バージョニング対応）
- **race/job参照**: ファイル名をID（resource_pathから取得、例: "human", "fighter"）
- **WizMap保存**: seed_valueのみ（決定論的再生成が保証されている）
- **スロット管理**: 自由作成・連番、メタ情報はファイル内に保持
- **「前回から」**: last_slot.txtに最終保存ファイル名を記録
- **セーブタイミング**: 町・ダンジョンどちらでも可能

## Non-goals

- アイテム操作・装備管理の実ロジック（items-and-economy）
- 設定項目の詳細（音量、キー設定等は後続で必要に応じて）
- オートセーブ機能
- セーブデータの暗号化・改竄防止

## Dependencies

- esc-menu: ESCメニュー（セーブ/ロードメニュー項目のdisabled解除先）
- town-screen-and-navigation: 地上画面 + 画面遷移（スタート画面、画面遷移管理）

## Risks

- セーブデータのバージョニング（将来version 2以降への移行時のマイグレーション）
- ダンジョン内セーブからの復元時のゲーム状態整合性
