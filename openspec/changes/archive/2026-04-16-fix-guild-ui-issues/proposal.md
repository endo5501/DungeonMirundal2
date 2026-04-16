## Why

冒険者ギルド画面に2つのバグがある。(1) メニューやキャラクター作成ウィザードのレイアウトが画面右下に偏っており、中央に表示されない。(2) キャラクター作成のStep 2（種族選択）がスキップされ、常にDwarf（リスト先頭）が自動選択されてしまう。どちらもユーザー体験を大きく損なう問題であり、早急な修正が必要。

## What Changes

- `guild_menu.gd`: VBoxContainerのアンカー設定を `PRESET_CENTER` からコンテンツ全体が画面中央に配置される方式に変更
- `character_creation.gd`: 同様にVBoxContainerのレイアウトを中央配置に修正
- `character_creation.gd`: Step 1のEnterキーイベントがStep 2に伝播してui_acceptが即発火する問題を修正。`_on_name_submitted` で遷移した直後のフレームでStep 2の入力を受け付けないようにする

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `guild-menu`: VBoxContainerのレイアウトを画面中央配置に修正
- `character-creation-wizard`: レイアウト中央配置の修正 + Step 1→Step 2遷移時のイベント伝播バグを修正し、種族選択画面が正しく表示されるようにする

## Impact

- `src/guild_scene/guild_menu.gd`: アンカー/レイアウト設定変更
- `src/guild_scene/character_creation.gd`: アンカー/レイアウト設定変更 + イベント伝播制御の追加
- 既存テスト: レイアウト変更によるテスト影響は軽微（ロジックテストは変更なし）。Step 2スキップバグの修正に伴い、遷移テストの追加が必要
