# AGENTS.md: Cognee Cloudron package working contract

The settled-decisions record for packaging **Cognee** (`cognee`, Apache-2.0) as a Cloudron community app. Read
this before changing anything. Do not relitigate these decisions without a concrete reason found on a running
box. **The box is the authority, not the docs.**

## What this package is

Cognee is an open-source memory layer for AI agents: documents go in, a knowledge graph and a vector index come
out. This package runs upstream's API and its Next.js web interface behind one address, from upstream release
**1.6.2** (commit `ba3631f`), on `cloudron/base` 6.0.0. It contains no upstream source; the image build fetches
it at the pinned commit.

| Process | Role | Port (localhost) |
|---|---|---|
| nginx | front proxy: `/health` and `/api/v<N>/` to the API, the rest to the interface | 8080 (the platform's `httpPort`) |
| backend | upstream's FastAPI application | 8000 |
| ui | upstream's Next.js interface | 3000 |

State: the relational store is the platform's PostgreSQL addon. The graph store (Kuzu) and the vector store
(LanceDB) are files under `/app/data`. Not included: upstream's MCP server, its Neo4j and other optional stores,
and anything behind a commercial licence.

## Golden rules

1. **Conformance to the Cloudron contract first.** Adapt the runtime environment only. Never patch the application.
2. **Pin everything by digest**: the base image, every build-stage image, and the upstream commit (in the `src`
   stage), mirrored in the manifest as `upstreamVersion`.
3. **Persisted state in `/app/data`; re-downloadable models in `/app/models`** (a `persistentDirs` entry, kept
   across updates and left out of backups). Ownership is re-asserted on every boot, because a restore drifts it.
4. **Fail loud.** Secrets are generated once and never regenerated.
5. **Code and docs ship together.** Decisions in `docs/decisions/`, the verified-versus-assumed log in
   `docs/PACKAGING-NOTES.md`, gate evidence in `docs/DEBUGGING.md`.
6. **`CMD`, never `ENTRYPOINT`.** Maintain `.dockerignore` as carefully as `.gitignore`.
7. **Anonymise before every push.** No real hostnames, no emails beyond the manifest's `contactEmail`, no tokens.
   `example.com` is the placeholder. `test/secret-scan.sh` is the release gate and scans the repository and the
   built image.
8. **Git hygiene.** No AI co-authorship or tool-attribution trailers, and a repo-local maintainer identity.

## Locked decisions

- **Manifest id** `io.github.orcvole.cognee`; registry `ghcr.io/orcvole/cognee-cloudron`, public.
- **Keyless by default** ([ADR-0001](docs/decisions/0001-keyless-by-default.md)): no language model is required.
- **Models out of backups** ([ADR-0002](docs/decisions/0002-models-in-a-persistent-directory.md)).
- **`memoryLimit` 8 GiB**, measured ([ADR-0003](docs/decisions/0003-memory-limit.md)).
- **Sign-in is email and password**, with no single sign-on, because upstream has none to wire to
  ([ADR-0004](docs/decisions/0004-auth-topology.md)). `proxyAuth` would lock out the API keys agents use.
- **Health check** `/health`, answered by the API through nginx without a session.
- **First login** uses the administrator address the install starts with. The post-install checklist asks the
  operator to set a real one with `set-admin-email.sh`.

## Pinned upstream

- `cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b`
- Cognee 1.6.2, commit `ba3631f2ed363a6ea50d649c34c56885af6b36fe`, Apache-2.0.
- The Ladybug extension repository image, `uv` and the Node build image, each by digest in the `Dockerfile`.

## Build shape

Six stages: upstream's extension bundle; the source at the pinned commit; the interface build; the Python
environment (`uv sync` at build time, including the keyless extraction runtime, because installing it at runtime
fails on a read-only filesystem); then the base with the three processes. Upstream's `tests` directory is removed
from the image, because it holds credential-shaped fixtures that trip the secret scan.

## Secrets

Generated on first start into `/app/data/.secrets/env`, mode 0600, re-asserted on every boot.

| Secret | Criticality | Notes |
|---|---|---|
| the three signing secrets | seed-once | losing them only signs everyone out |
| administrator password | seed-once | shown to the operator through the post-install note |
| connector-credential seed | data-loss-critical for stored connector credentials | must be byte-identical across update and restore |

Never record a value in any file. The invariant is the file's hash, proven identical across an update, a restore
and a clone ([docs/DEBUGGING.md](docs/DEBUGGING.md)).

## Backup and restore

`localstorage` and `postgresql` are backed up by the platform. The model folder is not, by design; a restored or
cloned app fetches its models again on first use and needs outbound internet for that.

## Future compatibility

The bump point is the pinned commit in the `src` stage plus `upstreamVersion` and `<upstream>` in the manifest and description. A new upstream major is a fresh round,
not an update. Nothing auto-migrates by this package's hand; upstream migrates its own schema at start.
