# Change: プロジェクト基盤 + ダンジョン生成

## Summary

Godotプロジェクトの初期セットアップ、テストフレームワーク(GUT)の導入、およびダンジョン自動生成アルゴリズムの実装を行う。ダンジョン生成は `docs/reference/dungeon_generator.py` の Python 参考実装を GDScript に移植する。

TDDに最適な最初のchangeとして、純粋なロジック（RefCountedベース）で入出力が明確なダンジョン生成から着手する。

## Scope

- Godotプロジェクトの初期作成（project.godot等）
- GUT（Godot Unit Test）フレームワークの導入
- ダンジョン生成アルゴリズムのGDScript実装
  - セルとエッジの定義（Wall / Open / Door）
  - 完全迷路生成（深さ優先探索）
  - 部屋配置と内部開放
  - ループ追加（extra links）
  - 部屋境界へのドア配置
  - 全体連結性の検証（BFS）
  - 開始地点・ゴール配置

## Non-goals

- 3D描画やUI（dungeon-3d-rendering-and-movement, dungeon-ui で対応）
- 外部データファイル形式の決定（必要になった時点で決める）
- 戦闘やキャラクターシステム

## Dependencies

- なし（最初のchange）

## Risks

- GDScriptとPythonの言語差異（型システム、データ構造）による移植時の注意点
- マップサイズが大きい場合のGDScriptでのパフォーマンス
