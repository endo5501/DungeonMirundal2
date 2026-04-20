## Context

現行の `src/town_scene/town_screen.gd` は右カラムに `ColorRect` + `Label` を重ねて、`FACILITY_COLORS[selected_index]` に応じた単色を背景にしたプレースホルダを表示している。これは town-screen spec に「ColorRect with a Label」と明記されており、意図的な仮実装である。

ユーザーから 4 施設分の原画 (tmp/guild.png, shop.png, church.png, dungeon.png, いずれも 1536×1024 / RGB / 3-4 MB) が提供された。これを正規のアセットとして組み込み、プレースホルダを置き換える。

プロジェクトは Godot 4.x (GDScript)。アセット用のディレクトリは現状なく、`data/` には JSON データのみが置かれている。描画方式には Godot 標準の `TextureRect` を用いる。

## Goals / Non-Goals

**Goals:**
- 4 施設のイラストを `assets/images/facilities/` に配置し、TownScreen の右カラムに表示する。
- カーソル移動に合わせて画像が即時切り替わる。
- 施設名ラベルは画像上に残し、可読性を半透明背景などで確保する。
- 画像ファイルは VRAM/ディスク負荷を抑えるためリサイズ + 再圧縮する。
- 画像ロードに失敗した場合でも画面が壊れない (従来の ColorRect フォールバックを残す)。

**Non-Goals:**
- 他施設 (戦闘・ダンジョン内・ギルド内画面など) への画像導入。
- 画像のアニメーションや遷移エフェクト。
- 画像の多言語差し替え／差分解像度対応。
- 他の `data/images` 等への横展開 (将来検討)。

## Decisions

### アセット配置: `assets/images/facilities/`
- 採用: `assets/images/facilities/{guild,shop,church,dungeon}.png`
- 代替案: `src/town_scene/images/`（コロケーション）、`data/images/facilities/`（既存 data 配下）
- 理由: 今後モンスター絵やアイテム絵など画像アセットが増える可能性を考え、アセット専用のトップ階層を新設するのが拡張性に優れる。`data/` は JSON 専用のまま残す方が意図が明確。

### 画像のリサイズとフォーマット
- 採用: 幅 1024px 前後へリサイズ (アスペクト 3:2 を維持、例 1024×683)、PNG の最適化再エンコード。目標ファイルサイズは 1 枚あたり 1 MB 以下。
- 代替案: 元画像そのまま使用 / WebP 変換。
- 理由: Godot インポート時は内部で `.ctex` (圧縮テクスチャ) に再変換されるが、ソース PNG も Git で管理するためサイズが効く。WebP は Godot 4 でも読めるが、ツールチェーンの普及度と後からの差し替えやすさを優先して PNG を維持。リサイズ後も右カラム描画領域 (推定 700-1000px 幅) に対して十分な解像度。

### リサイズ手段
- 採用: macOS 標準の `sips` コマンドでリサイズ、続けて `pngcrush`／`oxipng` のいずれか利用可能なものか、Godot 側のインポート圧縮に委ねる。可能なら `oxipng` を使う。
- 代替案: 手作業 (GIMP/Photoshop)、Godot エディタ上でのインポート設定のみ。
- 理由: 再現性とコマンドラインでの自動化のため。tasks.md で具体的コマンドを明示。

### 表示方式: TextureRect + STRETCH_KEEP_ASPECT_COVERED
- 採用: `TextureRect.expand_mode = EXPAND_IGNORE_SIZE` + `stretch_mode = STRETCH_KEEP_ASPECT_COVERED`。右カラム全体を埋めつつアスペクト比を保持、はみ出した部分はクリップ。
- 代替案: `STRETCH_KEEP_ASPECT_CENTERED` (上下に黒帯)、`STRETCH_SCALE` (引き伸ばし)。
- 理由: 没入感を優先し領域を画像で埋めたい。クリップされるのは上下端のみで、主題は中央にある前提。もし主題が切れるような画像があれば個別に調整する余地は残す。

