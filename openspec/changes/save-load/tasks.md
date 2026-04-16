## 1. シリアライズ層 - 基本データクラス

- [x] 1.1 PlayerState に to_dict() / static from_dict() を実装する
- [x] 1.2 ExploredMap に to_dict() / static from_dict() を実装する
- [x] 1.3 Character に to_dict() / static from_dict() を実装する（race/jobはファイル名IDで参照）
- [x] 1.4 Guild に to_dict() / static from_dict() を実装する（characters配列 + front_row/back_rowのインデックス参照）
- [x] 1.5 DungeonData に to_dict() / static from_dict() を実装する（seedからWizMap再生成）
- [x] 1.6 DungeonRegistry に to_dict() / static from_dict() を実装する

## 2. GameState拡張

- [x] 2.1 GameState に game_location プロパティ（String: "title"/"town"/"dungeon"）を追加する
- [x] 2.2 GameState に current_dungeon_index プロパティ（int, デフォルト -1）を追加する
- [x] 2.3 GameState.new_game() で game_location="town", current_dungeon_index=-1 にリセットするよう更新する
- [x] 2.4 main.gd の画面遷移時に GameState.game_location と current_dungeon_index を更新する処理を追加する

## 3. SaveManagerクラス

- [x] 3.1 SaveManager クラス（RefCounted）を作成し、save(slot_number) メソッドを実装する（GameState → Dictionary → JSON → ファイル書き出し）
- [x] 3.2 load(slot_number) メソッドを実装する（ファイル読み込み → JSON → Dictionary → GameState復元）
- [x] 3.3 list_saves() メソッドを実装する（user://saves/ を走査してメタ情報を返す、last_saved降順）
- [x] 3.4 get_last_slot() メソッドを実装する（last_slot.txt読み込み + ファイル存在チェック）
- [x] 3.5 get_next_slot_number() メソッドを実装する
- [x] 3.6 has_saves() メソッドを実装する
- [x] 3.7 delete_save(slot_number) メソッドを実装する
- [x] 3.8 GameState に save_manager プロパティを追加し、初期化する

## 4. 画面復元ロジック

- [x] 4.1 main.gd に _load_game(slot_number) メソッドを追加し、SaveManager.load() 後に game_location に応じた画面を表示する
- [x] 4.2 game_location="town" の場合の町画面復元を実装する
- [x] 4.3 game_location="dungeon" の場合のダンジョン画面復元を実装する（seedからWizMap再生成 + ExploredMap/PlayerState適用）

## 5. セーブ画面UI

- [x] 5.1 セーブ画面クラスを作成し、スロット一覧表示（番号、保存日時、パーティ名、最大レベル、現在地）を実装する
- [x] 5.2 「新規保存」項目を一覧の先頭に表示し、選択時に次の連番で保存する
- [x] 5.3 既存スロット選択時の上書き確認ダイアログを実装する
- [x] 5.4 CursorMenuによるスロット選択操作を実装する
- [x] 5.5 ESCキーで閉じる操作（back_requestedシグナル）を実装する

## 6. ロード画面UI

- [x] 6.1 ロード画面クラスを作成し、スロット一覧表示を実装する（セーブ画面と同一の表示形式）
- [x] 6.2 スロット選択時にload_requested(slot_number)シグナルを発行する
- [x] 6.3 セーブファイルが存在しない場合の「セーブデータがありません」表示を実装する
- [x] 6.4 ESCキーで閉じる操作（back_requestedシグナル）を実装する

## 7. ESCメニューとの統合

- [x] 7.1 ESCメニューの「ゲームを保存」を有効化し、選択時にセーブ画面を表示する
- [x] 7.2 ESCメニューの「ゲームをロード」を有効化し、選択時にロード画面を表示する
- [x] 7.3 セーブ完了後にESCメニューに戻る処理を実装する
- [x] 7.4 ロード選択後にESCメニューを閉じてゲーム画面を復元する処理を実装する

## 8. タイトル画面との統合

- [ ] 8.1 タイトル画面表示時にSaveManager.get_last_slot() と has_saves() を確認し、「前回から」「ロード」の有効/無効を切り替える
- [ ] 8.2 「前回から」選択時にcontinue_gameシグナルを発行し、main.gdで最終セーブをロードする
- [ ] 8.3 「ロード」選択時にload_gameシグナルを発行し、main.gdでロード画面を表示する
- [ ] 8.4 ロード画面からタイトル画面に戻る操作を実装する
