# Design: add-monster-balance-tuning-tools

## Context

モンスターの戦闘4値(HP レンジ・攻撃・防御・敏捷)は `data/monsters/*.tres` に手置きされた「とりあえず」の値で、tier 2→3 の停滞や tier 4→5 の急騰といった歪みがある。前 change で導入した遠征シミュレータ(`ExpeditionRunner` / `expedition_cli`)は、`monster_repo` を引数注入で受け取る設計になっており、`.tres` を書き換えずメモリ上のパラメータ差し替えで評価を回せる下地がある。

探索モードでの議論により以下が合意済み:

- モンスターは tier 成長式に従うと決めてよい(新モンスター追加の容易化も狙い)
- プレイヤー側パラメータは所与(今回は動かさない)
- 目指すのは自動最適化ではなく「調整を助ける計器盤」
- 案B(ジェネレータ式)を採用: ゲーム本体は無変更、確定値を `.tres` に焼き込む
- 標準パーティのデフォルトは fighter×3, priest, mage, thief(構成は設定で変更可能)
- 経験値・ゴールドはスコープ外
- 役割係数の正規化は警告に留める(強制しない)

## Goals / Non-Goals

**Goals:**

- モンスター戦闘4値を少数ノブ(tier 曲線8個+種ごとの役割係数)へ定式化する
- 曲線定義 → `.tres` 再生成のジェネレータ CLI(戦闘4値以外は現状維持)
- 生存率ヒートマップ(パーティ Lv × フロア)とノブ感度スイープを出力する計器盤 CLI
- 計器盤はメモリ上で曲線を適用し、`.tres` に一切触れない
- 初期の曲線係数は現状 `.tres` 値の近似として与え、ジェネレータをいきなり走らせても激変しないようにする

**Non-Goals:**

- 自動最適化(根探し・座標降下・CMA-ES 等)— 将来スイープ結果の上に足せる
- `experience` / `gold` の曲線化、エンカウントテーブル(`tier_weights` 等)の調整
- プレイヤー側(HP/MP 成長・装備)の調整、ゲーム本体コードの変更
- GUI。出力はコンソール表と CSV のみ

## Decisions

### D1: 定式化 — stat = tier曲線 × 役割係数、曲線は幾何級数

`stat(種) = curve_stat(tier) × role_modifier(種, stat)`、`curve_stat(t) = base × growth^(t-1)`。

- 曲線ノブは hp/attack/defense/agility × (base, growth) の8個。現状値の tier 間成長率はおおむね 1.6〜1.8 の幾何級数に乗っており、指数形が現実に合う
- 役割係数は種の個性(bat=脆いが速い等)を乗数で保持し、tier 内の相対関係を守る
- HP はレンジなので曲線は中央値 `hp_mid` を与え、`hp_min = round(hp_mid × (1 - hp_spread))`, `hp_max = round(hp_mid × (1 + hp_spread))` で展開する。`hp_spread` はグローバルノブ、種ごとの上書きも許す
- 丸めは四捨五入。HP・攻撃は最小 1、防御・敏捷は最小 0 にクランプ(現状 bat の防御 0 を表現可能に)

代替案: 種ごとの生値を直接探索(50 次元超で非現実的、tier 間の単調性も保証されない)、線形曲線(現状値の成長率に合わず、深層で平坦になりすぎる)。

### D2: 案B(ジェネレータ式)— ゲーム本体は無変更

曲線はツール層(ジェネレータ・計器盤)だけが解釈し、ゲームは従来通り `.tres` の生値を読む。

- 影響範囲がシミュレーション/ツール層で閉じる
- 生値が `.tres` に残るので git diff で変更を確認でき、いつでも手動で例外を上書きできる
- 計器盤はどのみちメモリ上で曲線→ステータス計算をするため、同じ計算器を書き出しに使うだけ

代替案A(ランタイム式: ゲーム起動時に曲線から計算)は、ゲーム本体への変更・セーブ互換・`.tres` と実効値の乖離という追加リスクに見合う利点がない。

### D3: バランス定義は `data/balance/monster_curve.json`(JSON、Godot エディタ不要)

```json
{
  "curves": {
    "hp":      { "base": 6.0, "growth": 1.75 },
    "attack":  { "base": 2.5, "growth": 1.6 },
    "defense": { "base": 0.8, "growth": 1.7 },
    "agility": { "base": 4.0, "growth": 1.35 }
  },
  "hp_spread": 0.25,
  "species": {
    "bat":      { "hp": 0.6, "attack": 0.8, "agility": 2.0 },
    "skeleton": { "hp": 1.2, "attack": 1.1, "agility": 0.9 }
  },
  "overrides": {
    "dragon": { "attack": 25 }
  }
}
```

- 役割係数は省略キー=1.0。`overrides` は該当ステータスだけ曲線を完全に無視した明示値(ボス格用)
- JSON を選ぶ理由: 手編集・diff・外部ツール(スプレッドシート等)との往復が容易。`ExpeditionConfig` と同じ「エラーを配列に集めて呼び出し側が判断」の検証パターンを踏襲する
- ロードは `RefCounted` の純ロジック(`MonsterCurve` + 計算器)にして GUT で単体テスト可能にする

### D4: 役割係数の正規化は警告のみ

