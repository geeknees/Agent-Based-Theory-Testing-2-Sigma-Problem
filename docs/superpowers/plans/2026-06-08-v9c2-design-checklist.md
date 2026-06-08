# v9c2 設計チェックリスト

## 背景

v9c（run_id: b412cfdb-0522-4997-a47e-1738eb414f4b）の独立監査により、5つの方法論的
バグ・confound（F1-F5、詳細は `2026-06-07-v9-and-earlier-methodology-remediation.md`
参照）が判明した。このうち F1（corrective_note 静的）と F2（L6 scorer artifact）は
addendum による再採点で対処済み（[[v9c-methodology-addendum]] [[v9b-methodology-addendum]]
参照）。残る項目は構造的修正 + 再実行が必須であり、v9c2 の設計に先行して解決すべき
依存関係を持つ。

なお、v4-v8 の同型監査（[[v4-v9c-replication-confound-audit-table]]、
[[v4-v6-methodology-addendum]]、[[v7a-v7b-methodology-addendum]]、
[[v8-methodology-addendum]]）の結果、F4（pseudoreplication）と F5b
（teacher/tutor/evaluator 単一性）は v4 から一貫して存在するフレームワーク全体の
構造的特徴であることが判明している。これは「v9c 固有の欠陥」ではなく
「フレームワークが歴史的に抱えてきた負債」であり、v9c2 で修正すれば
それ以降の全バージョンに恩恵がある、という位置づけで読むべきである。

## 再実験でしか直せない項目（集約結果、Task 12）

addendum による事後的な再採点・文書化では救えず、コード変更 + 再実行が
必須と判断された項目を、対象バージョン・最小再現条件・概算トークンコストとともに
以下に列挙する。

### 1. discussion participant への lesson/memory 注入（F3 修正）

- **対象**: `Phases::SizedDiscussion`（v9b, v9c）, `Phases::WholeClassDiscussion`（v8 WCD）
- **最小再現条件**: 修正後、called_on learner の初発話が「ルールを前提とした」
  内容に変わることを 1 session の smoke で目視確認する必要がある → 再実行必須
- **根拠**: v9c・v9b の transcript で、called_on された learner の初発話が全
  discussion 条件で一貫して「ルールを持っていない」内容になっていることを実証済み
  （[[v9c-methodology-addendum]] セクション 4、[[v9b-methodology-addendum]] セクション 4）。
  v8 の WCD では逆に「lesson を与えられていないのに正確なルールを再現する」という
  予想外の挙動が確認されており（[[v8-methodology-addendum]] セクション 4）、F3 の
  影響がバージョンによって非対称に現れている可能性がある——いずれにせよ
  discussion participant への情報アクセスはコードレベルで統一・明示化すべきである。
- **概算トークンコスト**: 既存 v9c 規模で再実行可能 → 約 632k トークン

### 2. discussion の反復化（F4 是正、N_disc ≥ 5）

- **対象**: `Phases::Classroom` / `WholeClassDiscussion` / `SmallGroupDiscussion` /
  `SizedDiscussion` を使う全バージョン・全 discussion/classroom 条件
  （[[v4-v9c-replication-confound-audit-table]] で `unique_discussions = 1`
  または部分的 pseudoreplication と判定された条件すべて）
- **最小再現条件**: 同一 condition で discussion インスタンスを複数回独立に走らせ、
  discussion-level mean を unit of analysis とする集計に変更する必要がある
  → コード変更 + 再実行必須（既存データの再集計では SE が定義できない —
  「N=1 の discussion に対する learner 反応の分散」と「条件効果の不確実性」は
  数学的に異なる量であり、後者は前者からは導出できない）
- **根拠**: v4 から v9c まで一貫して classroom 系条件で `unique_discussions = 1`
  が観測された（[[v4-v9c-replication-confound-audit-table]] まとめ表）。
  v8 の `lecture_plus_*` discussion 条件も部分的 pseudoreplication
  （8 セッション中 2〜5 種類のユニーク transcript）を示しており、バージョンが
  進むにつれて「discussion を1回だけ生成して共有する」方向に構造が変化していった
  可能性がある。
