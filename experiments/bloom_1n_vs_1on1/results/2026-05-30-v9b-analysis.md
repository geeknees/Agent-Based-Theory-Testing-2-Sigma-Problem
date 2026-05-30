# v9b Experiment 結果考察レポート — Classroom Size & Ownership

**実験バージョン:** bloom_v9b_classroom_size  
**run_id:** 9b599c12-ab43-42f8-8af4-de26551b3981  
**実施日:** 2026-05-30  
**条件:** スモークテスト（n=2〜4/条件 × 5 条件 = 14 学習者）  
**学習者タイプ:** rule_extractor, passive_listener  
**モデル:** claude-haiku-4-5-20251001  

> ⚠️ **スモーク run の位置づけ**  
> n が極小（lecture_only/pair は n=2）かつ haiku モデル使用。数値は傾向の参考に留め、統計的解釈は次回 sonnet run まで保留。

---

## 1. 実験の目的

v8 では 4 条件（lecture_only, whole_class_discussion, small_group_discussion, 1on1_tutoring）を比較し、WCD が最高スコア（83%）を示した。

v9b では **クラスサイズの連続変化**と**学習者の能動的関与（Ownership）**を独立変数として加える。具体的には：

- 共有講義は全条件で一本化（v8 からの継承）
- Phase 3 のインタラクションのみ条件を分ける（5 条件）
- called_on_count で「指名される確率」を制御し、大クラスほど一人あたり発言機会が減る設計

**中心的な問い：**  
①クラスサイズが大きくなるほど学習アウトカムは下がるか？  
②Ownership スコアはアウトカムと相関するか？

| 条件 | サイズ | called_on | n（smoke） |
|------|--------|-----------|-----------|
| lecture_only | — | — | 2 |
| pair_discussion_size_2 | 2 | all | 2 |
| small_class_discussion_size_4 | 4 | all | 2 |
| medium_class_discussion_size_8 | 8 | 2 | 4 |
| large_class_discussion_size_16 | 16 | 2 | 4 |

---

## 2. 実験設計の確認

### 2.1 共有講義

| 指標 | 値 |
|------|-----|
| 講義長 | 10,906 chars |
| モデル | haiku（teacher） |

v8（14,950〜17,826 chars）より大幅に短い。haiku による生成のため、講義の網羅性が低かった可能性が高い。

### 2.2 マスタリーチェックの状況

| Check Type | 受験数 | 正答数 | Pass Rate |
|------------|--------|--------|-----------|
| edge_case | 14 | 14 | **100%** |
| recall | 14 | 4 | **29%** |
| rule_interaction | 14 | 3 | **21%** |

全体正答率 50%（21/42）。v8（88%）と比較して著しく低い。  
**仮説：haiku の lecture が recall・rule_interaction に必要なルール記述を省略した。**  
これにより全条件でベースラインが押し下げられており、条件間差の解釈に注意が必要。

### 2.3 Ownership の設計確認

| 条件 | Avg Ownership Score | Avg Contributions | % Attempted | % Got Feedback |
|------|--------------------|--------------------|-------------|----------------|
| lecture_only | 0.0 | 0.0 | 0% | 0% |
| pair | **3.0** | 2.0 | 100% | 100% |
| small_class (4) | **3.0** | 1.0 | 100% | 100% |
| medium_class (8) | 1.5 | 0.5 | 50% | 50% |
| large_class (16) | 1.5 | 0.5 | 50% | 50% |

called_on_count の設計どおり：medium/large は半数のみ指名（Ownership ≈ 1.5）、pair/small は全員発言（Ownership = 3.0）。  
**設計の検証は成功。**

---

## 3. 結果

### 3.1 条件別正答率（メイン結果）

| 条件 | n | Attempts | Correct% | Std Dev |
|------|---|---------|---------|---------|
| lecture_only | 2 | 20 | **80%** | 0.141 |
| pair_discussion_size_2 | 2 | 20 | **80%** | 0.0 |
| small_class_discussion_size_4 | 2 | 20 | 40% | 0.141 |
| medium_class_discussion_size_8 | 4 | 40 | 45% | 0.238 |
| large_class_discussion_size_16 | 4 | 40 | 45% | 0.37 |

**全体平均:** 57%（80/140）

### 3.2 タスクタイプ別スコア

| Task Type | Diff | large_16 | lecture_only | medium_8 | pair_2 | small_4 |
|-----------|------|----------|-------------|---------|-------|--------|
| recall | L1 | 50% | **100%** | 25% | **100%** | 50% |
| edge_case | L2 | 63% | **100%** | 75% | **100%** | 50% |
| rule_interaction | L3 | 50% | **100%** | 25% | **100%** | 0% |
| debugging | L4 | 33% | **67%** | 17% | **67%** | 17% |
| debugging (L5) | L5 | 50% | **100%** | 25% | **100%** | 50% |
| short_rule_induction | L6 | 0% | 0% | 0% | 0% | 0% |
| explanation_choice | L7 | 75% | **100%** | **100%** | **100%** | **100%** |
| peer_error_detection | L7 | 50% | **100%** | **100%** | **100%** | **100%** |

L6（short_rule_induction）は全条件 0%（v8 と同一）。

### 3.3 Memory Coverage

| 条件 | Avg Rules | Edge Cases (%) | Procedure (%) |
|------|-----------|----------------|---------------|
| lecture_only | **4.0** | **100%** | 50% |
| pair | 3.5 | 33% | 50% |
| small_class | 3.5 | 50% | **100%** |
| medium_class | **4.1** | **0%** | 75% |
| large_class | 3.3 | 42% | 50% |

medium_class の edge_case 保持率が 0%。v8 の SGD（0%）と同じパターン。

