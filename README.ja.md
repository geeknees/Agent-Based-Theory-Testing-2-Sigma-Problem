# エージェントによる理論検証:ブルームの2シグマ問題

[![DOI](https://zenodo.org/badge/1240576444.svg)](https://doi.org/10.5281/zenodo.21186082)

*[English](README.md) / 日本語*

LLM エージェントは社会科学の理論を検証する**実験台**になりうるのか? 本リポジトリは、ベンジャミン・ブルームの**「2シグマ問題」**——1対1のマスタリー・チュータリングは、従来型の集団指導より約2標準偏差高い学習効果を生むという主張——を、LLM エージェント集団の実験として操作化し、その効果が再現するかを問います。

結論は否です。合成的なルール領域(*Zarn Tokens*)上で7世代(v3–v9c2)にわたり実験した結果、集団指導は1対1チュータリングと同等かそれ以上でした。最も厳密な実験(v9c2;学習者154名、240万トークン)では、教育条件間の差は **10ポイント**まで縮小する一方、*学習者の認知プロファイル*間の差は **38ポイント**に達しました。初期世代で見られた37ポイントの「ディスカッションの優位性」は、反復(replication)と前提知識の統制のもとでは消失しました。

本論文のより普遍的な貢献は方法論にあります。エージェントによる理論検証のための**交絡を意識したフレームワーク**——5系統の交絡分類(F1–F5)、是正レシピ(A コード)、真の反復のための*population-multiplication* 設計、前提知識統制のための*readiness gate*——です。

> **ステータス:** ワーキングペーパー — 査読は受けていません。これは探索的な理論検証とプロトコル開発であり、いかなる教育的主張の証明でもありません。本実験は LLM エージェントが人間の学習者であるとは主張しません。「学習」は対話トランスクリプトから形成される条件固有のメモリとして操作化されています(モデルの重みは更新しません)。

## 論文

- **Markdown:** [`experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.md`](experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.md)
- **LaTeX:** [`experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.tex`](experiments/bloom_1n_vs_1on1/results/2026-06-16-paper-draft.tex)

※ 論文本文は英語です。

## リポジトリ構成

| パス | 内容 |
|------|------|
| `experiments/bloom_1n_vs_1on1/` | 実験本体:コード、設定、プロンプト、ドメイン、テスト、結果 |
| `experiments/bloom_1n_vs_1on1/README.md` | 各世代(v6–v9c2)の実行方法 |
| `experiments/bloom_1n_vs_1on1/results/` | 世代ごとの分析、方法論の補遺、論文 |
| `experiments/bloom_1n_vs_1on1/config/` | 世代ごとの設定(haiku 用の `*_smoke.yml` を含む) |
| `docs/superpowers/plans/` | 各世代の設計プラン(開発記録) |

実行ごとのデータベースと生の実行ディレクトリ(`data/runs/`、`data/*.db`)は gitignore 対象です。報告された数値と run 識別子は `results/` 内の世代別分析ドキュメントに記載されています(論文 Appendix A の run index 参照)。

## 実験の実行

LLM 呼び出しは API キーではなく Claude Code CLI(`claude --print`)をシェル経由で呼ぶため、フルランは長時間のバックグラウンドジョブとして Claude Code のトークン枠を消費します。世代ごとのコマンドは [`experiments/bloom_1n_vs_1on1/README.md`](experiments/bloom_1n_vs_1on1/README.md) を参照してください。概要:

```bash
bundle install
bundle exec ruby experiments/bloom_1n_vs_1on1/scripts/run_experiment_v9c2.rb \
  experiments/bloom_1n_vs_1on1/config/config_v9c2.yml
```

各世代には、本番ランの前に高速な end-to-end 検証を行うための縮小スケール版 `*_smoke.yml`(haiku)が用意されています。

## 引用

本成果を利用する場合は、ワーキングペーパーを引用してください。

```
Kawasaki, Masumi. "Can LLM Agents Test Social-Science Theory? A Confound-Aware
Framework and a Seven-Generation Negative Result on Bloom's 2-Sigma Problem in
LLM Agents." Working paper, 2026. https://doi.org/10.5281/zenodo.21186083
```

## ライセンス

[MIT](LICENSE) © 2026 Masumi Kawasaki
