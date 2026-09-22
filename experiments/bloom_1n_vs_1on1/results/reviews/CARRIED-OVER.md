# セルフ査読 持ち越し一覧(監査・論文査読の入口で参照)

最終更新: 2026-09-22(**全13項目の査読完了、公開前の実務も完了**)
対象: v1–v3 / v4 / v5 / v6 / v7a / v7b / v8 / v9b / v9c / v9c2 / ablation / 監査 / **論文** の
**全13件が完了**。

> **A1–A5・B1–B5 はすべて処置済み。** 以下は経緯の記録として残す。
> 残っているのは査読ではなく**公開前の実務**(末尾 D)のみ。

> 各世代の査読で「その世代だけでは決められない」と判断し **deferred** とした項目。
> 監査文書と論文本体の記述にまたがるため、この2件の査読でまとめて文面を確定する。

---

## A. 論文本体の修正が要る、または要る可能性が高いもの

| # | 出典 | 内容 | 論文の該当箇所 |
|---|------|------|--------------|
| ~~**A1**~~ | v7a 所見1 / v9c 所見1 / **v9c2 所見2** | **教材と評価・readiness タスクの系列重複。** `lesson.md` の Example B は `l1_recall_01`(`[Green, Blue, Yellow]`→14)そのもの。v9c 以降の `fixed_lecture_v9c.md` では**評価10問中3問・readiness 4問中2問・mastery 3問中2問**が答え付きの worked example として本文にある。<br>**2世代連続で「掲載あり」の2項目が readiness pass rate の上位を占める**(v9c 100%/68% vs 59%/50%、v9c2 100%/91% vs 85%/85%)。ただし評価タスク側に同じ signature は出ない(掲載ありの `l2_edge_case_01` が v9c で 17.6%)。<br>→ 断定はできないが、**readiness を「前提知識の定着度」として読む根拠はその分だけ弱まる**。現状どの文書にも言及がない | §4(readiness gate passed の記述)、§3 のドメイン記述、または §9 Limitations |
| ~~**A2**~~ | v7b 所見2(v6 所見3 の確定) | **`order_confused` 型は一度も成立していなかった。** `rule_order_retention` は `rules` 配列を shuffle するだけで、手順が書かれた `strategy` は対象外。v7b 12名全員の `strategy` に正しい順序が残っていた(手順教示を受けていない8名を含む)。<br>**観測は生き残り、説明が崩れる**: 誤解修正率と得点の乖離は事実だが、その理由を「手続き的欠損が残るから」とする説明が根拠を失う | **l.118**「(degrading procedural knowledge)」= 実装の説明として不正確<br>**l.149** finding (iii) の理由づけ<br>**l.232** 同旨 |
| ~~**A3**~~ | ablation 所見1 | **F2 の修正が別の失敗に化けている。** `SEMANTIC_TASK_TYPES`(2026-06-15 導入)により L6 は LLM 判定へ回っているが、**`answer_correct` を設定するのは `lib/scorer.rb` の exact-match 経路だけ**で、`evaluator.rb` の LLM 経路は設定しない。<br>`experiment_v9c2_ablation_smoke.db` で実証: L6 行は `auto_scored=0` / **`total` 11〜20点** / **`answer_correct` null**。**LLM は「ほぼ正答」と採点しているのに 0 と数えられている**。<br>→ 論文が L6 を「re-routed to a semantic judge」と述べるとき、**その結果が主要スコアに届く経路が存在しない**。修正は数行だが**適用には再実行が必要** | §4(L6 の除外と semantic judge への再ルーティング) |
| ~~**A4**~~ | v9c2 所見3 | **null の強さ。** v9c2 の「条件効果は確認されなかった」は、分析単位 discussion-level **n=5**、比較の基準となる `lecture_plus_self_reflection` が **n=4・反復なし・SD 最大・教育トークン 1/15** という条件の上に立つ。<br>「大きな主効果は確認されなかった」は正しいが「**効果がないことを示した**」とは読めない | §7・§9 の null の表現 |
| ~~**A5**~~ | ablation 所見2・3 | **帰属の議論。** (a) readiness の `rule_interaction` が 50%→85%→**12%** と振れており、n=34 では二項標準誤差の4〜5倍。「シード未固定の変動」で説明しきれていない。(b) 37pp / 25pp / 10pp の spread 比較は、**3世代とも pair(n=2)と lecture(n=4)が両端**である | §8.2(効果消失の帰属) |

## B. 監査文書・レポート生成コードの修正が要るもの

