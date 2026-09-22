# 論文 §6–§9 人間セルフ査読記録

査読者: masumi / 日付: ____ / 所要: ____
プロトコル: `docs/templates/human-review-protocol.md`(重み: **フル**)
対象: `results/2026-06-16-paper-draft.md` / `.tex`。とくに **§6 Confound Taxonomy・§7 v9c2・
§8 Cross-Cutting Findings・§9 Limitations**。
位置づけ: **査読シリーズの最終項目**。全世代の持ち越し(`reviews/CARRIED-OVER.md` の A1–A5・B2・B3・B5)の
文面をここで確定する。

> **プロトコル §6 が定める別枠2箇所**(世代査読とは別に、masumi 自身の目で確認すること):
> - **AI involvement statement**(front matter)— 自分の認識と一致しているか。**ここだけは AI が代弁できない**
> - **§9 Limitations** — 「これで全部だと思うか」

---

## エージェント準備: claim→evidence トレース表

| # | 主張(論文) | DB・コードでの検証結果 | 一致? |
|---|---|---|:---:|
| 1 | Appendix A の学習者数 n(9世代) | 11 / 15 / 15 / 12 / 12 / 16 / 34 / 34 / 154 — **9件すべて一致** | ✅ |
| 2 | §7 主結果表: lecture 83%・pair 80%・small 76%・medium 86%・large 81% | 83.3 / 80.0 / 75.6 / 86.1 / 81.1(L6除外) | ✅ |
| 3 | §7 readiness 90%(edge_case 100・recall 91・procedure_order 85・rule_interaction 85) | 556/616 = 90.3%、内訳も一致 | ✅ |
| 4 | §7 learner type spread 38pp(edge_case_dropper 96% vs passive_listener 58%) | 96.0 / 57.6 | ✅ |
| 5 | §8-1「no-education baselines sat at 0% throughout」 | v4・v5・v6 の no_education はいずれも 0/24 | ✅ |
| 6 | §9「passive_listener … is lowest in v6, v9b, v9c, and v9c2」 | v6 25%(最下位)・v9b 37.5%(最下位)・**v9c 43.75% = order_confused と完全同率**(ともに 35/80)・v9c2 57.6%(最下位)。**v9c のみ「単独最下位」ではない**(所見3) | ⚠️ |
| 7 | §6 末尾「Its summary matrix shows F4 present (✓) in every generation except v8 (partial)」 | **2026-09-12 の監査査読で監査表を修正したため、記述が現行の監査表と一致しなくなった**(所見1) | ❌ |
| 8 | Appendix B「F3 … Affected generations: v8 (partial), v9b, v9c」 | `whole_class_discussion.rb:37-41` は participant に **lesson もメモリも渡さず** learner type 文字列のみ。同ファイルは 2026-05-24 以降変更なし、v8 実行は 05-27。**構造的には v8 も完全に F3 の影響下**(所見2) | ❌ |

## 横展開チェック(§3)エージェント下ろし分

- **論文が自力で正しく扱えている点**(査読で崩れなかったもの):
  - §7 が interpretation flags を「*threshold* tests … not significance tests」と明記し、
    「the honest reading is "no *large* effect," not "exactly zero."」と書いている
    → **持ち越し A4(null の強さ)は論文側で既に処理済み**
  - §8-2 が v9c→v9c2 の帰属について「six remediations *at once*」「we cannot attribute the collapse to
    any single control」と述べ、ablation の readiness 53% 失敗まで明記
    → **持ち越し A5(帰属の議論)も論文側で既に処理済み**
  - §9 が residual token asymmetry を「**the live confound**」として自認
  - §9 が「Reflexivity of AI authorship」「監査自体がエージェント実行」「independent human replication of
    the audit is the obvious external check」と明記。**本セルフ査読はまさにその external check に当たる**
- **数値の健全性**: Appendix A の n、§7 の主結果表、readiness、learner type spread は**すべて DB と一致**。
  世代査読で見つかった数値誤り(v8 の講義長、v9c2 の §2.1、v7b の §3.3 等)は**いずれも分析ドキュメント側**であり、
  **論文本体には伝播していない**
- **天井/床の扱い**: §4.5 が L6 の exact-match 失敗を明記し main score から除外。
  `peer_error_detection`(v9c2 で 99-100%)の天井には言及がない
- **未検証**: DOI 2件の解決確認、`.tex` のコンパイル(いずれも masumi の宿題として継続)

## 所見(エージェント検出分。処置の判断は masumi)

