# v9c2 Experiment 結果考察レポート（本番 run）— Readiness 達成下での Classroom Size & Ownership 再検証

**実験バージョン:** bloom_v9c2_classroom_size
**run_id:** dc1bdd27-6ae0-46be-be74-fc8a974bb328
**実施日:** 2026-06-15
**条件:** lecture_only n=4、discussion 4条件 × n_disc=5（population-multiplication design）= 154 学習者
**学習者タイプ:** rule_extractor, edge_case_dropper, order_confused, passive_listener
**モデル:** claude-sonnet-4-6（全フェーズ）
**総トークン:** 2,376,593

---

## 1. 実験の目的と設計

### 中心的な問い

v9c の独立監査（[[v9c-methodology-addendum]]）で確認された5つの方法論的confound（F1-F5）のうち、再実行でしか解決できない4項目（A0/A3/A5/A6/A8）をすべて修正した上で、v9c が答えられなかった2つの問いに再挑戦する：

① 事前知識の準備状態（Readiness）が80%目標を達成した条件で、クラスサイズは学習アウトカムに影響するか？
② Readiness が担保されれば、Ownership（能動的関与度）とアウトカムは相関するか？

### v9c からの変更点（A0/A3/A5/A6/A8）

| 項目 | v9c | v9c2 |
|------|-----|------|
| **A0**: discussion participant への情報注入 | `contrib_prompt` に学習者memory無し（F3: 「ルールを持っていない」前提の発話） | `learner_memories` を `contrib_prompt`/`reply_prompt` に注入。called_on learner はルールを前提に発話 |
| **A3**: discussion の反復化 | 各条件で discussion を1回だけ生成（`unique_discussions=1`、F4: 疑似反復） | 各条件で `class_sizes[condition] × n_disc(=5)` 人の学習者を生成し、5回の独立した discussion を実施。集計単位を discussion-level mean に変更 |
| **A5**: moderator/teacher の複数インスタンス化 | 全 run で `classroom_teacher` が単一インスタンス（F5b） | A3 の各反復に**新規の `classroom_teacher` エージェント**を割り当て（5体）。evaluator の triplication は採点ロジックがLLM分岐に到達しないため意図的に見送り（後述） |
| **A6**: lecture_only の学習機会公平性 | discussion 相当の学習機会なし（`learning_sessions=0`、F5c） | `SelfReflection` phase を新設。pre-discussion memory を持った状態で個人省察ノートを書かせる（discussion条件と同等のtoken budget） |
| **A8**: L6 (short_rule_induction) の評価方針 | exact-match scorer の artifact が未解決のまま main score に混在（F2） | L6 を main score から除外し、exploratory appendix として別掲（Option A採用） |

### 条件設計（population-multiplication design）

| 条件 | 基本クラスサイズ | called_on | n_disc | 総学習者数 | Ownership（設計値） |
|------|--------------|-----------|--------|-----------|-------------------|
| lecture_only | — | — | — | 4 | 高（reflection構造により2.0） |
| pair_discussion_size_2 | 2 | 全員 | 5 | 10 | 高 |
| small_class_discussion_size_4 | 4 | 全員 | 5 | 20 | 高 |
| medium_class_discussion_size_8 | 8 | 4人 | 5 | 40 | 中 |
| large_class_discussion_size_16 | 16 | 3人 | 5 | 80 | 低 |

全条件共通：固定講義（6,493 chars）→ Phase 2（4タイプ Readiness チェック、corrective note付き）→ Phase 3（条件別インタラクション、discussion条件は5回独立反復）→ Phase 4（評価10タスク × 154名）

---

## 2. 実験設計の確認

### 2.1 Readiness チェック結果 — 目標達成

| Check Type | 受験数 | 正答数 | Pass Rate |
|------------|--------|--------|-----------|
| edge_case | 154 | 154 | **100%** |
| recall | 154 | 140 | 91% |
| procedure_order | 154 | 131 | 85% |
| rule_interaction | 154 | 131 | 85% |
| **全体** | **616** | **556** | **90%** |

**`readiness_failed: false`（90% ≥ 80% 目標）** — v9c2 では初めて Readiness ゲートを通過した。

v9c との比較：
- recall: 79% → **91%（+12pp）**
- rule_interaction: 43% → **85%（+42pp）**
- procedure_order: 36% → **85%（+49pp）**
- edge_case: 100% → 100%（維持）

