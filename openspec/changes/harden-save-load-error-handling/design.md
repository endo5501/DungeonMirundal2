## Context

セーブ／ロードは `src/save_manager.gd` (RefCounted) と `src/save_screen.gd` / `src/load_screen.gd` (Control) と `src/main.gd._load_game` の 4 つのファイルにまたがる。`SaveManager` は GameState の autoload (`GameState.save_manager`) として常駐する。ユーザ可視の動線は次の 2 経路:

```
保存:  ESC → SaveScreen → CursorMenu 選択 → SaveManager.save() → save_completed → ESCメニュー帰還
ロード: ESC または Title → LoadScreen → 選択 → main._load_game() → SaveManager.load() → 画面遷移
```

現状の問題点 (TECH_DEBT_AUDIT.md 参照):

- `SaveManager.save` (`:21-43`) は `void` 返却。`FileAccess.open == null` で 2 箇所早期 return するが UI には届かない。
- `SaveManager.load` (`:45-64`) は `bool` 返却だが、失敗事由(欠損/破損/未来バージョン/中身不正)を識別できない。
- `_load_game` (`main.gd:259-263`) は `if not ok: return` だけで、ロード画面に「失敗しました」と表示する手段がない。
- `Character.from_dict` (`character.gd:119-122`) は `load("res://data/races/" + id + ".tres") as RaceData` の null を放置。後続の `ch.race.race_name` 参照で遠隔クラッシュ。
- `DataLoader._load_resources` (`data_loader.gd:43-54`) は `DirAccess.open == null` で空配列を返却。アセットディレクトリ欠損が静かに進行。

`SaveScreen` / `LoadScreen` には現状 "結果ラベル" 用のスペースがない。`PanelContainer` の `VBoxContainer` の末尾に `Label` を 1 行足す形で対応する。

## Goals / Non-Goals

**Goals**
- すべてのセーブ／ロード失敗をユーザに通知する
- 失敗事由を区別できるようにする(ファイル欠損 vs バージョン未来 vs JSON 破損 vs 復元失敗)
- 部分的に壊れたセーブからの復元を「壊れた要素を捨てつつ可能な範囲で進める」方針に統一する
- アセットディレクトリ欠損を debug ビルドで早期検出する

**Non-Goals**
- 自動バックアップ機能 (失敗時のリトライや旧版保持)
- セーブデータマイグレーション (version 1 → 2 への upgrade パス) — 必要になった時点で別 change
- リアルタイムセーブ進捗 UI (現状サイズなら同期書き込みで十分)
- 多言語化 (エラー文言は日本語固定)

## Decisions

### Decision 1: `SaveManager.save` は `bool` 返却、`load` は enum 拡張

**選択**: `save(slot_number: int) -> bool` に変更。`load` は事由を伝える必要があるため、エラー詳細を `LoadResult` enum (`OK`, `FILE_NOT_FOUND`, `PARSE_ERROR`, `VERSION_TOO_NEW`, `RESTORE_FAILED`) として返す。

**理由**:
- `save` は失敗事由が「ディスク I/O 失敗」しかない(JSON.stringify は string を必ず返す)。bool で十分。
- `load` は事由が複数あり、UI で文言を変えたい(「ファイルが見つかりません」 vs 「未対応の新しいバージョンです」)。

**代替案**:
- `save` も enum 化する → 区別する事由がないのでオーバーキル。bool で十分。
- 例外ベース → GDScript はチェック例外がない。enum + push_error が慣習。

### Decision 2: `LoadResult` の表現は GDScript の `enum`

**選択**: `SaveManager` 内に `enum LoadResult { OK, FILE_NOT_FOUND, PARSE_ERROR, VERSION_TOO_NEW, RESTORE_FAILED }` を定義。

**理由**:
- GDScript の enum は他クラスから `SaveManager.LoadResult.OK` で参照できる
- `Dictionary` を返す案も検討したが、構造化されない値は呼び出し元で文字列キーをミスる
- 後で `RESTORE_FAILED` を細分化したくなったら enum に値を足すだけ

### Decision 3: `Character.from_dict` の null 経路は呼び出し元で吸収

**選択**: `Character.from_dict` は `Character | null` を返す。`Guild.from_dict` は null を `push_warning` でログしてスキップする。party_index による `front_row` / `back_row` の参照は、欠損 character を踏むと party 配置を null に倒す。

