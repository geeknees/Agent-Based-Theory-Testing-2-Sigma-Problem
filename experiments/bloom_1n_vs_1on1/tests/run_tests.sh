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
bundle exec ruby "$EXPERIMENT_DIR/tests/test_profiles.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v5.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_learner_types.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_classroom_forced_checkin.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_tutoring_procedure_scaffolded.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v7.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_db_v9b.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_memory_diagnostics.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_sized_discussion_unit.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v9b.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_memory_diagnostics_v9c.rb"
bundle exec ruby "$EXPERIMENT_DIR/tests/test_report_v9c.rb"
echo "All tests passed."