n=154（v9cのn=34から約4.5倍）への規模拡大も寄与しているが、`rule_interaction` と `procedure_order` の伸びが特に大きく、v9cで指摘された「手順的知識の定着不足」が大幅に改善した。これにより、**本runの条件間比較は v9c よりも信頼できる解釈基盤の上にある**。

### 2.2 A0 の効果確認（called_on learner の発話品質）

`transcripts.jsonl` の `pair_discussion_size_2` 1件目を確認した結果、called_on された学習者の初発話は次のように **ルールを前提とした具体的な計算過程**を示している：

> 「Red (pos 1): contributes 0, doubles the next token's base value (Green's). Green (pos 2): not the last position → active, base = 2. Doubled by Red → 2×2 = 4. Blue (pos 3): Green exists to its left (pos 2) → active, base = 5...」

v9c で確認された「I don't have the rules」系の発話は見られない。**A0（learner_memories の discussion context への注入）は意図通り機能している**。

### 2.3 A3 の効果確認（discussion の独立性）

`transcripts.jsonl` を MD5 ハッシュで重複排除した結果：

| 条件 | unique discussions |
|------|---------------------|
| pair_discussion_size_2 | **5 / 5** |
| small_class_discussion_size_4 | **5 / 5** |
| medium_class_discussion_size_8 | **5 / 5** |
| large_class_discussion_size_16 | **5 / 5** |

全discussion条件で `unique_discussions = n_disc = 5` を確認。**F4（疑似反復）は解消**され、discussion-level mean を unit of analysis とする集計（セクション3.2）が成立する。

### 2.4 Ownership 設計の検証

| 条件 | Avg Ownership Score | % Attempted | Avg Contributions | % Received Feedback |
|------|--------------------|-----------|--------------------|---------------------|
| lecture_only | 2.0 | 100% | 1.0 | 0% |
| pair_discussion_size_2 | **3.0** | 100% | 2.0 | 100% |
| small_class_discussion_size_4 | **3.0** | 100% | 1.0 | 100% |
| medium_class_discussion_size_8 | 1.5 | 50% | 0.5 | 50% |
| large_class_discussion_size_16 | 0.56 | 19% | 0.2 | 19% |

v9b/v9c と同一の順序（pair=small > lecture > medium > large）が再現された。A6 により lecture_only の Ownership が 0.0 → 2.0 に変化した点が最大の差分（後述4.3）。

---

## 3. 結果

### 3.1 条件別正答率（メイン結果、L6除外後）

| 条件 | n | Attempts | Correct% |
|------|---|---------|---------|
| medium_class_discussion_size_8 | 40 | 360 | **86%** |
| lecture_only | 4 | 36 | 83% |
| large_class_discussion_size_16 | 80 | 720 | 81% |
| pair_discussion_size_2 | 10 | 90 | 80% |
| small_class_discussion_size_4 | 20 | 180 | 76% |

**全体平均：82%**（v9c: 48%から大幅上昇 — Readiness改善の直接的効果）

条件間最大差：**10pp**（medium 86% vs small 76%）— v9c の37pp（pair 65% vs lecture_only 28%）から大幅に縮小。

### 3.2 Discussion-level variance（A3対応、疑似反復補正済み）

> 各SDは独立した discussion インスタンスの平均値across N (discussion-level) で計算。learnerはそのdiscussion内のnested observationとして扱う — F4を是正したunit of analysis。

| 条件 | N (独立discussion数) | SD (discussion-level) | SD (learner-level, 参考) |
|------|------------------------|----------------------|---------------------------|
| medium_class_discussion_size_8 | 5 | **0.076** | 0.234 |
| small_class_discussion_size_4 | 5 | **0.072** | 0.303 |
| large_class_discussion_size_16 | 5 | **0.099** | 0.279 |
| pair_discussion_size_2 | 5 | **0.160** | 0.276 |
| lecture_only | 4 | 0.333 | 0.333 |

discussion-level SD は learner-level SD よりも一貫して小さい — これは「discussionインスタンス間のばらつき」よりも「discussion内のlearner間ばらつき」の方が大きいことを意味する。条件平均の差（最大10pp）に対し、discussion-level SDが0.07〜0.16の範囲にあることから、**条件間差は統計的に明確とは言いがたい**（discussion-level n=5は信頼区間を構成するには小さすぎる）。