### 3.4 Memory Delta（議論による知識獲得）

| 条件 | Avg 知識獲得数 |
|------|-------------|
| medium_class (8) | **0.25** |
| それ以外 | 0.0 |

medium_class だけが議論によって 1 アイテム以上獲得した学習者を含む。ただし量は微小。

### 3.5 Learner Type 別スコア

| Type | Correct% |
|------|---------|
| passive_listener | 51% |
| rule_extractor | **57%** |

差は 6pp。v8（passive_listener が条件によっては 30〜90% の幅）より learner type 効果が小さく見える。ただし条件 × type の交互作用は n が小さすぎて確認不能。

---

## 4. 考察

### 4.1 最大の発見：pair が lecture_only と同率トップ

**pair_discussion（80%）= lecture_only（80%）> small/medium/large（40〜45%）**

これは直感に反する結果に見えるが、複数の仮説で説明できる。

**仮説①: pair の高い Ownership が学習を補完した**  
pair の Ownership スコア = 3.0（最高）。全員が「発言 → フィードバック」を経験しており、メモリが能動的に更新された可能性がある。それにより lecture_only と同等のスコアを維持した。

**仮説②: lecture_only のベースライン自体が高い**  
マスタリーチェック Pass Rate が低い（29〜21%）にもかかわらず lecture_only が 80% を達成している。これは、マスタリーチェックのエラー補正（corrective note の追記）が記憶を強化した可能性を示す。つまり **Phase 2 の誤答 → フィードバック → 記憶更新** のループが lecture_only でも十分機能していたと見られる。

**仮説③: small_class の低スコア（40%）が異常値**  
n=2 かつ passive_listener × small_class の組み合わせが引き下げている可能性。v8 でも SGD × passive_listener の組み合わせが最低スコアを記録している。

### 4.2 クラスサイズ仮説への影響

「サイズが増えるほどスコアが下がる」という単純仮説は**支持されなかった**：

```
pair (2) = lecture_only > small (4) < medium (8) ≈ large (16)
```

small が medium/large より低い（40% vs 45%）のは n=2 の偶然誤差の可能性が高い。medium と large が同率（45%）という点は仮説と整合するが、いずれも n が小さすぎる。

### 4.3 Ownership × Performance の不一致

| 条件 | Ownership | Score |
|------|-----------|-------|
| lecture_only | 0.0 | 80% |
| pair | 3.0 | 80% |
| small | 3.0 | 40% |
| medium | 1.5 | 45% |
| large | 1.5 | 45% |

Ownership が最高（3.0）でも small は 40% に留まる。一方で Ownership = 0 の lecture_only が 80% を達成。**このスモーク run では Ownership とスコアに相関がない。**

ただしこれは：
- small の n=2 が passive_listener の影響を大きく受けている可能性
- haiku モデルでは議論の質が十分でなく、発言自体が学習に繋がっていない可能性

### 4.4 Memory Coverage の解釈

- **lecture_only の edge_case 保持率が 100%**：追加インタラクションなしでも講義内容を保持できている
- **medium の edge_case = 0%**：議論が edge_case を話題にしなかった可能性（v8 SGD の 0% と同一メカニズムか）
- **small の procedure 保持率 100%**：ペア以上の議論が手続き記憶を強化している可能性

---

## 5. v8 との比較

| 指標 | v8（sonnet, n=4/条件） | v9b smoke（haiku, n=2〜4/条件） |
|------|----------------------|-------------------------------|
| 最高条件 | WCD（83%） | lecture_only / pair（80%） |
| 最低条件 | SGD（68%） | small_class（40%） |
| 全体平均 | 74% | 57% |
| 1on1 vs lecture_only | +8pp | n/a（1on1 なし） |
| passive_listener 効果 | 条件により 30〜90% | 51%（条件詳細不明） |

最大の違いはモデル（haiku vs sonnet）と全体水準。haiku では講義品質が低く、全条件でスコアが押し下げられている。

---

## 6. 限界と解釈上の注意

1. **n が極小**（lecture_only / pair は n=2）——条件間差はほぼ統計的ノイズ
2. **haiku モデルの制約**——講義長・品質・議論の深さが sonnet より大幅に劣る可能性。マスタリーチェック Pass Rate（29%, 21%）が証拠
3. **learner type が 2 種類のみ**——rule_extractor と passive_listener のみ。v8 の 4 種から縮小しており type 効果の幅が狭い
4. **called_on_count による指名設計**——medium/large で指名されなかった学習者（observer）のメモリ更新は会話内容に依存するが、内容の質が低いと更新が弱くなる

---

## 7. 次のステップ（優先順）

| 優先度 | 内容 | 理由 |
|--------|------|------|
| ★★★ | **sonnet モデルで本番 run（n=8〜16/条件）** | haiku の品質制約を排除し、クラスサイズ効果を実際に測る |
| ★★★ | **lecture_only の強さの機構を解明** | マスタリーチェックのフィードバックが lecture_only を底上げしているか確認。MasteryCheck なし版と比較 |
| ★★ | **Ownership × Score の交互作用を n=8 以上で再確認** | small の低スコアが n=2 の偶然か passive_listener 効果かを判別 |
| ★★ | **small_class（4人）の passive_listener を deep dive** | v8 SGD と同様のパターン（group discussion が passive_listener を引き下げる）の再現を確認 |
| ★ | **observer（指名されなかった学習者）の Memory Delta を分析** | medium/large の called_on_count 制限が「観察学習」にどう影響するか |
| ★ | **called_on_count を条件間でより差別化**（e.g., medium=1, large=1） | Ownership スコアの分散を広げ、Ownership × Score 相関を検出しやすくする |
