# v7 Experiment A 結果考察レポート — Passive Listener Rescue

**実験バージョン:** bloom_v7a_passive_listener_rescue  
**run_id:** dd2fd888-0e7b-40a9-ad2a-abb6e9b8b6d1  
**実施日:** 2026-05-23  
**条件:** n=4/条件、全学習者 passive_listener 型  
**モデル:** claude-sonnet-4-6

---

## 1. 実験の目的

v6 で `passive_listener` 型が hetero_classroom (13%) より 1on1 (38%) で高スコアを示した。この差が「強制的なインタラクション」から来るのか「パーソナライゼーション」から来るのかを切り分けるため、3 条件を比較する。

| 条件 | 設計意図 |
|------|---------|
| classroom_public_qa | ベースライン：受動的受講のみ（passive_listener は質問しない） |
| classroom_forced_checkin | 共有授業 + 全員への強制的な個別理解確認 |
| one_on_one_tutoring | 診断-修正-再テストの個別セッション |

**解釈の枠組み：**
- `forced_checkin ≈ 1on1` → 利益は「強制的なインタラクション」であり、パーソナライゼーションは不要
- `forced_checkin < 1on1` → 個別適応（誤概念特定・修正）に追加の価値がある
- `public_qa > forced_checkin` → インタラクション自体が有害（講義の充実度が支配的）

---

## 2. 実験設計と確認事項

### 2.1 教育セッションの実際の長さ

実験ログから確認した実際の講義長：

| 条件 | 講義長（chars） |
|------|--------------|
| classroom_public_qa | 3,599 |
| classroom_forced_checkin | 1,022 |

**設計上の重要な問題：** `classroom_forced_checkin` の teacher prompt に `Under 200 words` という制約があったため、講義が大幅に短縮された。public_qa の講義は zarn_tokens ドメインの全ルールを体系的に説明しているが、forced_checkin の講義は概要のみに留まっている。

この差が結果の主要な交絡要因となっている可能性がある。

### 2.2 Passive_listener の classroom 挙動

`question_asking_probability = 0.0` のため：
- classroom_public_qa: 4 名全員が質問をスキップ（LLM 呼び出しなし）
- classroom_forced_checkin: 講義後、教師が各学習者に 1 問の確認問題を強制
- one_on_one_tutoring: 8 ターンの診断-修正-再テストセッション

---

## 3. 結果

### 3.1 条件別正答率（メイン結果）

| 条件 | Learners | 正答数 | 正答率 | Std Dev |
|------|---------|--------|--------|---------|
| classroom_public_qa | 4 | 28/32 | **88%** | 0.102 |
| classroom_forced_checkin | 4 | 17/32 | 53% | 0.120 |
| one_on_one_tutoring | 4 | 16/32 | 50% | 0.177 |

### 3.2 学習者個人別内訳

**classroom_public_qa（全員 passive_listener、質問なし）:**

| learner_id（先頭8桁） | 正解数 | 正答率 |
|---------------------|-------|--------|
| cfa45527 | 7/8 | 88% |
| 4b82e49a | 8/8 | 100% |
| 90b0c44d | 7/8 | 88% |
| 3ea352ea | 6/8 | 75% |

**classroom_forced_checkin（強制確認あり）:**

| learner_id | 正解数 | 正答率 |
|-----------|-------|--------|
| 1a441b3e | 5/8 | 63% |
| 661e3460 | 4/8 | 50% |
| f2119126 | 5/8 | 63% |
| 464ead8b | 3/8 | 38% |

**one_on_one_tutoring（個別チューター）:**

| learner_id | 正解数 | 正答率 |
|-----------|-------|--------|
| 132449e8 | 5/8 | 63% |
| 55fe2028 | 5/8 | 63% |
| 0e62feb9 | 4/8 | 50% |
| de3fcfe6 | 2/8 | 25% |

### 3.3 タスク種別正答率

| Task | 難易度 | public_qa | forced_checkin | 1on1 |
|------|--------|-----------|----------------|------|
| l1_recall_01 | L1 | 3/4 = 75% | 0/4 = 0% | 3/4 = 75% |
| l2_edge_case_01 | L2 | 4/4 = 100% | 4/4 = 100% | 4/4 = 100% |
| l2_edge_case_02 | L2 | 4/4 = 100% | 1/4 = 25% | 3/4 = 75% |
| l3_rule_interaction_01 | L3 | 3/4 = 75% | 2/4 = 50% | 0/4 = 0% |
| l4_debug_01 | L4 | 4/4 = 100% | 3/4 = 75% | 0/4 = 0% |
| l4_debug_02 | L4 | 4/4 = 100% | 4/4 = 100% | 4/4 = 100% |
| l5_debug_03 | L5 | 4/4 = 100% | 2/4 = 50% | 0/4 = 0% |
| l6_induction_02 | L6 | 2/4 = 50% | 1/4 = 25% | 2/4 = 50% |

