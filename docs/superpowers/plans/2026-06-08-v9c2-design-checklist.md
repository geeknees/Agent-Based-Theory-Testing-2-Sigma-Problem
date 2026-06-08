# v9c2 設計チェックリスト

## 背景

v9c（run_id: b412cfdb-0522-4997-a47e-1738eb414f4b）の独立監査により、5つの方法論的
バグ・confound（F1-F5、詳細は `2026-06-07-v9-and-earlier-methodology-remediation.md`
参照）が判明した。このうち F2（L6 scorer artifact）は addendum による再採点で
対処済みである（[[v9c-methodology-addendum]] [[v9b-methodology-addendum]] 参照）。
F1（corrective_note 静的テンプレート）はバグではなく構造的な設計上の制約であり、
再実験や修正の対象ではないと判断し、その旨を addendum に文書化することで対処した
（[[v9c-methodology-addendum]] セクション 5）。残る項目（F3-F5）は構造的修正 +
再実行が必須であり、v9c2 の設計に先行して解決すべき依存関係を持つ。

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

### 3. evaluator/moderator/teacher/tutor の複数インスタンス化（F5b 是正）

- **対象**: 全バージョン（[[v4-v9c-replication-confound-audit-table]] で
  `classroom_teacher` / `tutor` / `evaluator` がいずれも単一インスタンスと
  判定されている — v4・v5・v6・v7a・v7b・v8・v9b・v9c の全 8 run で確認済み）
- **最小再現条件**: 複数インスタンスでの再生成・再評価が必須 → 再実行必須
  （事後的な複数回採点では、同一インスタンスの non-determinism と複数インスタンス
  間の系統的な傾向差を区別できない）
- **根拠**: 本監査でカバーした全 8 run（v4, v5, v6, v7a, v7b, v8, v9b, v9c）
  すべてで `classroom_teacher` と `evaluator` が単一インスタンスと判定された
  （v9b/v9c は `tutor` 役自体が存在しない設計のため対象外）。これは個別バージョンの
  欠陥ではなく、フレームワーク発足時から続く構造的な特徴である。
- **優先順位の補足**: evaluator と moderator/teacher は対称な課題ではない。
  evaluator の単一性は「採点」という下流の一回だけに影響するのに対し、
  moderator/teacher の単一性は「discussion/lecture の生成そのもの」という
  上流に影響し、その偏りは transcript を経由して下流の評価結果にも伝播する。
  特に [[v8-methodology-addendum]] セクション 4 で確認された「WCD 学習者が
  lesson 無しで正確にルールを再現した」という未解明の現象は、moderator の
  介入の質が結果を支配していた可能性を示唆しており、v9c2 では moderator/teacher
  の複数インスタンス化を evaluator と同格、あるいはそれ以上の優先度として
  扱うべき根拠となる。
- **概算トークンコスト**: evaluation phase ×3 → +約 750k トークン
  （v9c 本番 run の evaluation phase 実測値 376,442 トークンを基準に ×3 ≈ 1.13M、
  既存の単一評価分を差し引いた追加分として +約 750k と見積もる。
  moderator/teacher 側のコストは A3（discussion 反復化）と統合実装すれば
  追加コストをほぼゼロに抑えられる——後述）

### 4. lecture_only の学習時間/トークン予算の公平性（F5c 是正）

- **対象**: v9b, v9c（`lecture_only` に discussion 相当の self-study phase が無く、
  `learning_sessions` 行数が 0 件であることを確認済み — [[v9c-methodology-addendum]]
  セクション 3、[[v9b-methodology-addendum]] セクション 3）
- **最小再現条件**: self-study phase を新設するか、token-cost-normalized score を
  主指標化するかの設計判断 + 再実行が必要
- **推奨設計案**: 「discussion の有無」ではなく「個人内 reflection か他者との
  discussion か」を比較軸にする self-study reflection phase を追加する。
  具体的には、lecture_only の learner にも discussion 条件と同じ pre-discussion
  memory（lesson 既読・readiness check 済みの状態）を持たせた上で、同じ task に
  ついて個人で reasoning note（自己説明）を書かせる：

  ```text
  lecture_only:
    pre-discussion memory + individual reflection / self-explanation
  discussion conditions:
    pre-discussion memory + discussion
  両条件:
    同程度の追加学習機会（トークン予算）を持つ
  ```

  **注意（研究問題の再定義であることを明示する）**: この設計変更は、単なる
  「公平性の是正」にとどまらず、研究問題そのものを「discussion は学習を促進するか
  （対 何もしない lecture_only）」から「同じ学習機会の量の下で、社会的討論は
  個人内省より効果的か（対 reflection を行う lecture_only）」へと再定義する
  ものである。これは confound 除去の方向としては正しいが、v9c2 のレポートでは
  「v9b/v9c の lecture_only との単純な数値比較はもはや成立しない（比較対象の
  構造が変わっているため）」ことを明記し、新しい比較軸として扱う必要がある。
