## ADDED Requirements

### Requirement: セーブ JSON はインデントなしで書き出される
SHALL: `SaveManager.save()` は `JSON.stringify(data)` (インデントなし) で書き出す。タブ・改行を含むインデント形式は使用しない。これによりセーブファイルサイズを縮小する。読み込み側(`JSON.parse`)はインデントの有無に関係なくパースできるため、旧形式のセーブも問題なくロードできる。

#### Scenario: 新セーブはインデントなし
- **WHEN** `save(1)` を呼ぶ
- **THEN** `save_001.json` の内容にタブ文字('\t')および冗長な改行は含まれない

#### Scenario: 旧形式の save_*.json も読み込める
- **WHEN** タブ・改行を含む形式の `save_*.json` を `load()` する
- **THEN** `JSON.parse` がパースに成功し、ロードが成功する
