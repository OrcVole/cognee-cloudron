FROM ghcr.io/ladybugdb/extension-repo@sha256:180c83fb190e9d6ef8d324850b192db26794ab7cb866a38813a45365f14bd46d AS ladybug-extensions
RUN mkdir -p /bundle && cd /usr/share/nginx/html && \
    for f in v*/linux_*/json/libjson.lbug_extension; do \
        d="/bundle/${f%/json/libjson.lbug_extension}"; \
        mkdir -p "$d" && cp "$f" "$d/libjson.lbug_extension"; \
    done

FROM ghcr.io/astral-sh/uv:0.12.22@sha256:f513a91fc62fe7c17567eee97230dd198e43edb8a9fbecca843714a4358fe1bc AS uvbin

FROM docker.io/cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b AS src
WORKDIR /src
RUN git init && git remote add origin https://github.com/topoteretes/cognee.git && git fetch --depth 1 origin ba3631f2ed363a6ea50d649c34c56885af6b36fe && git checkout FETCH_HEAD

FROM docker.io/library/node:22-bookworm-slim@sha256:43ac6c60b8f89723f746e8a92ce91abd5017e627ce1ddfe4238355d3a30b772c AS ui
COPY --from=src /src/cognee-frontend /ui
WORKDIR /ui
ENV NEXT_PUBLIC_IS_CLOUD_ENVIRONMENT=false NEXT_TELEMETRY_DISABLED=1
RUN npm ci && npm run build

FROM docker.io/cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b AS py
RUN apt-get update && apt-get install -y build-essential gcc clang cmake libpq-dev && rm -rf /var/lib/apt/lists/*
COPY --from=uvbin /uv /uvx /usr/local/bin/.
ENV UV_PYTHON_INSTALL_DIR=/app/code/python UV_PROJECT_ENVIRONMENT=/app/code/.venv UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
WORKDIR /app/code
RUN uv python install 3.12
COPY --from=src /src/README.md /src/pyproject.toml /src/uv.lock /app/code/
RUN uv sync --python 3.12 --extra debug --extra aws --extra api --extra postgres --extra neo4j --extra llama-index --extra dlt --extra ollama --extra mistral --extra groq --extra anthropic --extra tracing --frozen --no-install-project --no-dev --no-editable
COPY --from=src /src/cognee /app/code/cognee
COPY --from=src /src/cognee_db_workers /app/code/cognee_db_workers
COPY --from=src /src/kuzu /app/code/kuzu
COPY --from=ladybug-extensions /bundle/ /app/code/cognee_db_workers/ladybug_extensions/
RUN uv sync --python 3.12 --extra debug --extra aws --extra api --extra postgres --extra neo4j --extra llama-index --extra dlt --extra ollama --extra mistral --extra groq --extra anthropic --extra tracing --frozen --no-dev --no-editable
RUN /app/code/.venv/bin/python -m cognee.tasks.graph.gliner_demo.install
# Upstream's test suite and its fixtures are not needed at runtime (11 MB).
RUN rm -rf /app/code/cognee/tests

FROM docker.io/cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b
COPY --from=py /app/code /app/code
COPY --from=ui /ui/.next/standalone /app/code/ui
COPY --from=ui /ui/.next/static /app/code/ui/.next/static
COPY --from=ui /ui/public /app/code/ui/public
COPY --from=ui /usr/local/bin/node /app/code/node/bin/node
RUN rm -rf /app/code/ui/.next/cache && ln -s /run/ui-cache /app/code/ui/.next/cache
COPY nginx.conf supervisord.conf start.sh run-backend.sh run-ui.sh set-admin-email.sh /app/code/
RUN chmod 755 /app/code/start.sh /app/code/run-backend.sh /app/code/run-ui.sh /app/code/set-admin-email.sh
ENV PYTHONPATH=/app/code UV_PYTHON_DOWNLOADS=never
CMD ["/app/code/start.sh"]
