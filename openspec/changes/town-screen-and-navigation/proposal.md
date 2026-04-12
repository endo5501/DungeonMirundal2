# Change: 地上画面 + 画面遷移

## Summary

スタート画面、地上画面（施設選択）、および画面遷移管理を実装する。ダンジョンの選択・新規生成・破棄の管理もここで行う。

## Scope

- スタート画面
  - 新規ゲーム
  - 前回から（最後のセーブデータ）
  - ロード（セーブデータ選択）※UI枠のみ、実ロジックはsave-load
  - ゲーム終了
- 地上画面
  - 画面左側に施設選択ボタン
  - 画面右側にイラスト表示エリア（選択中の施設に応じて変化）
  - 冒険者ギルド → character-and-party-system のUI呼び出し
  - 商店・教会 → プレースホルダ（items-and-economy で実装）
- ダンジョン入口
  - ダンジョン選択
  - ダンジョン新規生成（project-foundation-and-dungeon-generation の生成アルゴリズム呼び出し）
  - ダンジョン破棄
- 画面遷移管理
  - スタート → 地上 → ダンジョン の遷移フロー
  - 地上に戻ったらHP全回復、状態異常解除

## Non-goals

- セーブ/ロードの実ロジック（save-load）
- 商店・教会の実機能（items-and-economy）
- 戦闘関連の遷移

## Dependencies

- dungeon-ui: ダンジョンUI（ダンジョン画面への遷移先）
- character-and-party-system: キャラクター＆パーティシステム（ギルドUIの呼び出し）

## Risks

- 画面遷移の設計（SceneTree.change_scene vs シーン管理シングルトン）
- 地上画面のイラスト素材の調達・仮置き