種ごとの役割係数(hp/attack/defense/agility、省略は 1.0)の幾何平均が 1.0 ± 許容幅(既定 15%)を外れたら警告を出すが、処理は続行する。tier 内の強さを揃える指針を示しつつ、意図的な逸脱(強めの tier 内エリート等)の自由度を残す。

### D5: ジェネレータはテキストレベルで `.tres` の4値だけ書き換える

`ResourceSaver.save` による再シリアライズは ext_resource の並びやフォーマットを書き換えるリスクがあるため使わない。既存 `.tres` を文字列として読み、`max_hp_min` / `max_hp_max` / `attack` / `defense` / `agility` の行だけを正規表現で置換して書き戻す。

- 他フィールド(`experience`, `gold_*`, `resists`, `known_spells`, `battle_texture`, `tier`, `default_row`, `attack_range`, `max_mp_*`)はバイト単位で不変 → diff が戦闘4値だけになる
- `--check`(dry-run)モードで「書き込まずに変更予定の一覧を表示」を必須機能とする。運用は「check で diff 確認 → 本実行 → git diff で最終確認」
- バランス定義に載っていない種はスキップして警告(黙って古い値が残る事故を防ぐため、警告は必ず出す)

### D6: 計器盤はメモリ上で `MonsterData` を複製・差し替え

`balance_dashboard_cli.gd`(SceneTree スクリプト)がリポジトリを一度だけロードし、曲線適用済みの `MonsterData` 複製(`duplicate()` + 戦闘4値上書き)で `MonsterRepository` を組み直して `ExpeditionRunner.run_expedition` に注入する。Godot 起動は1回で済み、スイープの数百評価が現実的になる。

- シード導出は expedition_cli と同じ `hash(str(master_seed) + ":" + str(run_index))` を踏襲し再現性を保つ。セル/ステップごとに独立した run 系列を張る(セル間で系列を共有しない)
- **heatmap モード**: (パーティ Lv リスト)×(フロアリスト)の各セルで N runs 実行し、生存率=`end_cause == "MAX_BATTLES"` の run 割合を算出。`STALLED` は生存に数えず別カウントで表示(ダレ戦闘の兆候として見えるように)
- **sweep モード**: ノブ1個(例: `curves.attack.growth`)を min..max を steps 刻みで動かし、指定シナリオ(Lv×フロア)ごとの生存率を出力
- 出力はコンソール表(heatmap はグリッド表示)+ CSV。CSV は既存 `SimulationCsvWriter` の方針(ヘッダ+行)に合わせる

### D7: 計器盤設定は JSON、標準パーティはテンプレート+レベル展開

```json
{
  "runs": 100, "max_battles": 10, "master_seed": 12345,
  "party_template": [
    { "race": "human", "job": "fighter", "row": "front" },
    { "race": "human", "job": "fighter", "row": "front" },
    { "race": "human", "job": "fighter", "row": "front" },
    { "race": "human", "job": "priest",  "row": "back"  },
    { "race": "human", "job": "mage",    "row": "back"  },
    { "race": "hobbit", "job": "thief",  "row": "back"  }
  ],
  "levels": [2, 4, 6, 8, 10],
  "floors": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
}
```

テンプレートの全員に同一レベルを適用して `PartyFactory.build` に渡す(レベルだけがセル間で変わる)。runs・levels・floors を絞れるので「粗く全体 → 気になるセルだけ精密に」の運用ができる。パーティ生成は既存 `PartyFactory` を再利用し、race/job の検証もそこに委ねる。

## Risks / Trade-offs

- [ヒートマップの計算量が大きい(例: 5Lv×12階×100runs×10戦)] → levels/floors/runs を設定で絞れる。リポジトリは一度だけロード。まず粗い設定で全体を見る運用を README/usage に明記
- [曲線の初期係数が現状値とずれ、ジェネレータ実行で意図せぬバランス激変] → 初期 `monster_curve.json` は現状 `.tres` 値へのフィットとして作成し、`--check` の diff が小さいことをテストではなく初期値作成時に確認する
- [正規表現での `.tres` 書き換えがフォーマット差異で失敗] → 対象は自前管理の 12 ファイルで書式が均一。置換対象行が見つからない場合はそのファイルをエラーにして書き込まない(部分書き込みしない)
- [`STALLED` の扱いで生存率の解釈がぶれる] → 生存率とは別列で stalled 率を常に併記し、解釈を一意にする
- [役割係数と overrides の二重指定の混乱] → overrides が最優先(曲線・係数とも無視)と仕様で固定。計器盤・ジェネレータで同一の計算器クラスを共有し解釈差をなくす

## Migration Plan

1. 曲線モデル+計算器(純ロジック)を TDD で実装
2. 現状 `.tres` 値にフィットした初期 `monster_curve.json` を作成し、`--check` で乖離を確認
3. ジェネレータ CLI → 計器盤 CLI の順に実装(計器盤は計算器とシミュレータの合流点)
4. ロールバック: ジェネレータの変更は git で戻せる。ゲーム本体は無変更のためリリースリスクなし

## Open Questions

- 敏捷の曲線が戦闘結果(行動順)にどの程度効くかは未計測 — 最初のスイープ対象として確認する(設計には影響しない)
- 種ごとの `hp_spread` 上書きを初期実装に含めるかは実装時判断(スキーマ上は許容しておく)
