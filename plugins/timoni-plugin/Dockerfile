# Sidecar image for the timoni-plugin CMP: the stock argocd image plus the
# timoni binary on $PATH. Build context must contain a `timoni` binary matching
# the cluster nodes' OS/arch (download from
# https://github.com/stefanprodan/timoni/releases and extract it here first).
FROM quay.io/argoproj/argocd:v3.4.5
USER root
COPY timoni /usr/local/bin/timoni
RUN chmod +x /usr/local/bin/timoni
USER 999
