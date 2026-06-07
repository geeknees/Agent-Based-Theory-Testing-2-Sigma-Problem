#!/usr/bin/env python3
# ABOUTME: Hashes learning_sessions.transcript_json per condition to count independent discussion instances
# ABOUTME: Usage: python3 check_replication.py <db_path> <run_id>

import sqlite3
import hashlib
import sys
from collections import defaultdict


def check_replication(db_path, run_id):
    con = sqlite3.connect(db_path)
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "SELECT condition, transcript_json FROM learning_sessions WHERE run_id = ?",
        (run_id,)
    ).fetchall()

    by_cond = defaultdict(lambda: {'hashes': set(), 'rows': 0})
    for r in rows:
        h = hashlib.md5(r['transcript_json'].encode()).hexdigest()
        by_cond[r['condition']]['hashes'].add(h)
        by_cond[r['condition']]['rows'] += 1

    print(f"{'condition':<35} {'sessions':>9} {'unique_discussions':>20}")
    for cond, stats in sorted(by_cond.items()):
        print(f"{cond:<35} {stats['rows']:>9} {len(stats['hashes']):>20}")
    con.close()


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 check_replication.py <db_path> <run_id>", file=sys.stderr)
        sys.exit(1)
    check_replication(sys.argv[1], sys.argv[2])
