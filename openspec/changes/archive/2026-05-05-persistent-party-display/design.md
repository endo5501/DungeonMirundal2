## Context

`enlarge-party-display` で PartyDisplay のレイアウト見直しが終わっている前提。本変更では、その HUD を「ダンジョン専用」から「ゲーム中の常駐 HUD」へ昇格させる。

調査で確認したこと:
- `Character.persistent_statuses: Array[StringName]` は永続的状態異常を保持し、`statuses_changed` シグナルが既に存在する。
- `PartyMemberPanel` は既に `statuses_changed` を購読して `queue_redraw` するため、データ取得経路は完成している。
- 利用可能な persistent status は `data/statuses/*.tres`: `poison`, `blind`, `sleep`, `paralysis`, `petrify`, `confusion`, `silence` の 7 種類。
- `StatModifierStack` は `CombatActor` 所有で、戦闘終了時に破棄される(戦闘専用データ)→ 本変更では扱わない。
- main.gd は `change_scene_to_packed` 系の遷移ではなく、`add_child` / `queue_free` で screen を切り替えている(`screen-navigation` spec 参照)。

## Goals / Non-Goals

**Goals:**
- パーティ HUD を Autoload 化し、シーン切替に関係なく単一インスタンスを維持する
- 表示すべきシーン(街・各施設・ダンジョン)で常駐表示し、表示すべきでないシーン(タイトル・セーブ/ロード)で非表示にする
- `Character.persistent_statuses` のアイコンを HUD 内で描画する(暫定: 1 文字 + 色矩形)
- 行動不能状態(死亡・睡眠・麻痺・石化)のメンバーを暗転オーバーレイで一目で識別できるようにする
- アクティブパーティの構成変更(ギルドの編成)を HUD が追従する

**Non-Goals:**
- バフ/デバフ(`StatModifierStack`)の表示 → `combat-party-reactions` で対応
- 戦闘時のリアクション(lift / shake / heal flash) → `combat-party-reactions` で対応
- 状態異常アイコンのアセット化(本変更では文字 + 色矩形の暫定)
- 残ターン数表示
- ESC メニューや全画面マップを開いている間の HUD のフェード・移動などの追加演出
- `confusion` を行動不能扱いにする(行動はできるので暗転対象外)

## Decisions

### D1. Autoload 構造: `PartyHud` (CanvasLayer)
- 採用: `src/autoload/party_hud.gd` を `CanvasLayer extends` で定義し、内部に `PartyDisplay` を子として持つ。
- `project.godot` の `[autoload]` セクションに `PartyHud="*res://src/autoload/party_hud.gd"` を追加。
- API:
  - `show_hud()` / `hide_hud()` - 可視性のみを制御(visible プロパティ)
  - `bind_active_party()` - GameState から現在のパーティを取得し、PartyDisplay に bind する。`bind_party_characters` を内部で呼ぶ。
- CanvasLayer の `layer` 値: 標準 UI より上、ESC オーバーレイより下を想定(具体値は実装時に確認)。

### D2. 表示・非表示の制御責務: main.gd
- 採用: シーン切替を行う `main.gd` が、切替時に `PartyHud.show_hud()` / `hide_hud()` を呼び分ける。
- 代替案: 各 screen の `_ready()` / `_exit_tree()` で自分が呼ぶ → screen 数が増える毎に書き忘れリスクが高い。一元化を採用。
- 表示シーン: `TownScreen`, `GuildScreen`, `Shop`, `Temple`, `DungeonEntrance`, `DungeonScreen`
- 非表示シーン: `TitleScreen`, `LoadScreen`, `SaveScreen`
- ギルド編成画面のみは GuildScreen 内部の状態遷移なので、GuildScreen 自身が編成画面の開閉時に `hide_hud()` / `show_hud()` を呼ぶ例外措置を許容する。

### D3. アクティブパーティの bind タイミング
- 採用: 以下のタイミングで `PartyHud.bind_active_party()` を呼ぶ
  - PartyHud 自身が初期化された時(GameState がロード済みなら即時)
  - main.gd が GameState のロード/新規作成を完了した直後
  - GameState または Guild からのパーティ変更通知(後述 D4)を受信した時
- 既に bind 済みの Character と一致する場合は何もしない最適化を入れてよい(bind_party_characters の冪等性で実現)。

### D4. パーティ変更通知シグナル
- 採用: `Guild` クラスに `active_party_changed` シグナル(ペイロードなし)を追加し、PartyHud が購読する。listener は `GameState.guild` から最新の編成を再取得する(single source of truth)。
- 既存の編成変更コード(`assign_to_party` / `remove_from_party`)から、編成変更完了時に `emit()` を呼ぶ。
- ペイロードを持たせない理由: PartyHud は最新の `GameState.guild` を再 query する設計(D3)なので、シグナル経由で渡された配列を信頼するより GameState の現状を読み直すほうが整合的。配列を引数で渡すと毎回 `_front_row.duplicate()` が必要で(参照渡しによる内部状態破壊を避けるため)、その allocation も不要になる。
- 代替案: 毎フレーム差分監視 → 過剰、却下。