| # | 深刻度 | 内容 | 処置 |
|---|--------|------|------|
| 1 | **high(監査表の修正に伴う不整合・新規)** | **2026-09-12 の監査査読で監査表を修正した結果、論文の記述が現行の監査表と食い違った。**<br>§6 末尾: 「Its summary matrix shows F4 present (✓) in every generation **except v8 (partial)** and F5b present in all」<br>Appendix B: 「F4 … Affected generations: **v4–v9c (v8 partial)**」<br>修正後の監査表では (a) **v8 は「✓該当(WCD 1/4)」**(Phase 3 だけで数えると WCD は v4–v7 の classroom と同一で、「partial」ではない)、(b) **v9c2 に「✅解消(各5/5)」の列を新設**。<br>→ 論文側も「v8 を例外としない」「v9c2 で解消したことを明示する」形に改める必要がある。<br>なお**この不整合は論文が誤っていたのではなく、監査表の側を正した結果**である。§6 の「the two structural confounds were *baked in from the first experiment*」という主張は、v8 を例外から外すことで**むしろ強まる** | (masumi 判断) |
| 2 | **medium(影響世代の過小評価・新規)** | Appendix B は F3 の影響世代を「**v8 (partial)**, v9b, v9c」としているが、v8 の討論参加者も **lesson もメモリも受け取っていない**。`lib/phases/whole_class_discussion.rb:37-41` の `learner_ctx` は `"YOUR LEARNER TYPE: … — respond authentically."` のみで、context は `"DISCUSSION SO FAR:\n#{history}"`。同ファイルは 2026-05-24 以降未変更、v8 実行は 05-27 → **実行時のコードがこれ**。moderator の opening にもルールは含まれない(全文確認済み)。<br>→ 構造的には **v8 も v9b/v9c と同じ完全な F3** であり「partial」ではない。<br>**さらに厄介な観察**: それにもかかわらず v8 の参加者は **Green=2・Blue=5・Yellow=7 と正しい基底値を使って計算している**(「Green (pos 2): Not last, so active. Base 2 × 2 (Red) = 4」)。v9b/v9c で観測された「I don't actually know the rules」型の発話は v8 には無い。**同じ構造的欠落から、一方は正答を即興し、他方は棄権した**。<br>→ v8 の討論発話は「学習の反映」ではなく**素のモデルの即興**である可能性があり、それが偶然正しかったことになる。「partial」というラベルはこの現象を覆い隠している | (masumi 判断) |
| 3 | low(精度) | §7 と §9 が「the passive_listener … is lowest in v6, v9b, v9c, and v9c2」と述べるが、**v9c では order_confused と完全同率**(ともに 35/80 = 43.75%)であり単独最下位ではない。他3世代は単独最下位。<br>§9 は 38pp の learner-type spread について「we lean on it more heavily only because it is larger and **directionally consistent across four generations**」と書いており、この「4世代で一貫」の一角が同率である点は、主張を崩しはしないが**正確には「4世代で最下位またはその同率」**である | (masumi 判断) |
| 4 | **持ち越し A1(v7a/v9c/v9c2)** | **readiness ゲートの4問中2問は、答えが固定講義に worked example として載っている。**<br>`rc_recall_01` `[Yellow, Green]`→7 ↔ `fixed_lecture_v9c.md` l.62-65、`rc_edge_case_01` `[Red, Blue]`→0 ↔ 同 l.81-84。<br>**2世代連続で「掲載あり」の2項目が pass rate 上位**(v9c 100%/68% vs 59%/50%、v9c2 100%/91% vs 85%/85%)。<br>→ §7「the first generation to clear the gate, so the condition contrast is, for the first time, measured over learners who **genuinely held the prerequisites**」の「genuinely」が、少なくとも edge_case と recall については「講義に載っていた答えを再生できた」を意味しうる。<br>**留保**: 評価タスク側には同じ signature が出ない(v9c の `l2_edge_case_01` は掲載ありで 17.6%)。断定はできず、**readiness を前提知識の定着度として読む根拠がその分だけ弱まる**という水準。<br>→ §7 に一文、または §9 に限界項目を足すのが妥当 | **fixed**(2026-09-22): §9 に限界項目「Readiness items overlap the teaching material」を追加(md・tex 両方)。掲載2項目が両世代で pass rate 上位であること、評価タスクには同じ signature が出ないこと、clean gate の条件を明記 |
| 5 | **持ち越し A2(v6/v7b)** | **`order_confused` 型は一度も成立していなかった。** `rule_order_retention` は `rules` 配列を shuffle するだけで、手順が書かれた `strategy` フィールドは対象外。v7b の12名全員(手順教示を受けていない classroom/generic の8名を含む)の `strategy` に正しい順序が残っていた。<br>該当3箇所:<br>**l.118** 「with probability `1 − rule_order_retention` the ordered rule list is shuffled (**degrading procedural knowledge**)」→ **実装の説明として不正確**<br>**l.149** finding (iii) 「correcting a *propositional* misconception … does nothing for a *procedural* deficit (**shuffled rule order**)」<br>**l.232** §8-4(ii) 「correcting a stated misconception leaves **procedural deficits** … untouched」<br>→ **観測は生き残り、説明が崩れる**。誤解修正率と得点の乖離(v6 75%、v7b 100%)は DB 照合済みの事実であり finding (iii) 自体は保持できるが、**その理由を「手続き的欠損」に帰す説明は根拠を失う** | (masumi 判断) |
| 6 | **持ち越し A3(ablation)** | **F2 の修正(A8)の後半が機能していない。** `SEMANTIC_TASK_TYPES`(2026-06-15 導入)により L6 は LLM 判定へ回るが、**`answer_correct` を設定するのは `lib/scorer.rb` の exact-match 経路だけ**で、`evaluator.rb` の LLM 経路は設定しない(`LLM_FALLBACK_SCORE` にもキーがない)。<br>`experiment_v9c2_ablation_smoke.db` で実証: L6 行は `auto_scored=0` / **`total` 11〜20点(満点20)** / **`answer_correct` は null**。**LLM は「ほぼ正答」と採点しているのに集計は 0 と数える**。<br>→ §6 F2 の「*Remediation A8:* exclude L6 from the main score and **route it to an LLM semantic judge** …, implemented for subsequent runs」と Appendix B「A8: exclude L6 + semantic judge」は、**前半(除外)は成立、後半(judge への再ルーティング)は結果が主要スコアに届かない**。<br>修正自体は数行だが**適用には再実行が必要**。**論文としては「実装したが検証はこれから」と書くか、現状を正確に記すかの判断** | **fixed**(2026-09-22): §9 に限界項目「The L6 semantic judge's verdict never reaches the score」を追加(md・tex 両方)。A8 の前半は成立・後半は届いていないこと、**本論文のどの世代にも検証済みの L6 測定値は存在しない**こと、run report の L6 は「0%」ではなく「未測定」と読むべきことを明記 |
| 7 | **持ち越し B2** | **interpretation flags が閾値テストであることの明示。** §7 は既に「these flags are *threshold* tests …, not significance tests」と**正しく明記している**。残る問題は `lib/report.rb:876-905` の計算式が文書側に無いこと: `class_size_effect_supported` は**完全単調のみ true**(4条件が偶然一致する確率 1/24 ≈ 4%)なので「false = サイズ効果なし」と読めず、`discussion_added_value` は**1条件でも baseline+5pp を超えれば true**。<br>→ **論文本体は既に適切**。Appendix C か §7 の脚注に判定式を1行足すかの判断 | (masumi 判断) |
| 8 | **持ち越し B3** | **run report の生成物の問題。** 存在しない条件の表(ablation run report の tutoring 列 全0%、`unknown` プロファイル行、v4 期の `classroom_advantage_under_homogeneity`)が残る。L6 Appendix はハードコード文字列により**同一表内で3つの矛盾する説明**を出力する(`lib/report.rb:584-603`)。<br>論文は **ablation の run report を verbatim で公開**する(front matter・§10)としているため、**外部査読者はこの残骸を目にする**。<br>→ `lib/report.rb` の修正か、公開時の注記かの判断。ablation は DB 紛失により再生成不可 | (masumi 判断) |
| 9 | **持ち越し B5** | **F1/F2/F3/F5c の世代別横断表が存在しない。** Appendix B は「Affected generations」列で各 F の影響世代を挙げており、**実質的にこれが横断表の役割を果たしている**。監査文書側には無い。<br>→ Appendix B が既にその役割を担っていることを確認したため、**追加作業は不要と判断してよい**。ただし所見1・2 により **F4 と F3 の「Affected generations」列は修正が必要** | (masumi 判断) |
| 11 | **medium(著者の理解と論文の乖離・理解テストで検出)** | **通読直後に masumi が書いた理解の5行目に、論文が主張していない内容が2つ含まれていた。**<br>(a)「生徒の主体性が正答率に貢献する傾向が見られた」→ **論文の結論と逆**。v9c2 の `ownership_effect_supported` は **false**、§7 は「Ownership と Score の間に単調な関係は見られない」、§5.3 は v9b について「**neither** a monotone class-size effect **nor** an ownership–outcome correlation」。主体性の効果は v9c(readiness 不合格)でのみ true であり、統制すると消えた3効果の1つ<br>(b)「1to1では先生の指導力が求められる」→ **論文に該当する主張がない**。近いのは F5b(single-instance role agents)だが、これは「teacher が1体だったため条件効果と教師個体の癖を分離できない」という**交絡の指摘**であって、指導力が結果を左右したという発見ではない<br>**論文側の記述は一貫しており(§5.3・§7 を確認済み)、誤りではない。** 出所は査読過程で読んだ中間成果物と推定される: (a) は v9c 分析ドキュメントの `ownership_effect_supported: true`、(b) は v5 査読の所見「プロファイルは tutor 側の適応経路でのみ効いている」。<br>→ **11世代ぶんの中間成果物を読んだ結果、分析ドキュメントの中間結論と査読所見が、論文の最終結論と混ざった。** 外部査読の場で著者が論文の主張していないことを擁護するリスクにあたる。<br>**論文の修正は不要。記録として残す** | **半分は論文側の問題と判定 → fixed**(2026-09-22): masumi の指摘により再調査したところ、**ownership の null は論文中で地の文として一度も述べられていなかった**(§7 のフラグ名の羅列と従属節の2箇所のみ)。さらに §8「Cross-Cutting Findings」の5項目に **null が独立項目として存在せず**、3つの null(クラスサイズ・主体性・討論の付加価値)が §8-1 の1文に束ねられていた。<br>→ §8 を8項目に再編し、**2「Class size does not predict outcome」・3「Ownership does not predict outcome」・4「Discussion adds no measurable value over individual reflection」を独立の発見として立てた**(md・tex 両方)。各項に世代別の実測値を添え、4の末尾に「a null reported only as a flag value is easy to lose」と明記。<br>**ヘッジは一切外していない**(§7・§8-5・§9 の留保は正確であり、問題は null が発見として提示されていなかったこと)。<br>なお (b)「1on1 では先生の指導力」は論文に対応する記述が無く、**書き方では防げない**。v5 査読所見の混入として記録にとどめる |
| 10 | low(評価) | **論文は分析ドキュメントより一貫して慎重である。** 世代査読で見つかった数値誤り(v8 の講義長 17,826、v9c2 §2.1 のスモーク取り違え、v7b §3.3 の8セル、v9b の v8 比較)は**いずれも論文本体に伝播していない**。<br>また §7 の「no *large* effect, not exactly zero」、§8-2 の「we cannot attribute the collapse to any single control」、§9 の「the auditor and the audited share a substrate」は、**本査読で独立に到達した留保と同じ内容を先に書いている**。<br>持ち越し A4(null の強さ)と A5(帰属)は、**論文側で既に処理済みとして閉じてよい** | (記録のみ) |

