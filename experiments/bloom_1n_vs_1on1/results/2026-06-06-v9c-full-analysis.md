# v9c Experiment 結果考察レポート（本番 run）— Readiness-Controlled Classroom Size & Ownership

**実験バージョン:** bloom_v9c_classroom_size  
**run_id:** b412cfdb-0522-4997-a47e-1738eb414f4b  
**実施日:** 2026-06-06  
**条件:** n=2〜16/条件 × 5 条件 = 34 学習者  
**学習者タイプ:** rule_extractor, edge_case_dropper, order_confused, passive_listener  
**モデル:** claude-sonnet-4-6（全フェーズ）  
**総トークン:** 631,955

---

## 1. 実験の目的と設計

### 中心的な問い

① 事前知識の準備状態（Readiness）を統制した上で、クラスサイズは学習アウトカムに影響するか？  
② Readiness が担保されれば、Ownership（能動的関与度）とアウトカムは相関するか？

### v9b からの変更点

v9b では lecture_only と pair_discussion_size_2 が同率最高スコア（60%）となり、Ownership とアウトカムの相関が観測されなかった。その解釈として「事前知識が不十分なため Ownership 効果が現れなかった可能性」が浮上した。

v9c はこの仮説を検証するため以下を変更した：

| 変更点 | v9b | v9c |
|--------|-----|-----|
| 講義 | LLM 生成（毎回再生成） | **固定リッチ講義**（6,493 chars、例5件） |
| Readiness チェック | 3タイプ（recall/edge_case/rule_interaction） | **4タイプ**（+procedure_order） |
| Readiness 統制 | なし | **80% 目標、達成しない場合は readiness_failed フラグ** |
| メモリ診断 | 6 items | **10 items**（+inactive_token/edge_case_checklist/debugging/common_mistake） |

### 条件設計

| 条件 | 名目クラスサイズ | called_on | n | Ownership（設計値） |
|------|--------------|-----------|---|-------------------|
| lecture_only | — | — | 4 | 0 |
| pair_discussion_size_2 | 2 | 全員 | 2 | 高 |
| small_class_discussion_size_4 | 4 | 全員 | 4 | 高 |
| medium_class_discussion_size_8 | 8 | 4人 | 8 | 中 |
| large_class_discussion_size_16 | 16 | 3人 | 16 | 低 |

全条件共通：固定講義（6,493 chars）→ Phase 2（4タイプ Readiness チェック）→ Phase 3（条件別インタラクション）→ Phase 4（評価 10 タスク）

---

## 2. 実験設計の確認

### 2.1 Readiness チェック結果

| Check Type | 受験数 | 正答数 | Pass Rate |
|------------|--------|--------|-----------|
| edge_case | 34 | 34 | **100%** |
| procedure_order | 34 | 20 | 59% |
| recall | 34 | 23 | 68% |
| rule_interaction | 34 | 17 | 50% |
| **全体** | **136** | **94** | **69%** |

**`readiness_failed: true`（69% < 80% 目標）**

v9b（recall 47%、rule_interaction 26%）と比較して：
- recall: **47% → 68%（+21pp）**
- rule_interaction: **26% → 50%（+24pp）**

固定講義の効果で事前知識の定着は明確に改善した。しかし 80% 目標には届かず。特に `rule_interaction`（50%）と `procedure_order`（59%）が低い。

`procedure_order` は v9c で初めて測定されたため v9b との直接比較はできないが、「活性化チェックをモディファイア適用より先に行う」という手順的知識の定着が 4 割の学習者で不十分であったことを示す。

### 2.2 Ownership 設計の検証

| 条件 | Avg Ownership Score | % Attempted | Avg Contributions |
|------|--------------------|-----------|--------------------|
| lecture_only | 0.0 | 0% | 0.0 |
| pair_discussion_size_2 | **3.0** | 100% | 2.0 |
| small_class_discussion_size_4 | **3.0** | 100% | 1.0 |
| medium_class_discussion_size_8 | 1.5 | 50% | 0.5 |
| large_class_discussion_size_16 | 0.56 | 19% | 0.2 |

v9b と同一の設計値が得られた。Ownership の操作化は正常に機能している。

---

## 3. 結果

