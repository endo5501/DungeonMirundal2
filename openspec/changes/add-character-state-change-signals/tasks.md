## 1. Character シグナル基盤(TDD)

- [x] 1.1 `tests/dungeon/test_character_signals.gd` を作成: hp_changed/mp_changed/statuses_changed が「異なる値の代入で 1 回だけ発火」「同値代入で発火しない」を検証する失敗テストを書く
- [x] 1.2 `tests/dungeon/test_character_signals.gd` に `_suspend_signals` フラグの直接操作で発火が抑制されること、解除後は通常通り発火することを検証するテストを追加
- [x] 1.3 テストを実行して期待通り失敗することを確認(GUT で 4–6 個 FAIL)
- [x] 1.4 `src/dungeon/character.gd` に `signal hp_changed(current_hp: int, max_hp: int)`、`signal mp_changed(current_mp: int, max_mp: int)`、`signal statuses_changed(persistent_statuses: Array[StringName])` を定義
- [x] 1.5 `current_hp` / `max_hp` / `current_mp` / `max_mp` をプロパティセッター付きに書き換え、値変化時のみ対応するシグナルを `_suspend_signals == false` の場合に発火
- [x] 1.6 `persistent_statuses` をプロパティセッター付きに書き換え、配列の値比較で変化時のみ `statuses_changed` を発火
- [x] 1.7 1.1–1.2 のテストがすべて PASS することを確認
- [x] 1.8 ここでコミット(英語、TDD 単位): `Add Character state change signals (hp/mp/statuses)`

## 2. ロード時のシグナル抑制

- [x] 2.1 `tests/dungeon/test_character_signals.gd` に「`Character.from_dict(valid_data)` 中はどのシグナルも発火しない」を検証する失敗テストを追加
- [x] 2.2 「`from_dict` から戻った後にプロパティを書き換えると通常通りシグナルが発火する」テストを追加
- [x] 2.3 「race リソース欠落で `from_dict` が null を返す経路でも、別の Character の発火挙動には影響しない」テストを追加
- [x] 2.4 テストが期待通り失敗することを確認(注: シグナル発火はリスナー不在時に no-op のため、契約テストとして記録。実装は防御的に from_dict を抑制)
- [x] 2.5 `src/dungeon/character.gd` の `Character.from_dict` 内で、新しい Character の `_suspend_signals` を冒頭で `true` にし、return する全分岐の直前で `false` に戻す。早期 return(race/job 解決失敗)の経路は null を返すため抑制不要
- [x] 2.6 2.1–2.3 のテストが PASS することを確認
- [x] 2.7 ここでコミット: `Suspend Character signals during from_dict`

## 3. PartyCombatant の発火経路統合

- [x] 3.1 `tests/combat/test_party_combatant_signals.gd` を作成: `take_damage(5)` で wrap した Character の `hp_changed` がちょうど 1 回 `(15, max_hp)` で発火することを検証する失敗テスト
- [x] 3.2 `spend_mp(2)` で `mp_changed` が `(3, max_mp)` で発火することを検証するテストを追加
- [x] 3.3 `commit_persistent_to_character` で配列内容が変わったときだけ `statuses_changed` が発火することを検証するテストを 2 ケース(変化あり/なし)追加
- [x] 3.4 テストが期待通り失敗することを確認(注: 1.5/1.6 のセッター実装が既存経路に自動的に効いたため、今回は最初から PASS)
- [x] 3.5 `src/combat/party_combatant.gd` の `_write_current_hp` / `_write_current_mp` を確認(プロパティ代入経由なので 1.5 のセッター対応で自動的に通った)。テストが PASS することを確認
- [x] 3.6 `commit_persistent_to_character` の最後の `character.persistent_statuses = persistent` がプロパティセッター経由で値比較した上で発火することを確認(1.6 で対応済み)
- [x] 3.7 既存の `tests/combat/test_party_combatant.gd` と既存戦闘系テストが回帰していないことを確認(全 PASS, 8248 asserts)
- [x] 3.8 ここでコミット: `Route PartyCombatant writes through Character setters`

## 4. PartyMemberPanel のシグナル購読

