#!/usr/bin/env bash
# ABOUTME: Runs all minitest unit tests for this experiment
# ABOUTME: Execute from project root: bash experiments/bloom_1n_vs_1on1/tests/run_tests.sh

set -euo pipefail

EXPERIMENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$EXPERIMENT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"
eval "$(mise activate bash)" 2>/dev/null || true
bundle exec ruby "$EXPERIMENT_DIR/tests/test_helpers.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_db.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_scorer.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_classification.rb"
echo "All tests passed."
