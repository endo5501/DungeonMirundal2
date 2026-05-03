## Context

監査の Tier 6 quick win は、それぞれ 1 ファイル数行〜十数行の改修で、リスクが低いが放置すると小さなノイズが残る。

- **F010**: `DungeonScene._dungeon_view` は使われない fallback。本来は誰もが `DungeonScreen.refresh()` で `visible_cells` を渡す。
- **F015**: `TempleScreen.revive` で `gold < cost` を early return → `spend_gold(cost)` で再チェック → 同じエラー文言。一方を消せる。
- **F021**: `mini(8, map_size / 3 + 1) as int` の `as int` は GDScript の整数除算結果に対して redundant。
- **F026**: `first_plan.md` は project inception のスナップショット。仕様は `openspec/specs/` に移行済みなので明記する。
- **F027**: `Equipment.equip` の slot match + job allowed check は `can_equip` と同じ。`equip` 内で `can_equip` を呼んで FailReason を分岐することで重複を解消できる。
- **F032**: `data/items/potion.tres` と `magic_potion.tres` の命名規約不一致 → `healing_potion.tres` に統一。
- **F040**: `JSON.stringify(data, "\t")` で改行+タブのインデントが入る。30x30 セルマップで 9KB→4KB 程度に圧縮可能。
- **F042**: README の "Godot Engine 4.6+" 表記が、project.godot の "4.6" 厳密一致と整合しない。
- **F043**: `item_use_context.gd` は effects と conditions 両方が使うのに `conditions/` の下にいる。
- **F045**: `town_screen.gd:select_item` の `match 0:..1:..` は esc_menu のように `MAIN_IDX_*` 定数化したほうが読みやすい(既に partial 適用済みなら確認のみ)。

## Goals / Non-Goals

**Goals:**
- 各 quick win を独立した commit で適用
- 既存テストを通したまま、最小差分で改修
- F032 のリネーム互換性をどう扱うか(エイリアス機構 vs README 明記)を判断
- 監査の C11 範囲のタスクを全て解消

**Non-Goals:**
- 性能改善(F040 を除く、単体としての性能は誤差レベル)
- 大規模リファクタ
- 新機能追加
- F025 (status effects) — 別 feature change
- F024 (multi-floor) — 別 feature change

## Decisions

### Decision 1: F032 のセーブ互換性は README 明記方式

**選択**: `ItemRepository` にエイリアス機構を追加するのではなく、`README.md` で「アイテム名変更の影響で、potion を持つ古いセーブは復元時に該当アイテムが消える」旨を明記する。

**理由**:
- エイリアス機構は将来も残り続けるノイズ(マイグレーション完了後も削除しにくい)
- 個人プロジェクトで既存セーブの保護優先度は低い
- ユーザは README を読めばわかる

**代替案**: `ItemRepository.find` で `&"potion"` を `&"healing_potion"` にエイリアス → 採用しない。

### Decision 2: F040 の JSON フォーマット変更は load 後方互換のみを保証

**選択**: `JSON.stringify(data, "")` (インデントなし)に変更。`JSON.parse` は改行・タブ含むファイルも問題なくパースできるので、既存セーブのロードに影響なし。

**理由**:
- 過去のセーブも問題なくロードできる(parser は柔軟)
- 新しいセーブはコンパクトになる
- 開発中に diff したい場合は手動で `jq` 通すなどで対応

### Decision 3: F043 の移動はファイル参照を更新

**選択**: `src/items/conditions/item_use_context.gd` を `src/items/item_use_context.gd` に `git mv`、同様に `item_effect_result.gd` を移動。すべての `class_name ItemUseContext` 参照は class_name 経由なのでパス変更の影響なし。`.gd.uid` ファイルも一緒に移動する必要がある。

**理由**:
- class_name は flat namespace なので、ファイル位置を変えても import 不要
- `.uid` は Godot 4.x の Resource UUID、移動が必要

### Decision 4: F015 / F027 / F045 はシンプル

**選択**: 各々が単純な refactor で、既存テストが通ればよい。F045 は `town_screen.gd` を grep して `match index:` 内が定数で参照されているか確認、不足なら定数化する。

### Decision 5: 全 quick win を 1 commit ずつ + 最後に統合テスト

**選択**: 各 finding ごとに独立した commit を作り、最後にフルテストスイート + 目視確認。レビュー単位は finding ごと。

**理由**:
- 個別 revert が可能
- レビュアーが finding と diff の対応を把握しやすい

## Risks / Trade-offs

- **[F032 のセーブ破壊]** 既存プレイヤー(=主に開発者自身)に影響 → 開発中なので許容。README に明記。
- **[F040 のセーブサイズ削減]** 既存セーブのロードには影響しないが、開発中の diff が読みにくくなる → デバッグ時のみインデントを戻す環境変数 / 設定を入れる案もあったが、本 change では採用しない(必要なら別で)。
- **[F010 の DungeonView 削除]** 万が一 `visible_cells` 空で呼ばれるパスがあったら crash → `DungeonScreen.refresh()` の呼び出し元を grep で確認、空配列を渡す経路がないことを担保する。
- **[F043 の移動]** Godot エディタで開いてから移動する必要がある(`.uid` の整合)。コマンドラインの `git mv` だけで OK か実装時確認。
- **[F042 の README 修正]** `4.6+` を厳密に維持したいなら `4.7` で動作確認するか、文言を `4.6.x` に絞る → どちらでも OK だが、簡単なのは後者。
- **[F045 が既に適用済みの可能性]** 監査時点と現在で差分があるかもしれない → タスクで grep 確認してから差分のみ修正する。
