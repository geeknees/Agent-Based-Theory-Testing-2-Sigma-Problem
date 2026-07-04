# 全体レビュー: 次の実験に向けた改善提案

**作成日:** 2026-07-03
**対象:** リポジトリ全体（実験コード・設計・再現性インフラ・運用）
**位置づけ:** 新しい実験は実施しない。v9c2 / ablation(n_disc=1) までの成果を踏まえ、
次の実験世代（v9c3 以降）を設計・実装する際のインプットとしてまとめる。

レビュー対象: `lib/`（llm, scorer, memory, sized_discussion, learner_types, report, db 等）、
`scripts/`（7世代の orchestrator）、`config/`、`results/` の全分析レポート、
論文ドラフト（2026-06-16）、テストスイート。

---

## TL;DR

次の実験を1本だけ走らせるなら、最も価値が高いのは
**「readiness を per-learner で強制した上での 1対1 mastery tutoring アーム再導入 + n_disc 増加」**（D1+D2+D3）。
その前提としてコード側では **RNG シード制御（R1）と LLM エラー処理の修正（E1）** が必須。
現状のコードは 2.4M トークン級の run を無シード・無チェックポイント・
「全エラー=レート制限扱いで5.5時間sleep」という状態で走らせており、
次の run をより大規模にする前にここを直さないと、事故時のコストが跳ね上がる。

---

## 1. 実験設計の改善（次実験の研究デザイン）

### D1. ★★★ 1対1 mastery tutoring アームの再導入

v9c2 の条件セットは「self-reflection vs discussion サイズ4種」であり、
**Bloom の 2-sigma 問題の本来の比較軸である「1対1 mastery tutoring vs 集団授業」が存在しない**。
v4–v7 には tutoring 条件があったが、readiness gate・population-multiplication・
memory 注入などの統制はその後に導入されたため、
「confound 統制下での tutoring vs 集団」は一度も測定されていない。
`phases/tutoring.rb` / `flipped_tutoring.rb` は既存なので実装コストは低い。
論文の主張（「2-sigma は再現しない」）を最も直接に強化・反証できるアーム。

### D2. ★★★ readiness を per-learner で強制するゲート設計

現状の readiness gate は**集計値の測定のみで、enforcement がない**
（80% 未満でも run は続行し、フラグが立つだけ。失格学習者もそのまま Phase 3 へ進む）。
ablation(n_disc=1) では gate が 53% で fail し、
「A3 の効果を単離するはずが readiness も同時に動いた」という結果になった
（論文 §9 に記載の通り）。次世代では:

- readiness チェック → corrective note → 再チェックのループを
  **学習者ごとに合格（または上限回数）まで回す**
- これにより (a) 条件間の事前知識が設計上揃う、(b) 単一変数 ablation が初めて成立する、
  (c) 「readiness 到達までの反復回数」自体が learner type の新しい従属変数になる

### D3. ★★★ n_disc 増加（10–15）と統計計画の事前定義

v9c2 の結論「条件差10ppは効果なしと言い切れない」は discussion-level n=5 が原因。
n_disc=10–15 に増やすとともに、**分析計画を run 前に固定**する:

- 単位: discussion-level mean（現行方針を維持）
- 検定: discussion-level permutation test + bootstrap CI（学習者は discussion にネスト。
  混合効果モデルはn が小さいので permutation の方が誠実）
- 判定閾値（何pp以上を「効果あり」とするか）を config か設計文書に事前registration
- `scores.csv` は既に出るので、検定は Python スクリプト
  （`scripts/` に `analyze_stats.py` を追加）でオフライン実行できる。**LLMトークン不要**

### D4. ★★ 教育トークン予算の均等化アーム

残存 confound の筆頭（論文 §9「the live confound」）。
lecture_plus_self_reflection の教育トークンは discussion 条件の約 1/15（2.7k vs 35–46k）。
対応案は2つあり、両方入れると解釈が強くなる:

- **budget-matched reflection**: self-reflection を複数ラウンド化し
  discussion と同トークン量まで与える
