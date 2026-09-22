# v9c2 Ablation (n_disc=1) 結果考察レポート — 反復因子の単独切り出し

**実験バージョン:** bloom_v9c2_ablation_ndisc1
**run_id:** a551c74d-aaed-498f-82cb-188b610380a8
**実施日:** 2026-06-16〜17(レポート再生成: 2026-06-21)
**条件:** lecture_plus_self_reflection n=4、discussion 4条件 × **n_disc=1**(v9c 相当の反復数)= 34 学習者
**学習者タイプ:** rule_extractor, edge_case_dropper, order_confused, passive_listener
**モデル:** claude-sonnet-4-6(全フェーズ)
**総トークン:** 631,243
**一次資料:** [`2026-06-21-v9c2-ablation-ndisc1-run-report.md`](2026-06-21-v9c2-ablation-ndisc1-run-report.md)(生成された run report の verbatim コピー。DB は保持していない)

---

## 1. 実験の目的

v9c(37pp spread)→ v9c2(10pp spread)の比較は、6つの是正(A0/A3/A5/A6/A8 + n 増加)を同時に適用したため、効果消失をどの統制に帰属できるかが分からない(論文 §8.2)。本 ablation は **A3(population-multiplication)だけを v9c 相当(n_disc=1)に戻し、他の v9c2 是正はすべて有効のまま**にした arm である。

**解釈の枠組み:**
- spread が v9c2(10pp)水準に留まる → 反復以外の是正(メモリ注入等)が効果消失の主因
- spread が v9c(37pp)水準に戻る → 反復(A3)が主因
- 中間 → 複合要因

## 2. 結果

### 2.1 条件別正答率(L6 除外)

| 条件 | n | Attempts | Correct% |
|------|---|---------|---------|
| pair_discussion_size_2 | 2 | 18 | **72%** |
| small_class_discussion_size_4 | 4 | 36 | 58% |
| large_class_discussion_size_16 | 16 | 144 | 51% |
| medium_class_discussion_size_8 | 8 | 72 | 49% |
| lecture_plus_self_reflection | 4 | 36 | **47%** |

**条件間最大差 25pp(pair 72% vs lecture 47%)** — v9c(37pp)と v9c2(10pp)の中間。

### 2.2 Readiness チェック — 未達(53%)

| Check Type | 受験数 | 正答数 | Pass Rate |
|------------|--------|--------|-----------|
| edge_case | 34 | 34 | **100%** |
| recall | 34 | 18 | 53% |
| procedure_order | 34 | 16 | 47% |
| rule_interaction | 34 | 4 | **12%** |
| **全体** | **136** | **72** | **53%** |

**`readiness_failed: true`(53% < 80%)** — v9c(69%)よりさらに低い。同一の固定講義・同一の readiness チェックを使っているにもかかわらず低下しており、run 間のサンプリング変動の大きさ自体が(シード未固定の)確率的プロセスの不安定さを示す。

### 2.3 その他の観察

- **Interpretation flags:** `ownership_effect_supported: true`、`discussion_added_value: true`、`class_size_effect_supported: false` — v9c と同方向の「discussion 優位」フラグが復活
- **学習者タイプ別:** rule_extractor 63% / edge_case_dropper 63% / order_confused 43% / passive_listener 36%(タイプ間差 27pp。v9c2 の 38pp と同順位傾向、passive_listener 最下位は一貫)
- **High-confidence wrong 15%** — v9c(15%)と同水準、v9c2(2%)より大幅に悪い。readiness 未達 regime の特徴が再現
- **Discussion-level SD:** 全 discussion 条件で N=1 のため 0.0 — pseudoreplication の構造をレポート上でも明示

## 3. 解釈

> **n_disc=1 に戻すと、v9c2 で消えた「discussion 優位」が 25pp spread として部分的に復活した。** 方向としては反復(A3)が v9c の見かけの効果の主要因という仮説と整合する。

ただし **決定的な帰属はできない**:本 run では readiness も 53% で崩れており(v9c2 は 90%)、「反復の欠如」と「前提知識の未統制」が同時に変化している。したがって本 ablation が示すのは「是正バンドルが効いている」ことまでで、A3 単独の寄与量は分離できない(論文 §9 に明記)。

きれいな次の設計:readiness を固定した上で(ゲート通過まで再試行するなど)、n_disc のみを 1/5 で変化させる 2-arm 比較。

## 4. 限界

1. **readiness_failed(53%)** — 条件間差の因果的解釈は不可。v9c との比較も readiness 水準が異なる(69% vs 53%)
2. **pair n=2** — 72% というトップスコアの信頼区間は極めて広い
3. **単一 run** — ablation 自体の反復がない
4. トークンは chars/4 の推定値(±20%)
5. DB は保持されておらず、本ドキュメントと verbatim run report が一次記録である

---

*生成日: 2026-06-21(run report より再構成: 2026-07-13)*
*実験コード: experiments/bloom_1n_vs_1on1/(config_v9c2_ablation_ndisc1.yml)*
*run_id: a551c74d-aaed-498f-82cb-188b610380a8*
