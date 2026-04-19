## Context

現状の `DungeonScene` (`src/dungeon_scene/dungeon_scene.gd`) は単一の `StandardMaterial3D` に `SHADING_MODE_UNSHADED` + `vertex_color_use_as_albedo = true` を設定し、`CellMeshBuilder` (`src/dungeon/cell_mesh_builder.gd`) が生成する面の頂点色のみで描画している。法線は書き出されているがライト・環境光・フォグが存在しないため、シェーディングによる立体感や距離感のヒントが一切得られない。壁 0.70、床 0.15、天井 0.10 というパレットも極端で、明暗差が支配的な印象を与えている。

ImmediateMesh は毎フレーム再構築される構造だが、マテリアルの差し替えとライト/環境ノードの追加は `_ready()` で 1 度だけ行えば済む。UV は現在出力していない(`surface_set_uv()` が呼ばれない)ため、テクスチャ前提のシェーダは組めない。今回は world-space 座標を入力にした triplanar 的な手続きシェーダでこれを回避する。

## Goals / Non-Goals

**Goals:**
- 既存アセット(PNG)を追加せずにダンジョンらしい薄暗い雰囲気を実現する
- 距離による明るさ減衰(松明+フォグ)を実装し、奥行きを感じさせる
- 壁面にノイズ/煉瓦段パターンを描画して単調さを解消する
- タイル種別(壁/床/天井/扉/階段)の識別性は維持する
- `CellMeshBuilder` のテストは定数変更に追従するだけで済ませる

**Non-Goals:**
- 外部 PNG テクスチャの導入(D 案は別 change)
- UV 出力の追加
- ミニマップ・HUD・戦闘画面の描画改修
- Wizardry クラシック風(黒+線画)方向への路線変更
- 動的な松明ゆらぎ、光源強度のアニメーション(将来拡張)

## Decisions

### Decision 1: マテリアルは `ShaderMaterial` に差し替える
**選定**: `ShaderMaterial` + 自作 GDShader(`spatial` モード)に置換する。
**理由**:
- 手続き型ノイズ・煉瓦パターン・距離 AO は `StandardMaterial3D` の範疇を超える
- 単一シェーダで全タイル種別(壁/床/天井/扉/階段)を扱い、頂点色で種別を識別するのが最もシンプル

**却下した代替**:
- `StandardMaterial3D` の lit 化のみ → テクスチャ感を出せず「ただ暗いベタ塗り」になる
- タイル種別ごとに別マテリアル → 面ごとに surface が増えて ImmediateMesh との相性が悪い

**実装中の軌道修正**: 当初は Godot 標準の lit パスに乗せる前提だったが、Forward+ × `SubViewport` × `ImmediateMesh` × `material_override` の組み合わせでは `OmniLight3D` の寄与が描画に乗らず、視界が真っ黒になった(チューニングでは解消せず)。このため shader の `render_mode` を `unshaded` に切り替え、トーチ光・ambient floor・Lambert 風の face shading・距離 AO をすべてシェーダ内部で自前計算する方針へ変更した。`OmniLight3D` と `WorldEnvironment` のノードはスペックおよび fog・ambient の継続性のため残している(fog は `unshaded` サーフェスにも適用される)。

### Decision 2: 光源は Camera 子 `OmniLight3D` 1 基に絞る
**選定**: `Camera3D` の子として `OmniLight3D` を 1 つ追加。最終値は `light_color = Color(1.0, 0.88, 0.65)`、`omni_range = 10.0`、`light_energy = 4.0`、`omni_attenuation = 0.8`。実装では shader 側で視覚効果を自前計算しているため、この `OmniLight3D` は可視寄与よりスペック上の存在保証 (テストが camera 子の light を参照) と将来 lit パスに戻す余地を担う。
**理由**:
- プレイヤー視点の松明としてわかりやすい
- Omni 1 灯なら Forward/Mobile レンダラの負荷も軽い
- 距離減衰の美味しさが自然に乗る