- **budget-capped discussion**: discussion のターン数を削って reflection 側に合わせる

### D5. ★★ 評価タスクの天井対策（難易度再キャリブレーション）

v9c2 は全体平均 82%、L7 系は 95–100% でほぼ天井。
**readiness 統制で全体スコアが上がった結果、タスクセットの感度が失われている**
可能性がある（条件差10ppへの収縮の一部は天井圧縮かもしれない）。
`eval_tasks_v8.json` に L3（rule_interaction）相当の難タスクを増やし、
天井 90% 超のタスクを退役させる。`ceiling_threshold: 0.9` は config に既にあるので、
report の ceiling 検出結果をタスク改訂に接続する運用にする。

### D6. ★★ discussion 刺激（問題）のバリエーション

`SizedDiscussion::DISCUSSION_PROBLEM` は固定1問（[Red, Green, Blue, Yellow]）で、
**全条件・全反復が同一刺激**。n_disc の「独立反復」はエージェントの確率性のみに
依存しており、刺激レベルの一般化可能性がない。反復ごとにカウンターバランスした
問題セット（例: 5問ローテーション）を使うと、A3 の replication がより本物になる。
その際、eval タスクとの表面的重複（同じトークン列）を避けること。

### D7. ★★ learner type × condition の交互作用を主要仮説に昇格

v9c2 の最大の知見は「条件間 10pp ≪ learner type 間 38pp」。
次の自然な問いは v9c2 分析 §8 にもある通り
**「class size / tutoring の効果は learner type によって異なるか」**。
type 別に条件割付を層化し（現状の `i % type_keys.size` 割付は既に層化に近い）、
type×condition セルごとの discussion-level 集計を report に追加する。
特に passive_listener（58%）が tutoring で救済されるかは Bloom 理論の
「個別化は弱い学習者に効く」という核心予測に直結する。

### D8. ★ passive_listener の memory_budget 感度分析

38pp 差の主因が memory_budget(80 words) という設計パラメータであることはほぼ確実。
budget を 80/100/120 と振る小規模 run で「type 差 = budget 差」をどこまで説明できるか
定量化しておくと、論文の「learner profile が支配的」という主張の機序が明確になる。

### D9. ★ 汎化チェック: 別モデル・別ドメイン

全結果が zarn_tokens × claude-sonnet-4-6 に閉じている。
smoke 構成（haiku）が既にあるので、**同一設計を haiku で full-scale 実行**するのが
最安の汎化チェック。ドメイン第2弾（別の合成ルール体系）は工数が大きいので
モデル汎化を先に。

### D10. ★ 保持・転移の測定（構成概念の拡張）

現在の「学習」は直後テストのみ。memory を保存済みなので、
**同一 memory に対して遅延セッション（干渉タスク後の再評価）を追加する**のは
orchestrator の追加フェーズだけで実現でき、「retention」への拡張が安価にできる。

---

## 2. 再現性・妥当性のインフラ改善

### R1. ★★★ RNG シード制御（現状、run が原理的に再現不能）

`LearnerTypes.apply_constraints` / `should_ask_question?` は素の `rand` を使っており、
**シードが一切ない**。edge_case の脱落・rules のシャッフルという
「learner type の操作的定義そのもの」が run ごとに変わる。
対応: config に `seed` を追加し、`Random.new(seed)` を学習者IDで派生させて
（例: `Random.new(seed ^ learner_index)`）注入する。run metadata に記録。
LLM 出力の非決定性は残るが、**統制変数側の確率性は固定できる**。

### R2. ★★★ prompts / domain ファイルの run_dir スナップショット

`config.json` は run_dir に凍結されるが、**prompts と domain ファイルは凍結されない**。
全世代が同じ `prompts/` を共有しているため、プロンプトを編集すると
過去 run の再現材料が失われる。run 開始時に `prompts/` と参照 domain ファイルを
run_dir にコピーする（数KB、コストゼロ）。

### R3. ★★ 実トークン数の計測

