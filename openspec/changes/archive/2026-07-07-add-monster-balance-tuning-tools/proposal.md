# Proposal: add-monster-balance-tuning-tools

## Why

モンスターの戦闘パラメータ(HP・攻撃・防御・敏捷)は現状すべて「とりあえず」の手置き値で、tier 2→3 で戦闘力がほぼ成長しない一方 tier 4→5 で急激に跳ねるなどの歪みがある。遠征シミュレータで現状把握はできるようになったが、調整には「値を変えて→シミュレーションして→効果を見る」の反復を手作業で回すしかなく、パラメータ数が多すぎて実用的でない。tier 成長曲線 × 種の役割係数という少数ノブへの定式化と、その効果を一望できる計器盤ツールがあれば、調整の反復が現実的なコストになり、新モンスター追加も「tier と役割係数を書くだけ」になる。

## What Changes

- モンスター戦闘パラメータを「tier 成長曲線 × 種の役割係数」で定式化するバランス定義ファイル(`data/balance/monster_curve.json`)を追加する
  - tier 曲線: HP/攻撃/防御/敏捷それぞれ `base × growth^(tier-1)` の幾何級数(ノブは8個)
  - 役割係数: 種ごとの個性(例: bat = 脆いが速い)を曲線値への乗数で表現
  - 例外オーバーライド: dragon のようなボス格は曲線を無視した明示値を許す
  - 役割係数の幾何平均が 1.0 から大きく外れた場合は警告(強制はしない)
- 曲線定義から `data/monsters/*.tres` の戦闘4値(`max_hp_min/max`, `attack`, `defense`, `agility`)を再生成するジェネレータ CLI を追加する(案B: ゲーム本体は無変更、確定値を `.tres` に焼き込み diff で確認できる)
  - `experience` / `gold` / `resists` / `known_spells` / `battle_texture` / `tier` / 隊列・射程・MP など戦闘4値以外のフィールドは現状値を保持する
- バランス調整用の計器盤 CLI を追加する(`godot --headless` 実行、`.tres` は書き換えずメモリ上で曲線を適用)
  - **heatmap モード**: 標準パーティ(レベル別)× フロアのグリッドで各セルの生存率(`max_battles` 戦を全滅せず完走した run の割合)を一括算出し、コンソール表と CSV で出力
  - **sweep モード**: 曲線ノブ1個を指定範囲で刻み、選択シナリオ群の生存率がどう動くかを CSV で出力
  - 標準パーティ構成(デフォルト: fighter×3, priest, mage, thief)・レベル刻み・フロア範囲・runs 数は設定ファイルで変更可能
- スコープ外: `experience` / `gold` の曲線化、プレイヤー側パラメータ(HP/MP 成長・装備)の調整、自動最適化(根探し・座標降下等)、エンカウントテーブルの調整

## Capabilities

### New Capabilities

- `monster-balance-curve`: tier 成長曲線+役割係数+例外オーバーライドのバランス定義(JSON スキーマ、曲線→戦闘4値の計算器、検証と正規化警告)
- `monster-tres-generator`: 曲線定義から `data/monsters/*.tres` の戦闘4値を再生成するヘッドレス CLI(その他フィールドの保持を含む)
- `balance-dashboard`: 生存率ヒートマップとノブ感度スイープを出力するヘッドレス計器盤 CLI(標準パーティ設定を含む)

### Modified Capabilities

(なし — `monster-data` の要求はフィールド構造・tier 割当・resists 等を規定するが個々の戦闘数値は規定しておらず、ジェネレータは戦闘4値の書き換えのみ行う。`expedition-simulator` / `party-ai` / `simulation-report` は既存 API の利用者として振る舞う)

## Impact

- 新規コード: `src/simulation/`(または `src/balance/`)配下に曲線モデル・計算器・ジェネレータ CLI・計器盤 CLI・設定ローダ
- 新規データ: `data/balance/monster_curve.json`(現状の `.tres` 値に近い係数で初期化)、計器盤用設定ファイル
- 既存コードへの変更: 原則なし。`ExpeditionRunner.run_expedition` が `monster_repo` を引数で受ける現設計をそのまま利用し、メモリ上で差し替えた `MonsterData` を渡す
- 既存データへの変更: ジェネレータ実行時のみ `data/monsters/*.tres` の戦闘4値が更新される(本 change ではツール整備までを行い、実際の数値確定は運用フェーズ)
- テスト: GUT による曲線計算器・ジェネレータの保持動作・ヒートマップ/スイープ集計のユニットテスト
