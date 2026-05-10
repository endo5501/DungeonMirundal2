## Why

ESC > パーティ > ステータス画面は現在、編成中メンバー全員を縦に並べて HP/MP・基礎ステータス・状態のみを表示する閲覧画面で、経験値・装備・習得呪文といった重要情報が欠けており、職業別のポートレイトも表示されていない。さらにダンジョン中に同画面を開いた状態でも WASD などの移動キーがダンジョン側に届いてしまい、`esc-menu-overlay` 仕様の「メニュー表示中はゲーム入力を遮断する」要件が事実上満たされていない。本変更でステータス画面を 2 ペイン構成（左: メンバーリスト+カーソル、右: 選択キャラの詳細）にリデザインし、同時に EscMenu の入力遮断を実装で担保する。

## What Changes

- パーティステータス画面を 2 ペイン構成にリデザインする:
  - 左ペイン: パーティ編成済みメンバー（前列 0-2 → 後列 0-2 の順）をカーソル付きリストで表示。↑↓ で選択、ESC で戻る、Enter は閲覧専用のため何もしない。
  - 右ペイン: カーソルが当たっているキャラクターの詳細を表示。表示項目はジョブポートレイト画像、名前/種族/職/Lv、状態、HP（現在/最大）、MP（現在/最大）、経験値（現在値/次レベル必要値、最大レベル時は MAX）、基礎ステータス 6 項目、装備 6 スロット、習得呪文（日本語表示名）。
  - 右ペインは `ScrollContainer` でクリップし、装備・呪文が増えても破綻しないこと。
  - ジョブポートレイトは `party_member_panel.gd` の `JOB_PORTRAIT_PATHS` および `get_job_portrait_texture` を共通モジュール (`src/ui/job_portrait.gd`) に昇格させて再利用する。
- ステータス画面用の Control を `src/esc_menu/views/status_view.gd` に新規分離し、`esc_menu.gd` からは visibility 切替と委譲だけを行う（既存 flow と同じ構造）。
- **BREAKING (UI 構造)**: 旧来の「全メンバーを縦積みする」レイアウトと `_build_character_entry`/`_refresh_status_view` を削除する。`tests/esc_menu/test_esc_menu_status.gd` の構造前提（`_status_container.get_child_count() > 2` など）も新仕様に合わせて置き換える。
- `EscMenu._unhandled_input` を、`visible == true` の間は **全 InputEvent を `set_input_as_handled()` で消費する** モーダル動作に変更する（B 案）。これにより `move_forward`/`move_back`/`strafe_*`/`turn_*`/`toggle_full_map` などのアクションが DungeonScreen に漏れ、画面背後でプレイヤーが移動してしまう不具合を解消する。
- スコープ外（明示）: ギルド全員の閲覧、ステータス画面からの装備変更、職業 ID 以外のポートレイト個別 ID、マウス操作。

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `party-status`: ステータス画面のレイアウトと表示要件を変更。「全員を縦積み」から「左メンバーリスト + 右詳細パネル + カーソル選択」に置き換え、ポートレイト・経験値・装備・習得呪文の表示要件を追加する。
- `esc-menu-overlay`: 「メニュー表示中はゲーム入力を遮断する」要件の実現手段を、`EscMenu._unhandled_input` 内で全イベントを `set_input_as_handled()` する形式で明文化する。

## Impact

- 影響コード（変更）: `src/esc_menu/esc_menu.gd`（ステータス画面構築コードを削除して新 view へ委譲、`_unhandled_input` のモーダル化）、`src/dungeon_scene/party_member_panel.gd`（ポートレイト関連の共通モジュールへの抽出）。
- 影響コード（新規）: `src/esc_menu/views/status_view.gd`、`src/ui/job_portrait.gd`。
- 影響テスト: `tests/esc_menu/test_esc_menu_status.gd`（前提構造が変わるため書き換え）、`tests/dungeon_scene/test_party_member_panel_job_portraits.gd`（共通モジュールに移行した呼び出しに合わせて要更新）、新規テスト（カーソル動作、詳細パネル表示、WASD 漏れ解消）。
- データ・セーブ形式: 既存 `Character` フィールドのみ参照するため、セーブフォーマットへの影響なし。
- 依存: `SpellRepository.get(id).display_name` 経由で呪文表示名を解決（`SpellUseFlow` と同じ lazy-load パターン）。
