## Context

現在のゲームにはゲーム中に呼び出せるメニュー機能がない。ダンジョン画面ではESCキーで帰還確認ダイアログが表示されるが、パーティ情報の確認やゲーム終了といった共通操作は存在しない。

画面遷移は `main.gd` が一元管理しており、各画面（TownScreen, DungeonScreen等）は `_switch_screen()` で切り替えられる。各画面は `Control` ノードとしてMainの子に追加され、入力は `_unhandled_input()` で処理されている。

メニューUI操作には既存の `CursorMenu` ユーティリティが使用可能。

## Goals / Non-Goals

**Goals:**
- ESCキーでどの画面からでも呼び出せるオーバーレイメニュー
- パーティメンバーのステータス確認
- ゲームを終了してタイトル画面に戻る機能
- セーブ/ロード・アイテム・装備・設定のメニュー項目をdisabled状態で配置

**Non-Goals:**
- セーブ/ロードの実ロジック（save-load changeで有効化）
- アイテム操作・装備管理の実ロジック（items-and-economy changeで有効化）
- 設定項目の詳細（音量、キー設定等）

## Decisions

### 1. ESCメニューの配置場所: main.gdが管理するCanvasLayerオーバーレイ

ESCメニューを `main.gd` の子として `CanvasLayer`（layer=10）上に配置する。各画面の上に重なるオーバーレイとして表示し、メニュー表示中は背面の画面への入力を遮断する。

**代替案:**
- 各画面が個別にESCメニューを管理 → 画面ごとに重複コードが発生するため却下
- GameStateにメニュー機能を持たせる → UIをAutoloadに持たせるのは責務違反

### 2. ESCキー入力の制御方式: main.gdの `_unhandled_input()` で捕捉

Godot 4の `_unhandled_input()` は子ノードから親ノードの順に伝播する。この仕組みを活用する:

1. 子画面（DungeonScreen等）が自身のダイアログ操作でESCを消費した場合 → main.gdには到達しない
2. 子画面がESCを消費しなかった場合 → main.gdの `_unhandled_input()` でESCメニューを開く
3. ESCメニュー表示中にESCが押された場合 → メニューを閉じる

これにより、既存の画面内ダイアログ（帰還確認等）との競合を自然に回避できる。

**DungeonScreenの変更:** 現在ESCキーで帰還確認ダイアログを直接開いているが、この機能はESCメニューの「終了」に移行する。DungeonScreenのESCキー処理はダイアログを閉じる操作のみに限定する。

**代替案:**
- `_input()` でESCを先に捕捉 → 子画面のダイアログ操作が阻害されるため却下
- InputMapにカスタムアクション定義 → ESCキー1つだけなので過剰

### 3. メニュー構成: 単一のEscMenuクラスにサブパネルを内包

```
EscMenu (CanvasLayer, layer=10)
└── FullScreenOverlay (ColorRect, 半透明背景)
    └── MainPanel (PanelContainer)
        ├── MainMenuView (VBoxContainer)
        │   ├── "パーティ"
        │   ├── "ゲームを保存" (disabled)
        │   ├── "ゲームをロード" (disabled)
        │   ├── "設定" (disabled)
        │   └── "終了"
        ├── PartyMenuView (VBoxContainer)
        │   ├── "ステータス"
        │   ├── "アイテム" (disabled)
        │   └── "装備" (disabled)
        └── StatusView (VBoxContainer)
            └── キャラクター詳細表示
```

メニュー遷移はビューの表示/非表示で切り替える。CursorMenuをビューごとに持ち、各ビューでのカーソル操作・選択を管理する。ESCキーまたは「戻る」操作でサブメニューからメインメニューに戻る。

### 4. パーティステータス表示: GameState.guildから直接参照

`GameState.guild.get_all_characters()` と `guild.get_character_at(row, position)` を使い、パーティに編成されたキャラクターの詳細情報を表示する。

表示項目:
- キャラクター名、種族名、職業名
- レベル
- HP / MP（現在値 / 最大値）
- 基本ステータス（STR, INT, PIE, VIT, AGI, LUC）

パーティ編成順（前列3枠 + 後列3枠）でリスト表示する。

### 5. 「終了」の動作: コンテキストによらずタイトル画面に戻る

「終了」選択時は確認ダイアログを表示し、承認でタイトル画面に遷移する。ダンジョン内でも町でも同じ動作とする。

ESCメニューからは `quit_to_title` シグナルを発行し、`main.gd` がタイトル画面への遷移を実行する。ダンジョンからの直接帰還（帰還タイルでEnter）は既存のフローを維持する。

### 6. メニュー表示中のゲーム状態: 入力遮断のみ

`get_tree().paused` は使用しない。メニュー表示中はフルスクリーンのColorRectが入力を遮断し、メニュー自身が入力を処理する。現在のゲームにはリアルタイム処理（アニメーション等）がないため、一時停止は不要。

**代替案:**
- `SceneTree.paused` を使用 → 将来的にアニメーション追加時に検討。現時点では不要な複雑さ

## Risks / Trade-offs

- **DungeonScreenのESC動作変更** → 既存の帰還確認フローの変更が必要。ESCメニューの「終了」から帰還確認に繋がるため、ユーザー操作が1ステップ増える。ただしメニューからの操作は直感的であり、許容範囲。
- **将来のリアルタイム要素追加時** → メニュー中のポーズ処理が必要になる可能性がある。現時点では入力遮断のみで十分だが、将来必要に応じて `SceneTree.paused` への移行を検討する。
