# Sidecar image for the timoni-plugin CMP: the stock argocd image plus the
# timoni binary on $PATH, plus the hello-timoni module baked in at a fixed
# path. That's what lets an app's git source contain nothing but a
# values.yaml (see apps/hello-timoni-values) instead of a full CUE module —
# generate.sh picks whichever mode the app's checked-out path calls for.
#
# Build context must be the REPO ROOT (paths below are relative to it):
#   docker build -f plugins/timoni-plugin/Dockerfile .
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

# Module engine only: schema + templates, not values.cue/values.yaml/README/
# debug files — those are per-app/per-instance concerns, not part of the
# reusable module. A fresh placeholder values.cue is generated since timoni
# hard-requires that filename to exist regardless.
COPY apps/hello-timoni/cue.mod /opt/timoni-modules/hello-timoni/cue.mod
COPY apps/hello-timoni/templates /opt/timoni-modules/hello-timoni/templates
COPY apps/hello-timoni/timoni.cue /opt/timoni-modules/hello-timoni/timoni.cue
RUN printf 'package main\n\nvalues: {}\n' > /opt/timoni-modules/hello-timoni/values.cue \
    # COPY preserves the host filesystem's mode bits, which can be more
    # restrictive than the non-root USER 999 below needs (e.g. 750 dirs
    # unreadable by anyone but their owning group) — make sure everything
    # under /opt/timoni-modules is world-readable regardless of how it
    # looked on the machine that built this image.
    && chmod -R a+rX /opt/timoni-modules

USER 999
