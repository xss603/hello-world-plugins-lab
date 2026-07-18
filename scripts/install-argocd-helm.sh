#!/usr/bin/env bash
# Installs ArgoCD via the argo-helm/argo-cd chart, with both CMP sidecars
# (custom-render-plugin, timoni-plugin) wired in declaratively through
# argocd/helm/values.yaml — an alternative to this repo's other install path
# (kubectl apply -f .../install.yaml + manual kubectl patch/create configmap,
# see plugins/*/README.md). Produces the same resource names either way
# (argocd-repo-server, etc.), so every other command/doc in this repo works
# unmodified regardless of which install method you used.
#
# Usage:
#   ./scripts/install-argocd-helm.sh [kube-context] [namespace] [release-name]
#
# Examples:
#   ./scripts/install-argocd-helm.sh kind-plugins-lab
#   ./scripts/install-argocd-helm.sh kind-plugins-lab argocd argocd
#
# Note: no `-u` (nounset) — see scripts/apply-argocd-manifests.sh for why
# (macOS's stock bash 3.2 + empty arrays under nounset).
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

KUBE_CONTEXT="${1:-}"
NAMESPACE="${2:-argocd}"
RELEASE="${3:-argocd}"
# Pinned to the chart version whose appVersion (v3.4.5) matches what this
# repo has actually been tested against — bump deliberately, not by accident.
CHART_VERSION="10.1.4"

HELM_ARGS=()
KUBECTL_ARGS=()
if [ -n "$KUBE_CONTEXT" ]; then
  HELM_ARGS+=(--kube-context "$KUBE_CONTEXT")
  KUBECTL_ARGS+=(--context "$KUBE_CONTEXT")
fi

echo "==> Adding/updating the argo-helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo

echo "==> Installing/upgrading '$RELEASE' (chart v$CHART_VERSION) into namespace '$NAMESPACE'..."
helm upgrade --install "$RELEASE" argo/argo-cd \
  "${HELM_ARGS[@]}" \
  --version "$CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  -f "$REPO_ROOT/argocd/helm/values.yaml" \
  --set-file 'extraObjects[0].data.plugin\.yaml'="$REPO_ROOT/plugins/custom-render-plugin/plugin.yaml" \
  --set-file 'extraObjects[1].data.generate\.sh'="$REPO_ROOT/plugins/custom-render-plugin/generate.sh" \
  --set-file 'extraObjects[2].data.plugin\.yaml'="$REPO_ROOT/plugins/timoni-plugin/plugin.yaml" \
  --set-file 'extraObjects[3].data.generate\.sh'="$REPO_ROOT/plugins/timoni-plugin/generate.sh"

echo "==> Waiting for repo-server (with both CMP sidecars) to roll out..."
kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" rollout status "deploy/${RELEASE}-repo-server" --timeout=180s

echo "==> Sidecar status:"
kubectl "${KUBECTL_ARGS[@]}" -n "$NAMESPACE" get pods -l app.kubernetes.io/name=argocd-repo-server
