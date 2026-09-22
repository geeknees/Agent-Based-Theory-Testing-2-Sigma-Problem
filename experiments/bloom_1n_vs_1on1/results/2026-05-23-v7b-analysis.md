# v7 Experiment B 結果考察レポート — Order Confused Intervention

**実験バージョン:** bloom_v7b_order_confused_intervention  
**run_id:** 32ffaa49-2d26-4edd-9cf8-ecdf1d019c78  
**実施日:** 2026-05-23  
**条件:** n=4/条件、全学習者 order_confused 型  
**モデル:** claude-sonnet-4-6

---

## 1. 実験の目的

v6 で `order_confused` 型が hetero_classroom (88%) より 1on1 (63%) で低スコアを示した。この差が「介入の不一致（generic tutoring は命題的誤概念を修正するが、手続き的順序の問題には効かない）」から来るのかを検証する。

| 条件 | 設計意図 |
|------|---------|
| classroom_public_qa | ベースライン：活性化チェック優先を強調した共有授業 |
| generic_one_on_one_tutoring | 標準的診断-修正-再テスト（`applies_modifiers_before_activation` 誤概念を標的） |
| procedure_scaffolded_one_on_one_tutoring | 4ステップ手続きチェックリストを明示教示、学習者が手順を再陳述、再テストでステップをラベル付け |

**解釈の枠組み：**
- `procedure_scaffolded > generic` → v6 の失敗は介入ミスマッチ（標的誤り）
- `procedure_scaffolded ≈ generic` → 介入の種類より別の要因が支配的
- `procedure_scaffolded < generic` → 手続きスキャフォールドが逆効果（コンテンツカバレッジを圧迫）

---

## 2. 実験設計

### 2.1 Order Confused の特性

| 制約 | 値 |
|------|-----|
| memory_budget_words | 100 |
| edge_case_retention | 60% |
| rule_order_retention | **20%**（ルール順序が 80% の確率でシャッフル） |
| question_asking_probability | 40% |
| likely_misconceptions | applies_modifiers_before_activation |

ルール順序シャッフルはメモリ生成後に適用される。手続き（strategy フィールド）はシャッフル対象外。

### 2.2 Procedure Scaffolded セッション構造

4 ステップ手続き（PROCEDURE const）：
1. 活性化トークンを決定（Green Token 位置を先に確認）
2. 活性トークンのみに修飾子を適用
3. エッジケースルールがあれば適用
4. 最終スコアを合算

セッション構造：
- Exchange 1: 手続き紹介（tutor） → 再陳述（learner）
- Exchange 2: 診断問題（tutor） → 手順ラベル付き解答（learner）
- Exchange 3: 手順順序の確認・修正（tutor） → 修正承認（learner）
- Exchange 4: 再テスト（tutor、ステップラベル指示） → 手順ラベル付き解答（learner）

### 2.3 Classroom の lecture 確認

| 条件 | 講義長（ログより推定） |
|------|---------------------|
| classroom_public_qa | 3,506 chars（教育フェーズ 8,724 tokens、4 学習者） |

Exp A の forced_checkin 問題（"Under 200 words" 制約）は Exp B の public_qa には該当しない。

---

## 3. 結果

### 3.1 条件別正答率（メイン結果）

| 条件 | 学習者数 | 正答率 | Std Dev |
|------|---------|--------|---------|
| classroom_public_qa | 4 | **69%** | 0.462 |
| generic_one_on_one_tutoring | 4 | 47% | 0.313 |
| procedure_scaffolded_one_on_one_tutoring | 4 | 41% | 0.157 |

**主要発見：** `procedure_scaffolded (41%) < generic (47%)` — 手続きスキャフォールドは generic tutoring を下回った。

### 3.2 学習者個人別内訳

**classroom_public_qa（4 order_confused）:**

| learner_id | 正解数 | 正答率 | 特記 |
|-----------|-------|--------|------|
| 81d3a1e2 | 8/8 | 100% | 全問正解 |
| 429522f6 | 7/8 | 88% | l3 のみ失敗 |
| 6087fa8c | 7/8 | 88% | l3 のみ失敗 |
| 177c0b13 | 0/8 | **0%** | 全問不正解 |

極端な bimodal 分布：3 名が 88〜100%、1 名が 0%。これが std dev 0.462 の原因。

**generic_one_on_one_tutoring（4 order_confused）:**

| learner_id | 正解数 | 正答率 |
|-----------|-------|--------|
| 08304c78 | 7/8 | 88% |
| 46acf1e1 | 4/8 | 50% |
| 7d27368c | 3/8 | 38% |
| 6728a7eb | 1/8 | 13% |

**procedure_scaffolded_one_on_one_tutoring（4 order_confused）:**

