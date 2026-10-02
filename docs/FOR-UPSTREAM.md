# For the Cognee project: notes from packaging it

Offered gratefully, with evidence, from packaging Cognee 1.6.2 for Cloudron (a read-only root filesystem, a managed
PostgreSQL, a TLS-terminating proxy in front). None of this blocks us; each item would make Cognee easier to run
on a locked-down platform.

1. **The extraction model name is a constant.** The keyless path downloads one fixed model; there is no environment
   variable to choose another. An override would let operators pick a different size.
2. **Runtime installation of the extraction runtime.** If the runtime is missing, Cognee runs pip into the running
   environment at the first keyless `cognify`. On a read-only code directory that fails. We install it at build
   time; a documented "preinstall" step or a clearer error would help others.
3. **Model caches default to temporary locations.** The embedding cache defaults to a temp directory, so the model
   is downloaded again after every restart unless `FASTEMBED_CACHE_PATH` is set. A line in the deployment docs would
   save people a surprise.
4. **`ACCEPT_LOCAL_FILE_PATH`.** The comment in `.env.template` suggests `False` for production, but with it `False`
   every file upload is rejected with 415 ("Local files are not accepted") until `COGNEE_ALLOWED_LOCAL_FILE_ROOTS`
   is set as well. Clarifying the pair would help.
5. **Registration has no switch.** The register route is always mounted. An environment variable to disable it would
   let platforms close it without a proxy rule.
6. **The auth cookie is never marked `Secure`** (`cookie_secure=False` is fixed in the transport), which matters
   behind a TLS-terminating proxy. An option would be welcome.
7. **`LLM_ARGS` and unsupported parameters.** Passing `{"reasoning_effort":"low"}` to an OpenAI-compatible server
   raised `UnsupportedParamsError` until `"allowed_openai_params":["reasoning_effort"]` was added. The failure
   then surfaces as an unreachable endpoint after retries with growing back-off. Documenting the working form
   would save time.
8. **Bulk ingestion against a single-slot local model.** With a one-slot server, a request throttle near the
   server's own rate stops a queue of timeouts from turning into a retry storm. We use `LLM_RATE_LIMIT_*`; a
   mention in the local-model docs may help others.
