# v9b Experiment 結果考察レポート（本番 run）— Classroom Size & Ownership

**実験バージョン:** bloom_v9b_classroom_size  
**run_id:** 772d2ce7-246a-467e-89ae-b63d02d39c85  
**実施日:** 2026-06-04  
**条件:** n=2〜16/条件 × 5 条件 = 34 学習者  
**学習者タイプ:** rule_extractor, edge_case_dropper, order_confused, passive_listener  
**モデル:** claude-sonnet-4-6（全フェーズ）  
**総トークン:** 619,507

---

## 1. 実験の目的と設計

### 中心的な問い

① クラスサイズが大きくなるほど学習アウトカムは下がるか？  
② Ownership（能動的関与度）はアウトカムと相関するか？

### 条件設計

| 条件 | 名目クラスサイズ | called_on | n | Ownership（設計値） |
|------|--------------|-----------|---|-------------------|
| lecture_only | — | — | 4 | 0 |
| pair_discussion_size_2 | 2 | 全員 | 2 | 高 |
| small_class_discussion_size_4 | 4 | 全員 | 4 | 高 |
| medium_class_discussion_size_8 | 8 | 4人 | 8 | 中 |
| large_class_discussion_size_16 | 16 | 3人 | 16 | 低 |

全条件共通：Phase 1（共有講義 11,094 chars）→ Phase 2（マスタリーチェック 3 問）→ Phase 3（条件別インタラクション）→ Phase 4（評価 10 タスク）

---

## 2. 実験設計の確認

### 2.1 マスタリーチェック

| Check Type | 受験数 | 正答数 | Pass Rate |
|------------|--------|--------|-----------|
| edge_case | 34 | 34 | **100%** |
| recall | 34 | 16 | 47% |
| rule_interaction | 34 | 9 | 26% |

recall・rule_interaction の正答率が低い（47%・26%）。v8（88%）と比較して依然低く、共有講義（11,094 chars）が rule 記述の網羅性において不十分だった可能性がある。ただし haiku 使用のスモーク run（29%・21%）よりは改善しており、**sonnet によるマスタリーチェックのフィードバック補正は機能している**。

### 2.2 Ownership 設計の検証

| 条件 | Avg Ownership Score | Avg Contributions | % Attempted |
|------|--------------------|--------------------|-------------|
| lecture_only | 0.0 | 0.0 | 0% |
| pair | **3.0** | 2.0 | 100% |
| small_class | **3.0** | 1.0 | 100% |
| medium_class | 1.5 | 0.5 | 50% |
| large_class | 0.56 | 0.2 | **19%** |

called_on_count による設計どおり。large_class の発言率 19%（3/16 人）は特に重要な観察点——「名目上クラスに所属しているが、ほぼ傍観者」という状態を再現できている。

---

## 3. 結果

### 3.1 条件別正答率（メイン結果）

| 条件 | n | Attempts | Correct% | Std Dev |
|------|---|---------|---------|---------|
| lecture_only | 4 | 40 | **60%** | 0.141 |
| pair_discussion_size_2 | 2 | 20 | **60%** | 0.0 |
| small_class_discussion_size_4 | 4 | 40 | 48% | 0.222 |
| large_class_discussion_size_16 | 16 | 160 | 47% | 0.158 |
| medium_class_discussion_size_8 | 8 | 80 | 45% | 0.107 |

**全体平均：49%**（167/340）

### 3.2 タスクタイプ別スコア

| Task Type | Diff | large_16 | **lecture** | medium_8 | **pair_2** | small_4 |
|-----------|------|----------|------------|---------|----------|--------|
| recall | L1 | 38% | **100%** | 75% | **100%** | 50% |
| edge_case | L2 | 34% | 25% | 13% | **0%** | 38% |
| rule_interaction | L3 | 44% | 75% | 75% | **100%** | 50% |
| debugging | L4 | 42% | 58% | 33% | **67%** | 33% |
| debugging | L5 | 69% | 75% | 38% | **100%** | 25% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |
| explanation_choice | L7 | **100%** | **100%** | **100%** | **100%** | **100%** |
| peer_error_detection | L7 | 94% | **100%** | 75% | **100%** | **100%** |

### 3.3 Learner Type 別スコア

| Type | Correct% |
|------|---------|
| rule_extractor | **58%** |
| edge_case_dropper | **59%** |
| order_confused | 39% |
| passive_listener | 38% |

type 間のギャップ：約 **20pp**。条件間のギャップ（最大 15pp）より大きい。

### 3.4 Memory Coverage

| 条件 | Avg Rules | Edge Cases (%) | Procedure (%) |
|------|-----------|----------------|---------------|
| lecture_only | 4.3 | **75%** | **100%** |
| large_class | 4.3 | 60% | 96% |
| medium_class | 4.2 | 46% | **100%** |
| pair | 4.0 | 50% | **100%** |
| small_class | 3.9 | 42% | **100%** |

