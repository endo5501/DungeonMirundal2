## Context

タイトル画面とダンジョン入口は、どちらも CursorMenu によるキーボード選択 UI を使っている。共通の基盤（`src/dungeon/cursor_menu.gd`）と各画面の初期化ロジックに跨って、初期カーソル位置に関する引っかかりが残っている。CursorMenu は title / town / shop / temple / guild / character / combat / esc-menu など 18 画面で使われているため、共通基盤への変更は副作用を慎重に見極める必要がある。

## Goals / Non-Goals

**Goals:**
- タイトル画面の初期カーソルが「前回から」（セーブ有り時）または「新規ゲーム」（セーブ無し時）に正しく乗る。
- ダンジョン入口を開いた直後、登録済みダンジョンが0件でも Enter を追加で押さず「新規生成」を確定できる。
- ダンジョンが0件の時のプレースホルダ文言を、ユーザが次にとるべき行動を示す誘導文に変える。
- CursorMenu に加える「初期 disabled 自動スキップ」は、他 17 画面の挙動を変えない安全な拡張である。

**Non-Goals:**
- CursorMenu のレンダリング方式（`"> "` プレフィックスのズレ問題）の解消。別 change で扱う。
- ダンジョン入口のレイアウト変更、ボタン並び替え、空状態専用画面。
- ロード画面や他の画面への手入れ。

## Decisions

### Decision 1: CursorMenu の初期 disabled スキップ実装

**採用案:** `CursorMenu._init()` の末尾、または別途 `ensure_valid_selection()` メソッドを追加し、`selected_index` が disabled の時は `move_cursor(1)` を呼んで最初の有効インデックスへ進める。全項目 disabled の場合は現状維持。

**代替案と比較:**

| 案 | 内容 | 却下理由 |
|---|---|---|
| A. 各画面側で `if disabled: move_cursor(1)` を書く | 画面ごとに初期化ロジックを足す | title 以外にも同種の問題が潜む可能性があり、DRY ではない |
| **B. `CursorMenu` に初期スキップを組み込む（採用）** | `_init` または `setup_save_state` のような経路で、disabled 変更時に自動補正 | 1箇所で完結し、全画面の潜在バグを予防 |
| C. 画面描画フレームで毎回補正 | 毎 update で検査 | オーバーヘッドと意図の不明瞭さ |

**API の選択:** `_init` の中で自動実行するのではなく、`disabled_indices` が後から `setup_save_state` 等で変わる可能性を考慮し、**`disabled_indices` プロパティの setter または公開メソッド `ensure_valid_selection()` で明示的に呼ぶ方式**を採用する。`_init` だけで済ませると、セーブ有無判定後に disabled が再設定される title 画面では機能しない。

### Decision 2: タイトル画面の並び替えと初期カーソル

**採用案:** `MENU_ITEMS` を `["前回から", "新規ゲーム", "ロード", "ゲーム終了"]` に並び替え、`setup_save_state()` 内で `disabled_indices` を更新した後に `_menu.ensure_valid_selection()` を呼ぶ。これにより:

| 状態 | disabled_indices | ensure_valid_selection の結果 |
|---|---|---|
| セーブ有り、last_slot 有効 | `[]` | index 0（前回から）維持 |
| セーブ有り、last_slot 無効 | `[0]` | index 0→1（新規ゲーム）にスキップ |
| セーブ無し | `[0, 2]` | index 0→1（新規ゲーム）にスキップ |

main.gd 側の signal 接続順とロジックは変更不要。

### Decision 3: ダンジョン入口の空状態初期フォーカス

**採用案:** `setup(registry, has_party)` 内で `registry.size() == 0` の場合:
- `_focus = Focus.BUTTONS`
- `_button_menu.selected_index = 1`（新規生成）
- `selected_index` は `-1` のまま（dungeon list のカーソル）

`_build_ui()` 呼び出し後に `_update_button_disabled()` が「潜入する」を disabled にするため、ボタン列の move_cursor は disabled をスキップする既存動作に則る。ただし**初期値を直接 1 にしておくこと**で、ensure_valid_selection 的な補正を待たずに正しい位置に置く。

### Decision 4: 空状態の誘導メッセージ

**採用案:** `(ダンジョンがありません)` を以下に差し替える:

```
まず「新規生成」でダンジョンを作成してください
```

視覚的強調は、既存の `CursorMenu.DISABLED_COLOR`（灰色）から通常色へ戻し、フォントサイズは現状維持。

## Risks / Trade-offs

- **[Risk] CursorMenu の初期スキップが他画面で意図せず動く** → Mitigation: `_init()` では実行せず、明示 API (`ensure_valid_selection()`) を追加する。呼ぶのは title 画面のみ。他 17 画面はコードを変更しないので挙動不変。
- **[Risk] テストで現状の「初期カーソルは新規ゲーム」前提のものが壊れる** → Mitigation: 既存テストを棚卸しし、新仕様に合わせて更新。
- **[Trade-off] ダンジョン入口の空状態でも「破棄」「潜入する」を表示し続ける** → Issue の「案B（disabled 項目を非表示）」は今回対象外とし、A+D に留める。表示階層が変わらず既存テストへの影響が最小。

## Migration Plan

TDD で進める:
1. CursorMenu に `ensure_valid_selection()` を追加するテストを書く（RefCounted 単体テスト）
2. 実装して緑にする
3. タイトル画面のテストを更新・追加
4. タイトル画面の並び替えと ensure_valid_selection 呼び出しを実装
5. ダンジョン入口のテストを追加（空状態時の初期 focus とメッセージ）
6. ダンジョン入口の実装
7. 全テスト通過後、手動で起動確認（セーブ有/無 × ダンジョン有/無）

ロールバックは 3 ファイルの git revert で完結する。