### 3.1 条件別正答率（メイン結果）

| 条件 | n | Attempts | Correct% | Std Dev |
|------|---|---------|---------|---------|
| pair_discussion_size_2 | 2 | 20 | **65%** | 0.071 |
| small_class_discussion_size_4 | 4 | 40 | **57%** | 0.126 |
| large_class_discussion_size_16 | 16 | 160 | 52% | 0.168 |
| medium_class_discussion_size_8 | 8 | 80 | 40% | 0.214 |
| **lecture_only** | 4 | 40 | **28%** | 0.096 |

**全体平均：48%**

### 3.2 タスクタイプ別スコア

| Task Type | Diff | large_16 | **lecture** | medium_8 | **pair_2** | small_4 |
|-----------|------|----------|------------|---------|----------|--------|
| recall | L1 | 63% | **0%** | 75% | **100%** | **100%** |
| edge_case | L2 | 41% | 25% | 25% | **75%** | 50% |
| rule_interaction | L3 | 69% | **0%** | 38% | **100%** | 75% |
| debugging | L4 | 35% | 25% | 17% | 33% | 33% |
| debugging | L5 | 44% | 25% | 25% | **50%** | 25% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |
| explanation_choice | L7 | **100%** | 50% | 88% | **100%** | **100%** |
| peer_error_detection | L7 | **100%** | **100%** | **100%** | **100%** | **100%** |

### 3.3 Learner Type 別スコア

| Type | Correct% |
|------|---------|
| rule_extractor | **52%** |
| edge_case_dropper | **50%** |
| order_confused | 44% |
| passive_listener | 44% |

条件間最大差：37pp（pair 65% vs lecture_only 28%）  
Learner type 最大差：8pp（rule_extractor vs passive_listener）— v9b（21pp）より大幅縮小

### 3.4 Fine-Grained Memory Coverage（10 items）

| 条件 | blue | green | red | yellow | act_before | sum | inactive | ec_list | debug | mistake |
|------|------|-------|-----|--------|------------|-----|----------|---------|-------|---------|
| lecture_only | 100% | 100% | 100% | 100% | **100%** | **38%** | **100%** | **75%** | **75%** | **38%** |
| pair | 100% | 100% | 100% | 100% | **100%** | 17% | 50% | **100%** | **100%** | 0% |
| small | 100% | 100% | 100% | 100% | **100%** | 17% | **92%** | **92%** | 83% | 25% |
| medium | 100% | 100% | 100% | 100% | 96% | 17% | 79% | 67% | 88% | 0% |
| large | 100% | 100% | 100% | 100% | 90% | 10% | 65% | 69% | 75% | 17% |

全条件で blue/green/red/yellow/activation_before の 5 items は ≥ 90%。`final_summing`（sum）と `common_mistake_notes` の保持率が全条件で低い。

### 3.5 Fine-Grained Memory Delta（pre → post discussion）

| 条件 | Avg Acquired | Avg Lost | Avg Stable |
|------|:---:|:---:|:---:|
| large_class | **0.0** | **0.9** | 7.2 |
| lecture_only | 0.0 | 0.5 | **8.3** |
| medium_class | 0.1 | 0.5 | 7.4 |
| pair | 0.0 | 0.3 | 7.7 |
| small_class | 0.1 | **0.3** | **8.0** |

全条件で議論による新規獲得（Acquired）≈ 0。v9b と同じパターン。  
注目点：`large_class` の Lost = 0.9 が最大 — 大人数ディスカッションが既存の記憶を薄める可能性。

### 3.6 Interpretation Flags

| Flag | Value |
|------|-------|
| readiness_failed | **true** |
| ownership_effect_supported | true |
| class_size_effect_supported | false |
| lecture_only_dominant | **false** |
| discussion_added_value | **true** |

---

## 4. 考察

### 4.1 【最重要発見】lecture_only が最低スコア（28%）に転落

v9b では lecture_only = pair = 60%（全条件トップタイ）だったが、v9c では **lecture_only が全条件最低（28%）** となった。これは v9c 最大の驚きであり、設計変更の影響を示す重要なシグナルである。

**仮説 A: 固定講義 → マスタリーチェックのフィードバック効果が弱まった**