- **概算トークンコスト**: 設計判断に依存するため、設計確定後に見積もる
  （上記の reflection phase 案を採用する場合、追加コストは discussion phase の
  代替であるため、lecture_only 条件の token 総量を discussion 条件と同程度に
  揃える形で見積もり可能）

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

### 6. L6 (short_rule_induction) の評価方針を確定する（F2 残存リスクの是正）

- **対象**: `eval_tasks_v8.json` を使う全条件（v9c2 もこれを継承する想定）
- **背景**: F2（scorer の exact-match artifact）はalias 拡充による再採点で
  部分的に対処したが、各 addendum が繰り返し指摘している通り、
  「修正後の真の L6 正答率は依然として不明」という状態は解消されていない
  （v9c: before=0/after=3 [8.8%]、v8: before=after=0、v9b: before=after=0 —
  alias リストが run ごとの言い換えパターンに過適合しており汎化しない。
  [[v9c-methodology-addendum]] セクション 1、[[v8-methodology-addendum]]
  セクション 1 参照）。このまま v9c2 を回しても、L6 のスコアは「信頼できる
  指標」にはならない。
- **最小再現条件**: 以下のいずれかを v9c2 開始前に確定する必要がある（再実行前の
  設計判断であり、再実行そのものは不要）：
  - **Option A（推奨）**: L6 を main score から除外し、appendix 扱いの
    探索的指標として報告する。v9c2 の主目的が class size / ownership の
    検証であるなら、信頼性が未確認の指標を主要結論に混在させるリスクを
    完全に排除できる、最も安価で安全な選択。
  - **Option B**: semantic scorer（embedding 類似度や LLM-judge）を
    sampled evaluation として導入し、exact-match と並記する。
  - **Option C**: 十分な acceptable_aliases を事前に拡充してから
    exact-match で採点する（汎化しない過去のパターンを踏まえると、
    最も労力対効果が低い選択肢）。
- **概算トークンコスト**: Option A は追加コストなし。Option B は
  evaluation phase に sampled judge 呼び出し分が追加される
  （規模は sampling 率に依存するため設計確定後に見積もる）。Option C は
  追加実行コストなし（事前のキュレーション工数のみ）。

## 依存グラフ

```
A0 (discussion context injection 修正)
  ↓
A3 (N_disc ≥ 5 反復化、discussion-level 集計への変更。
    各反復に異なる moderator/teacher インスタンスを割り当てれば、
    A5 の moderator/teacher 側も同じ実装変更で同時に解決できる)
  ↓
A4 (learner profile 多様化 — v9c は既に4型混在のため対応不要、確認のみ)
A5 (evaluator / moderator / teacher の複数インスタンス化)
A6 (lecture_only の学習時間公平性 — reflection phase 設計)
A8 (L6 評価方針の確定 — 主に設計判断、再実行不要)
  ↓
新規研究条件（Hybrid lecture / ambiguity-of-call 等）
```

A0 が解決しない限り、discussion の内容そのものが「lesson を前提としない、
忘却状態からの回復」という別物を測り続けることになるため、A3 で反復回数を
増やしても「再現性の高い、しかし誤った量」を測定するだけになる。したがって
A0 → A3 の順序は必須。A4・A5・A6・A8 は互いに独立しており、並行して設計・
実装してよい。ただし A5 のうち moderator/teacher 側は A3 の実装（独立反復化）
に統合すると効率が良い——個別に取り組む必要はない。

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
- [ ] 各反復に異なる moderator/teacher エージェントインスタンス（または
      seed/persona）を割り当てる設計にする（A5 の moderator/teacher 側を
      ここで同時に解消する——個別実装は不要）
- [ ] 集計の unit of analysis を「discussion-level mean」に変更し、
      learner は nested observation として扱う
- [ ] `lib/report.rb` の Score Variance セクションを discussion-level の
      SD/CI を計算する形に変更する

見積もりトークン: discussion phase ×5 → 既存 +約 1.0M トークン
（合計で約 1.6M〜1.8M トークン規模）

**A0 + A3 統合 smoke gate（本番投入前に必須）**

トークンコストが 1.6M〜1.8M 規模に達するため、本番 run の前に縮小規模の
smoke run で A0・A3 の組み合わせが意図通り機能することを確認する：

- [ ] `N_disc = 3`、条件は `lecture_only` / `pair`（2人）/ `large`（一斉討論）
      の3条件のみに絞った smoke run を実行する
- [ ] 3 つの discussion インスタンスの transcript が互いに独立している
      （byte-identical でない）ことを確認する
- [ ] called_on された learner の初発話が、lesson/learner memory 由来の
      ルール参照を含み、「I don't have the rules」系の発話が出ていないことを
      確認する（A0 の効果検証）