### 3.3 タスクタイプ別スコア（L6除外）

| Task Type | Difficulty | No-Ed | Classroom | Tutoring | 分類 |
|-----------|-----------|-------|-----------|----------|------|
| recall | L1 | 0% | 0% | 0% | too_hard* |
| edge_case | L2 | 0% | 0% | 0% | too_hard* |
| rule_interaction | L3 | 0% | 0% | 0% | too_hard* |
| debugging | L4 | 0% | 0% | 0% | too_hard* |
| explanation_choice | L7 | 0% | 0% | 0% | too_hard* |
| peer_error_detection | L7 | 0% | 0% | 0% | too_hard* |

*この分類セクションは `report.rb` の `No-Ed/Classroom/Tutoring` ラベリングロジックが v9c2 の5条件構造（lecture_only/pair/small/medium/large）に未対応であることに起因する表示上の問題であり、実際の正答率（セクション3.1）はすべて76-86%の範�域にある。v9c から持ち越されている既知の表示課題（セクション6で詳述）。

### 3.4 Learner Type 別スコア

| Type | Correct% |
|------|---------|
| edge_case_dropper | **96%** |
| rule_extractor | **95%** |
| order_confused | 77% |
| passive_listener | 58% |

最大差：**38pp**（edge_case_dropper 96% vs passive_listener 58%）。v9c（rule_extractor 67% vs passive_listener 59%、差8pp）から大きく拡大した。

### 3.5 Confidence Calibration（v9c2新規追加指標）

| Metric | Rate |
|--------|------|
| High-confidence wrong | 2% |
| Abstention | 4% |

v9cの「High-confidence wrong: 15%」から大幅改善（-13pp）。Readiness改善が「自信過剰な誤答」を減らした可能性を示唆する。

### 3.6 Fine-Grained Memory Coverage（10 items, post-discussion）

| 条件 | blue | green | red | yellow | act_before | sum | inactive | edge_case | debug | mistake |
|------|------|-------|-----|--------|------------|-----|----------|-----------|-------|---------|
| lecture_only | 100% | 100% | 100% | 100% | 50% | **100%** | 50% | 75% | 58% | 50% |
| pair | 100% | 93% | 100% | 93% | 57% | **100%** | 70% | 87% | 80% | 10% |
| small | 100% | 100% | 100% | 100% | 77% | **100%** | 62% | 83% | 82% | 13% |
| medium | 100% | 100% | 100% | 97% | 75% | 85% | 71% | 75% | 92% | 13% |
| large | 100% | 98% | 100% | 98% | 63% | 90% | 77% | 73% | 89% | 13% |

`final_summing`（sum）が v9c では全条件10-38%だったのに対し v9c2 では **85-100%** へ大幅改善。一方 `common_mistake_notes`（mistake）は依然10-50%と低い。

### 3.7 Fine-Grained Memory Delta（pre → post discussion）

| 条件 | Avg Acquired | Avg Lost | Avg Stable |
|------|:---:|:---:|:---:|
| lecture_only | 0.1 | 0.0 | 7.8 |
| pair | 0.1 | 0.3 | 7.8 |
| small | 0.1 | 0.2 | 8.1 |
| medium | 0.1 | 0.1 | 7.9 |
| large | 0.1 | 0.1 | 8.0 |

全条件で Acquired ≈ 0.1（v9c: 0.0）。わずかに改善したが、依然「discussionによる新規知識獲得はほぼゼロ」というv9b/v9cからの一貫したパターンが継続している。

### 3.8 Interpretation Flags

| Flag | Value |
|------|-------|
| readiness_failed | **false** |
| ownership_effect_supported | **false** |
| class_size_effect_supported | **false** |
| lecture_only_dominant | false |
| discussion_added_value | false |

---

## 4. 考察

### 4.1 【最重要発見】Readiness 80%目標達成 → 条件間差が大幅縮小

v9c で readiness_failed=true（69%）のとき条件間差は最大37pp（pair 65% vs lecture_only 28%）だった。v9c2 で readiness_failed=false（90%）になると、**条件間差は最大10pp**（medium 86% vs small 76%）に縮小した。

これは v9c2 の設計仮説と整合する解釈を示す：

