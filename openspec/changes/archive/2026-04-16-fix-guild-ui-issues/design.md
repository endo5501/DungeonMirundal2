## Context

冒険者ギルド画面（`guild_menu.gd`、`character_creation.gd`）では、VBoxContainerに `set_anchors_and_offsets_preset(PRESET_CENTER)` を使用している。これはコンテナの左上隅を親の中央に配置するため、コンテンツ全体が右下に偏る。

また、キャラクター作成ウィザードのStep 1（名前入力）でEnterキーを押すと、`LineEdit.text_submitted` シグナル経由で `_on_name_submitted()` が呼ばれStep 2に遷移するが、同一フレーム内で同じキーイベントが `_unhandled_input` → `_input_step2()` にも伝播し、`ui_accept` として処理されてStep 2が即座にスキップされる。

## Goals / Non-Goals

**Goals:**
- ギルドメニューとキャラクター作成ウィザードのコンテンツを画面中央に配置する
- Step 1→Step 2遷移時のイベント伝播を防ぎ、種族選択画面を正しく表示する

**Non-Goals:**
- UI全体のリデザインやレスポンシブ対応
- 他の画面（パーティ編成、キャラクター一覧など）のレイアウト修正（ただし同じパターンを使っていれば波及的に修正される可能性あり）

## Decisions

### レイアウト修正: PRESET_CENTER → CenterContainer方式

**選択**: VBoxContainerを `CenterContainer` で包み、CenterContainerに `PRESET_FULL_RECT` を設定する。

**理由**: `PRESET_CENTER` はコントロールのpivot（左上）を中央に置くだけでサイズを考慮しない。`CenterContainer` は子のサイズを計測した上で中央に配置するため、正確なセンタリングが可能。

**代替案**:
- `PRESET_CENTER` + grow direction `BOTH` → VBoxContainerの最小サイズが確定しないとずれる場合がある
- `PRESET_FULL_RECT` + VBoxContainer の alignment → VBoxContainer自体は全画面に広がり、中身のセンタリングは別途必要
- MarginContainer で手動調整 → 画面サイズ変更時に追従しない

### イベント伝播修正: ステップ遷移ガードフラグ

**選択**: ステップ遷移直後に `_step_just_changed` フラグを立て、次の `_process` または `await get_tree().process_frame` でリセットする。フラグが立っている間は `_unhandled_input` での入力を無視する。

**理由**: `_on_name_submitted` はシグナルコールバックであり、`get_viewport().set_input_as_handled()` を呼んでも `_unhandled_input` への伝播を止められない（Godotの入力伝播モデル上、シグナル内での `set_input_as_handled` は効果がない場合がある）。フレーム単位のガードは確実で、他のステップ遷移にも汎用的に適用可能。

**代替案**:
- `call_deferred("_build_step_ui")` で遅延構築 → UIが一瞬ちらつく可能性
- `_on_name_submitted` 内で `set_input_as_handled()` → シグナルコールバック内では動作が不確実
- `_input_step2` で `_selected_race_index == -1` かつ即advance不可にする → advance()のバリデーションは既にあるが、select_race(0) が先に呼ばれるため防げない

## Risks / Trade-offs

- [Risk] CenterContainer追加でノードツリーが1段深くなる → 影響は軽微。パフォーマンスへの影響なし
- [Risk] ガードフラグが他のステップ遷移に影響する可能性 → `_process` でリセットするため1フレームのみ有効。通常のキー操作には影響しない
- [Risk] 他の画面（PartyFormation, CharacterList）も同じ `PRESET_CENTER` パターンを使用している可能性 → 本changeのスコープ外だが、同パターンがあれば別途修正が望ましい
