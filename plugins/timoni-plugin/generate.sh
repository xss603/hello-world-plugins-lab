#!/usr/bin/env bash
# CMP generate script for timoni-plugin. Supports two consumption patterns
# from the same sidecar image:
#
#   1. Full module checked into the app's own source path (has timoni.cue) —
#      build it directly, e.g. apps/hello-timoni.
#   2. Just a values.yaml, nothing else — render against the shared module
#      baked into this image at build time, e.g. apps/hello-timoni-values.
set -euo pipefail

if [ -f timoni.cue ]; then
  exec timoni build "${ARGOCD_APP_NAME}" . -n "${ARGOCD_APP_NAMESPACE}"
fi

ARGS=(timoni build "${ARGOCD_APP_NAME}" /opt/timoni-modules/hello-timoni -n "${ARGOCD_APP_NAMESPACE}")
if [ -f values.yaml ]; then
  ARGS+=(--values ./values.yaml)
fi
exec "${ARGS[@]}"
