# confirm-dialog Specification

## Purpose
TBD - created by archiving change extract-confirm-dialog. Update Purpose after archive.
## Requirements
### Requirement: ConfirmDialog はメッセージとはい/いいえ選択を提供する Control である
SHALL: `ConfirmDialog extends Control` クラスを `src/ui/confirm_dialog.gd` に定義する。本 Control は `setup(message: String, default_index: int = 1)` メソッドで初期化され、内部に CursorMenu(["はい", "いいえ"])を持ち、`confirmed` シグナル(「はい」が選択された時)と `cancelled` シグナル(「いいえ」または ui_cancel 時)を発行する。setup 後 visible = true となり、入力フォーカスを取得する。

#### Scenario: setup でメッセージとデフォルト選択が設定される
- **WHEN** `dialog.setup("削除しますか？", 1)` を呼ぶ
- **THEN** ダイアログが「削除しますか？」というメッセージを表示し、「いいえ」がデフォルト選択になり、visible = true となる

#### Scenario: 「はい」を選択して ui_accept で confirmed が発行される
- **WHEN** ダイアログが visible で「はい」が選択中、ui_accept が押される
- **THEN** `confirmed` シグナルが発行され、ダイアログが visible = false になる

#### Scenario: 「いいえ」を選択して ui_accept で cancelled が発行される
- **WHEN** ダイアログが visible で「いいえ」が選択中、ui_accept が押される
- **THEN** `cancelled` シグナルが発行され、ダイアログが visible = false になる

#### Scenario: ui_cancel で常に cancelled が発行される
- **WHEN** ダイアログが visible で何が選択中であっても ui_cancel が押される
- **THEN** `cancelled` シグナルが発行され、ダイアログが visible = false になる

#### Scenario: setup を再度呼べば再表示できる
- **WHEN** 一度 cancelled 後、別のメッセージで `setup("別の確認", 0)` を呼ぶ
- **THEN** メッセージが更新され、デフォルトが「はい」になり、visible = true で再表示される

#### Scenario: 入力は ConfirmDialog 自身が消費する
- **WHEN** ダイアログが visible で何らかの ui_* event が発行される
- **THEN** ConfirmDialog の `_unhandled_input` が処理し、`set_input_as_handled` を呼ぶ。背後の Control(画面)には input が届かない

