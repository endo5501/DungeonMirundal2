# Change: キャラクター＆パーティシステム

## Summary

キャラクターの作成・管理およびパーティ編成のロジック層を構築する。種族・職業などのデータはGodot Resource (.tres) で定義し、データローダーとキャラクター作成・管理の仕組みを実装する。UIは別change（guild-ui）で扱う。

## Scope

- 外部データファイル（.tres Resource）によるデータ定義とローダー実装
- 種族データの定義と読み込み（5種族: Human, Elf, Dwarf, Gnome, Hobbit）
  - 基礎ステータス（STR, INT, PIE, VIT, AGI, LUC）
- 職業データの定義と読み込み（8職業: Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja）
  - 就任条件（ステータス閾値）
  - 基礎HP、MP有無
- キャラクター作成ロジック
  - 名前・種族・職業の選択
  - ボーナスポイント配分制によるステータス決定（Wizardry準拠の確率分布）
  - 初期HP = 職業の基礎HP + VIT補正
  - 初期MP = 魔法職のみ、レベル依存
- Character クラス（RefCounted）
  - name, race, job, level, stats, hp, mp を保持
  - PartyMemberData への導出メソッド（to_party_member_data()）
- パーティ管理ロジック
  - 前列3名・後列3名の編成
  - メンバーの入替え
  - 冒険者ギルドでの未所属キャラクター管理
  - キャラクターの削除

## Design decisions

- ステータス体系: STR, INT, PIE, VIT, AGI, LUC（Wizardry準拠）
- 種族補正: 基礎値 + ボーナスポイント加算
- ボーナスポイント: Wizardry準拠の確率分布（低確率で高ボーナス）、上限なし
- アライメント: なし（Lord/Samurai/Ninjaはステータス条件のみで就任可能）
- データ形式: Godot .tres Resource
- Character → PartyMemberData は導出（別クラス）
- experience, equipment フィールドは後続changeで追加

## Non-goals

- レベルアップ・経験値（combat-system 以降）
- アイテム・装備の実装（items-and-economy）
- 転職の仕組み
- 種族特性（耐性、固有スキルなど）
- 冒険者ギルドUI（guild-ui）
- キャラクター作成画面・パーティ編成画面などのUI全般

## Dependencies

- project-foundation-and-dungeon-generation: プロジェクト基盤（Godotプロジェクト、GUT）

## Risks

- データバリデーションの設計（.tres の型安全性に頼りつつ、ローダーでの追加チェックが必要か）
- ボーナスポイント確率分布の再現精度