- **概算トークンコスト**: discussion phase ×5 → +約 1.0M トークン
  （v9c 本番 run の discussion phase 実測比率 ~40% = 約 253k トークンを基準に
  253k×4 ≈ 1.0M を追加。合計で約 1.6M〜1.8M トークン規模）

### 3. evaluator/moderator/teacher/tutor の triplication（F5b 是正）

- **対象**: 全バージョン（[[v4-v9c-replication-confound-audit-table]] で
  `classroom_teacher` / `tutor` / `evaluator` がいずれも単一インスタンスと
  判定されている — v4・v5・v6・v7a・v7b・v8・v9b・v9c の全 8 run で確認済み）
- **最小再現条件**: 複数 evaluator インスタンスでの再評価が必須 → 再実行必須
  （事後的な複数回採点では、同一 evaluator の non-determinism と複数 evaluator
  間の系統的な傾向差を区別できない）
- **根拠**: 本監査でカバーした全 8 run（v4, v5, v6, v7a, v7b, v8, v9b, v9c）
  すべてで `classroom_teacher` と `evaluator` が単一インスタンスと判定された
  （v9b/v9c は `tutor` 役自体が存在しない設計のため対象外）。これは個別バージョンの
  欠陥ではなく、フレームワーク発足時から続く構造的な特徴である。
- **概算トークンコスト**: evaluation phase ×3 → +約 750k トークン
  （v9c 本番 run の evaluation phase 実測値 376,442 トークンを基準に ×3 ≈ 1.13M、
  既存の単一評価分を差し引いた追加分として +約 750k と見積もる）

### 4. lecture_only の学習時間/トークン予算の公平性（F5c 是正）

- **対象**: v9b, v9c（`lecture_only` に discussion 相当の self-study phase が無く、
  `learning_sessions` 行数が 0 件であることを確認済み — [[v9c-methodology-addendum]]
  セクション 3、[[v9b-methodology-addendum]] セクション 3）
- **最小再現条件**: self-study phase を新設するか、token-cost-normalized score を
  主指標化するかの設計判断 + 再実行が必要
- **概算トークンコスト**: 設計判断に依存するため、設計確定後に見積もる

### 5. v8 WCD/SGD の lesson 注入を統一する（v8 固有の confound 是正）

- **対象**: v8 のみ
- **最小再現条件**: 両 discussion 形式で同じ情報アクセス構造（lesson を learner
  contribution に渡すか渡さないか）に揃えてから再比較する必要がある → 再実行必須
- **根拠**: コード上、`whole_class_discussion.rb:41` の learner `contrib_prompt`
  は lesson 無し、`small_group_discussion.rb:36` の round 1 `contrib_prompt` は
  lesson 有り、という非対称が確認された（[[v8-methodology-addendum]] セクション 4）。
  しかも実際の transcript では、この非対称が「予想された形」（WCD でルール崩壊）
  ではなく「予想されない形」（WCD 学習者が lesson 無しで一字一句に近い精度で
  ルールを再現）で現れており、現状のままでは「WCD (83%) > SGD (68%)」という
  結果が教育法の効果を示しているのか、別の交絡（学習者集団の能力、moderator の
  介入の質など）を示しているのかを判別できない。
- **概算トークンコスト**: 設計判断（どちらの形式に揃えるか）に依存するため、
  設計確定後に見積もる。既存 v8 規模（全体で約 220k トークン台と推定）から
  大きく外れない可能性が高い。

## 依存グラフ

```
A0 (discussion context injection 修正)
  ↓
A3 (N_disc ≥ 5 反復化、discussion-level 集計への変更)
  ↓
A4 (learner profile 多様化 — v9c は既に4型混在のため対応不要、確認のみ)
A5 (evaluator triplication)
A6 (lecture_only の学習時間公平性)
  ↓
新規研究条件（Hybrid lecture / ambiguity-of-call 等）
```