| # | 出典 | 内容 | 該当 |
|---|------|------|------|
| ~~**B1**~~ **解消** | v8 所見3 / 監査 所見2 | **監査表 F4 の分母に共通講義が混入している。** v8 を `sessions/unique` = WCD 8/2・SGD 8/3・1on1 8/5 と数え3条件すべて「部分的」と評価しているが、この分母には全条件共通の Phase 1 講義(4行複製)が入っている。**Phase 3 だけで数えると WCD 1/4・SGD 2/4・1on1 4/4** で、WCD は v4–v7 の classroom と同一の深刻度、1on1 は完全反復 | **2026-09-12 修正済み**: v8 の3行を Phase3 内訳つきに書き換え、まとめ表も ✓該当(WCD 1/4) に |
| **B2** | v9c 所見2 | **interpretation flags が閾値テストであることの明示。** `class_size_effect_supported` は完全単調のみ true(偶然一致 1/24)、`discussion_added_value` は1条件が baseline+5pp を超えれば true。**フラグ名が主張を先取りしている** | `lib/report.rb:876-905`、および flags を引用する各文書 |
| **B3** | ablation 所見4 | **run report に存在しない条件の表が残る。** Ceiling Effect Summary の Tutoring 列(全 0%)、Score by Learner Profile の `unknown` 行、v4 期の `classroom_advantage_under_homogeneity`。<br>あわせて **L6 Appendix のハードコード文字列が同一表内で3つの矛盾する説明**をしている(`lib/report.rb:584-603`) | `lib/report.rb`。ablation は DB 紛失で再生成不可のため**注記対応の見込み** |
| ~~**B4**~~ **解消** | v9c2 所見1 | **スモーク run と本番 run の取り違え。** v9c2 §2.1 は「v9c」として自身のスモーク DB の値を引用していた(修正済み)。**監査表の run_id 対応表に、スモーク DB を含めた完全な対応を載せるべきか**を監査査読で判断 | **2026-09-12 修正済み**: run_id 対応表にスモーク取り違えの注意書きを追記 |

### 論文査読へ引き継ぐ B 項目

| # | 内容 | 該当 |
|---|------|------|
| ~~**B2**~~ **処置済み**(Appendix C に判定式を追記) | **interpretation flags が閾値テストであることの明示。** `class_size_effect_supported` は完全単調のみ true(偶然一致 1/24)、`discussion_added_value` は1条件が baseline+5pp を超えれば true。**フラグ名が主張を先取りしている** | `lib/report.rb:876-905`、flags を引用する各文書 |
| ~~**B3**~~ **注記で処置**(Artifact 記述に追記。`lib/report.rb` の修正は未実施) | **run report の残骸と L6 Appendix の矛盾。** 存在しない条件の表(tutoring 列・`unknown` 行・v4 期の heterogeneity 判定)が残る。L6 Appendix はハードコード文字列により**同一表内で3つの矛盾する説明**を出力する | `lib/report.rb`。ablation は DB 紛失で再生成不可のため**注記対応の見込み** |
| ~~**B5**~~ **不要と判断**(Appendix B が役割を果たしている) | **F1/F2/F3/F5c の横断表が存在しない。** 監査文書のまとめ表は F4/F5a/F5b の3項目のみ(2026-09-12 に範囲を明記済み)。**F2 と F3 は複数世代を汚染しており F4 と同等以上に重い**が、世代別マッピングがどこにもない | 監査文書、または論文 §9 |

## C. 解決済み(記録のみ)

| # | 内容 |
|---|------|
| C1 | **F3(討論に lesson/memory 非注入)は v9c2 で解消**。`run_experiment_v9c2.rb:251-261` が `learner_memories:` を渡している。v9b・v9c は未修正のまま(該当世代の分析ドキュメントに注記済み) |
| C2 | **F4(pseudoreplication)は v9c2 で解消**。全 discussion 条件で unique discussions = 5/5 |
| C3 | **F5b(単一インスタンス)は v9c2 で部分解消**。`classroom_teacher` 1体 → 20体。evaluator の複数化は no-op として意図的に見送り(理由はコードと整合) |
| C4 | **監査文書を v4–v9c2 に拡張済み**(2026-09-12)。v9c2・ablation の行を全表に追加し、F4 の「✅解消」を記録。**是正が監査文書に書き戻された** |

## D. 査読とは別に残っている宿題

- masumi 自身による**論文の通読**(他者への査読依頼の前提条件)
- DOI 2件が解決するか確認
- `.tex` のコンパイル(ローカルに LaTeX 環境なし)
- 次のリリース時に Zenodo の deposit description を更新
- 論文固有の2箇所を世代査読と別枠で確認: **AI involvement statement**(自分の認識と一致するか)と
  **§9 Limitations**(「これで全部だと思うか」)