v9b では LLM が毎回講義を生成していた。この生成過程で教師エージェントが暗黙的にドメイン知識をより詳細に展開し、それが lecture_only 条件の高スコアを支えていた可能性がある。v9c の固定講義は確かに構造的・網羅的だが、LLM 生成特有の「応答的な説明の深さ」を持たない。

また、v9b の lecture_only が高スコアを取れた主因として「マスタリーチェックのフィードバックが記憶を強化した」という仮説があったが、v9c では Readiness チェックで corrective note が追加されても recall 0%・rule_interaction 0% という異常値が出ている。これは特定の n=4 の学習者プロファイルの組み合わせに起因する可能性が高い。

**仮説 B: n=4 のサンプリング誤差**

v9b の lecture_only は n=4 で 60% だった。v9c の lecture_only も n=4 で 28% という全問不正解に近い状況。recall と rule_interaction が **0%** というのは、たまたま order_confused・passive_listener の組み合わせが不利に働いた可能性が否定できない。

**仮説 C: lecture_only に固定講義は相性が悪い**

LLM 生成講義は問答的・インタラクティブな説明スタイルで記憶に残りやすい一方、固定テキストは「読む」だけで終わりやすく、記憶への定着が弱い可能性がある。lecture_only 条件はこの差を最も受けやすい。

### 4.2 Discussion 条件がこぞって lecture_only を上回った意味

```
pair(65%) > small(57%) > large(52%) > medium(40%) > lecture_only(28%)
```

`discussion_added_value: true`。これは v9b では見られなかった傾向であり、v9c の重要な知見候補である。ただし **readiness_failed: true** であるため、以下の解釈は暫定的である：

「固定講義＋Readiness チェックの組み合わせでは、lecture_only 単独より discussion が上回る」

この傾向が真であれば、**Bloom の 2-sigma 問題に対するひとつの答え** として、「インタラクティブな議論が記憶定着を助ける」というメカニズムの存在を示唆する。

### 4.3 【パラドックス】medium_class が pair より低い（40% vs 65%）

Ownership スコアが 1.5（中程度）の medium は、より低 Ownership の large（52%）より低いスコア。v9b でも同様のパターン（medium が最低）が観察されており、今回も再現した。

考えられる解釈：

**仮説: 「中途半端な関与」が最も不利**
- pair/small: 全員が話す → 理解を言語化する強制力がある
- large: 観察者が多いが、モデレーターの要約を静かに聞く → ある種の観察学習
- medium: 半数だけ呼ばれる → 呼ばれなかった学習者は「観察」でも「全員参加」でもない宙ぶらりな状態

この仮説はスモークテストでも同パターン（medium が低め）が観察されており、実験固有のノイズではない可能性がある。

### 4.4 クラスサイズ仮説（`class_size_effect_supported: false`）

discussion 条件だけ見ると：

```
pair(2) > small(4) > large(16) > medium(8)
```

単純な線形減少ではない。medium が large より低い時点でクラスサイズの単調効果は否定される。`class_size_effect_supported: false` は正しい判定。

ただし pair(2) > small(4) > large(16) の順は「サイズが小さいほど高い」仮説と整合する部分もある。medium の外れ値を除けば、部分的な支持は見られる。

### 4.5 Ownership × Score（`ownership_effect_supported: true`）

| 条件 | Ownership | Score |
|------|-----------|-------|
| pair | 3.0 | **65%** |
| small | 3.0 | 57% |
| medium | 1.5 | 40% |
| large | 0.56 | 52% |
| lecture_only | 0.0 | 28% |

Kendall-tau 一致（concordance > discordance）で `ownership_effect_supported: true`。lecture_only（Ownership=0）が最低スコアという事実が大きく寄与している。ただしこれは「Ownership がアウトカムを引き上げた」証拠ではなく、「Ownership=0 の条件が最も低い」という相関にすぎない。

### 4.6 `readiness_failed: true` の意味と次の一手

今回最も重要な制約は `readiness_failed: true`（69% < 80%）であり、すべての条件間比較は暫定的解釈にとどめなければならない。

