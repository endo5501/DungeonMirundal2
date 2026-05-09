# Dev Console

DungeonMirundal2 の開発者向けデバッグツール。本体ゲームから独立した Godot シーンとして動作し、現在は **Saves タブ** (セーブデータ編集) のみを提供する。Phase 2 以降で Items / Spells / Monsters の `.tres` 編集タブを追加する想定。

## 起動

```bash
godot --path . res://tools/dev_console/main.tscn
```

PowerShell でも同じコマンドで動く。

> **本体ゲームを閉じてから利用すること。** Dev Console は `user://saves/save_NNN.json` を直接読み書きする。本体ゲームと同時に開いた状態で保存すると競合する可能性がある(ロック制御は行っていない)。

## Saves タブで編集できるもの

- **スロット選択 / Reload / Save** — 上部の OptionButton で `user://saves/` 配下の既存セーブを選び、`Reload` でロード、`Save` で同スロットに書き戻す。
- **キャラクター単位の編集**:
  - 名前 (`character_name`)
  - 種族 (Race) / 職業 (Job) — `data/races/` と `data/jobs/` のリソースから選択
  - レベル / 累積 EXP / current_hp / max_hp / current_mp / max_mp / 6 能力値 (STR/INT/PIE/VIT/AGI/LUC)
  - 既知呪文のチェックボックス (全呪文 — 職業の `spell_progression` 範囲外も自由に追加可能)
  - 装備 6 スロット (Weapon/Armor/Helmet/Shield/Gauntlet/Accessory) — インベントリから任意のアイテムを選択
- **インベントリ単位の編集**:
  - Gold (負の値も保存可能)
  - アイテム追加 (ItemRepository から ID で選択)
  - アイテム削除 (装備中アイテムを削除すると当該キャラの装備スロットは自動でクリアされる)

## ヘルパボタン

- **Set Level** — レベル入力欄の値で `set_level(N)` を実行する。Lv1 ベースラインから本体の `level_up()` を N-1 回回して HP/MP/呪文を再構築し、累積 EXP を `job.exp_to_reach_level(N)` に揃え、HP/MP は full に戻す。本体プレイで Lv N に到達したのと同じ状態になる。
- **Rebuild Spells from Level** — 現在のレベルに対して `_rebuild_known_spells_through_level()` を実行し、既知呪文を職業の `spell_progression` から再生成する(手動で追加した呪文は失われる)。
- **Recompute HP/MP from Level** — 現在のレベルから HP/MP を再計算する。既知呪文には触れない。

## Validation について

**意図的に validation を行わない。** 戦士に魔法剣を装備、Lv1 で MP 100、職業適性外の呪文を習得 — そういった「通常では到達不能な状態」を作れるのが本ツールの目的(ゲームバランス調整やテスト用途)。誤操作からの保護より自由度を優先している。

## ファイル構造

```
tools/dev_console/
├── main.tscn / main.gd           # タブシェル
├── tabs/
│   └── saves/
│       ├── save_editor.tscn
│       ├── save_editor_panel.gd  # UI バインディング (薄)
│       └── save_session.gd       # ロジック層 (RefCounted, GUT でテスト)
└── shared/
    └── repository_picker.gd      # OptionButton ヘルパ

tests/dev_console/
└── test_save_session.gd          # SaveSession の GUT 単体テスト (33 ケース)
```

## アーキテクチャの肝

すべての mutation は `SaveSession` (RefCounted) を経由する。UI スクリプト (`save_editor_panel.gd`) はフォーム入力を SaveSession のメソッド呼び出しに変換するだけで、JSON や Character オブジェクトを直接操作しない。ロジックは `tests/dev_console/test_save_session.gd` で網羅的にテストしてあるので、本体側で `Character` / `Inventory` / `Equipment` の API が変わってもテストが先に壊れて気付ける。

## Phase 2 拡張の差し込み方

1. 新しいタブのシーンを `tools/dev_console/tabs/<name>/` に作る
2. `main.gd` の `_TabSpec` 定数に `"<TabName>": "res://tools/dev_console/tabs/<name>/<scene>.tscn"` を追加する

シェル本体 (`main.gd`) のロジック改修は不要。

## ビルド除外

`tools/` と `tests/` 配下はリリースビルドには含めない。Godot のエクスポートプリセットを作成する際、各プリセットの `Resources` タブの `Filters to exclude non-resource files/folders from export` (= `exclude_filter`) に以下を追加すること:

```
tools/*, tests/*
```

## テスト

```powershell
.\scripts\run_tests.ps1
```

`tests/dev_console/test_save_session.gd` が GUT で実行される。Pre-flight 段階で `tools/` 配下の `.gd` も parse 検証されるので、構文エラーがあれば GUT 起動前に halt する。
