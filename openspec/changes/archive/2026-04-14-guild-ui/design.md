## Context

DungeonMirundal2はWizardry風ダンジョン探索RPG（Godot 4.x）。character-and-party-system changeでロジック層（Character, Guild, RaceData, JobData, BonusPointGenerator, DataLoader）が完成済み。本changeでは、そのロジック層の上に冒険者ギルドのUI/シーン層を構築する。

既存UIパターン:
- `PartyDisplay` / `PartyMemberPanel` はプログラム的にノードを生成する方式（.tscnなし）
- ロジック層はRefCounted（Node非依存）で、UI層が薄いラッパーとして機能する

town-screen-and-navigation changeは未実装のため、Guild UIは独立したシーンとして構築し、後から統合する。

## Goals / Non-Goals

**Goals:**
- Wizardryライクなテキストメニュー方式のギルドUI
- キャラクター作成ウィザード（5ステップ: 名前→種族→配分→職業→確認）
- パーティ編成画面（スロット選択→操作方式、パーティ名変更含む）
- キャラクター一覧画面（詳細表示・削除機能）
- .tscnシーンファイルによるUI構築（メンテナンス性優先）

**Non-Goals:**
- ロジック層の変更（完成済みをそのまま利用）
- town-screen統合（別change）
- ソート・フィルタ機能（初期実装では不要）
- キャラクターアイコンやグラフィカルなUI装飾
- セーブ/ロード（save-load changeで対応）

## Decisions

### 1. 画面構造: GuildScreenによる子シーン差し替え方式

```
GuildScreen (.gd)  ← 親。Guildインスタンスを保持
├── GuildMenu.gd         メニュー選択
├── CharacterCreation.gd ウィザード5ステップ
├── PartyFormation.gd    編成 + パーティ名変更
└── CharacterList.gd     一覧・詳細・削除
```

GuildScreenが唯一のGuildインスタンスを保持し、各子画面を `ClassName.new()` でインスタンス化して差し替える。各子画面はsignalで `back_requested` を通知する。各画面は `_ready()` でプログラム的にUIノード（Label, VBoxContainer, LineEdit等）を構築し、`_unhandled_input()` でキーボード操作を処理する。

**理由:** 既存コードベース（`dungeon_scene/PartyDisplay`, `PartyMemberPanel`）がプログラム的ノード生成パターンを採用しているため、一貫性を優先した。差し替え方式はメモリ効率が良く、画面間の状態リセットが自然に行える。

**代替案:**
- .tscnシーンファイル: Godotエディタでのレイアウト調整が容易だが、既存パターンとの不一致
- 全画面をvisibility切り替え: メモリ消費が増え、状態管理が複雑化

### 2. UIスタイル: Wizardryライクなテキストメニュー

全画面でテキストベースのメニュー表示を採用。カーソル選択方式で、キーボード操作を主体とする。

**理由:** Wizardryのゲーム体験を再現するため。シンプルな実装で動作確認しやすい。

### 3. キャラクター作成: ウィザード（ステップ）形式

1画面内で5つのステップを順次表示する。各ステップはCharacterCreation内のVBoxContainer内容を動的に再構築して切り替える。

```
Step 1: 名前入力（テキストフィールド）
Step 2: 種族選択（リスト + ステータス合計値表示）
Step 3: ボーナスポイント配分（+/-ボタン、振り直し機能）
Step 4: 職業選択（就任可能職のみ選択可、不可職はグレー）
Step 5: 確認画面（全情報表示 → 作成実行）
```

「戻る」でStep 3→Step 2に戻ると配分はリセットされる（種族変更で基礎値が変わるため）。

**理由:** 各ステップが前ステップの結果に依存するため、順次進行が自然。1画面にまとめると情報過多になる。

### 4. ボーナスポイント配分: +/-ボタン方式

各ステータスに対して+/-ボタンを配置。残りポイントが0になったら次へ進める。「振り直し」ボタンでBonusPointGenerator.generate()を再実行し、配分をリセットする。

合計値のみ表示（種族基礎値 + 配分の内訳は非表示）。

**理由:** Wizardryの操作感に近く、直感的。内訳表示は情報量が過剰。

### 5. パーティ編成: スロット選択 → 操作方式

操作フロー:
1. パーティグリッド（前列3 × 後列3）からスロットを選択
2. スロットが空き → 待機リストからキャラ選択して配置
3. スロットが占有 → 「外す」で待機リストへ戻す

パーティ名は画面上部に表示し、選択で直接編集可能。

**理由:** スロット基点の操作は「どこに誰を置くか」を直感的に操作でき、パーティの全体像が常に見える。

**代替案:**
- キャラ選択 → 配置先選択（Wizardry原作に近い）: 全体像が見えにくく、操作ステップが増える

### 6. キャラクター削除: 確認ダイアログ方式

パーティ所属中のキャラは削除不可（Guild.remove()のロジックに従う）。待機中キャラのみ削除可能で、「はい/いいえ」の確認ダイアログを表示する。

### 7. ファイル配置

```
src/guild_scene/
├── guild_screen.gd       # 親画面。Guild保持、子シーン差し替え
├── guild_menu.gd         # メニュー（4項目、カーソル選択）
├── character_creation.gd # 作成ウィザード（5ステップ内包）
├── party_formation.gd    # パーティ編成 + 名前変更
├── character_list.gd     # 一覧・詳細・削除（確認ダイアログ付き）
└── guild_test_entry.gd   # テスト用エントリーポイント
```

### 8. 画面間のデータフロー

GuildScreenがGuild, DataLoaderのインスタンスを保持し、各子画面の初期化時に必要なデータを渡す。

```gdscript
# GuildScreen
var guild: Guild
var data_loader: DataLoader

func _on_create_character():
    var creation := CharacterCreation.new()
    creation.setup(guild, data_loader.load_all_races(), data_loader.load_all_jobs())
    creation.back_requested.connect(_show_menu)
    _switch_view(creation)
```

各子画面はsignalで結果を通知:
- `character_created` — 作成完了
- `back_requested` — メニューに戻る

## Risks / Trade-offs

- **[プログラム的UIのレイアウト調整]** → エディタプレビューが使えないため、レイアウト調整はコード変更→実行のサイクルが必要。対策: VBoxContainer/HBoxContainerベースのシンプルなレイアウトに留め、Wizardryスタイルのテキスト表示を基本とする
- **[town-screen統合時の改修]** → 後からGuildScreenをtown画面のサブシーンとして組み込む際、画面切り替えロジックの調整が必要になる可能性。対策: GuildScreen自体を独立したシーンとして完結させ、外部からはinstantiate()するだけにする
- **[キーボード操作のフォーカス管理]** → テキストメニューのカーソル移動やテキスト入力のフォーカス切り替えが複雑になる可能性。対策: Godotの `grab_focus()` と `FocusMode` を活用し、各画面で明示的にフォーカス管理する
- **[BonusPointGeneratorの状態管理]** → 振り直しの度に新しいポイントが生成されるため、ステップ間の戻り/進みで状態の整合性に注意。対策: Step 3に入る度に新規生成し、Step 2に戻った場合はStep 3再入時に再生成