| learner_id | 正解数 | 正答率 |
|-----------|-------|--------|
| bdf6b82d | 5/8 | 63% |
| 47296ffc | 2/8 | 25% |
| 72c469d7 | 3/8 | 38% |
| 9bf1881c | 3/8 | 38% |

procedure_scaffolded は最高スコアが 63%（vs generic の 88%）で、variance が最も低い（0.157）— より均質に低いパフォーマンスを生み出した。

### 3.3 タスク種別正答率

| Task | 難易度 | public_qa | generic | procedure_scaffolded |
|------|--------|-----------|---------|---------------------|
| l1_recall_01 | L1 | 3/4 = 75% | 1/4 = 25% | 1/4 = 25% |
| l2_edge_case_01 | L2 | 3/4 = 75% | 3/4 = 75% | 3/4 = 75% |
| l2_edge_case_02 | L2 | 3/4 = 75% | 2/4 = 50% | 1/4 = 25% |
| l3_rule_interaction_01 | L3 | 1/4 = 25% | 3/4 = 75% | 0/4 = 0% |
| l4_debug_01 | L4 | 3/4 = 75% | 2/4 = 50% | 2/4 = 50% |
| l4_debug_02 | L4 | 3/4 = 75% | 2/4 = 50% | 4/4 = 100% |
| l5_debug_03 | L5 | 3/4 = 75% | 1/4 = 25% | 0/4 = 0% |
| l6_induction_02 | L6 | 3/4 = 75% | 1/4 = 25% | 2/4 = 50% |

*2026-08-09 セルフ査読で修正: 旧版は3列とも §3.1 の合計と整合していなかった(列合計 28/16/16 に対し実際は 22/15/13)。
特に public_qa 列の「4/4」は、同条件に 0/8 の学習者 `177c0b13` がいるため成立しえない値だった。上表は DB 実測値。*

**特記事項：**
- l1_recall（最も基礎的なタスク）: generic = 25%、procedure_scaffolded = 25% — 両条件ともに 1on1 の learner がルールを recall できていない
- l3_rule_interaction: procedure_scaffolded = 0/4（全員不正解）、generic = 3/4
- l5_debug_03: procedure_scaffolded = 0/4（全員不正解）、generic = 1/4
- l4_debug_02: procedure_scaffolded = 4/4（全員正解）、generic = 2/4 — 手順ラベル付きが有効に働いた唯一のタスク

### 3.4 誤解修正・キャリブレーション

| 指標 | public_qa | generic | procedure_scaffolded |
|------|-----------|---------|---------------------|
| 誤解修正率 | 50% | **100%** | 25% |
| 残存誤解数（平均） | 0.0 | 0.5 | 0.25 |
| 高確信・誤答率 | 25% | 25% | 25% |
| 棄権率 | 13% | 13% | 13% |

**注目すべき逆転：** generic は 100% の誤解修正率を達成したにもかかわらず、スコアは procedure_scaffolded と大差ない（47% vs 41%）。procedure_scaffolded の修正率は 25% と低い — 手続き教示に exchange を費やした結果、誤概念の明示的修正機会が減少した。

### 3.5 タスク種別 Ceiling 分類（修正版 report より）

report.rb のバグ修正後に再生成した report.md より（旧版は全て 0% で `too_hard` と誤分類されていた）：

| Task Type | 難易度 | No-Ed | Classroom | Tutoring | 分類 |
|-----------|--------|-------|-----------|---------|------|
| recall | L1 | 0% | 75% | 25% | condition_sensitive |
| edge_case | L2 | 0% | 75% | 56% | condition_sensitive |
| rule_interaction | L3 | 0% | 25% | 38% | condition_sensitive |
| debugging | L4 | 0% | 75% | 46% | condition_sensitive |
| short_rule_induction | L6 | 0% | 75% | 38% | condition_sensitive |

*注: Classroom = classroom_public_qa。Tutoring = generic + procedure_scaffolded の平均。*

全タスク種別で `condition_sensitive` — 教育の効果は条件によって大きく異なる。classroom が一貫して tutoring を上回る。

### 3.6 Procedure Order Errors

全条件で 0%（検出器が機能しなかった）。

`×` 記号や "modifier"/"multiply" というキーワードを使った heuristic を使用したが、Sonnet 4.6 は計算を言語で記述することが多く（例: "then apply the modifier to the active tokens"）、記号的表現を使わないため検出できない。この指標は今回の実験では無効。

### 3.7 トークンコスト

| フェーズ | Tokens |
|---------|--------|
| classroom_public_qa | 8,724 |
| generic_one_on_one_tutoring | 43,061 |
| procedure_scaffolded_one_on_one_tutoring | **48,334** |
| memory | 28,987 |
| evaluation | 75,114 |
| **TOTAL** | **204,220** |