### ラベル表示: 画像上に半透明オーバーレイ
- 採用: 右カラム下部に `ColorRect` (半透明黒、`Color(0, 0, 0, 0.5)` 程度) を配置し、その上に施設名 `Label` を載せる。ラベルは白文字・中央寄せ・既存フォントサイズ 32 を流用。
- 代替案: 画像全面にラベルを重ねる (視認性低)、ラベル撤去 (施設識別の一貫性が落ちる)。
- 理由: spec で施設名表示を維持しつつ、画像の視認性とのバランスを取るため下部帯のみ暗くするのが標準的。

### ロード失敗時のフォールバック
- 採用: `load("res://assets/images/facilities/<name>.png")` が `null` を返す／`TextureRect.texture` に設定できない場合、従来どおり `ColorRect` を表示し `FACILITY_COLORS` を適用する。
- 理由: 画像ファイルの欠落や命名ミスでも画面が空白にならず、開発・デバッグ時の発見性を保てる。

### TownScreen の構造変更
- 採用: `_illustration_rect` (ColorRect) を残しつつ、新たに `_illustration_texture` (TextureRect) と `_illustration_overlay` (下部半透明帯) を追加。`_update_illustration()` で `texture` を切り替え、ロード失敗時は `TextureRect.visible = false` + `ColorRect.visible = true` に切り替える。
- 代替案: ColorRect を完全撤去。
- 理由: フォールバック方針との整合性。

### 画像パス管理
- 採用: `town_screen.gd` 内に `const FACILITY_IMAGES: Array[String]` を定義し `MENU_ITEMS` と同じインデックス順で並べる。画像リソースは `_ready()` 時に `load()` で事前ロードしキャッシュ。
- 代替案: `preload()` を使う。
- 理由: `load()` ならロード失敗を検知してフォールバック処理に分岐できる (`preload` はコンパイル時エラー)。メモリ上にはロード後に保持され続けるので実行時コストは無視できる。

## Risks / Trade-offs

- **リスク: リサイズ後の画質劣化** → 目標 1024px 幅は現実の描画領域より十分大きく、視認性は問題にならない想定。気になる施設画像があれば個別に 1280px で残す調整余地を持たせる。
- **リスク: `STRETCH_KEEP_ASPECT_COVERED` で主題がクリップされる** → 画像の主題が中央寄りであれば許容範囲。デザイン上不満がある施設だけ `CENTERED` に切り替えるスイッチを将来追加しうる (今回は対象外)。
- **リスク: Godot の `.godot/imported/` が膨らむ** → 一般的な PNG 数 MB 追加は許容範囲。`.gitignore` により `.godot/` は管理外。
- **リスク: 既存テストが画像差し替えで落ちる** → 既存の `tests/town/test_town_screen.gd` は存在しない。本 change で新規に画像関連のテスト (ロード成功・切替・フォールバック) を追加する。
- **トレードオフ: ColorRect フォールバックを残す** → コードがやや複雑になるが、本番環境でも開発環境でも壊れにくさを優先。

## Migration Plan

1. feature ブランチ (`feature/town-facility-images`) 上で作業。
2. `tmp/*.png` から `assets/images/facilities/*.png` にリサイズ・再圧縮して配置。
3. TownScreen を改修し、既存挙動 (signals / confirm_selection) を壊さないことを確認。
4. テスト追加・既存テスト実行。
5. `tmp/*.png` はリポジトリから削除 (もともと tmp/ は作業用)。
6. `openspec validate town-facility-images --strict` 通過後に PR → main マージ → `openspec archive town-facility-images`。

ロールバックは git revert で可能。spec 変更もコミット単位で元に戻せる。

## Open Questions

- 施設画像の主題位置 (`COVERED` でクリップされる領域) は許容できるか。実装後に目視確認し、問題があれば `CENTERED` への切り替えを検討する。
- ラベルのオーバーレイ高さは右カラム高さの何 % が妥当か。初期値 15% 程度で実装し、プレイして調整。