- [x] 4.1 `tests/dungeon_scene/test_party_member_panel_signals.gd` を作成: Panel に Character をバインドし、その Character の `current_hp` を変えると Panel の表示用フィールド(または `queue_redraw` 呼出回数)が更新されることを検証する失敗テスト
- [x] 4.2 「Character A → B に切替後、A の HP 変化では Panel が反応しない」テストを追加
- [x] 4.3 「Panel を null で unbind した後の HP 変化に Panel が反応しない」テストを追加
- [x] 4.4 テストが期待通り失敗することを確認(bind_character 未実装で 6 件 FAIL)
- [x] 4.5 `src/dungeon_scene/party_member_panel.gd` に Character 参照を保持するフィールドと、バインド/アンバインド時にシグナル接続を切り替えるメソッド `bind_character(c: Character)` を追加
- [x] 4.6 接続したシグナルのコールバックは `_data` を `to_party_member_data()` で再生成して `queue_redraw()` を呼ぶ(HP/MP/statuses)
- [x] 4.7 既存の `set_member(data: PartyMemberData)` 経路は保持する(後方互換)。`set_member` は古い Character 接続を切ってからスナップショット保持
- [x] 4.8 7/7 のテストが PASS することを確認
- [ ] 4.9 ここでコミット: `Make PartyMemberPanel auto-refresh from Character signals`

## 5. PartyDisplay と DungeonScreen の配線

- [x] 5.1 `tests/dungeon_scene/test_party_display_character_binding.gd` を作成: PartyDisplay に Character 配列を渡し、特定 Character の HP 変化で対応する Panel だけが再描画されることを検証
- [x] 5.2 「null スロットを含む Character 配列でも安全に動作する」ことを検証するテストを追加
- [x] 5.3 テストが期待通り失敗することを確認(bind_party_characters 未実装で 3 件 FAIL)
- [x] 5.4 `src/dungeon_scene/party_display.gd` に `bind_party_characters(front: Array, back: Array)` を追加
- [x] 5.5 5.1–5.2 のテストが PASS することを確認(3/3 PASS)
- [x] 5.6 `DungeonScreen.bind_party(guild)` を追加し、`main.gd` の `_show_dungeon_screen` と `_on_combat_party_state_changed` でこれを呼び出すように切替。`refresh_party_display(party_data)` はテスト用後方互換として温存
- [x] 5.7 既存の `tests/dungeon_scene/` および全体テスト(8263 asserts)が回帰なし
- [x] 5.8 ここでコミット: `Bind PartyDisplay to live Characters in DungeonScreen`

## 6. 統合テストでバグ再現と修正の確認

- [x] 6.1 `tests/dungeon_scene/test_esc_menu_heal_refreshes_status_bar.gd` を作成: PartyDisplay を Character 配列にバインドした状態で `SpellUseFlow` の heal を走らせ、対応する Panel の `_data.current_hp` が新しい値を反映することを検証
- [x] 6.2 戦闘経由は `tests/combat/test_party_combatant_signals.gd::test_take_damage_emits_hp_changed_with_new_value` と Section 4 の Panel シグナルテストで連鎖がカバーされているため、追加テストは不要(同じ Character セッター経由)
- [x] 6.3 統合テストが PASS することを確認
- [x] 6.4 既存テスト全体を実行して回帰が無いことを確認(8269 asserts、All tests passed)
- [ ] 6.5 Godot エディタで実機確認: ヘッドレス環境のため実施不可。ユーザによる確認が必要(ダンジョン入場 → エンカウント → ダメージ受ける → 戦闘終了 → ESC メニュー → ヒール → ステータスバーが追従)
- [ ] 6.6 ここでコミット: `Verify ESC menu heal refreshes dungeon status bar`

## 7. 仕上げ

- [ ] 7.1 全テストを実行し、PASS 件数と失敗件数を記録
- [ ] 7.2 `openspec verify add-character-state-change-signals` を実行し、spec と実装の整合を確認
- [ ] 7.3 design.md / proposal.md の Open Questions / Migration Plan に対し、実装中に判明した事項があれば追記
- [ ] 7.4 PR を作成(変更概要、テスト方法、関連 in-progress changes との関係を記述)