**却下した代替**:
- DirectionalLight → ダンジョン内で方向光は違和感
- SpotLight → 横方向の壁が見えなくなり探索性を損ねる

### Decision 3: 環境は `WorldEnvironment` で Sky 無し + depth_fog
**選定**: `WorldEnvironment` を `DungeonScene` に追加。最終値は `background_mode = BG_COLOR` / `background_color = Color.BLACK`、`ambient_light_source = AMBIENT_SOURCE_COLOR`(既定の SKY ソースだと Sky 無しのとき ambient が 0 になるため明示する)、`ambient_light_color = Color(0.08, 0.08, 0.10)`(輝度 < 0.1 を維持)、`ambient_light_energy = 2.0`、`fog_enabled = true`、`fog_light_color = Color(0.03, 0.03, 0.05)`、`fog_density = 0.02`(深度フォグは淡く、遠くに溶け込ませる程度)。
**理由**:
- ambient をほぼ黒にすることで松明以外の部分が自然に沈む
- 深度フォグで奥の壁が暗く溶け込み、距離感が出る
- Sky 描画は不要(ダンジョンなので空は見えない)

### Decision 4: シェーダでは world-space の triplanar 的手法を使う
**選定**: UV 非対応のまま、フラグメントシェーダで `VERTEX`(世界座標)+ `NORMAL` を入力にし、平面ごとに適切な 2D 座標に射影してパターン計算する。
**理由**:
- 既存 `CellMeshBuilder` の出力契約(`surface_set_uv` 未使用)を崩さない
- axis-aligned の壁/床/天井のみなので、normal の絶対値が大きい軸を除いた残り 2 軸をそのまま使うだけで triplanar 相当になり、分岐は最小限
- 煉瓦段は壁の y 座標を整数化 + x/z を整数化してラインを描くだけで足りる

**却下した代替**:
- フル triplanar blending → axis-aligned のみで過剰
- UV 追加 → `CellMeshBuilder` 側の全面改修が必要になり、本 change のスコープを超える

### Decision 5: 距離 AO は `length(CAMERA_POSITION_WORLD - VERTEX)` で近似
**選定**: フラグメントシェーダで 1 - smoothstep(near, far, dist) を albedo に乗算する。`near=1.0`, `far=8.0` 程度。
**理由**:
- フォグと重なる部分はあるが、フォグは「遠くを特定色に寄せる」のに対し AO は「遠くの輝度そのものを下げる」ので重層的な暗さを作れる
- スクリーンスペース AO(SSAO)より軽く、小さな ImmediateMesh でも安定する

### Decision 6: タイル種別の識別は引き続き頂点色で行う
**選定**: `CellMeshBuilder` は従来どおり面ごとに `Color` を設定し、シェーダ側は `COLOR.rgb` をベースティント(石の基調色)として使う。種別ごとの色は暗めにリバランス:
| タイル | 旧 | 新(暫定) |
| --- | --- | --- |
| WALL | (0.70, 0.70, 0.65) | (0.55, 0.53, 0.48) |
| FLOOR | (0.15, 0.15, 0.20) | (0.28, 0.26, 0.24) |
| CEILING | (0.10, 0.10, 0.15) | (0.20, 0.19, 0.22) |
| DOOR | (0.60, 0.35, 0.10) | (0.45, 0.28, 0.12) |
| STAIRS | (0.55, 0.50, 0.40) | (0.48, 0.42, 0.34) |

**理由**:
- ライティング前で色を均しすぎると、松明で照らしたときに全部似たような暖色に染まってしまう
- 床を少し明るく、天井を少し暗くして自然な感覚に寄せる

