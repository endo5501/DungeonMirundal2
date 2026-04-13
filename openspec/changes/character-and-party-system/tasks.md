## 1. RaceData — 種族データ定義

- [x] 1.1 RaceData Resource クラスを作成 (src/dungeon/data/race_data.gd) — race_name, base_str/int/pie/vit/agi/luc の @export フィールド
- [x] 1.2 RaceData のテストを作成・通過 (tests/dungeon/test_race_data.gd) — インスタンス生成とフィールド参照
- [x] 1.3 5種族の .tres ファイルを作成 (data/races/) — Human, Elf, Dwarf, Gnome, Hobbit

## 2. JobData — 職業データ定義

- [x] 2.1 JobData Resource クラスを作成 (src/dungeon/data/job_data.gd) — job_name, base_hp, has_magic, base_mp, required_* フィールド + can_qualify() メソッド
- [x] 2.2 JobData のテストを作成・通過 (tests/dungeon/test_job_data.gd) — フィールド参照、can_qualify() の合格/不合格パターン
- [x] 2.3 8職業の .tres ファイルを作成 (data/jobs/) — Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja

## 3. DataLoader — データ読み込み

- [x] 3.1 DataLoader クラスを作成 (src/dungeon/data/data_loader.gd) — load_all_races(), load_all_jobs()
- [x] 3.2 DataLoader のテストを作成・通過 (tests/dungeon/test_data_loader.gd) — .tres ファイルのロードと件数・名前の検証

## 4. BonusPointGenerator — ボーナスポイント生成

- [x] 4.1 BonusPointGenerator クラスを作成 (src/dungeon/bonus_point_generator.gd) — Wizardry準拠の再帰的抽選、シード指定可能
- [x] 4.2 BonusPointGenerator のテストを作成・通過 (tests/dungeon/test_bonus_point_generator.gd) — 最小値保証、シード再現性、確率分布の傾向

## 5. Character — キャラクター

- [x] 5.1 Character クラスを作成 (src/dungeon/character.gd) — name, race, job, level, base_stats, hp, mp + to_party_member_data()
- [x] 5.2 Character のテストを作成・通過 (tests/dungeon/test_character.gd) — 作成、ステータス計算、HP/MP初期値、PartyMemberData導出、就任条件チェック

## 6. Guild — 冒険者ギルド管理

- [x] 6.1 Guild クラスを作成 (src/dungeon/guild.gd) — register, remove, get_unassigned, assign_to_party, remove_from_party, get_party_data
- [x] 6.2 Guild のテストを作成・通過 (tests/dungeon/test_guild.gd) — 登録・削除・パーティ配置・パーティ解除・PartyData生成・エッジケース

## 7. 統合・既存コードとの接続

- [x] 7.1 DungeonScreen で Guild.get_party_data() からパーティ表示に接続できることを確認（手動テストまたは統合テスト）
- [ ] 7.2 全テストが通過することを確認し、コミット

## 8. 最終確認

- [ ] 8.1 `/simplify` スキルを使用してコードレビューを実施
- [ ] 8.2 `/codex:review --scope branch --background` スキルを使用して現在開発中のコードレビューを実施
- [ ] 8.3 `/opsx:verify` で change を検証