## 持ち越し(`CARRIED-OVER.md`)の帰結

| # | 内容 | 本査読での判定 |
|---|------|---------------|
| A1 | 教材と readiness タスクの重複 | **所見4** — §7 または §9 に追記が要る |
| A2 | order_confused 型が未成立 | **所見5** — l.118/l.149/l.232 の書き換えが要る |
| A3 | semantic scorer の結果が届かない | **所見6** — §6 F2 と Appendix B の記述に要修正 |
| A4 | null の強さ | **解決済み** — §7・§9 が既に適切に扱っている(所見10) |
| A5 | 帰属の議論 | **解決済み** — §8-2・§9 が既に適切に扱っている(所見10) |
| B2 | flags が閾値テスト | **ほぼ解決** — §7 が明記済み。判定式の追記は任意(所見7) |
| B3 | run report の残骸 | **所見8** — 公開物に残るため判断が要る |
| B5 | F の横断表 | **不要と判断** — Appendix B が役割を果たしている(所見9) |

**新規に論文修正が必要なもの: 所見1(監査表との不整合)・所見2(F3 の影響世代)・所見3(同率の精度)。**

## 確認したこと(masumi 記入)

- **論文通読(2026-09-22)**: front matter から §10・付録まで通読。**他者への査読依頼の前提条件を満たした**
- **AI involvement statement の確認(プロトコル §6 必修)**: **実態と一致している**と判定。
  「the human author, who framed the research question, approved each generation's design,
  and reviewed the outputs」は masumi 自身の認識と合う
- **§9 Limitations は「これで全部」か(プロトコル §6 必修)**: **不足あり → 修正した**。
  本査読で出た A1(readiness 項目と講義の重複)と A3(L6 semantic judge の判定が主要スコアに届かない)が
  10項目のどこにも入っていなかった。2項目を追加(所見4・6 の処置)
- 垂直貫通: 所見1(監査表との不整合)について 論文 §6/Appendix B → 監査表(2026-09-12 修正版)→
  `check_replication.py` の Phase 分離実測、まで貫通。
  所見2(F3 の影響世代)について Appendix B → `whole_class_discussion.rb:37-41` →
  git log(2026-05-24 以降未変更、v8 実行は 05-27)→ v8 討論トランスクリプトの実データ、まで貫通

## 信頼で受け入れたこと(未検証)

- (記入)

## 見ないで書いた5行要約(masumi 記入)

> 本項目のみ、対象が実験ではなく論文であるため次の5点で記入する。

1. この論文が主張していること(2つの貢献):
2. その根拠として何を示しているか:
3. 査読を通じて自分が確認できたこと:
4. 自分が確認できていないこと・信頼で受け入れていること:
5. 外部査読者に依頼する前にすべきこと:

## チェックリストへの追記候補

- (記入)