### Decision 7: サーフェス種別は頂点色の alpha にフラグとして載せる
**選定**: `CellMeshBuilder` でタイル種別ごとに Face の `Color` の alpha を `STONE_ALPHA = 1.0` / `WOOD_ALPHA = 0.5` と使い分け、シェーダは `COLOR.a < 0.75` で木板パターンに分岐する。扉の RGB は現行パレット値(暖色ブラウン)のまま。
**理由**:
- ShaderMaterial は透過無しの opaque(`render_mode` に `blend_*` も `transparency` も指定していない)なので、`COLOR.a` は純粋なデータチャネルとして使え、描画アルファに影響しない
- RGB 成分からヒューリスティックに扉判定(例: `r - b > 0.25`)する案はパレット定数と結合してしまい、将来パレットを触ったときに扉検出が黙って壊れる。`CellMeshBuilder` が明示的にフラグを立てる方式だと契約が明文化される
- 追加の surface attribute(`UV2` や `CUSTOM0`)を `ImmediateMesh.surface_set_*` でセットするより既存 `surface_set_color` の活用で済み、書き出し側の差分が最小

**却下した代替**:
- RGB ベース検出(`(COLOR.r - COLOR.b) > 0.25`): パレットにカップリング、S1 警告の原因
- `UV2` / `CUSTOM0` 経由: `CellMeshBuilder` の面生成ループに余分な API を増やす

## Risks / Trade-offs

- **松明色で全体が暖色に染まる**: ambient をほぼ黒にするとこの傾向が強まる → fog_light_color をわずかに青寄せ(`Color(0.02, 0.03, 0.05)`)して補正する余地を残す
- **ImmediateMesh の毎フレーム再構築 × ShaderMaterial のコンパイル**: シェーダは 1 度だけコンパイルされ再利用されるため影響なし。ただしシェーダのユニフォームは毎フレームセットせず `_ready()` で 1 度だけでよい
- **distance AO とフォグが二重に暗くする**: 強度を両方弱めに始めて、スクリーンショット比較で調整する
- **既存スペック文言との齟齬**: 現行 spec は「WALL はグレー」「DOOR は茶色」と色を断定している。新パレットに更新する形で MODIFIED にする(意味的な区別:壁/扉の視認可能性は維持)
- **ヘッドレスCI でのシェーダ差分**: GUT のユニットテストは `CellMeshBuilder`(ジオメトリと色の生成)までしか検証しないので、シェーダ起因のビジュアル回帰は手動確認に頼る

## Migration Plan

1. パレット定数の更新 + 既存テストの期待値追従(最も小さい差分)
2. `ShaderMaterial` + `.gdshader` 新設、`DungeonScene._ready()` で差し替え(この時点ではライトなし、`unshaded` 相当のまま)
3. `OmniLight3D` を `Camera3D` に追加、シェーダを lit モードに切り替え(`render_mode` を規定値に)
4. `WorldEnvironment` 追加、fog/ambient を設定
5. シェーダに noise/brick/distance AO の順で積み増し、都度スクリーンショット比較
6. 必要に応じて最終的なバランス調整(定数ユニフォーム化して試行)

各ステップ後に `tmp/dungeon.png` を撮り直し、手動確認を 1 イテレーションとする。

## Open Questions

- 松明の `light_energy` と fog_density は実機で何度か調整が必要。→ **解決**: `light_energy = 4.0`, `omni_range = 10.0`, `omni_attenuation = 0.8`, `fog_density = 0.02` に確定(Decision 2/3 参照)。shader 側の `torch_energy = 1.8`, `torch_range = 8.0`, `ambient_floor = 0.55`, `distance_ao_min = 0.55` も同時に詰めた
- 階段(STAIRS)は手続きパターンを乗せるか、vertex color ベタでよいか。→ **解決**: ベタのままで進めた。ユーザ視認で違和感なしを確認済み
- Forward+ / Mobile / Compatibility のうちどのレンダラを対象にするか要確認。→ **部分解決**: プロジェクト既定の Forward+ で実装しビジュアル確認済み。Mobile/Compatibility への移植は未検証(シェーダは `unshaded` なのでライトパスの互換性は最小)
