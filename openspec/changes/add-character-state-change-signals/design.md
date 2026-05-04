## Context

`Character` は RefCounted で、HP/MP/永続状態異常を生のプロパティとして公開している(`current_hp`, `current_mp`, `persistent_statuses`)。これらを書き換える経路は複数ある:

- `PartyCombatant._write_current_hp` / `_write_current_mp`(戦闘中)
- `PartyCombatant.commit_persistent_to_character`(戦闘終了時)
- `Character.level_up`(レベルアップ時の HP/MP 増加)
- `SpellUseFlow._apply_cast_and_show_result` 経由で呼ばれるエフェクトの中で間接的に Character.current_hp を書き換える(現状の ESC メニューヒール経路)
- 将来追加される: 状態異常治療フロー、消費アイテム使用フロー、装備効果による上限変動

UI 側は `PartyDisplay` (= `PartyMemberPanel` × 6 の集合) で、現在は Character ではなく `PartyMemberData` (RefCounted の DTO) を介して描画している。`PartyMemberData` は `Character.to_party_member_data()` で生成される **その瞬間のスナップショット** で、Character の HP が変わってもこの DTO は更新されない。

戦闘中だけ動いている理由は、`CombatOverlay._refresh_panels()` がターン終端で `party_state_changed` を発火し、`main` がそれを受けて `DungeonScreen.refresh_party_display(GameState.guild.get_party_data())` を呼び、新しい PartyMemberData 群を作り直しているから。戦闘外には同等のトリガが無い。

## Goals / Non-Goals

**Goals:**
- Character の HP/MP/永続状態異常が変わったら、表示している UI が経路を問わず追従する。
- 新たに「Character の状態を変える経路」を追加するときに、UI 経路の手当てを忘れても自動で追従する。
- 既存の戦闘 UI 更新経路(`party_state_changed` → `refresh_party_display`)を壊さない。
- ロード処理中にシグナルが発火してノイズにならない。

**Non-Goals:**
- 戦闘中の `StatusTrack`(BATTLE_ONLY 含む)のリアルタイム表示は対象外。本変更が扱うのは Character.persistent_statuses(永続状態異常)のみ。
- 装備変更による派生ステ(攻撃力等)の通知は対象外。今回は HP/MP/永続状態異常 3 種に絞る。
- `MonsterCombatant` 側の通知は対象外。モンスターは UI 連動が単純(CombatOverlay 内で完結)なので必要が無い。
- レベルアップ演出のフック追加は対象外(ただし `level_up` でも HP/MP は変わるので副次的にシグナルは発火する)。

## Decisions

### Decision 1: シグナルは `Character` クラスに置く

`Character` は単一の RefCounted で、HP/MP/永続状態異常の真の所有者。`PartyCombatant` はラッパーであり、戦闘中もすべての書き込みを Character へプロキシしている。シグナルを Character に置けば、書き換え経路がどこでも(戦闘中・戦闘外・将来追加分も)1 箇所で発火が保証される。

**代替案**: `PartyCombatant` にシグナルを置く案 — 却下。戦闘外では PartyCombatant インスタンスは存在しない(戦闘開始時に作って戦闘終了時に commit して捨てる)。ESC メニューヒールの瞬間は Character への直接書き込みなので、PartyCombatant にシグナルがあっても無意味。

### Decision 2: シグナルは 3 つに分割する(まとめない)

```
signal hp_changed(current_hp: int, max_hp: int)
signal mp_changed(current_mp: int, max_mp: int)
signal statuses_changed(persistent_statuses: Array[StringName])
```

**まとめ案(`state_changed()` 1 つ)を却下した理由**: 受信側が「何が変わったか」を判断するためにスナップショット比較を強いられる。3 種に分けると `PartyMemberPanel` は HP 表示だけ更新する/MP 表示だけ更新する選択ができ、無駄な再描画が減る。引数で「変化後の値」を渡しておけば、受信側は Character への参照経由で値を読みに行く必要も無い。

### Decision 3: プロパティのセッター(`var current_hp: int: set = _set_current_hp`)で発火

GDScript のプロパティセッターを使う。これにより、既存の `character.current_hp = X` という形の代入箇所を **書き換えずに** シグナル発火を有効化できる。`PartyCombatant._write_current_hp`、`Character.level_up`、`SpellUseFlow` 経由のエフェクト、すべてが自動で恩恵を受ける。

```
var current_hp: int = 0:
    set(value):
        if current_hp == value:
            return
        current_hp = value
        if not _suspend_signals:
            hp_changed.emit(current_hp, max_hp)
```

**代替案**: 公開セッターメソッド(`set_current_hp(value: int)`)を追加し、生プロパティを private にする — 却下。既存呼び出し箇所が多く(combatant、レベルアップ、ロード、テスト)、機械的書き換えが本変更の主旨を超えてしまう。

**注意**: `max_hp` を変更したときも HP 表示の分母が変わるので、`max_hp` のセッターでも `hp_changed` を発火させる(MP 同様)。

### Decision 4: ロード中はシグナルを抑制する

`Character.from_dict` は新規 Character を生成して各フィールドを直接代入する。この間にシグナルが発火しても購読者はまだいないが、将来 `Character` インスタンスが永続化されている状況(セーブ→部分更新→ロード)で誤発火する可能性を避けるため、`_suspend_signals: bool` フラグを設ける。`from_dict` の冒頭で `true` にし、最後に `false` に戻す。`level_up` 経由などゲーム実行中の書き換えではフラグが `false` のままなので影響しない。

