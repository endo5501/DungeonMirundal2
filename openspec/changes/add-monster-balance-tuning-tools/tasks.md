# Tasks: add-monster-balance-tuning-tools

TDD 原則(CLAUDE.md)に従い、各グループとも「テスト作成 → 失敗確認 → コミット → 実装 → 全テスト通過 → コミット」の順で進める。

## 1. 曲線モデルと計算器(monster-balance-curve)

- [x] 1.1 `MonsterCurve`(定義ロード+検証)の GUT テストを作成する — 正常ロード、curve キー欠落、非正の growth、`hp_spread` 範囲外、不正 JSON→null、`errors` 収集パターン
- [x] 1.2 曲線計算器の GUT テストを作成する — 幾何級数、役割係数の乗算、省略キー=1.0、HP レンジ展開(spread・種別上書き)、四捨五入とクランプ(HP/攻撃≥1、防御/敏捷≥0)、`hp_min <= hp_max`、決定性
- [x] 1.3 overrides 優先と正規化警告の GUT テストを作成する — override が曲線と係数を無視する、非 override ステータスは曲線に従う、幾何平均が許容幅超で `warnings` に追加・処理は続行
- [x] 1.4 テストの失敗を確認しコミットする
- [x] 1.5 `src/simulation/monster_curve.gd`(RefCounted: ロード・検証・警告)と計算器を実装し、全テストを通す
- [x] 1.6 実装をコミットする

## 2. 初期バランス定義データ

- [x] 2.1 現状 `data/monsters/*.tres` の値にフィットする初期 `data/balance/monster_curve.json` を作成する(tier 曲線係数を現状値の回帰から決め、種ごとの役割係数で残差を吸収、dragon は overrides で表現)
- [x] 2.2 初期定義がロード時にエラー 0 件であることのテストを追加し、コミットする

## 3. ジェネレータ CLI(monster-tres-generator)

- [ ] 3.1 テキスト置換ロジックの GUT テストを作成する — 戦闘4値行のみ置換、他フィールド・書式のバイト単位保持、置換行欠落時はエラーで未書き込み
- [ ] 3.2 生成フローの GUT テストを作成する — 定義未掲載種のスキップ+警告(exit 0)、無効定義で exit 1・未書き込み、`--check` の差分表示・差分なし表示・ファイル無変更
- [ ] 3.3 テストの失敗を確認しコミットする
- [ ] 3.4 `src/simulation/balance_generator_cli.gd`(SceneTree エントリポイント+引数解析、exit code 0/1/2)と置換ロジックを実装し、全テストを通す
- [ ] 3.5 初期定義で `--check` を実行し、現状値との乖離が想定内(小差分)であることを確認・必要なら係数を微修正してコミットする

## 4. 計器盤 CLI(balance-dashboard)

- [ ] 4.1 ダッシュボード設定ローダの GUT テストを作成する — `party_template`/`levels`/`floors`/`runs`/`max_battles`/`master_seed` の検証、sweep 用 `knob`/`from`/`to`/`steps`/`scenarios` の検証、未知 knob パスのエラー
- [ ] 4.2 メモリ上の曲線適用(`MonsterData` 複製+戦闘4値上書きでリポジトリ再構成)の GUT テストを作成する — 元リソース・`.tres` ファイル無変更、`--balance` 省略時は現状値
- [ ] 4.3 heatmap 集計の GUT テストを作成する — `survival_rate` = MAX_BATTLES 割合、`stalled_rate` 分離、セルごとの CSV 行(level/floor/runs/survival_rate/stalled_rate/median_battles_survived)、シード導出の決定性
- [ ] 4.4 sweep 集計の GUT テストを作成する — 範囲の等間隔サンプリング(両端含む)、knob 値×シナリオごとの CSV 行、`--balance` 必須(なければ exit 2)
- [ ] 4.5 テストの失敗を確認しコミットする
- [ ] 4.6 `src/simulation/balance_dashboard_cli.gd`(モード分岐・引数解析・コンソールグリッド表示)と設定ローダ・集計を実装し、全テストを通す
- [ ] 4.7 サンプル設定 `data/balance/dashboard_config.json`(fighter×3/priest/mage/thief、levels/floors/runs のデフォルト)を追加する
- [ ] 4.8 実装をコミットする

## 5. 統合確認と仕上げ

- [ ] 5.1 `godot --headless` で heatmap モードを実機実行し、コンソールグリッドと CSV が出力されること・`data/monsters/` が無変更であることを確認する
- [ ] 5.2 sweep モード(例: `curves.attack.growth` を 1.4→2.0)を実機実行し、生存率が単調に応答することを目視確認する
- [ ] 5.3 同一入力での再実行で CSV がバイト一致することを確認する
- [ ] 5.4 使い方(check→生成→git diff の運用、粗い設定→精密設定の順で見る運用)を README またはツールの usage 出力に記載する
- [ ] 5.5 全テストを実行し、変更をコミットする