procedure_scaffolded は generic より 12% 多いトークンを使用（48,334 vs 43,061）し、スコアは低い。トークン効率が最も悪い。

---

## 4. 仮説の検証

| 仮説 | 内容 | 結果 |
|------|------|------|
| procedure_scaffolded > generic | 介入ミスマッチが v6 失敗の原因 | ❌ procedure(41%) < generic(47%) |
| classroom_public_qa < tutoring | 共有授業よりもカスタム介入が有効 | ❌ classroom(69%) >> 両 tutoring |
| procedure_scaffolded の variance < generic | 手順強制で均質化 | ✅ 0.157 < 0.313 |

全主要仮説が否定された。

---

## 5. 考察

### 5.1 なぜ procedure_scaffolded が generic を下回ったか

**仮説 1: コンテンツカバレッジの圧迫**

procedure_scaffolded の 8 ターンは以下の構造：
1. 手続き紹介（tutor）
2. 手続き再陳述（learner）← 追加
3. 診断問題
4. 手順ラベル付き解答
5. 手順違反の修正
6. 修正承認（learner）← 追加
7. 再テスト（ラベル付き指示）
8. ラベル付き解答

Turn 2（再陳述）と Turn 6（承認）が追加された結果、tutor が費やす時間のうち「実際のルールコンテンツ」に充てられる比率が低下する。learner のメモリに書き込まれる情報は最終的に「手続きの概念」が多く、「個々のルールの詳細」が少なくなる可能性。

l1_recall（基礎的ルール暗記）で generic と同等（25%）なのは、この効果の傍証。

**仮説 2: 手続き知識とルール知識の競合**

order_confused 型のルール順序シャッフルはメモリの `rules` フィールドに適用される。procedure_scaffolded でチューターが教えた「4 ステップ手続き」は `strategy` フィールドに記録される（シャッフル対象外）。しかしその手続き知識が `rules` の混乱を補完できない — 「活性化を先に確認すべき」という手続き知識があっても、「活性化判定の具体的ルール」が記憶から脱落していれば問題を解けない。

**仮説 3: l4_debug_02 での逆転が示す部分的成功**

l4_debug_02 では procedure_scaffolded = 4/4（100%）、generic = 2/4（50%）。このタスクは特定のステップ順序が明確に問われる構造であり、手順ラベル付き訓練が唯一有効に機能した。procedure_scaffolded は「手順の順序が明示的なタスク」には有効だが、複合的判断（l3, l5）には効かない。

### 5.2 classroom_public_qa の高スコアと 177c0b13 の 0%

classroom の variance が 0.462 と最大で、177c0b13 が 0/8 という完全失敗を記録した。この学習者の全タスク不正解のパターン（l4_debug_01 = 0 tokens, l4_debug_02 = mistakes 0%など）は、メモリがほぼ空の状態でタスクに臨んだことを示唆する。

order_confused 型は rule_order_retention = 20% のため、rules フィールドがシャッフルされる確率が 80%。さらに memory_budget_words = 100 でのトリムが重なり、177c0b13 は実質的に空のメモリで評価を受けた可能性が高い。これは order_confused 型の制約の変動性を示す — 同じ型でも制約適用の確率的結果によって 0%〜100% のスコア幅が生じる。

### 5.3 Generic tutoring での 08304c78 の 88%

generic 1on1 で 7/8 = 88% を達成した学習者（08304c78）は誤解修正が成功し、かつ tutoring 内容がタスクカバレッジと合致した。generic tutoring は「当たり」の学習者には非常に効果的だが、「外れ」の学習者（6728a7eb = 1/8 = 13%）には全く効かない。高 variance（0.313）はこのばらつきを反映する。

### 5.4 v6 結果との再解釈

v6 の hetero_classroom で order_confused が 88% を達成したのは、今回の public_qa での 69% より高い。理由：
- v6 hetero の order_confused（a2f999d9）は 7/8 = 88% と個人レベルで高かった
- v7 public_qa の平均は 177c0b13（0%）が引き下げている
- 除外した場合: (7+7+8)/24 = 92% — v6 の 88% と整合

v6 での 1on1 order_confused（63%）vs v7 generic（47%）の差は hetero vs homo 条件の違い（v6 では 4 型混合 1on1 の中で order_confused が受けた教育）とランダム性によるものと思われる。

### 5.5 Procedure Order Errors 検出の失敗

現在のヒューリスティック（`×` 記号の位置で判定）は機能していない。Sonnet 4.6 は計算を記号でなく言語で記述する（"apply a 2x modifier" や "the modifier doubles the score"）ため、`×` がテキストに出現しない。

