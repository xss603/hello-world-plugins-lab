# Sidecar image for the timoni-plugin CMP: the stock argocd image plus the
# timoni binary on $PATH. Self-fetches the matching release from GitHub, so
# it builds multi-arch via `docker buildx build --platform linux/amd64,linux/arm64`
# without any local pre-download step.
FROM quay.io/argoproj/argocd:v3.4.5
ARG TARGETOS=linux
ARG TARGETARCH
ARG TIMONI_VERSION=0.26.0
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -sSL -o /tmp/timoni.tar.gz \
       "https://github.com/stefanprodan/timoni/releases/download/v${TIMONI_VERSION}/timoni_${TIMONI_VERSION}_${TARGETOS}_${TARGETARCH}.tar.gz" \
    && tar -xzf /tmp/timoni.tar.gz -C /usr/local/bin timoni \
    && chmod +x /usr/local/bin/timoni \
    && rm -f /tmp/timoni.tar.gz \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
USER 999