**理由**:
- 失敗を near にする原則。race/job が load できない時点で character は不完全なので「壊れた character を返す」より null のほうが安全。
- 全 character が壊れていたら空 Guild になる。少なくともゲームは起動する。
- party_index は `_characters.find()` で得るので、要素数が減れば自然に再採番される。ただし保存時のインデックスが配列位置で記録されているため、この対応では party 配置がずれる可能性がある。Guild.from_dict のリストア順を保ちつつ、null character は同じ位置に Character.new() のダミーで占有させて配置インデックスを安定化させるか、より単純にスキップした上で party 配置を再構築する。

**実装方針(最終)**: `Guild.from_dict` は `Array[Character]` ではなく `Array` で `null` も含む形で characters を一旦読み込み、null 要素は登録しない。`front_row` / `back_row` は `_characters.find()` 経由ではなく、直接 `chars_arr` の元インデックスを使う形で参照しているので、null をスキップした後に「インデックスが指す位置に null character がいる場合は配置しない」という前処理を入れる。

### Decision 4: `DataLoader` 失敗は `push_error` (debug ビルド) と空配列(release)

**選択**: `DirAccess.open == null` のとき `push_error("DataLoader: cannot open " + dir_path)` を出した上で空配列を返す。`assert` は使わない。

**理由**:
- debug ビルドではエラーログが GodotEditor のエラータブに出る。CI でも `--verbose` で拾える。
- release ビルドでは空配列で進行 → 後続の `RaceData` 不在で character creation が失敗する。だが少なくとも push_error はログファイルに残る。
- `assert` を使うと release ビルドではストリップされるため検出できない。

### Decision 5: UI のエラーフィードバックは Label を末尾に追加

**選択**: `SaveScreen` / `LoadScreen` の `_container: VBoxContainer` の末尾に `_status_label: Label` を作成。失敗時のみ `text` をセットして可視化、成功時は非表示。

**理由**:
- 既存 UI の構造を維持したまま追加のみで対応できる
- ダイアログ表示よりシンプル(モーダルにする必要がない)
- 既存テスト (`get_slot_count`, `is_overwrite_dialog_visible`) と整合する

### Decision 6: 既存テストの保護

**選択**: 既存テストの公開 API シグネチャ(返り値型を含む)を変更するため、`tests/save_load/test_save_manager.gd` の `save` を呼んでいる箇所を `bool` 返却を assert する形に書き換える。`load` の `bool` を assert している箇所は `SaveManager.LoadResult.OK` を assert する形に書き換える。

**理由**:
- API 変更なので呼び出し元のテストも更新が必要。新規テスト(失敗ケース)とまとめて 1 コミットにする。

## Risks / Trade-offs

- **[呼び出し元の更新漏れ]** `SaveManager.save` は将来 auto-save が追加されるかもしれない。bool を `_` で握りつぶす実装が紛れ込む可能性 → コードレビュー対応とする。
- **[`LoadResult` enum 値の増加]** 後で「ネットワーク失敗」みたいなケースが追加される可能性 → enum なので追記可能。
- **[エラーラベルの重ね表示]** 連続失敗時に古いラベルが残る可能性 → 成功時に必ず `text = ""` でクリアする。
- **[`Character.from_dict` の null 返却の連鎖]** Guild.from_dict だけでなく他の呼び出し元(現状なし、しかし)に伝播する → 他の呼び出し元は CharacterCreation の Character.create() であり、from_dict は使っていない。安全。
- **[`DataLoader` の `push_error` がノイズになるシナリオ]** 開発中に意図的に空ディレクトリを作る場面は無さそう → 念のため `_load_resources` 呼び出し元(load_all_races など)が空でも進めるよう既存挙動は維持。

## Out of Scope (Reserved for Future Change)

- **[`LoadResult.RESTORE_FAILED` の検出経路]** enum 値と LoadScreen 文言は本 change で確立するが、実際に `load()` から返す検出ロジックは含めない。理由:
  - GDScript に例外機構が無く、復元中の型不正を try/catch で捕まえられない
  - `Inventory.from_dict` / `DungeonRegistry.from_dict` が成功/失敗を返す契約になっていない(本 change で行ったのは Character/Guild の null 化のみ)
  - 仕様の「GameState は安全な状態に保たれる」を満たすには load 前 snapshot + 失敗時 restore の機構が必要
  - これらの工事は本 change のスコープ「失敗を呼び出し元に必ず伝える契約」を超え、別 change `add-restore-failure-detection` 等で扱うのが適切
  - UI 側(`LoadScreen.show_load_failure`)は `RESTORE_FAILED` への対応を済ませているので、後続 change は SaveManager 内部の検出ロジック追加だけで完結する