`TokenTracker` は「4文字≒1トークン」の推定で、論文にもこの推定値が載っている。
`claude --print --output-format json` は実 usage を返すので、
llm.rb を JSON 出力に切り替えれば**実測値**にできる（コスト分析 §3.3.1 の
token-normalized score の信頼性が上がる）。出力テキストは `.result` から取る。

### R4. ★★ データ公開の整合性

論文 §10 は「per-run databases を release する」と述べているが、
`data/runs/`・`*.db` は gitignore されておりリポジトリには存在しない。
Zenodo リリース時に run DB（少なくとも dc1bdd27 / a551c74d / b412cfdb）を
アーカイブに含めるか、論文の文言を修正する。**現状のままだと論文の再現性主張と
リポジトリの実態が食い違う。**

### R5. ★ 条件名の DB 記録揺れ

v9c2 本番 run の DB には旧名 `lecture_only` で記録されている
（分析レポート冒頭に注記あり、リネームは実施済みで次 run 待ち）。
次 run で新名称になることの確認は既知 TODO として維持。
加えて、**analysis スクリプト側に新旧名のエイリアス対応**を入れておくと
過去 run との横断集計が安全になる。

---

## 3. コード・運用の改善

### E1. ★★★ LLM.call のエラー処理（最重要バグ級）

`lib/llm.rb` は **あらゆる RuntimeError をレート制限とみなして 5.5時間 sleep × 最大20回**
リトライする。モデル名の typo、CLI 未ログイン、プロンプト起因の即時エラーでも
静かに5.5時間停止する。次の 10M トークン級 run では致命的。対応:

- stderr / exit code からレート制限を判別（例: "rate limit" 文字列、特定 exit code）
- レート制限以外は指数バックオフ短時間リトライ（3回程度）→ fail fast
- 連続失敗時は run を中断し、E2 の resume に接続する

### E2. ★★★ チェックポイント / resume 機構

run は数日規模・数千 LLM 呼び出しだが、**途中クラッシュ時の再開手段がない**
（DB には書いているが orchestrator に resume パスがない）。
phase × learner 単位の進捗を DB から復元し、`--resume <run_id>` で
未完了分だけ実行できるようにする。A3 で全フェーズが n_disc 倍された今、
これがないと failure コスト = run 全体のトークン。

### E3. ★★ 並列化

全 LLM 呼び出しが逐次 + 各呼び出し後 2秒 sleep。学習者間は独立なので、
memory fork / readiness / evaluation フェーズは 4–8 並列にするだけで
wall-clock が数分の1になる（レート制限と相談の上、並列度を config 化）。

### E4. ★★ orchestrator の統合

`run_experiment*.rb` が7本あり、フェーズ組み立てロジックの大半が重複している。
次世代を作る際は「フェーズ列を config で宣言する単一 orchestrator」に寄せる
（例: `phases: [fixed_lecture, memory_fork, readiness_loop, sized_discussion, ...]`）。
過去世代スクリプトは凍結扱いで残してよいが、新規追加をコピペで増やすのはやめる。

### E5. ★★ evaluator の failure バイアスと extract_json の堅牢化

- LLM evaluator のパース失敗は**0点として本採点に混入**する
  （`LLM_FALLBACK_SCORE`）。L6 semantic scorer を有効化する次 run では
  この 0 点化がそのまま条件比較を歪める。失敗時はリトライ（2回）→
  それでも失敗なら `scoring_failed` フラグを立てて集計から除外する。
- `Helpers.extract_json` は貪欲正規表現 `/\{.*\}/m` で、応答に JSON が2個あると壊れる。
  コードフェンス除去 + 最初のバランスした `{}` を取る実装に置き換え、
  失敗ケースをログではなく jsonl に記録して失敗率を測れるようにする。

### E6. ★★ L6 semantic scorer の検証プロトコル

`SEMANTIC_TASK_TYPES` は実装済みだが未検証。有効化 run の前に、
**過去 run の L6 回答（154件、全て手元の DB にある）へ retrospective に
LLM 採点を当て、人手スポットチェック（20–30件）と突き合わせる**。
これは新しい実験ではなく既存データの再採点なので低コストで、
scorer の信頼性を確認してから main score へ組み込む判断ができる。
`scripts/rescore_l6.rb` が土台に使える。