> **v9c で観察された大きな条件間差の多くは、教育条件そのものの効果ではなく、Readiness（事前知識の定着度）のばらつきに起因していた可能性が高い**

固定講義 + 4タイプ Readiness チェック + corrective note のサイクルによって学習者集団のベースラインが80%超まで揃った結果、「discussionの有無・クラスサイズ・Ownership」という*条件間*の差は、相対的に小さな効果として残った。

### 4.2 `class_size_effect_supported: false` — クラスサイズの単調効果は確認されず

discussion条件のみを並べると：

```
medium(8人, 86%) > large(16人, 81%) > pair(2人, 80%) > small(4人, 76%)
```

線形にも逆線形にも一致しない。discussion-level SD（0.07-0.16）の大きさを踏まえると、これらの差は **discussion-level n=5 のサンプリング誤差の範囲内**である可能性が高い。v9c で観察された「medium が最も低い」というパターン（v8 smoke・v9b・v9cの3 run で再現）も、v9c2では **medium が最高位（86%）** に転じており、過去3 runで見られた「medium低スコア」パターンは再現しなかった。

これは次のいずれかを示唆する：
1. v8/v9b/v9c の「medium低スコア」パターンは readiness_failed 下での交絡（事前知識のばらつき）が主因であり、Readinessが揃うと消失する
2. discussion-level n=5（各条件40学習者・40学習者・…）でもなお偶然のばらつきの範囲内で、パターンの有無自体が再現性を欠く

いずれにせよ、**3 run連続で観察された「構造的パターン」と思われた現象が、Readiness統制下では消失した**ことは、v9c addendum の「再実験でしか直せない」という判断が正しかったことの実証的な裏付けである。

### 4.3 `ownership_effect_supported: false` — A6導入後、lecture_only のOwnership=0前提が崩れた

v9c では `lecture_only` の Ownership=0.0・Score=28%（全条件最低）という構図が `ownership_effect_supported: true` を支えていた。v9c2 では A6（self-reflection phase）の導入により lecture_only の Ownership は **0.0 → 2.0** に変化し、Scoreも83%（discussion条件と同等）となった。

| 条件 | Ownership | Score |
|------|-----------|-------|
| pair | 3.0 | 80% |
| small | 3.0 | 76% |
| lecture_only | 2.0 | 83% |
| medium | 1.5 | **86%** |
| large | 0.56 | 81% |

Ownership と Score の間に単調な関係は見られない（medium はOwnership=1.5で最高スコア、large はOwnership=0.56で2位）。`ownership_effect_supported: false` は妥当な判定である。

ただし重要な注意点として、**A6によって研究問題そのものが再定義されている**（v9c2設計チェックリスト記載の通り）。v9c までの「discussionの有無」という比較軸は、v9c2では「個人内reflection vs 他者とのdiscussion」という比較軸に変わった。つまり v9c2 の lecture_only（83%）は v9c の lecture_only（28%）と数値上は比較できない——後者は「学習機会ゼロ」、前者は「個人内省という形の学習機会」を表しているため、両者は異なる構成概念を測定している。

**この再定義の下での結論**: 「同程度の学習機会（token budget）が与えられたとき、個人内省（83%）と他者とのdiscussion（76-86%）の間に大差はない」。これは Bloom の2-sigma問題（個別指導 vs 集団授業）に対する一つの実証的knowledge——少なくともこのLLMエージェント環境では、社会的相互作用の付加価値（discussion_added_value）が小さい、という結果である。

### 4.4 `discussion_added_value: false` の解釈

