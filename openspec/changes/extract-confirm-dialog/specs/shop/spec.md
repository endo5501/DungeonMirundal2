## ADDED Requirements

### Requirement: shop_screen はリスト操作を _handle_list_input ヘルパーで統合する
SHALL: `ShopScreen` の `_input_buy` と `_input_sell` は、共通ヘルパー `_handle_list_input(event, count, on_accept)` を介してリスト操作(ui_up/ui_down/ui_left/ui_right/ui_accept/ui_cancel)を処理する。`_input_buy` と `_input_sell` は `on_accept` のみが異なる薄いラッパーである。

#### Scenario: _input_buy と _input_sell の重複が解消される
- **WHEN** `shop_screen.gd` を grep で確認する
- **THEN** `_input_buy` および `_input_sell` の本体行数は それぞれ概ね 5〜10 行程度であり、共通の `_handle_list_input` ヘルパーを呼んでいる

#### Scenario: ui_left/ui_right で tab 切替
- **WHEN** Buy または Sell モード中に ui_left または ui_right が押される
- **THEN** `_toggle_tab()` が呼ばれ、_rebuild が走る(buy / sell どちらでも同じ挙動)

#### Scenario: ui_accept で対応する処理が走る
- **WHEN** Buy モード中に ui_accept が押される
- **THEN** `buy(catalog[_selected_index])` が呼ばれる

#### Scenario: ui_cancel で TOP_MENU に戻る
- **WHEN** Buy または Sell モード中に ui_cancel が押される
- **THEN** `_mode = Mode.TOP_MENU` となり、`_selected_index = 0` にリセット
