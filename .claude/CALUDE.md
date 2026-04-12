# DungeonMirundal

Godot製の(Wizardlyライクな)ダンジョン探索RPG開発プロジェクト

## 開発コマンド


```bash
# 初回はインポートが必要
godot --headless --import
# テスト(ヘッドレス)
godot --headless -s addons/gut/gut_cmdln.gd
```

## change作成時の注意

OpenSpecのスキルでchange作成した際、同時に開発用ブランチを作成してください

## tasks.md作成時の注意

OpenSpecのスキルでtasks.mdを作成する際、最終確認のため以下の項目を追加してください

```md
## X. 最終確認

- [ ] X.1 `/simplify`スキルを使用してコードレビューを実施
- [ ] X.2 `/codex:review --scope branch --background` スキルを使用して現在開発中のコードレビューを実施
- [ ] X.3 `/opsx:verify`でcahngeを検証
```

## archive時の注意

必ずDelta specの同期を行なってください