特に rule_interaction（50%）と procedure_order（59%）の低さは：
1. **固定講義の不足** — worked examples が 5 件だが、rule interaction と procedure order をより明示的に繰り返す必要がある
2. **learner type の制約** — passive_listener の memory_budget（80 words）が短く、手順的知識が削られやすい
3. **Readiness チェック自体の難易度** — v9b では 3 問だったが v9c は 4 問。より多くの corrective note が追加される分、記憶が複雑化した可能性

---

## 5. v9b との比較

| 指標 | v9b（sonnet, n=34） | v9c（sonnet, n=34） |
|------|---------------------|---------------------|
| 全体平均 | 49% | **48%** |
| 最高条件 | lecture_only/pair: 60% | pair: **65%** |
| 最低条件 | medium: 45% | lecture_only: **28%** |
| lecture_only スコア | **60%** | **28%** |
| Mastery recall Pass Rate | 47% | **68%** |
| Mastery rule_interaction | 26% | **50%** |
| lecture_only_dominant | true | **false** |
| discussion_added_value | false | **true** |
| Token/correct answer | 3,732 | 3,901 |

**最大の変化：** v9b で最強だった lecture_only が v9c で最弱に転落。固定講義への切り替えと 4 タイプ Readiness チェックの追加が、lecture_only 条件の性質を根本的に変えた。

**改善した点：** Readiness pass rate の向上（recall +21pp、rule_interaction +24pp）。固定講義の効果は確認された。

---

## 6. 限界と解釈上の注意

1. **readiness_failed = true** — 69% < 80%。条件間差の因果的解釈は困難
2. **lecture_only n=4** — 特に recall 0%・rule_interaction 0% という異常値は n=4 のサンプリング誤差の可能性が高い
3. **pair n=2** — 65% というトップスコアも n=2 で信頼区間が極めて広い
4. **固定講義の副作用** — LLM 生成講義と固定テキストで学習プロセスが異なる可能性。特に lecture_only 条件への影響が大きい
5. **Readiness チェックの「二重計上」** — report.md の Readiness Summary と Mastery Check Score by Check Type は同一データを重複表示している（軽微な表示上の問題）

---

## 7. 次のステップ（優先順）

| 優先度 | 内容 | 理由 |
|--------|------|------|
| ★★★ | **v9c2: 固定講義の強化版**（rule_interaction/procedure_order の worked examples を 3〜5 件追加） | rule_interaction 50%・procedure_order 59% を 80% 超えに引き上げる。Readiness gate が有効に機能する条件での再実験が必要 |
| ★★★ | **lecture_only n を 8〜12 に増やす** | n=4 では recall 0%・rule_interaction 0% という異常値が統計的ノイズか本質かを判別できない |
| ★★ | **v9b vs v9c の lecture_only 比較を深掘り** | LLM 生成講義 vs 固定講義でなぜ lecture_only スコアが 60% → 28% に落ちたかを検証。Phase 2 の corrective note 数・内容を比較する |
| ★★ | **medium の低スコアの再現確認** | smoke/v9b/v9c の 3 run で medium が large より低いパターンが続く。called_on=4/8 の設計が構造的にこの結果を生むかを検証 |
| ★ | **pair の n を 8〜12 に増やす** | n=2 での 65% は信頼できない。pair の真の効果を測るために n を増やす |
| ★ | **report の Readiness Summary 重複を解消** | Readiness Summary と Mastery Check Score の内容が同一 — いずれかを削除または差別化する |

---

## 8. 総合解釈

v9c の知見を一言で言えば：

> **「固定講義に切り替えた結果、lecture_only は崩れ、discussion 条件が相対的に浮上した」**

しかしこの解釈は `readiness_failed: true` という制約の下にあり、強い主張は保留が必要である。Readiness 80% が達成された条件での再実験（v9c2 以降）があって初めて、以下の問いに答えられる：

> 「事前知識が十分に担保されたとき、クラスサイズと Ownership はアウトカムを説明するか？」

現時点での最も堅固な知見は：
1. 固定講義は LLM 生成講義より recall/rule_interaction の事前定着を改善する（+21〜24pp）
2. rule_interaction と procedure_order の定着には、さらに explicit な worked examples が必要
3. medium_class の低スコア（discussion 条件最低）は 3 run で一貫しており、構造的パターンの可能性がある
