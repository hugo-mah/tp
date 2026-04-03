# syntax=docker/dockerfile:1

# Multi-stage build: install dependencies in a separate build stage
FROM python:3.14-slim AS builder

WORKDIR /build

# Create a virtualenv for a clean dependency layer
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY ./app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt


# Final runtime image (lightweight: slim)
FROM python:3.14-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH"

# Upgrade base tooling/libs so Trivy doesn't flag old system packages
RUN python -m pip install --no-cache-dir --upgrade pip

# Run as a non-root user (avoid relying on useradd/groupadd presence)
ARG APP_UID=10001
ARG APP_GID=10001
RUN set -eux; \
    mkdir -p /app; \
    chown -R ${APP_UID}:${APP_GID} /app

WORKDIR /app

# Copy the virtualenv from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application code
COPY --chown=${APP_UID}:${APP_GID} ./app/ /app/

USER ${APP_UID}:${APP_GID}

EXPOSE 5000

# Start with gunicorn (do not use `flask run`)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