lecture_only が edge_case 保持率最高（75%）。ディスカッション条件ではルール数は同程度だが edge_case 保持率が低下する傾向。

### 3.5 Memory Delta（議論による知識獲得）

全条件で **0.0**。議論フェーズを通じた新規知識獲得は検出されなかった。

### 3.6 誤概念修正率

| 条件 | Correction Rate |
|------|----------------|
| small_class | **92%** |
| large_class | 85% |
| medium_class | 83% |
| lecture_only | 75% |
| pair | 67% |

---

## 4. 考察

### 4.1 【最重要発見】lecture_only = pair（60%）が全ディスカッション条件を上回る

> **⚠️ 2026-08-22 セルフ査読による重大な留保 — 本節の結論は本文のままでは成立しない**
>
> 本レポートの4日後に作成された [[2026-06-08-v9b-methodology-addendum]] §4 が、
> **討論参加者に lesson も learner memory も注入されていなかった**ことを記録している。
> 4条件すべてで「I don't actually know the rules for Zarn tokens」型の発話が採取された。
> 根本原因は `scripts/run_experiment_v9b.rb:201` の `Phases::SizedDiscussion.run` 呼び出しに
> `learner_memories:` 引数が渡されていないこと（v9c も同様。**v9c2 で修正済み**）。
>
> したがって本節が測ったのは「議論すること自体の効果」ではなく、
> 「**ルールを持たない参加者による議論の効果**」である。
> 「議論すること自体が学習を改善するわけではない」という一般的主張の根拠には使えない。
>
> あわせて §2.1 のマスタリーチェックは recall 47%・rule_interaction 26%（全体 58%）であり、
> v9c 以降の readiness gate 基準（80%）を大きく下回る。本節の
> 「Phase 1–2 が既に十分な学習基盤を提供しており」という記述は §2.1 と矛盾する。
> 正しくは「**前提が確立していない集団で条件比較を行った**」状態である。

スモーク run から継続して確認された最大の発見。**Ownership が 0 の条件と、Ownership が最高（3.0）の条件が同率トップ**となった。

この結果が示すのは：

**「議論すること自体が学習を改善するわけではない」**

より正確には、共有講義 + マスタリーチェック（フィードバック込み）という Phase 1–2 の組み合わせが既に十分な学習基盤を提供しており、Phase 3 のインタラクションが**追加の価値を生み出せていない**可能性が高い。

### 4.2 クラスサイズ仮説は不支持

「サイズが大きくなるほどスコアが下がる」という仮説に対して：

```
pair(2) = lecture_only > small(4) > large(16) ≈ medium(8)
```

単純な線形関係は成立しない。small が large より高いのは v9b の設計上の違い（small は全員指名、large は 3/16 人のみ）に起因する可能性があるが、それでも両者の差は 1pp（48% vs 47%）に過ぎない。

また、**medium（called_on=4/8、50%発言）が最低スコア（45%）**であることは直感に反する。中途半端な Ownership（1.5）が、「全員参加」でも「完全傍観」でもない中途半端な学習状態を生んでいる可能性がある。

### 4.3 【パラドックス】edge_case (L2) で pair が 0%

> **〔2026-08-22 セルフ査読〕** 以下の仮説A・Cはいずれも「議論の中身」に原因を求めているが、
> その議論は §4.1 の留保のとおり**ルールを持たない状態で行われていた**。
> また pair は n=2・edge_case は2問なので、0% は **2名×2問=4試行がすべて外れた**という意味しかなく、
> §6 限界5 の「pair の n=2 は統計的に無意味」という自己評価と、3仮説を立てる本節の扱いは整合しない。

最も興味深い異常値：

| 条件 | edge_case L2 Correct% |
|------|----------------------|
| pair | **0%** |
| medium | 13% |
| lecture_only | 25% |
| large | 34% |
| small | 38% |

マスタリーチェックでは edge_case が 100% 正答にもかかわらず、評価タスクでは pair が全問不正解。考えられる解釈：

**仮説A: pair の議論が edge_case を扱わなかった**  
ペア議論は自由度が高く、双方が edge_case より基本ルールを優先して議論した結果、edge_case の記憶が薄れた可能性（Memory Coverage: pair の edge_case 50%）。

**仮説B: n=2 のサンプリング誤差**  
pair は学習者が 2 名しかいないため、たまたま edge_case が苦手な組み合わせだった可能性は否定できない（rule_extractor + edge_case_dropper のペア）。

**仮説C: ペア議論が誤った理解を強化した**  
2 人の learner が同じ誤解を共有・強化し合う「誤った合意」が生じた可能性。peer learning のリスクとして知られる現象。

### 4.4 Ownership-Score 不一致の深刻さ

| 条件 | Ownership | Score |
|------|-----------|-------|
| lecture_only | 0.0 | 60% |
| pair | 3.0 | 60% |
| small | 3.0 | 48% |
| medium | 1.5 | 45% |
| large | 0.56 | 47% |

