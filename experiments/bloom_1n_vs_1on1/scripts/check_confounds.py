#!/usr/bin/env python3
# ABOUTME: Reports learner-profile diversity and single-instance moderator/evaluator/tutor risk for a run
# ABOUTME: Usage: python3 check_confounds.py <db_path> <run_id>

import sqlite3
import sys
from collections import Counter

ROLES_TO_CHECK = ('classroom_teacher', 'tutor', 'evaluator')


def check_confounds(db_path, run_id):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row

    profiles = Counter()
    for r in con.execute(
        "SELECT profile_json FROM agents WHERE run_id = ? AND role = 'learner'", (run_id,)
    ):
        profiles[r['profile_json'] or '(none)'] += 1
    print("Learner profile distribution:")
    for p, c in profiles.most_common():
        print(f"  {c:>3}  {p}")
    print(f"  -> distinct profiles: {len(profiles)}")
    print()

    print("Single-instance role check:")
    for role in ROLES_TO_CHECK:
        ids = [r[0] for r in con.execute(
            "SELECT DISTINCT id FROM agents WHERE run_id = ? AND role = ?", (run_id, role)
        )]
        if ids:
            flag = '  <-- SINGLE INSTANCE (tutor/judge variance ≠ condition variance)' if len(ids) == 1 else ''
            print(f"  {role:<20} distinct instances: {len(ids)}{flag}")
    print()

    print("learning_sessions rows per condition (phase-exposure check):")
    for r in con.execute(
        "SELECT condition, COUNT(*) AS n FROM learning_sessions WHERE run_id = ? GROUP BY condition",
        (run_id,)
    ):
        print(f"  {r['condition']:<35} {r['n']}")
    con.close()


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 check_confounds.py <db_path> <run_id>", file=sys.stderr)
        sys.exit(1)
    check_confounds(sys.argv[1], sys.argv[2])
