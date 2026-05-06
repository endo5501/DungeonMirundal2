# AGENTS.md

## Conversation Guidelines

- 常にユーザに対して日本語で会話する
- しかし、思考は英語で行う

## Development Philosopy

### Test-Driven Development(TDD)

- 原則としてテスト駆動開発(TDD)で進める
- 期待される入力に基づき、まずテストを作成する
- 実装コードは書かず、テストのみを用意する
- テストを実行し、失敗を確認する
- テストが正しいことを確認できた段階でコミットする
- その後、テストをパスさせる実装を進める
- 実装中はテストを変更せず、コードを修正し続ける
- すべてのテストが通過するまで繰り返す

## テストの実行

### コマンドライン (推奨ラッパ経由)

```powershell
# Windows (PowerShell)
.\scripts\run_tests.ps1
```

```bash
# Linux / macOS / WSL / Git Bash
./scripts/run_tests.sh
```

`scripts/run_tests.ps1` (および `.sh`) は GUT を 2 段階の安全網付きで実行します:

1. **Pre-flight**: `src/` と `tests/` 配下の全 `.gd` を `scripts/check_scripts.gd` で parse 検証する。1つでも parse error があれば GUT を起動せずに即座に halt する。
2. **Post-scan**: GUT 出力から `SCRIPT ERROR:` / `Failed to load script` / `Ignoring script ... because it does not extend GutTest` を検出したら、たとえ GUT が `All tests passed!` と返しても exit 1 で fail する。

これにより、parse error で silently skip されたテストファイルが「緑」のまま見過ごされる事故を防げます。

追加の引数はそのまま `gut_cmdln.gd` に転送されます:

```powershell
.\scripts\run_tests.ps1 -gtest=res://tests/dungeon/test_wiz_map.gd
```