## Context

DungeonMirundal2はWizardry風ダンジョン探索RPG（Godot 4.x）。現在、ダンジョン3D描画・移動、ダンジョンUI、キャラクター＆パーティシステム、冒険者ギルドUIが完成済み。しかしmain.gdがWizMapを直接生成してDungeonScreenを表示するだけの仮実装であり、タイトル画面・地上画面・画面遷移の仕組みが一切存在しない。

既存アーキテクチャの特徴:
- Model層: RefCountedベース（Guild, Character, WizMap, PlayerState等）
- View層: Controlノードによるプログラム的UI構築
- 画面内遷移: signal + `_switch_view()` パターン（GuildScreen内で確立済み）
- Autoload: なし（画面間で状態を共有する手段がない）

## Goals / Non-Goals

**Goals:**
- タイトル画面 → 地上画面 → ダンジョンの基本的な画面フローの確立
- GameState autoloadによるゲーム状態の画面間共有
- 複数ダンジョンの作成・選択・削除の管理
- ダンジョンからの帰還手段（STARTタイル + 確認ダイアログ）
- 既存のGuildScreenを地上画面から呼び出し可能にする

**Non-Goals:**
- セーブ/ロードの実ロジック（save-load changeのスコープ）
- 商店・教会の実機能（items-and-economy changeのスコープ）
- 画面遷移アニメーション（即切り替え方式を採用）
- 戦闘関連の遷移（combat-system changeのスコープ）
- ESCメニュー（save-load changeのスコープ）

## Decisions

### 1. 画面遷移方式: main.gd による signal + _switch_screen()

main.gdをトップレベルの画面管理者とし、各画面（TitleScreen, TownScreen, DungeonScreen, GuildScreen）をsignalベースで切り替える。

```
main.gd (Control, ルートノード)
  └── 現在の画面 (1つだけ子として存在)
      ├── TitleScreen   → start_game signal
      ├── TownScreen    → facility_selected signal
      ├── GuildScreen   → back_requested signal
      ├── DungeonEntrance (TownScreenの子)
      └── DungeonScreen → return_to_town signal
```

切り替えロジック:
```gdscript
func _switch_screen(new_screen: Control) -> void:
    if _current_screen:
        _current_screen.queue_free()
    _current_screen = new_screen
    add_child(new_screen)
```

**理由:** GuildScreen内部で確立済みの`_switch_view()`パターンをトップレベルに拡張するだけで、新しいパターンを導入せずに済む。画面数が限られているため（4-5画面）、複雑なスタック管理やシーンマネージャは不要。

**代替案:**
- SceneTree.change_scene(): 画面間でGameState以外のデータ引き継ぎが面倒
- シーン管理シングルトン（push/pop方式）: この規模では過剰な抽象化

### 2. ゲーム状態管理: GameState autoload

```
GameState (Node, autoload)
├── guild: Guild
├── dungeon_registry: DungeonRegistry
├── new_game() → Guild初期化 + DungeonRegistry初期化
└── heal_party() → パーティ全員のHP/MPを全回復、状態異常解除
```

GameStateはゲーム全体で共有されるデータの唯一のオーナー。各画面はGameState経由でGuildやDungeonRegistryにアクセスする。

**理由:** Autoloadにすることで、画面の生成・破棄に関わらずデータが永続する。main.gdにデータを持たせる方法もあるが、各画面からの参照が煩雑になる。

### 3. ダンジョン管理: DungeonData + DungeonRegistry

```
DungeonData (RefCounted)
├── dungeon_name: String
├── seed: int
├── map_size: int
├── wiz_map: WizMap
├── explored_map: ExploredMap
├── player_state: PlayerState  (最後の位置、初回はSTARTタイル)
└── get_exploration_rate() -> float

DungeonRegistry (RefCounted)
├── _dungeons: Array[DungeonData]
├── create(name: String, size_category: int) -> DungeonData
├── remove(index: int) -> void
├── get_all() -> Array[DungeonData]
├── get(index: int) -> DungeonData
└── size() -> int
```

サイズカテゴリ:
- SMALL = 0: 8〜12 の範囲でランダム
- MEDIUM = 1: 13〜20 の範囲でランダム
- LARGE = 2: 21〜30 の範囲でランダム

保有数制限なし。

**理由:** ダンジョンごとにWizMap、ExploredMap、PlayerStateを保持することで、複数ダンジョンの探索状態を独立に管理できる。seedを保存しておけばWizMapは再生成可能だが、ExploredMapとPlayerStateはダンジョン固有の進行状態であるため保持が必須。

### 4. ダンジョン名生成: 形容詞 + 名詞の組み合わせ

```
DungeonNameGenerator (RefCounted)
├── ADJECTIVES: Array[String]  ("暗黒の", "深淵の", "忘却の", "灼熱の", ...)
├── NOUNS: Array[String]       ("迷宮", "洞窟", "回廊", "地下墓地", ...)
└── generate() -> String       (ランダムに1つずつ選んで結合)
```

生成後、プレイヤーが自由に名前を編集可能。

### 5. タイトル画面: シンプルな4項目メニュー

```
TitleScreen (Control)
├── "新規ゲーム"     → start_new_game signal
├── "前回から"       → continue_game signal (グレーアウト、save-loadで有効化)
├── "ロード"         → load_game signal (グレーアウト、save-loadで有効化)
└── "ゲーム終了"     → quit_game signal
```

「前回から」「ロード」はUIとしてボタンを表示するが、選択不可（disabled）。save-load changeで実ロジックを接続する。

