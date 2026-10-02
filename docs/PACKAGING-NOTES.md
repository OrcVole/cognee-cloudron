# Packaging notes (verified-versus-assumed log, newest first)

Anonymised. Box-specific detail lives in the maintainer's local notes, not here.

---

## 2026-10-02: first release, 0.1.0 (Cognee 1.6.2)

First packaging round, built and gated against the shipping image digest on a test box (Cloudron 10.0.5,
PostgreSQL 16). Evidence is in [DEBUGGING.md](DEBUGGING.md).

**Validated (decisions that held up):**

- **Keyless default** ([ADR-0001](decisions/0001-keyless-by-default.md)). Three documents were added and
  `cognify` ran with no language model in 40 s; a chunk search found them.
- **Models in a persistent directory** ([ADR-0002](decisions/0002-models-in-a-persistent-directory.md)). After an
  in-place update the old directory was gone, and a clone refilled its models on first use.
- **Secrets generated once.** The hash of the secrets file was identical before and after a restart, an update, a
  restore and a clone.
- **One address, split by version segment.** nginx sends `/health` and `/api/v<N>/` to the API and the rest to the
  interface; the proxy keeps the original `Host` header including the port (`$http_host`, not `$host`).

**Surfaced (wrong or missing, and fixed):**

- **`gosu` discards `HOME`.** The processes lost their home and tried to write into the read-only tree. The run
  scripts now export it explicitly.
- **nginx `$host` drops the port**, which broke the interface's server actions behind the platform's proxy. Fixed
  with `$http_host`. The smoke check for it first used a made-up action ID and passed vacuously; it now extracts a
  real ID from the built chunks.
- **`ACCEPT_LOCAL_FILE_PATH=false` rejects every upload** (415) unless an allowed-roots variable is set too. The
  package sets `True` with the roots pinned to the data directory.
- **A memory limit hit thousands of times with no OOM kill.** See [ADR-0003](decisions/0003-memory-limit.md).
- **Backup size.** 418 MB for about 2 MB of data until the models moved out of `/app/data`.
- **A scan that printed OK while skipping its image half** now fails when the image is not present.

**Still open:**

- Gate 5 (the stranger path from the published versions file) is recorded in `DEBUGGING.md` once run.
- Creating further users beyond the administrator is unverified.
- The extraction runtime's first-use download needs outbound internet; behaviour with the network blocked is
  unverified.

---

## Conventions for this file

Newest first. Every claim carries its evidence. Verified and assumed are kept apart.