### E7. ★ dead metrics の整理

- `misconception_exposed` / `misconception_corrected` は常に false（コメントにも明記）
- auto-score 経路では `reasoning_quality` / `autonomy` が常に 0
- self-reflection の ownership_data は orchestrator 内でハードコード

これらは report の表に「測っているように見えて測っていない」列を作っている。
次世代では (a) transcript からの misconception 検出を実装するか、
(b) 列ごと落として ownership_score の定義から除外するか、どちらかに倒す。
中途半端に残すと将来の分析で再び confound 監査対象になる。

### E8. ★ フェーズ別モデル階層化によるコスト削減

config は全フェーズ sonnet。**条件間比較に影響しないフェーズ**
（特に memory_summarizer と auto-score 済み evaluator）を haiku に落とせば
総トークンの相当部分を削減でき、その分を n_disc に回せる。
ただし memory summarizer は「学習」の操作的定義に触れるため、
変更するなら全条件一律 + smoke で分布比較をしてから。

### E9. ★ テスト実行とCI

`run_tests.sh` はテストを手書き列挙しており、追加漏れが起きうる
（実際 `test_mastery_check.rb` / `test_evaluator.rb` / `test_report_v8.rb` が
リストに見当たらない）。`tests/test_*.rb` の glob 実行に変え、
GitHub Actions で bundle + テストを回す最小 CI を足す。
LLM 不要のユニットテストのみなので CI コストはほぼゼロ。

### E10. ★ report.rb の分割

946行・全世代の分岐が同居。次世代のセクション追加時に、
世代別モジュール（`report/sections/*.rb`）へ切り出す。挙動変更なしの機械的分割。

---

## 4. 優先度まとめ（次の実験までにやる順）

| 順 | 項目 | 種別 | 理由 |
|----|------|------|------|
| 1 | E1 LLMエラー処理 | code | 次 run の事故コスト直結。半日仕事 |
| 2 | R1 RNGシード | code | 統制変数が run ごとに変わる状態を解消。半日仕事 |
| 3 | E2 resume | code | run 大型化(D3)の前提 |
| 4 | D2 per-learner readiness 強制 | design | 単一変数 ablation の成立条件 |
| 5 | D1 tutoring アーム再導入 | design | Bloom 本来の比較軸。論文の核心を強化 |
| 6 | D3 n_disc=10–15 + 統計計画 | design | 「効果なし」を言える検出力へ |
| 7 | E6 L6 retrospective 再採点 | analysis | 既存データで完結。run 不要 |
| 8 | D4 トークン予算均等化 | design | 残存 confound の解消 |
| 9 | D5 天井対策 / D6 刺激バリエーション | design | 測定感度と一般化 |
| 10 | R2/R3/R4 スナップショット・実トークン・データ公開 | infra | 論文リリース前に必須 |

体力があれば同一 run に D7（type×condition）を同居させる。
D8–D10、E3–E5、E7–E10 はその次の世代で。

---

## 5. 次の実験(v9c3 案)の骨子

上記を束ねると、v9c3 は次の形が最小で最大の情報量になる:

- **条件**: one_on_one_tutoring / lecture_plus_self_reflection(budget-matched) /
  pair(2) / medium(8) / large(16) — small(4) は v9c2 で pair と差がないため削減候補
- **統制**: per-learner readiness 強制ループ(D2)、seed 固定(R1)、
  刺激5問ローテーション(D6)
- **規模**: n_disc=10、learner 4タイプ層化
- **分析**: discussion-level permutation test を事前登録、
  type×condition 交互作用を主要セカンダリ
- **主要仮説**: 「readiness 統制下でも tutoring は集団条件を上回らない」
  (Bloom への直接の負の再現) + 「tutoring の便益は passive_listener に集中する」
  (交互作用としての 2-sigma の残滓)

これが成立すれば、論文は「discussion サイズの null 結果」から
「mastery tutoring そのものの confound 統制下での検証」へ格上げできる。