A0 が解決しない限り、discussion の内容そのものが「lesson を前提としない、
忘却状態からの回復」という別物を測り続けることになるため、A3 で反復回数を
増やしても「再現性の高い、しかし誤った量」を測定するだけになる。したがって
A0 → A3 の順序は必須。A4・A5・A6 は互いに独立しており、並行して設計・実装してよい。

## 優先度付きチェックリスト

### P0: A0 — discussion participant context への lesson/memory 注入

- [ ] `lib/phases/sized_discussion.rb` の `contrib_prompt` の `context` に
      最新の learner memory（rules/examples/edge_cases/corrected_misconceptions）
      を注入する
- [ ] 修正後、1 session の smoke run で called_on learner の初発話が
      「ルールを前提とした」内容に変わることを目視確認する
- [ ] 同じ修正を `lib/phases/whole_class_discussion.rb` にも適用する
      （v8 由来の同型バグ。`contrib_prompt` の `context` に lesson または
      learner memory を追加する）

見積もりトークン: 既存 v9c 規模で再実行可能 → 約 632k トークン

### P0: A3 — discussion の反復化（N_disc ≥ 5）

- [ ] 各 condition で discussion を独立に N_disc 回走らせる設計に変更する
- [ ] 集計の unit of analysis を「discussion-level mean」に変更し、
      learner は nested observation として扱う
- [ ] `lib/report.rb` の Score Variance セクションを discussion-level の
      SD/CI を計算する形に変更する

見積もりトークン: discussion phase ×5 → 既存 +約 1.0M トークン
（合計で約 1.6M〜1.8M トークン規模）

### P1: A5 — evaluator の triplication

- [ ] evaluator agent を3インスタンス化し、median score と
      agreement（Krippendorff's α か簡易一致率）をレポートに含める
- [ ] 同様の triplication を `classroom_teacher` / `tutor` にも適用するかどうか、
      コスト対効果を検討する（[[v4-v9c-replication-confound-audit-table]] の
      とおり、これは v4 から続く全バージョン共通の構造的課題である）

見積もりトークン: evaluation phase ×3 → +約 750k トークン

### P1: A6 — lecture_only の学習時間公平性

- [ ] 設計判断: (a) token-budget 統制で self-study reflection phase を
      追加する／(b) token-cost-normalized score を主指標に格上げする
      のいずれかを選択する
- [ ] 選択した設計を反映し、報告セクションを更新する

見積もりトークン: 設計確定後に見積もる

### P1: A7 — v8 由来の WCD/SGD lesson 注入統一（v8 再実験を行う場合のみ）

- [ ] v8 を再実験する計画がある場合、WCD と SGD の participant prompt の
      lesson アクセス構造を統一してから再比較する
- [ ] 統一後も「WCD 学習者が lesson 無しでルールを再現できる」という現象が
      再現されるかどうかを確認する（再現されれば、それ自体が独立した
      興味深い研究テーマになりうる — 「最小限の手がかりからの自己無撞着な
      ルール再構成能力」）

見積もりトークン: 設計確定後に見積もる（既存 v8 規模、約 220k トークン台から
大きく外れない可能性が高い）

### P2: 確認のみ（追加実装不要）

- [ ] A4: learner profile 多様化 — v9c は既に4型混在を確認済み
      （Task 2 の結果、[[v9c-methodology-addendum]] セクション 3）。
      v9c2 でも同じ config 設定を維持すればよい。外部ノートの F5a 記述は
      訂正済み（[[v9c-methodology-addendum]] 末尾「外部ノートへの訂正依頼」）

## 新 run 前のゲート条件

上記 P0 の A0・A3 が解決し、smoke run で動作確認が取れるまで、
v9c2 の本番 run には着手しない。これは F0（既存データ診断の固定化）
が完了済みであることが前提となる（本計画 `2026-06-07-v9-and-earlier-methodology-remediation.md`
の STEP 1/2 が該当 — 全 13 タスク完了済み）。

A0 → A3 の順序が逆転すると、「誤った量を高い再現性で測定する」という
無意味な反復になる点に特に注意する。