**理由:** UIの枠を先に作っておくことで、save-load changeでは画面生成なしにロジック接続だけで済む。

### 6. 地上画面: 左右2カラム構成

```
TownScreen (Control)
├── 左カラム: VBoxContainer (施設選択ボタン)
│   ├── "冒険者ギルド"   → open_guild signal
│   ├── "商店"           → (disabled, items-and-economyで有効化)
│   ├── "教会"           → (disabled, items-and-economyで有効化)
│   └── "ダンジョン入口"  → open_dungeon_entrance signal
└── 右カラム: ColorRect + Label (施設イラストプレースホルダ)
    └── 選択中の施設に応じてテキストと背景色が変化
```

**理由:** 将来的にイラスト素材を差し替えるための枠を確保しつつ、今回はColorRect+Labelで最低限の視覚フィードバックを提供する。

### 7. ダンジョン入口: 一覧 + 操作ボタン

```
DungeonEntrance (Control)
├── ダンジョン一覧 (VBoxContainer, スクロール対応)
│   └── 各行: "名前  サイズ  探索率%"
├── [ 潜入する ]  → enter_dungeon signal (ダンジョン未選択時disabled)
├── [ 新規生成 ]  → create_dungeon signal → DungeonCreateDialog表示
├── [ 破棄 ]      → delete_dungeon signal (確認ダイアログ後に削除)
└── [ 戻る ]      → back_requested signal

DungeonCreateDialog (確認パネル、DungeonEntrance内に表示)
├── サイズ選択: 小 / 中 / 大
├── 名前: [ランダム生成されたテキスト] (編集可能)
├── [ 生成 ]  → confirm signal
└── [ やめる ] → cancel signal
```

パーティが未編成（全スロット空）の場合、「潜入する」は選択不可。

### 8. ダンジョン帰還: STARTタイル + 確認ダイアログ

DungeonScreenにSTARTタイル検出ロジックを追加:

```
プレイヤーがSTARTタイルに移動
  → "地上に戻りますか？  はい / いいえ" ダイアログ表示
    → "はい": return_to_town signal 発火
    → "いいえ": ダイアログ閉じ、探索続行
```

main.gdがreturn_to_town signalを受け取り:
1. GameState.heal_party() 呼び出し（HP/MP全回復）
2. DungeonScreenをqueue_free
3. TownScreenを表示

STARTタイルに立つたびにダイアログが表示される（帰還を強制しない）。

**理由:** STARTタイルは「ダンジョンの入口」であり、帰還ポイントとして直感的。ESCメニューはsave-load changeのスコープなので、今回はこの方法のみ。

### 9. ファイル配置

```
src/
├── main.gd                          # 全面改修: 画面管理者
├── dungeon/
│   ├── dungeon_data.gd              # 新規: 1ダンジョン分のデータ
│   ├── dungeon_registry.gd          # 新規: 複数ダンジョン管理
│   └── dungeon_name_generator.gd    # 新規: ランダム名生成
├── game_state.gd                    # 新規: autoloadシングルトン
├── title_scene/
│   └── title_screen.gd              # 新規: タイトル画面
├── town_scene/
│   ├── town_screen.gd               # 新規: 地上画面
│   ├── dungeon_entrance.gd          # 新規: ダンジョン入口
│   └── dungeon_create_dialog.gd     # 新規: ダンジョン生成ダイアログ
├── dungeon_scene/
│   └── dungeon_screen.gd            # 改修: STARTタイル検出+帰還ダイアログ
└── guild_scene/
    └── (変更なし、back_requestedの接続はmain.gdが担う)
```

### 10. 画面遷移フロー全体像

```
TitleScreen
  │
  ├─ 新規ゲーム → GameState.new_game() → TownScreen
  ├─ 前回から   → (disabled)
  ├─ ロード     → (disabled)
  └─ ゲーム終了 → get_tree().quit()
          │
      TownScreen
          │
          ├─ 冒険者ギルド    → GuildScreen → 「立ち去る」→ TownScreen
          ├─ 商店            → (disabled)
          ├─ 教会            → (disabled)
          └─ ダンジョン入口  → DungeonEntrance
                               ├─ 潜入する → DungeonScreen
                               │              └─ STARTタイル帰還 → heal_party() → TownScreen
                               ├─ 新規生成 → DungeonCreateDialog → DungeonEntrance
                               ├─ 破棄     → 確認 → DungeonEntrance
                               └─ 戻る     → TownScreen
```

## Risks / Trade-offs

- **[GameState autoloadの依存集中]** → 全画面がGameStateに依存するため、テスト時にモック/スタブが必要。対策: GameState自体はGuild/DungeonRegistryの薄いラッパーであり、ロジックのテストは各RefCountedクラス単体で行う
- **[DungeonScreenへの帰還ロジック追加]** → 既存のDungeonScreenに新しい責務が加わる。対策: STARTタイル検出とダイアログ表示は独立したメソッドとして追加し、既存のキー入力処理を変更しない
- **[ダンジョンの大量保持]** → 保有数無制限のため、大量生成時にメモリ消費が増加する可能性。対策: WizMapのgridは参照のみで軽量（16x16で256セル）。30x30でも900セル。実用上問題にならない
- **[save-load統合時の改修]** → タイトル画面の「前回から」「ロード」を有効化する際、GameStateの初期化フローに変更が必要。対策: new_game()と対になるload_game()メソッドの追加ポイントを明確にしておく
