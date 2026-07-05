# Proposal: add-combat-expedition-simulator

## Why

ゲームバランス(戦闘テンポ・フロア難易度・資源設計)の調整には「あるパーティ構成が回復なし補給なしで何戦・何ターン耐えられるか」を定量的に測る手段が必要だが、現状は手動プレイでしか確認できず、乱数のブレもあり再現性のある評価ができない。`TurnEngine` は UI から分離された純ロジックなので、ヘッドレスで連戦を回す遠征シミュレータを低コストで構築できる。

## What Changes

- ヘッドレス実行可能な遠征シミュレータを追加する(`godot --headless --script` で起動)
- 1 回の遠征 (run) = パーティ生成 → エンカウント生成 → 戦闘 → 戦闘間回復 → 次戦闘、を全滅または上限戦闘数まで繰り返すループ
- パーティ側の自動戦闘 AI(PartyAi)を新設する:
  - 僧侶系: HP 閾値以下の味方がいて MP があれば回復呪文(不足 HP 量で heal/heala 等を選択)、いなければ攻撃
  - 魔法使い系: 発動条件(ノブ)を満たせば攻撃呪文(敵複数なら全体、単体なら単体)、満たさなければ通常攻撃
  - 前衛: 生存中の敵への通常攻撃
  - MP 温存条件・回復閾値はパラメータ(ノブ)として設定可能にする
- 戦闘間回復: MP が許す限り `OUTSIDE_OK` スコープの回復呪文を最も傷ついたメンバーに使用する
- モンスター編成は「固定パターンの繰り返し」と「EncounterTableData からのランダム生成」の両対応
- N シード実行して戦闘数・総ターン数・戦闘ごとの HP/MP 残量を集計し、中央値/p10/p90 をコンソール表で出力、戦闘ごとの推移を CSV で出力
- スコープ外: アイテム使用、逃走判断、隊列変更、歩行中の毒ティック、レベルアップを跨ぐ長期シミュレーション最適化

## Capabilities

### New Capabilities

- `party-ai`: パーティメンバーの戦闘コマンドを自動選択するポリシー(回復閾値・MP 温存条件のノブを含む)
- `expedition-simulator`: 連戦ループ・戦闘間回復・エンカウント供給・メトリクス記録を統括する遠征シミュレーション本体
- `simulation-report`: N シードの集計(中央値/p10/p90)、コンソール表出力、CSV 出力

### Modified Capabilities

(なし — 既存の `combat-engine` / `monster-ai` / `encounter-detection` の要求は変更しない。シミュレータは既存 API の利用者として振る舞う)

## Impact

- 新規コード: `src/simulation/`(または `tools/simulation/`)配下に PartyAi・遠征ループ・レポート出力・ヘッドレスエントリポイント
- 既存コードへの変更: 原則なし。`TurnEngine.submit_command` / `resolve_turn`、`EncounterManager.generate`、`Character` / `PartyCombatant`、`SpellRepository` / `DataLoader` を読み取り利用するのみ
- テスト: GUT による PartyAi・遠征ループ・集計のユニットテストを追加
- 実行環境: CI やローカルで `godot --headless` により実行可能(ゲーム本体のビルドには影響しない)