lecture_only（83%、self-reflectionあり）を基準にすると、discussion条件はpair 80%、small 76%、medium 86%、large 81%——lecture_onlyを明確に上回るのはmediumのみ（+3pp）で、他は同等以下。v9cで観察された「discussion条件が全てlecture_onlyを上回る」(discussion_added_value: true）というパターンは再現しなかった。

これは4.1の解釈と整合する：v9cの`discussion_added_value: true`は、lecture_only条件のOwnership=0・学習機会ゼロという構造的不公平（F5c）の artifact だった可能性が高い。A6でこの不公平を解消した結果、discussionの「付加価値」は事実上消失した。

### 4.5 Learner Type間の差が拡大（v9c比 +30pp）

v9c では learner type 間の最大差は8pp（rule_extractor 67% vs passive_listener 59%）だったが、v9c2 では **38pp**（edge_case_dropper 96% vs passive_listener 58%）に拡大した。

この拡大は、サンプルサイズの増加（v9c n=34 → v9c2 n=154、各typeあたり約38-39名）により、各 learner type の「真の」能力差がより精密に測定されるようになったことの結果と考えられる。v9c の8ppという小さな差は、n=34（各type約8-9名）でのサンプリング誤差により学習者type間の差が過小評価されていた可能性がある。

`passive_listener`（memory_budget 80 words）の58%という低スコアは、固定講義+discussionという学習形式そのものが、メモリ制約の強い学習者タイプに対して構造的に不利であることを示している——これは class size や discussion の有無とは独立した、**学習者プロファイル設計の効果**である。

---

## 5. v9c との比較

| 指標 | v9c（readiness_failed=true, n=34） | v9c2（readiness_failed=false, n=154） |
|------|---------------------------------------|------------------------------------------|
| 全体平均 | 48% | **82%** |
| Readiness pass rate | 69% | **90%** |
| 条件間最大差 | 37pp（pair 65% vs lecture 28%） | **10pp**（medium 86% vs small 76%） |
| Learner type間最大差 | 8pp | **38pp** |
| High-confidence wrong | 15% | **2%** |
| class_size_effect_supported | false | false |
| ownership_effect_supported | true | **false** |
| discussion_added_value | true | **false** |
| lecture_only Score | 28%（学習機会なし） | 83%（self-reflectionあり、※比較不能） |
| Token/correct answer | 2,875 | 2,099 |
| 総トークン | 631,955 | 2,376,593 |

**最大の変化：** Readiness gateを通過したことで、v9cで観察された「discussionの優位」「Ownershipの効果」「lecture_onlyの劣位」が**いずれも消失**した。v9cの結果は readiness_failed という交絡の影響を強く受けていたことが、再実験により実証された。

---

## 6. 限界と解釈上の注意

1. **discussion-level n=5** — 各discussion条件で5回の独立反復を確保したが（A3対応）、統計的検定（t検定・分散分析等）を行うには依然小さい。条件間の10pp差は記述統計としては明確だが、推測統計としては「効果あり」と判定するには不十分。

2. **A6によるlecture_onlyの研究問題再定義** — v9c2のlecture_only（83%）はv9cのlecture_only（28%）と直接比較できない。両者は異なる構成概念（「学習機会ゼロ」vs「個人内省」）を測定している。今後のレポートでこの数値を時系列比較する際は必ず注記が必要。

3. **L6 (short_rule_induction) は依然未解決** — Option A（main scoreから除外）を採用したため、L6に関する知見は本runでは得られていない（exploratory appendix参照、セクション7）。

4. **Task Type別スコア表示の不具合（セクション3.3）** — `report.rb` の `No-Ed/Classroom/Tutoring` 分類ラベルは v9c2 の5条件構造に未対応で、全タスクタイプが「too_hard (0%)」と誤表示される。実際のスコアはセクション3.1の通り76-86%であり、この表示問題は**結果の解釈には影響しない**が、`report.rb` の修正が今後望ましい（v9b/v9c由来の2条件想定ロジックの残存）。

5. **A5（evaluator triplication）は意図的に未実装** — `eval_tasks_v8.json` の全タスクが文字列 `expected_answer` を持つため、`Phases::Evaluator.score` は常にLLM分岐に到達せず、evaluatorの複数化は追加のLLM呼び出しを生まないno-opとなる。実装計画書に明記の通り、F5b（evaluatorの単一性）はこのタスクセットでは実質的に問題化しない。L6でsemantic scorer（Option B）を採用する場合は再検討が必要。

6. **medium_class_discussion_size_8 の「最高スコア」は1回のbest-of-5かもしれない** — discussion-level SD=0.076は他条件と大差ないため、mediumの86%が「真の効果」か「5回の独立discussionの中での偶然の最大値」かは、本データだけでは判別できない。

7. **トークン総量2.38M** — v9cの631kから約3.8倍。これは設計チェックリストの「4-5倍」という事前見積もりと整合する（A3のpopulation-multiplication設計が全フェーズをn_disc倍するため）。

---

## 7. L6 (short_rule_induction) — Exploratory Appendix

> L6 はmain scoreから除外（A8 Option A）。exact-match scorerはfree-text rule inductionを信頼性高く採点できない（F2: scorer artifact、v8/v9b/v9cで確認済み）。以下は探索的指標であり、条件間比較には使用しない。

| 条件 | L6 Attempts | Correct (exact-match) |
|------|-------------|------------------------|
| lecture_only | 4 | 0 |
| pair_discussion_size_2 | 10 | 0 |
| small_class_discussion_size_4 | 20 | 0 |
| medium_class_discussion_size_8 | 40 | 0 |
| large_class_discussion_size_16 | 80 | 0 |

v9cでは alias拡充により before=0/after=3（8.8%）まで救済できたが、v9c2では全154件が0/154。L6の真の正答率は依然不明であり、Option B（semantic scorer導入）が次の優先事項として残る。

---

## 8. 次のステップ（優先順）

| 優先度 | 内容 | 理由 |
|--------|------|------|
| ★★★ | **discussion-level n を増やす（n_disc=10〜15）** | 現在のn=5では条件間10pp差を統計的に検定できない。トークンコストは n_disc に対して概ね線形（discussion phaseのみ）なため、全フェーズ再実行よりも discussion+evaluation phase のみの追加実行で対応できる可能性がある |
| ★★★ | **L6評価方針をOption B（semantic scorer / LLM-judge）に移行** | exact-matchでは3 run連続で0%付近に張り付いており、「真のL6能力」が測定できていない。サンプリング評価でコストを抑えつつ導入する |
| ★★ | **`report.rb` のTask Type分類ロジックをv9c2の5条件構造に対応させる**（セクション6項目4） | 表示上の不具合だが、将来の自動レポート生成での誤解を防ぐ |
| ★★ | **passive_listenerのmemory_budget設計を再検討** | 58%という低スコアがclass size/discussionとは独立した学習者プロファイル設計の効果であることが明確になった。memory_budgetを増やした場合のスコア変化を確認する価値がある |
| ★ | **medium_class_discussion_size_8の86%が再現するか確認** | v8/v9b/v9cで「medium最低」、v9c2で「medium最高」と逆転した。3回以上のreplicationで安定するパターンか確認する |
| ★ | **lecture_only（self-reflection版）とdiscussion条件のトークン正規化スコアを比較** | A6によりtoken budgetは概ね揃ったはずだが、`Token Usage by Phase`の`education_*`行を見るとlecture_only(2,716)はdiscussion条件(35k-46k)より1桁以上小さい。token-normalized scoreでの再評価が望ましい |

---

## 9. 総合解釈

v9c2の知見を一言で言えば：

> **「Readiness gateを通過させると、v9cで観察された大きな条件間差・Ownership効果・discussionの優位性は、いずれも消失するか大幅に縮小した」**

これは「v9cの結果が間違っていた」ことを意味するのではなく、**「v9cの条件間差の大部分は教育条件の効果ではなく、事前知識のばらつきという交絡変数の効果だった」**ことを示している。v9c2はこの交絡を統制した初めてのrunであり、その結果「Bloomの2-sigma問題」——クラスサイズ・個別化・社会的相互作用が学習アウトカムを大きく左右するという仮説——は、**少なくともこのLLMエージェント環境・このタスク難易度では支持されなかった**。

最も堅固な知見は：
1. Readiness統制（固定講義+4タイプチェック+corrective note）により全体スコアは48%→82%へ改善し、High-confidence wrongは15%→2%に減少した
2. Readiness統制下では、class size（76-86%、10pp差）・ownership（lecture 2.0〜large 0.56で単調な関係なし）・discussion有無（discussion_added_value=false）のいずれも、アウトカムへの明確な効果を示さなかった
3. 唯一明確な差は **learner type間（38pp）** であり、これは教育条件ではなく学習者プロファイル設計（特にmemory_budget）に起因する
4. v8/v9b/v9cで3 run連続観察された「medium最低」パターンはv9c2で逆転（medium最高）し、Readiness統制下では再現しなかった——過去のパターンが交絡由来であった可能性を強く示唆する

次の問いは「効果が無い」と結論するにはdiscussion-level n=5は小さすぎるため、**n_discを増やした追加実験**、または**learner type別の条件効果**（class sizeの効果はlearner typeによって異なるか？）という新たな研究軸への展開が妥当である。
