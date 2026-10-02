# ADR-0001: keyless by default, a language model optional

**Status:** accepted.

**Context.** Cognee extracts entities and relationships with a language model, but upstream also ships a fallback:
a small local extraction model and a small local embedding model, so it runs with no API key. A Cloudron host
usually has no GPU, and the package must work the moment it is installed.

**Decision.** Ship the keyless path as the default. A language model and an embedding endpoint are optional and
are set through the app's environment (`LLM_*`, `EMBEDDING_*`; see the post-install note).

**Consequences.**
- Chunk search works out of the box. Answer-style searches and richer graph extraction need a language model.
- The keyless path holds both models in memory (about 5.3 GB resident after a load), which sets the memory limit.
- With a language model **and** an embedding endpoint configured, neither local model is fetched or loaded: a
  348-document run this way left the model folder empty and the container near 2.4 GB.
- The embedding vector size is fixed when a dataset is first indexed. Choose the embedding model before adding data.