### Decision 5: 値が変わらないときは発火しない

セッター内で `if current_hp == value: return` する。同値代入(リフレッシュ目的の冗長書き込み等)で UI を再描画しないことで CPU を節約し、テスト時の発火回数アサーションも安定する。

### Decision 6: `PartyCombatant.commit_persistent_to_character` の書き換え経路

現状: `character.persistent_statuses = persistent`(配列丸ごと代入)。これも Character のセッターで `statuses_changed` を発火させる。配列は値比較で「変化あり」を判定する(`Array == Array` は要素単位比較なので OK)。

### Decision 7: `PartyMemberPanel` がシグナルを直接購読する

`PartyMemberPanel.set_member(character_or_data)` を Character 受け取りに統一し、内部でシグナル接続を張り直す。表示対象が変わる(別 Character を `set_member` された)ら、古い Character の `hp_changed` 等の接続を切ってから新しい Character に繋ぎ直す。

**代替案**: `PartyDisplay` 親が一括購読 — 却下。Panel 自身が表示対象を知っているので、Panel に責務を寄せた方が結合度が下がる。

**互換性**: 既存の `setup(party_data: PartyData)` 経由のフロー(`PartyMemberData` を渡す経路)は維持する。Panel 内部で「Character 直接受け取り」と「PartyMemberData スナップショット受け取り」の両方をサポートする(後者ではシグナル購読は張らない)。これにより `CombatOverlay` がスナップショット経由で更新する経路も生き残る。

### Decision 8: 既存の `party_state_changed` 経路は撤去しない

`CombatOverlay._refresh_panels()` の `party_state_changed.emit()` は今回そのまま残す。冗長だが、戦闘中はパーティ情報以外(モンスターパネル等)の更新も同じハンドラに乗っており、切り離しは別の change で扱うのが筋。Panel 側のシグナル直購読が追加されることで、戦闘中の HP 変化通知が **二重に** 走るが、`set_member` の同値比較で実害は無い(`PartyMemberPanel.set_member` 内部で `queue_redraw` が二度呼ばれる程度)。

## Risks / Trade-offs

- **[Risk]** プロパティセッターでの自動発火は、テストコード等で意図せず Character.current_hp を書き換えている場所からも発火する → **Mitigation**: 値が変わらないときは発火しない条件で大半は問題なし。テストでは `_suspend_signals` を一時的に立てるヘルパは用意しない(用意するとプロダクションコードへの誘惑になる)。

- **[Risk]** RefCounted のシグナル接続が解放を妨げる(循環参照) → **Mitigation**: `Character` は RefCounted、`PartyMemberPanel` は Node。Node → RefCounted への参照は通常通り。Panel 側で `Callable.bind` でなく直接メソッド渡しなら循環は発生しない。`set_member` で必ず古い接続を切るので接続が累積することも無い。

- **[Risk]** `Array[StringName]` の値比較で誤判定 → **Mitigation**: 同じ要素・同じ順序なら GDScript の `==` は等値判定する。順序依存だが、`commit_persistent_to_character` は常に `repo` の find 順で構築するので順序は安定。

- **[Trade-off]** シグナル直購読と既存の `party_state_changed` バルク更新の **二重経路** が当面残る。完全な単一経路化は将来の change(例: `simplify-party-display-refresh`)に分割する。

- **[Risk]** `from_dict` の `_suspend_signals = true / false` を例外で抜けたら永久抑制状態になる → **Mitigation**: 冒頭の代入と末尾の解除を `try/finally` 風に書く必要があるが、GDScript には try/finally が無い。`from_dict` は途中で `return null` する分岐があるので、各 return 直前に解除を入れるか、ヘルパで包む。design 上は「`Character.new()` 直後に立てて、return する全ての分岐で必ず戻す」をルール化する。tasks.md に「全 return 経路をレビューする」を含める。

## Migration Plan

機能追加であり破壊的変更は無い。段階的に:

1. `Character` にシグナル定義とセッター追加(挙動は変えず、発火だけ追加)。
2. テストで「セッター経由で値が変わるとシグナルが 1 回発火する/同値だと発火しない/`_suspend_signals` 中は発火しない」を担保。
3. `PartyMemberPanel` に Character 受け入れ + 購読/解除を追加。既存の PartyMemberData 経路は残す。
4. `PartyDisplay.setup` を「Character 配列を渡せる」インターフェイスに拡張(または別メソッドを追加)。`DungeonScreen` がこちらを呼ぶように切り替え。
5. `SpellUseFlow` 経由の ESC メニューヒールで HP バーが追従することを統合テストで確認。

ロールバック: シグナル接続をしないだけで以前と同じ挙動に戻る(セッター追加自体は無害)。

## Open Questions

- `equipment` 変更による `max_hp` / `max_mp` 変動を将来扱うか? — 本 change の対象外。装備変更時に Character の `max_hp` 自体は変わらない(現状は equipment_provider 経由で導出)ので、当面表面化しない。
- `PartyMemberPanel` 側のシグナル購読を Godot の `Connect` flag(`CONNECT_REFERENCE_COUNTED` 等)でどう扱うか? — 実装時に決定。デフォルト挙動で問題なければそのまま。
