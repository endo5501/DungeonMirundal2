## Why

現在のパーティ表示はダンジョン画面でしか表示されず、街・ギルド・店・教会などにいる時のメンバー確認は ESC メニューを開かないとできない。また、状態異常(毒・盲目・睡眠など)が付与されているかは戦闘ログを読まないとわからず、行動不能(死亡・睡眠・麻痺・石化)状態のメンバーも一見して識別できない。

本変更では「パーティ表示の段階的強化」3部作の第2段として、パーティ HUD を Autoload 化して各種シーンで常駐表示できるようにし、`Character.persistent_statuses` を視覚化する。これによりプレイヤーはどの画面にいてもパーティの構成と状態を瞬時に把握できる。

## What Changes

- パーティ HUD を Autoload(常駐 `CanvasLayer`)に格上げし、シーン切替で破棄/再生成されない構造に変更
- `DungeonScreen` から `PartyDisplay` の所有を外し、HUD 側で active party を bind する責務に移行
- 表示するシーン: TownScreen, GuildScreen(編成画面以外), Shop, Temple, DungeonEntrance, DungeonScreen
- 非表示にするシーン: TitleScreen, LoadScreen, SaveScreen, GuildScreen のパーティ編成 UI 中
- 重なって構わないシーン(HUD はそのまま残す): ESC メニューオーバーレイ、全画面マップオーバーレイ
- `PartyMemberPanel` に `Character.persistent_statuses` を視覚化するアイコンエリアを追加(暫定: 1 文字 + 色矩形のミニアイコン、ステータス毎に色分け)
- 行動不能(`current_hp <= 0` or `persistent_statuses` に `sleep` / `paralysis` / `petrify` のいずれかが含まれる)時、パネル全体を半透明の暗いオーバーレイで覆う
- アクティブパーティの構成変更(ギルドでの編成)を HUD が検知し、再 bind する
- バフ/デバフ(`StatModifierStack`)は **本変更では扱わない** — `StatModifierStack` は `CombatActor` 所有の戦闘専用データのため、`combat-party-reactions` で扱う

## Capabilities

### New Capabilities

- `party-hud-autoload`: パーティ HUD を Autoload (`CanvasLayer`) として常駐させ、シーン毎に表示/非表示を切り替え、アクティブパーティを bind するライフサイクル全体を扱う

### Modified Capabilities

- `party-display`: persistent status のアイコン描画要件・行動不能時のパネル暗転要件を追加。`DungeonScreen binds PartyDisplay` 要件は autoload 経由の bind に置き換え

## Impact

- **新規**: `src/autoload/party_hud.gd` (CanvasLayer + PartyDisplay 所有 + show/hide API + active party bind)
- **新規**: `project.godot` に Autoload 登録(`PartyHud=*res://src/autoload/party_hud.gd`)
- `src/dungeon_scene/dungeon_screen.gd` から `PartyDisplay` 所有・生成・bind コードを削除
- `src/main.gd`(または各 screen 側): screen 切替時に PartyHud の表示/非表示を制御
- `src/town_scene/town_screen.gd`: 表示要求を発行(または main.gd 側で制御)
- `src/guild_scene/guild_menu.gd`: 表示要求を発行、編成画面では非表示
- `src/dungeon_scene/party_display.gd`: 状態アイコンエリアの描画追加、アクティブパーティ変更を再 bind する API 追加
- `src/dungeon_scene/party_member_panel.gd`: `_data` の参照する Character から `persistent_statuses` を取得してアイコン描画、行動不能判定で暗転オーバーレイ
- `src/dungeon/party_member_data.gd`: `persistent_statuses` フィールドと `is_incapacitated()` を追加(または PartyMemberPanel で Character を直接参照)
- 関連テスト: 新規 `tests/autoload/test_party_hud.gd`、既存 `tests/dungeon_scene/` の影響箇所更新
- GameState 側のパーティ変更通知シグナル(なければ追加)