- [ ] report が learner-level ではなく discussion-level mean で集計されて
      いることを確認する（A3 の効果検証）

これらが確認できてから、はじめて `N_disc ≥ 5` の本番規模 run に進む。

### P1: A5 — evaluator / moderator / teacher の複数インスタンス化

- [ ] evaluator agent を3インスタンス化し、median score と
      agreement（Krippendorff's α か簡易一致率）をレポートに含める
- [ ] moderator / classroom_teacher については、A3 の独立反復化と統合
      実装する（各反復に異なるインスタンスを割り当てる）ことで、
      追加コストをほぼゼロに抑えつつ複数化する（[[v8-methodology-addendum]]
      セクション 4 で示された「moderator の介入の質が結果を支配しうる」
      という未解明の現象を踏まえると、evaluator 単独の triplication より
      優先度が高いと判断する）
- [ ] コストが許容範囲を超える場合は、evaluator の複数化を sampled
      evaluation（一部 task/condition のみ複数採点）に限定し、
      moderator/teacher 側の複数化を優先する
- [ ] `tutor` への適用要否は、v9c2 で `tutor` 役が存在するかどうかの
      設計次第で判断する（[[v4-v9c-replication-confound-audit-table]]
      のとおり、これは v4 から続く全バージョン共通の構造的課題である）

見積もりトークン: evaluation phase ×3 → +約 750k トークン
（moderator/teacher 側は A3 と統合実装するため追加コストはほぼ無視できる）

### P1: A6 — lecture_only の学習時間公平性

- [ ] 設計判断: 「discussion の有無」ではなく「個人内 reflection か
      他者との discussion か」を比較軸にする self-study reflection phase
      を追加する案（上記アイテム4の推奨設計案）を採用する
- [ ] lecture_only の learner にも pre-discussion memory を持たせた上で、
      同じ task について個人で reasoning note（自己説明）を書かせる
      phase を新設する
- [ ] 選択した設計を反映し、報告セクションを更新する。その際、
      「v9b/v9c の lecture_only との単純な数値比較はもはや成立しない
      （研究問題が再定義されているため）」ことを明記する

見積もりトークン: 設計確定後に見積もる
（reflection phase は discussion phase の代替として実装すれば、
lecture_only の token 総量を discussion 条件と同程度に揃えられる）

### P1: A8 — L6 (short_rule_induction) の評価方針

- [ ] L6 の扱いを v9c2 開始前に確定する: (a) main score から除外し
      appendix 扱いの探索的指標とする（推奨）／(b) semantic scorer /
      LLM-judge による sampled evaluation を導入する／(c) acceptable_aliases
      を事前に十分拡充してから exact-match で採点する、のいずれかを選択する
- [ ] 選択した方針をレポートの該当節に明記し、「L6 の真の正答率は
      過去 run（v8/v9b/v9c）では未確定だった」という経緯を記載する

見積もりトークン: (a)(c) は追加コストなし。(b) は sampling 率に依存するため
設計確定後に見積もる

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

## v9c2 smoke run の受け入れ基準

A0・A3（と、それに統合された A5 の moderator/teacher 側）の smoke run が
「合格」と言えるためには、以下をすべて満たす必要がある。これは A3 の
P0 チェックリストに記載した「A0 + A3 統合 smoke gate」の確認項目に加え、
A6・A8 の設計判断が反映されていることまで含めた、本番 run 着手可否の
最終判定基準である：

- [ ] called_on された learner の初発話に、lesson/learner memory 由来の
      ルール参照が含まれている
- [ ] 「I don't have the rules」系の、ルールを前提としない発話が
      出ていない
- [ ] 各 condition で `unique_discussions >= N_disc` になっている
      （`scripts/check_replication.py` で確認可能）
- [ ] report の unit of analysis が learner-level ではなく
      discussion-level mean になっている
- [ ] lecture_only に self-study reflection phase が実装されている、
      または token-normalized score が主指標として報告される設計に
      なっている（A6 の設計判断が反映済み）
- [ ] L6 (`short_rule_induction`) が main score から除外されている、
      または semantic scorer / sampled evaluation で採点される設計に
      なっている（A8 の方針が確定・反映済み）

## 新 run 前のゲート条件

上記 P0 の A0・A3 が解決し、smoke run で上記の受け入れ基準を満たすことが
確認できるまで、v9c2 の本番 run には着手しない。これは F0（既存データ診断の
固定化）が完了済みであることが前提となる（本計画
`2026-06-07-v9-and-earlier-methodology-remediation.md` の STEP 1/2 が該当
— 全 13 タスク完了済み）。

A0 → A3 の順序が逆転すると、「誤った量を高い再現性で測定する」という
無意味な反復になる点に特に注意する。
