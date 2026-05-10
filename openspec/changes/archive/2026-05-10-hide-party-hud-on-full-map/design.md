## Context

`FullMapOverlay` は `DungeonScreen` 配下の通常 Control レイヤーに置かれる一方、`PartyHud` は autoload の `CanvasLayer` で常に最前面で描画される。結果、フルマップを開いても画面下部の HUD が地図を覆ってしまい、地図の俯瞰機能の意味が損なわれている。

既存の `FullMapOverlay` は同種の問題を `MinimapDisplay` (DungeonScreen 内の Control) について既に解決している:
- `setup(_, _, _, _, minimap_display)` で対象 Control を依存性注入で受け取る
- `open()` / `close()` で `_minimap_display.visible` を反転
- テストはスタブ Control を渡して挙動を検証

この既存パターンが「対称的な空間」を提供しているので、新しい挙動を追加するのではなく、同じ空間にもう一本枝を生やす形で `PartyHud` を扱う。

## Goals / Non-Goals

**Goals:**
- フルマップ表示中はパーティHUDを非表示にし、フルマップを閉じたら自動で復帰させる
- 既存の `MinimapDisplay` 制御パターン (DI + open/close で `.visible` 反転) との対称性を保つ
- テストで挙動を検証可能にする(autoload 直接参照ではなく DI 経由のスタブテスト)
- 既存の `FullMapOverlay.setup()` 呼び出しサイトの後方互換を保つ(新規引数はデフォルト null)

**Non-Goals:**
- フルマップ表示中の戦闘起動・状態保存・複数オーバーレイの相互作用の整理 (フルマップ表示中は移動入力ブロックでエンカウント発生不可のため、考慮不要)
- ESC メニュー表示時の HUD 挙動の変更 (現状の「ESC メニュー中は HUD 据え置き」を維持)
- `PartyHud` 自身の API 追加・拡張(既存の `show_hud()` / `hide_hud()` も今回は呼ばない、`.visible` 直接操作で十分)
- 一般化された「集中モード」共通機構の導入(対象が minimap と HUD の2つだけなので過剰設計)

## Decisions

### Decision 1: 依存性注入(DI)で `CanvasLayer` 参照を渡す

`FullMapOverlay.setup()` に `party_hud_layer: CanvasLayer = null` を末尾追加し、`DungeonScreen` から `PartyHud` (autoload) を渡す。

**Rationale:**
- 既存の `_minimap_display` パターンと完全に対称(同じファイル内で一貫性を保てる)
- テストでスタブ `CanvasLayer.new()` を注入できる(既存 `_minimap_stub: Control` と同じ手法)
- `FullMapOverlay` がグローバル autoload `PartyHud` を直接参照しなくて済む(疎結合)

**Alternatives considered:**
- (a) `PartyHud.hide_hud()` / `show_hud()` を直接呼ぶ — 配線は1行で済むが、`FullMapOverlay` が autoload に直接依存する形になりテストしづらい(autoload 全体を起動する必要がある、または静的にモックする必要)。一貫性も損なわれる
- (b) シグナル経由 (`overlay.opened` / `overlay.closed` を発火し `PartyHud` 側で listen) — 結合は最も疎になるが、既存の minimap パターンとずれて非対称になる。今回の規模では過剰

### Decision 2: 引数のデフォルト値を null とし、null チェックを既存パターンに合わせる

`open()` / `close()` 内で `if _party_hud_layer != null:` チェックしてから `.visible` を反転。

**Rationale:**
- 既存の `_minimap_display` も同じパターン (line 97, 103) なので踏襲
- 一部のテスト/シナリオで HUD を渡さない場合(将来的な単体テスト等)に壊れない
- `setup()` を引数なしで呼ばれることは現在ないが、デフォルト引数で後方互換を担保

### Decision 3: 型は `CanvasLayer` を使う

`PartyHud` autoload は `extends CanvasLayer` なので、フィールド型・引数型として `CanvasLayer` を採用する。

**Rationale:**
- production の実体型と一致
- `CanvasLayer` は `visible` プロパティを持つので `.visible` 直接操作が可能
- テストでは `CanvasLayer.new()` をスタブとして使える

**Alternatives considered:**
- (a) `Node` で受ける(より抽象的) — 緩いが、`visible` プロパティを持たない Node を渡された場合に実行時エラー。型で守った方が安全
- (b) `Control` で受ける(minimap と揃える) — `PartyHud` は `CanvasLayer` なので不整合。既存の minimap が `Control` なのは minimap 自体が `Control` だから

### Decision 4: テストは既存の minimap visibility テスト 3件と対称にする

`test_open_hides_minimap`, `test_close_restores_minimap`, `test_close_via_esc_restores_minimap` の3つに対し、それぞれ `_party_hud` 版を追加する。

**Rationale:**
- 既存テストとレビューア視点で対称性が明確
- minimap 側のリグレッションを並行して検出できる
- `_make_overlay()` ヘルパーに stub 追加で済むため、既存テスト全体への影響は最小

## Risks / Trade-offs

- **[Risk]** フルマップ表示中に `PartyHud.show_hud()` / `hide_hud()` が外部から呼ばれた場合、`FullMapOverlay.close()` 時に強制的に `visible = true` にしてしまう
  → **Mitigation**: 現状そのような呼び出しパスは存在しない(`main.gd` のスクリーン遷移はフルマップ閉じる前に走らないし、フルマップ表示中は移動・ダイアログ起動も全てブロックされる)。前提が壊れた時に備えて、`design.md` のこのリスクを将来の拡張時の警告として残す
- **[Risk]** `CanvasLayer` を `add_child_autofree` でテストツリーに足した際、レンダリング側の副作用が出る
  → **Mitigation**: テストは `.visible` プロパティのみ検証するので、レンダリングは関係なし。GUT のヘッドレス実行で問題は発生しない想定
- **[Trade-off]** `setup()` の引数が 6 個に増える(やや多い)
  → 既存パターンの素直な拡張で、可読性は維持される。将来 7 個目以降が必要になった時点で options struct への refactor を検討