**1on1 の顕著な弱点：** l3_rule_interaction(0/4)、l4_debug_01(0/4)、l5_debug_03(0/4) で全員不正解。これらのタスクは複数ルールの複合適用を要求する。passive_listener がチューターとのインタラクションに注力した結果、複合ルール適用の記憶が浅くなった可能性。

### 3.4 誤解修正・信頼度

| 指標 | public_qa | forced_checkin | 1on1 |
|------|-----------|----------------|------|
| 誤解修正率 | 0% | 0% | **75%** |
| 高確信・誤答率 | 20% | 20% | 20% |
| 棄権率 | 9% | 9% | 9% |

1on1 のみが誤解修正を行った（75%）。しかしスコアは forced_checkin とほぼ同等（50% vs 53%）であり、誤解修正がスコア向上に直結しなかった。

### 3.5 タスク種別 Ceiling 分類（修正版 report より）

report.rb のバグ修正後に再生成した report.md より（旧版は全て 0% で `too_hard` と誤分類されていた）：

| Task Type | 難易度 | No-Ed | Classroom | Tutoring | 分類 |
|-----------|--------|-------|-----------|---------|------|
| recall | L1 | 0% | 38% | 75% | condition_sensitive |
| edge_case | L2 | 0% | 81% | 88% | education_sensitive |
| rule_interaction | L3 | 0% | 63% | 0% | education_sensitive |
| debugging | L4 | 0% | 88% | 33% | condition_sensitive |
| short_rule_induction | L6 | 0% | 38% | 50% | condition_sensitive |

*注: Classroom = classroom_public_qa + classroom_forced_checkin の平均。Tutoring = one_on_one_tutoring。*

recall（L1）と debugging（L4）で条件による大きな差（`condition_sensitive`）。1on1 が recall では classroom を上回るが debugging では大幅に下回るという逆転が起きている。

### 3.6 トークンコスト

| フェーズ | Tokens |
|---------|--------|
| classroom_public_qa | 1,638 |
| classroom_forced_checkin | 10,396 |
| one_on_one_tutoring | 35,133 |
| memory | 18,037 |
| evaluation | 70,619 |
| **TOTAL** | **135,823** |

教育フェーズのコスト比：public_qa 1 に対し forced_checkin 6.3×、1on1 21.5×。

---

## 4. 仮説の検証

| 仮説 | 内容 | 結果 |
|------|------|------|
| forced_checkin ≈ 1on1 → 利益は強制インタラクション | | ✅ 53% ≈ 50%（差 3pp） |
| public_qa < forced_checkin | 受動聴講より強制インタラクションが有効 | ❌ public_qa(88%) >> forced_checkin(53%) |

第一仮説は支持された：forced_checkin と 1on1 はほぼ同等であり、「強制的な接触」と「パーソナライゼーション」の差は小さい。

第二仮説は完全に否定された：passive_listener は受動的に良質な講義を聞くだけで最高スコアを達成した。

---

## 5. 考察

### 5.1 講義長の交絡と真の解釈

classroom_public_qa の 88% は「インタラクションなしで高スコア」という驚くべき結果だが、その主因は講義の充実度である可能性が高い：

- public_qa の講義（3,599 chars）：全ルール体系的説明、多数の具体例
- forced_checkin の講義（1,022 chars）："Under 200 words" 制約により概要のみ

もし forced_checkin の講義長を public_qa と揃えた場合、結果は異なる可能性がある。現在の比較は「充実した講義（インタラクションなし）」vs「短い講義 + 確認問題」であり、純粋な「インタラクションの有無」の比較ではない。

### 5.2 Passive_listener が受動受講で高スコアを取れる理由

passive_listener 型の制約は：
- memory_budget_words = 80（少ない）
- edge_case_retention = 20%（多くを失う）
- question_asking_probability = 0.0（インタラクションなし）

にもかかわらず public_qa で 88% を達成した。この理由として考えられる：

1. **充実した講義の情報密度**：3,599 chars の講義は zarn_tokens の全ルールを繰り返し説明しており、passive_listener が 80 語のメモリに圧縮しても、評価タスクに必要なルールが残りやすい
2. **edge_case の影響が限定的**：eval_tasks で edge_case が必要なタスクは l2_edge_case_01/02 のみ。このうち l2_edge_case_01 は全条件で全員正解しており、edge_case の喪失は限定的
3. **記憶圧縮の質**：充実した講義からは LLM が質の高い 7 フィールド記憶を生成しやすく、80 語に圧縮しても核心ルールが残る

### 5.3 1on1 の失敗パターン

