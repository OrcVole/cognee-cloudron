#!/app/code/.venv/bin/python
"""Daily LanceDB maintenance for the Cognee package.

Cognee 1.6.4 removed LanceDB's automatic background pruning. LanceDB writes new fragment and manifest files on
every write, and /app/data is backed up, so without pruning the file count grows without bound. For every
LanceDB table under the system root this compacts small files and removes versions older than
COGNEE_LANCEDB_RETENTION_DAYS (default 7) with Table.optimize(). LanceDB never removes the latest version, and
cleanup is designed to run beside writers; a commit that conflicts with a write is logged and retried next day.
"""
import os
import sys
from datetime import timedelta

ROOT = os.environ.get("COGNEE_LANCEDB_ROOT", os.path.join(os.environ.get("SYSTEM_ROOT_DIRECTORY", "/app/data/system"), "databases"))


def log(msg):
    print("lancedb-maintain: " + msg, flush=True)


def count(path):
    files = 0
    for _, _, names in os.walk(path):
        files += len(names)
    return files


def main():
    try:
        days = int(os.environ.get("COGNEE_LANCEDB_RETENTION_DAYS", "7"))
        if days < 0:
            raise ValueError
    except ValueError:
        log("COGNEE_LANCEDB_RETENTION_DAYS must be a whole number of days, 0 or more")
        return 2
    if not os.path.isdir(ROOT):
        log("no LanceDB directory yet at %s, nothing to do" % ROOT)
        return 0
    import lancedb

    tables = []
    for dirpath, dirs, _ in os.walk(ROOT):
        for d in list(dirs):
            if d.endswith(".lance"):
                tables.append((dirpath, d[: -len(".lance")]))
                dirs.remove(d)  # do not descend into a table
    if not tables:
        log("no LanceDB tables under %s, nothing to do" % ROOT)
        return 0
    failed = 0
    for parent, name in sorted(tables):
        tdir = os.path.join(parent, name + ".lance")
        before = count(tdir)
        try:
            table = lancedb.connect(parent).open_table(name)
            table.optimize(cleanup_older_than=timedelta(days=days))
            log("%s: optimised, files %d -> %d, keeping versions newer than %d days" % (os.path.relpath(tdir, ROOT), before, count(tdir), days))
        except Exception as exc:  # one bad table must not stop the rest
            failed += 1
            log("%s: FAILED: %s" % (os.path.relpath(tdir, ROOT), exc))
    log("done, %d tables, %d failed" % (len(tables), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
