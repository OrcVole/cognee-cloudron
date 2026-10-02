## Sign in

Open the app and go to **Sign in**. **The form is pre-filled with upstream's own defaults
(`default_user@example.com` and a placeholder password). They are not valid here: replace both.**

- The administrator's address is the content of `/app/data/admin-email`. It starts as
  `admin@<this app's domain>`; change it with `/app/code/set-admin-email.sh you@example.com` from a
  Terminal for this app. Do not change it any other way: Cognee finds its administrator by address, and a
  mismatch silently creates a second administrator with no password.
- The password is generated once at first start and kept in `/app/data/.secrets/env` as
  `DEFAULT_USER_PASSWORD` (File Manager or Terminal). It never changes unless you change it in the app.

## First use is slow

The local extraction and embedding models are downloaded the first time they are needed (about 850 MB
together) into `/app/data/models`. The first `cognify` therefore takes longer and needs outbound internet
access. Later runs reuse them.

## Add a language model (optional)

Without one, entities are extracted by the small local model and answer-style searches are unavailable.
To use any OpenAI-compatible endpoint, set these in the app's environment and restart:

```text
LLM_PROVIDER=custom
LLM_MODEL=openai/<model name>
LLM_ENDPOINT=https://llm.example.com/v1
LLM_API_KEY=<key>
EMBEDDING_PROVIDER=openai_compatible
EMBEDDING_ENDPOINT=https://embeddings.example.com/v1
EMBEDDING_MODEL=<model name>
EMBEDDING_DIMENSIONS=<the model's vector size>
EMBEDDING_API_KEY=<key>
```

**Choose the embedding model before adding data.** The vector size is fixed when a dataset is first
indexed; changing the model later means starting that dataset again. If your server rejects a parameter
such as `reasoning_effort`, set `LLM_ARGS={"reasoning_effort":"low","allowed_openai_params":["reasoning_effort"]}`:
without the allow-list the call fails and Cognee reports a connection timeout.

## Calling the API from other programs

Create a key on the **API Keys** page (or `POST /api/v1/auth/api-keys`) and send it as `X-Api-Key`.
Interactive API documentation is at `/docs`.

## Good to know

- Registration is closed (`/api/v1/auth/register` answers 403). Add users as the administrator.
- Everything Cognee stores, including your documents, is under `/app/data` and in the PostgreSQL addon.
  Turn on backup encryption in the platform settings if the backups leave your server.
- The memory limit is provisional. Large datasets and local-model extraction use more memory than a
  small test does; raise it in the app's settings if the app is restarted for lack of memory.
