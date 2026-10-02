# Gate evidence

Anonymised results of the acceptance ladder, run against the **shipping image digest**
`sha256:4d3ccda22eea24fa94b67860d8f0e5e46a721cf34f6d80b2da4397c5cd483bf9` (tag `1.6.2-2`, manifest 0.1.0) on a
test box running Cloudron 10.0.5 with PostgreSQL 16. A rebuilt image restarts the ladder at gate 0.

| Gate | Result | Evidence |
|---|---|---|
| 0 install, health, first run | **PASS** | image ID on the box equals the pushed image; healthy within a minute; the three processes running; secrets file mode 600 `cloudron:cloudron` with an identical hash before and after a restart; no permission errors, read-only errors or restart loops in the idle log |
| 1 auth | **PASS** | sign-in in a real browser over HTTPS with no server errors on three pages; wrong password 400; no credential 401; made-up API key 401; self-registration 403; the four interface routes that need a session 401 without one; `/health`, `/docs` and the sign-in page open |
| 2 flows | **PASS** | `test/gate2.sh` 20 of 20: three documents added, keyless `cognify` in about 40 s, chunk search finds them, an API key issued, used, revoked and then refused; the script was shown to fail on a wrong password and on a dead address |
| 3 update, backup, restore, clone | **PASS** | see below |
| 4 memory | **PASS at 8 GiB** (fails at 4 GiB) | see below |
| 5 stranger path | recorded below once run | install from the published versions file |

## Gate 3

Baseline: 3 documents in one dataset, a fixed node fingerprint, a fixed PostgreSQL row count, the secrets file hash.

| Invariant | After update (an older build to this one) | After restore | After clone |
|---|---|---|---|
| documents, nodes, edges, node fingerprint, PostgreSQL rows | identical | **identical to the state at backup** | identical |
| secrets hash and mode | identical, 600 | identical | identical |
| search | finds the text | finds the text | finds the text |
| churn (3 more documents, rebuilt graph) | n/a | **gone** after the restore | n/a |
| the old model folder in the data directory | **removed** by `start.sh` | n/a | n/a |
| the persistent model folder | created, refills on first use | untouched by the restore | starts with only the small embedding model; refilled to full on the first `cognify` |
| backup size | a fraction of the 418 MB it was while the models lived in the data directory | | |

A first churn silently added nothing (HTTP 409 on reused file names) and was caught because the state was identical
to the backup; the driver now stops on any non-200.

## Gate 4

Load: 348 documents through the keyless `cognify` (local extraction and embedding models on CPU).

| | 4 GiB | 8 GiB (shipping digest) |
|---|---|---|
| idle | 822 MB | 888 MB |
| `memory.peak` | 4.29 GB, the cap | 7.25 GB (about 1 GB is reclaimable file cache) |
| anonymous memory after the drain | 4.18 GB plus 1.86 GB swapped | 5.19 GB, no swap |
| `memory.events` `max` (times the limit was hit) | **3,997** | **0** |
| swap peak | **2.23 GB** | 0 |
| `oom_kill` | 0 | 0 |
| health during and after | 200 | 200, all 348 documents landed |

At 4 GiB nothing was killed, which is what makes it dangerous: swap absorbed 2 GB and a user would only see a slow
app. The shipped limit is 8 GiB. The loaded models and allocator caches are not released after the load.

## Divergences from prediction

1. Backup size was 418 MB for about 2 MB of data until the models moved to a persistent directory.
2. Boot takes about 48 s to the backend serving; one health probe was aborted in that window.
3. The restore leg cannot log "existing secrets found": idempotence is proven by the secrets hash instead.
4. Images loaded straight into a test box lose their tag when the platform prunes; re-tag before any resize,
   repair or update.
5. The test box's kernel cannot reset `memory.peak`; restart the app for a clean high-water mark.
