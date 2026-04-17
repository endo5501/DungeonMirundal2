# Change: モンスター＆エンカウント

## Summary

ダンジョン探索中に発生するランダムエンカウントの基盤を実装する。モンスターデータ定義、出現判定、モンスターパーティ編成までを担当し、戦闘そのものはスタブ・オーバーレイ（遭遇表示→閉じるだけ）で代替する。後続の combat-system change で本物の戦闘UIに差し替える。

## Scope

- モンスターデータ定義
  - 外部データファイル（YAML/JSON）でのモンスター定義
  - ステータス（HP、攻撃力、防御力、素早さ 等）
  - 出現条件（ダンジョン階層、エリア 等）
- モンスターデータ管理
  - MonsterRepository / ローダー
  - バリデーション（必須フィールド、範囲チェック）
- エンカウント判定
  - EncounterTable（階層別の出現テーブル）
  - EncounterManager（移動時の発生判定、乱数シード制御）
- モンスターパーティ編成
  - 出現パターン（種類・数の組み合わせ）
  - 編成ロジック
- ダンジョン統合
  - 既存の移動処理フックへのエンカウント判定組み込み
  - 発生時のオーバーレイ表示・入力フォーカス切替
- スタブ・オーバーレイ
  - 「〜とエンカウント！」の簡易表示
  - 確認操作でオーバーレイを閉じてダンジョンへ復帰
  - combat-system で本番UIに置換予定

## Non-goals

- ターン制戦闘ロジック（combat-system）
- 戦闘UI（combat-system）
- 経験値・レベルアップ・死亡処理（combat-system）
- ダミー/本番アイテムの取り扱い（combat-system / items-and-economy）
- 魔法・スキルシステム

## Dependencies

- dungeon-3d-rendering-and-movement (archived): ダンジョン移動処理
- character-and-party-system (archived): パーティ情報

## Risks

- エンカウント発生率のバランス（移動のテンポを損なわない）
- 既存 dungeon movement との統合点の設計（疎結合に保ちたい）
- 出現テーブルのデータ表現（拡張性と書きやすさの両立）
