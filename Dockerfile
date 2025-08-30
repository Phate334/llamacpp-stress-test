FROM ghcr.io/ggml-org/llama.cpp:full-cuda-b6322
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

COPY --from=ghcr.io/astral-sh/uv:0.8.14 /uv /uvx /bin/

WORKDIR /app
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

COPY ./pyproject.toml ./uv.lock ./README.md /app/
COPY ./ui /app/ui

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

ENV PATH="/app/.venv/bin:$PATH"

ENTRYPOINT ["fastapi", "run", "ui/main.py"]
CMD ["--host", "0.0.0.0", "--port", "8000"]