Ownership と Score の相関はほぼゼロ（むしろ負の関係すら見られる）。

ただしこの結果は「Ownership が無意味」ではなく、**Ownership が効果を発揮する条件が整っていない**ことを示唆する可能性がある：

- 議論の質（haiku でなく sonnet でも）が学習定着に繋がる深さに達していない
- Ownership が高くても、議論内容が既知事項の確認に留まり、新規学習が発生していない（Memory Delta = 0 が裏付ける）
- Phase 2（マスタリーチェック）が既に誤りを修正しており、Phase 3 では修正すべき誤概念が残っていない

### 4.5 Learner Type 効果 > 条件効果

条件間の最大差：15pp（lecture_only/pair 60% vs medium 45%）  
Learner type の最大差：**21pp**（edge_case_dropper 59% vs passive_listener 38%）

**学習者の認知スタイルが条件の設計効果を上回っている。** これは v7・v8 でも一貫して観察されてきた。特に order_confused と passive_listener の低さは構造的——この 2 タイプは追加インタラクションがあっても改善されにくい。

### 4.6 Memory Delta がすべて 0 という意味

全条件で議論による新規知識獲得が検出されなかった。これは：

1. **講義 + マスタリーチェックが記憶の天井を形成している**——Phase 3 以降に学べることが少ない
2. **議論の内容が知識の新規追加でなく確認・整理に留まる**——MemoryDiagnostics が「新規獲得」として検出する変化が生じない
3. **あるいは MemoryDiagnostics の感度不足**——細かな記憶の洗練が数値に現れていない可能性

---

## 5. v8 との比較

| 指標 | v8（sonnet, n=4/条件, 4条件） | v9b（sonnet, n=2〜16/条件, 5条件） |
|------|------------------------------|----------------------------------|
| 全体平均 | **74%** | 49% |
| 最高条件 | WCD: **83%** | lecture_only/pair: 60% |
| 最低条件 | SGD: 68% | medium: 45% |
| 講義長 | 11k〜18k chars | 11,094 chars |
| Mastery recall Pass Rate | 81% | **47%** |
| Token/correct answer | 2,162 | 3,732 |

**v9b が v8 より全体的に低い主因：** ~~講義長の短さと~~ recall Pass Rate の低さ。

**〔2026-08-22 セルフ査読で訂正〕** 本節が引用していた v8 の講義長（WCD 17,826 chars、
lecture_only 11,016 chars）は**誤りである**（v8 セルフ査読 所見2 で DB 実測と不一致を確認）。
v8 の実測は 9,856〜12,300 chars で最長は 1on1 条件の 12,300、v9b は 11,094 chars。
両者はほぼ同水準であり、「v8 は偶然長い lecture が生成された条件が有利だった」という説明は成立しない。
v9b と v8 の差（49% vs 74%）は講義長では説明できず、
**mastery pass rate（v9b 58% vs v8 88%）**に寄せて読むべきである。

---

## 6. 限界と解釈上の注意

1. **n が不均等かつ小さい**（pair: n=2、lecture_only: n=4、large: n=16）——pair の結果は特に信頼性が低い
2. **共有講義の品質が全条件を規定**——Phase 3 の効果を講義品質から切り離せていない。長さ・網羅性の制御が今後の課題
3. **called_on_count による Ownership の操作化が粗い**——「指名された/されない」の二値だが、実際の学習への関与はより連続的
4. **Memory Delta の感度**——MemoryDiagnostics は 6 カテゴリの粗い検出。細かな記憶の質的変化を捉えられていない可能性がある
5. **v9b の n=2（pair）**は統計的に無意味。pair の知見は次回の n 増加で再確認が必要

---

## 7. 次のステップ（優先順）

| 優先度 | 内容 | 理由 |
|--------|------|------|
| ★★★ | **共有講義の長さ・品質を統制した再実験** | 現在の 11k chars 講義では recall/rule_interaction が十分に定着しない。目標: recall ≥ 80%（v8 水準） |
| ★★★ | **Phase 2（マスタリーチェック）なし版との比較** | lecture_only が 60% を取れているのが「講義」の効果か「マスタリーチェックのフィードバック」の効果かを切り離す |
| ★★ | **pair の n を 8〜12 に増やす** | n=2 では edge_case 0% などの異常値を信頼できない。learner type × pair の組み合わせ効果を測る |
| ★★ | **「議論が edge_case を扱うか」をトレースする** | transcript を分析し、pair・small が edge_case を議題にしたかを検証 |
| ★ | **called_on_count をより細かく設計**（large: 1 人のみ） | Ownership の変化幅を広げ、Ownership × Score 相関の検出力を高める |
| ★ | **Memory Delta 計算の精緻化** | 現在の 6 カテゴリ検出を、より細粒度の知識項目（ルール×条件）レベルへ拡張 |