真の procedure order error を検出するには、LLM evaluator に「ステップ 1 の前にステップ 2 を適用したか」を判定させる必要がある。

---

## 6. 方法論的課題

### 6.1 Order_confused 制約の高い確率的変動

rule_order_retention = 20%（80% でシャッフル）という設定が、同じ型の学習者間で 0%〜100% の広大な結果幅を生む。n=4 では 1 名の「外れ」（177c0b13）が全体平均を大幅に引き下げ、条件間比較の信頼性を損なう。

### 6.2 procedure_scaffolded の session 設計の問題

8 ターン固定のセッションに「手続き紹介 → 再陳述 → 診断 → ラベル付き解答 → 修正 → 承認 → 再テスト → ラベル付き解答」を詰め込んだ結果、tutor がルール内容を教える時間が不足した。手続きスキャフォールドは turn 数の増加（10〜12 ターン）とセットで実装すべきかもしれない。

### 6.3 Procedure Order Errors 検出の無効性

定量的な手順順序エラー検出が機能しなかった。この指標は次回実験では LLM-based evaluator に置き換える必要がある。

---

## 7. 次の実験への提案

| 優先度 | 提案 | 理由 |
|--------|------|------|
| **最高** | **procedure_scaffolded のターン数を増やす（+2〜4 ターン）** | 現状は手続き教示にターンを使いすぎてルール教育が不足。手続き + ルールの両方をカバーできる session 設計に改善 |
| 高 | **Procedure Order Errors を LLM evaluator で検出** | 現ヒューリスティックが機能しないため、evaluator prompt に「手順順序違反を検出せよ」を追加 |
| 高 | **order_confused の n を 8 以上に増やす** | 0%〜100% の二峰性分布を持つ型は n=4 では統計的に意味なし |
| 中 | **rule_order_retention をより緩やかに（20% → 30〜40%）調整** | 現在の 80% シャッフル確率が extreme すぎて、実験の分散を制御できない |
| 低 | **177c0b13 のメモリを確認** | 0/8 の完全失敗の原因がメモリ空洞化によるものか確認 |

---

## 8. 結論

**Exp B の核心的知見：**

> `procedure_scaffolded (41%) < generic (47%) < classroom (69%)` — 手続きスキャフォールドは介入ミスマッチ仮説を支持せず、generic tutoring をわずかに下回った。

**確実に言えること：**
1. **介入ミスマッチ仮説は支持されない** — 手続き特化の tutoring が generic を上回ることはなかった
2. **procedure_scaffolded は variance を圧縮する** — 均質に低いパフォーマンスを生む（均質化効果）
3. **classroom は order_confused でも最高スコア** — ただし 1 名の 0% による高 variance を伴う
4. **誤解修正率と最終スコアの乖離** — generic の修正率 100% vs スコア 47%：修正がスコアに直結しない
5. **Procedure Order Errors 検出が無効** — ヒューリスティックを LLM evaluator に置き換える必要がある

> **⚠️ 2026-08-09 セルフ査読による重大な留保 — 本実験の前提は成立していなかった**
>
> `order_confused` 型の中核操作 `rule_order_retention: 0.2` は、実装上 `rules` 配列を `shuffle` するだけで、
> 実際の適用手順が書かれた `strategy` フィールドは対象外である(`lib/learner_types.rb`)。
> DB を全数確認した結果、**12名全員の `strategy` に「activation を先、modifier を後」という正しい順序が
> 保持されていた**。手順教示を一度も受けていない classroom・generic の8名も例外ではない。
>
> したがって「手続き的に混乱した学習者」は本実験に一人も存在せず、上記の結論1・2および
> 「Bloom の理論との関係」は、**直すべき欠損がない相手に手順教示を与えた結果**を見ている。
> §3.6 の「Procedure Order Errors 検出率 0%」も、ヒューリスティックの失敗ではなく
> 実態を正しく反映していた可能性がある。
>
> なお結論4(誤解修正率と最終スコアの乖離)は本留保の影響を受けない。修正率 100% と スコア 47% は
> いずれも DB 照合済みの事実である。

**Bloom の理論との関係：**  
order_confused 型に対して 1on1 tutoring が classroom を下回るという v6 パターンが v7 でも確認された。この型の問題の本質は「手続き的知識の習得」であり、現在の短いセッション（8 ターン固定）では命題的誤概念の修正も手続き的順序の改善も十分な効果を上げられなかった。mastery criterion（再テスト正解まで繰り返し）を持つ tutoring ループが必要な可能性が高い。

---

*生成日: 2026-05-23*  
*Exp B run_id: 32ffaa49-2d26-4edd-9cf8-ecdf1d019c78*
