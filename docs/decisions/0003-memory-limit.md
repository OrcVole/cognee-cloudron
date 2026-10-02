# ADR-0003: memoryLimit 8 GiB

**Status:** accepted.

**Context.** Ingesting 348 documents through the keyless path.

| | 4 GiB | 8 GiB |
|---|---|---|
| peak (`memory.peak`) | 4.29 GB, the cap | 7.27 GB (about 1 GB is reclaimable file cache) |
| steady anonymous memory after the drain | 4.18 GB plus 1.86 GB swapped | 5.29 GB, no swap |
| times the limit was hit (`memory.events max`) | 3,997 | 0 |
| swap peak | 2.23 GB | 0 |
| OOM kills | 0 | 0 |

**Decision.** 8 GiB. At 4 GiB nothing was killed, which is what makes it dangerous: swap absorbed the overflow and
a user would only see a slow app. Judge a limit by `memory.events` and `memory.swap.peak`, not by OOM kills.

**Consequences.** The loaded models are not released after a load; they stay resident until the app restarts.
With a language model and an embedding endpoint configured the app is far lighter (about 2.4 GB observed), and an
operator can lower the limit in the dashboard.