### D5. 状態アイコン描画(暫定デザイン)
- 採用: `PartyMemberPanel._draw()` 内で、データソースの persistent_statuses を順に走査し、パネル下部の右半分に小さな矩形 + 1 文字を並べる。
- アイコンサイズ: 16×16 程度。1 行に最大 6 個まで並べる(7 種類目があれば overflow 警告)。
- 色マッピング:
  - poison → 紫 (Color(0.6, 0.2, 0.7))
  - blind → 灰 (Color(0.4, 0.4, 0.4))
  - sleep → 青 (Color(0.3, 0.4, 0.9))
  - paralysis → 黄 (Color(0.9, 0.8, 0.1))
  - petrify → 暗い灰 (Color(0.3, 0.3, 0.3))
  - confusion → 桃 (Color(0.9, 0.4, 0.7))
  - silence → 茶 (Color(0.5, 0.3, 0.2))
- 文字: ステータス名の頭文字大文字(`P`, `B`, `S`, `Y`(paralysis = paralYsis を避けるため P 衝突回避: `Pa`)…) → 簡潔さ優先で `P/B/S/Pa/St/C/Si` のような 1〜2 文字。実装時に重複しない命名で確定。
- アセット化は将来課題。データ駆動で `StatusData` に色とアイコン文字を持たせる手もあるが本変更では `PartyMemberPanel` 内のテーブル定数で十分。

### D6. 行動不能の暗転オーバーレイ
- 採用: `PartyMemberPanel._draw()` の最後に、判定 `is_incapacitated()` が真なら全パネル領域に半透明黒(例 `Color(0, 0, 0, 0.55)`)を上塗りする。
- 判定: `current_hp <= 0` OR `persistent_statuses` に `&"sleep"`, `&"paralysis"`, `&"petrify"` のいずれかを含む。
- `confusion` は行動不能扱いにしない(自由意志で動けないが、行動自体はする)。
- `silence`, `blind`, `poison` は行動可能なので暗転対象外。
- HP=0 のメンバーには将来「DEAD」テキスト等を上書きする余地を残すが、本変更では暗転だけで十分。

### D7. PartyMemberPanel が直接 Character を参照する
- 既存実装で `_character: Character` を保持しているため、状態アイコン描画と暗転判定もこのフィールドから直接参照する。
- スナップショット経路 (`set_member(PartyMemberData)`) でも整合させるか? → スナップショット経路は legacy のテストでしか使われていないため、状態アイコン・暗転は live Character 経路でのみサポートする(スナップショット時は単に状態を描画しない)。
- 代替案: PartyMemberData に persistent_statuses / is_incapacitated を追加 → コード分岐が増えるので採らない。

### D8. ESC メニュー / 全画面マップ重畳時の挙動
- 採用: HUD はそのまま表示し続ける(プレイヤーが状況確認するために ESC を押す可能性があるため)。
- ESC メニュー / 全画面マップオーバーレイは CanvasLayer の layer 値を PartyHud より上に設定するか、単に Z オーダーで処理する。
- ESC メニューが画面の下半分まで覆うレイアウトであれば、ESC メニューが視覚的に HUD を隠すのは構わない。明示的な hide は呼ばない。

### D9. 戦闘中の HUD
- 戦闘オーバーレイ (`combat-overlay`) も HUD と共存する。重複情報があっても変更スコープ外として許容。
- `combat-party-reactions` ではこの HUD にアニメを乗せる前提で、本変更では HUD が戦闘中も表示されることを保証するだけ。

### D10. パネル高さの拡張
- アイコンエリアの追加で名前/LV/HP/MP の 4 行 + アイコン行が入る必要があるため、`enlarge-party-display` で 110 にしたパネル高さをさらに 130〜140 に拡張する可能性がある。実装時に判断。
- アイコン行を MP 行の右側に並べて 4 行に収める案もある。スペースが許せばそちらを採用。実装時のレイアウト微調整で確定。

## Risks / Trade-offs

- **既存 `DungeonScreen` の所有関係を移すことで、シーン切替時に PartyDisplay が破棄されない不整合が起きる可能性** → DungeonScreen から `PartyDisplay` の生成・bind コードを完全に削除する。テストで PartyDisplay が DungeonScreen の子として存在しないことを確認。
- **複数のシーンが PartyHud を二重で `show_hud()` するなどの整合性ズレ** → main.gd 一元管理で副作用を最小化。show/hide は冪等。
- **アイコン重なり**: persistent_statuses が複数付与された時、アイコンが画面外にはみ出す可能性 → 最大表示数を 6 にし、超過時は省略(将来要件)。
- **GameState のシグナル整備**: 既存コードに `active_party_changed` 相当が無い場合、新規追加が必要 → spec で明示。
- **テスト**: Autoload はテスト環境で扱いが難しいため、`PartyHud` のロジック部分は分離して unit-testable にし、Autoload 統合は手動確認で済ませる。

## Migration Plan

1. `PartyHud` autoload を追加し、`DungeonScreen` の `PartyDisplay` 所有を外す。この時点で街シーンには表示されないが、ダンジョンの挙動が壊れていないことをテストで確認。
2. main.gd / 各 screen で `show_hud()` / `hide_hud()` を呼ぶようにする。街シーンで HUD が表示されることを確認。
3. 状態アイコン描画と暗転オーバーレイを追加。
4. ギルド編成変更時の bind 更新パスを追加。

## Open Questions

- アイコン文字の最終マッピング(P/B/S/Pa/St/C/Si など)→ 実装時に文字衝突を避けつつ確定
- パネル高さ最終値(110 維持 or 130〜140 拡張)→ 実装時にレイアウトで判断
- `StatusData` にアイコン色/文字フィールドを追加するか(将来拡張)→ 本変更ではテーブル定数で十分なので保留
