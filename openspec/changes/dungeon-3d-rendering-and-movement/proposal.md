# Change: ダンジョン3D描画 + 移動

## Summary

project-foundation-and-dungeon-generation で生成したダンジョンデータを Wizardry 風の一人称3D視点で描画し、プレイヤーがダンジョン内を移動できるようにする。

## Scope

- Wizardry風一人称3Dダンジョン描画
  - 壁・床・天井の描画
  - ドアの描画（通常の壁と区別）
  - 視野内のセルを手前から奥に向けて描画
- 移動操作
  - 前進・後退
  - 左回転・右回転
  - 壁判定（壁方向には進めない）
- ダンジョンシーンの基本構成

## Non-goals

- ミニマップ・パーティ表示（dungeon-ui で対応）
- テクスチャや装飾の凝った表現（基本的な壁表現で十分）
- 戦闘エンカウント

## Dependencies

- project-foundation-and-dungeon-generation: ダンジョン生成アルゴリズム（マップデータの参照）

## Risks

- Wizardry風3D描画のアプローチ選定（メッシュ直接構築 vs サブビューポート vs 事前レンダリング）
- 描画パフォーマンス（大きなマップでの視野計算）