1on1 で 4 名全員が不正解だったタスク：
- l3_rule_interaction_01（ルール複合適用）
- l4_debug_01（L4 デバッグ）
- l5_debug_03（L5 デバッグ）

チューターは passive_listener の `forgets_edge_cases` 誤概念に集中するが、これらのタスクはエッジケースではなく**複合ルール適用順序**を要求する。チューターの誤概念ターゲットが評価タスクの要求とミスマッチしていた可能性。

また、de3fcfe6（25%）の極端な低スコアが平均を引き下げている。この学習者はセッション中にレート制限による中断が発生しており（5.5h 待機）、それが影響した可能性は排除できない。

### 5.4 v6 結果との比較

v6 の hetero_classroom での passive_listener の結果と比較：

| 比較 | v6 hetero_classroom | v7 public_qa |
|------|---------------------|-------------|
| passive_listener 正答率 | 13%（1/8） | 88% |
| 共有講義長 | 不明（hetero 条件） | 3,599 chars |
| 学習者数 | 1 名 | 4 名 |

v6 の 13% は n=1 の偶然変動と、hetero クラスでの講義が mixed type 全体向けに設計されていたことの影響が大きい。v7 の public_qa で passive_listener のみに最適化した講義（"受動聴講者向けに明示的に教えよ"という context）を受けたことで 88% に達した。

---

## 6. 方法論的課題

### 6.1 講義長の非対称性（設計バグ → 修正済み）

~~最重要課題。classroom_forced_checkin の lecture 指示 "Under 200 words" を削除し、public_qa と同等の講義長にすれば公平な比較ができる。~~

**対応済み（2026-05-23）:** `classroom_forced_checkin.rb` の lecture 指示から `"Under 200 words."` を削除。次回以降のランでは講義長の非対称性は発生しない。現在の Exp A 結果は「短い講義 + check-in」対「長い講義」の比較であり、check-in 効果の純粋な測定ではないという解釈上の制約は残る。

### 6.2 レート制限中断

1on1 セッション中（de3fcfe6）と evaluation フェーズで複数回のレート制限が発生。5.5h 待機後に再開する設計だが、モデルの状態変化がないため結果への影響は基本的にない。ただし同一ランが複数日にまたがる点は注意。

### 6.3 n=4 の限界

条件間の差 3pp（forced_checkin vs 1on1）は n=4 では 1 問の差に相当。統計的信頼性なし。

---

## 7. 次の実験への提案

| 優先度 | 提案 | 状態 |
|--------|------|------|
| ~~**最高**~~ | ~~**forced_checkin の lecture 指示から "Under 200 words" を削除して再実験**~~ | ✅ 修正済み（2026-05-23） |
| **高** | **Exp A を再実験（lecture 長を揃えた条件で）** | 未実施。現 Exp A は lecture 長が交絡しており forced_checkin の単独評価が不可能 |
| 高 | 1on1 の診断ターゲットを変更（誤概念→ルール総合理解） | 未実施。passive_listener の 1on1 失敗が誤概念ターゲットのミスマッチの可能性 |
| 中 | n を 8〜10 に増やす | 未実施。forced_checkin vs 1on1 の 3pp 差に統計的意味を持たせる |
| 低 | de3fcfe6 の 1on1 セッションのトランスクリプトを確認 | 未実施。レート制限中断が結果に影響したか確認 |

---

## 8. 結論

**Exp A の核心的知見（暫定的）：**

> `forced_checkin (53%) ≈ 1on1 (50%)` という結果は「passive_listener への利益は強制的なインタラクションから来ており、パーソナライゼーションからは来ない」という仮説と一致する。ただし `public_qa (88%)` の圧倒的高スコアは、講義長の差（3,599 vs 1,022 chars）という設計上の交絡があり、純粋な解釈ができない。

**確実に言えること：**
1. forced_checkin ≈ 1on1（差 3pp）— パーソナライゼーションの追加価値は小さい。**ただし本ランの forced_checkin は「強制インタラクション」条件として成立していない**: トランスクリプトの `checkin_correction` ターンは4名全員が `"Correct."` の8文字のみで、全員が確認問題に正答したため教師が伝えた矯正情報はゼロだった。実態は「短い講義 + 情報量ゼロの一往復」であり、この結論はインタラクション条件が成立しないまま導かれている（2026-08-09 セルフ査読 所見3）
2. passive_listener に特化した充実した講義（passive 指示あり）は非常に効果的（88%）
3. 1on1 は l3, l4_debug_01, l5 で全員失敗 — 誤概念修正特化が複合タスクカバレッジを犠牲にする

---

*生成日: 2026-05-23*  
*Exp A run_id: dd2fd888-0e7b-40a9-ad2a-abb6e9b8b6d1*
