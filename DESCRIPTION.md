<upstream>1.6.2</upstream>

# Cognee

Cognee is an open-source memory layer for AI agents. It turns documents, conversations and other data
into a knowledge graph together with a vector index, so an agent can recall facts and how they relate.
Add data through the web interface or the REST API, build the graph with `cognify`, and query it by
chunk search, by graph search, or by asking a question and getting an answer drawn from the graph.

This package runs the API and the web interface behind one address. PostgreSQL comes from the platform;
the graph store (Kuzu) and the vector store (LanceDB) are files in the app's data directory, so they are
covered by the platform's backups.

**A language model is optional.** With none configured, Cognee extracts entities with a small local model
(about 784 MB) and embeds text with another (about 67 MB). Both download the first time they are used,
not at install, and are kept in a persistent directory that is left out of backups. Chunk search works this way. Answer-style searches
and richer graph extraction need a language model: point Cognee at any OpenAI-compatible endpoint with
the `LLM_*` and `EMBEDDING_*` settings described in the post-install notes.

**Sign-in is by email and password only.** There is no single sign-on, no mail is sent, and there is no
password reset by email: an administrator with access to the app resets passwords. Self-registration is
closed, and telemetry is off.

The web interface is upstream's open-source one. Its Overview panels are marked as Cognee Cloud features
and stay empty; the Brain, Search and Mindmap pages are the useful ones.
