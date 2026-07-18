#!/usr/bin/env bash
# Applies this repo's ArgoCD AppProject + Application manifests (argocd/) to
# whatever cluster the given kube-context points at. Idempotent — safe to
# re-run after editing any Application or the AppProject.
#
# Usage:
#   ./scripts/apply-argocd-manifests.sh [kube-context] [--wait]
#
# Examples:
#   ./scripts/apply-argocd-manifests.sh kind-plugins-lab
#   ./scripts/apply-argocd-manifests.sh kind-plugins-lab --wait
#
# Note: this only applies the AppProject/Applications. It does not install
# ArgoCD itself, and it does not wire up the CMP plugin sidecars needed for
# hello-plugin/hello-timoni to sync — see plugins/*/README.md for that.
# Note: no `-u` (nounset) — macOS ships bash 3.2, where expanding an empty
# array under nounset (e.g. "${KUBECTL_ARGS[@]}" with no --context given)
# throws "unbound variable" and aborts the script.
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARGOCD_DIR="$REPO_ROOT/argocd"

WAIT=false
KUBE_CONTEXT=""
for arg in "$@"; do
  case "$arg" in
    --wait) WAIT=true ;;
    *) KUBE_CONTEXT="$arg" ;;
  esac
done

KUBECTL_ARGS=()
if [ -n "$KUBE_CONTEXT" ]; then
  KUBECTL_ARGS+=(--context "$KUBE_CONTEXT")
fi

k() { kubectl "${KUBECTL_ARGS[@]}" "$@"; }

echo "==> kubectl context: ${KUBE_CONTEXT:-$(kubectl config current-context)}"

echo "==> Checking ArgoCD CRDs are installed..."
if ! k get crd applications.argoproj.io >/dev/null 2>&1; then
  echo "error: ArgoCD CRDs not found (applications.argoproj.io missing)." >&2
  echo "       Install ArgoCD first, e.g.:" >&2
  echo "       kubectl create namespace argocd" >&2
  echo "       kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" >&2
  exit 1
fi

echo "==> Applying AppProject..."
k apply -f "$ARGOCD_DIR/appproject.yaml"

echo "==> Applying Applications..."
k apply -f "$ARGOCD_DIR/applications/"

status_table() {
  k -n argocd get applications.argoproj.io \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
}

if [ "$WAIT" = true ]; then
  echo "==> Waiting up to 5m for all Applications to be Synced + Healthy..."
  deadline=$((SECONDS + 300))
  while [ $SECONDS -lt $deadline ]; do
    total=$(k -n argocd get applications.argoproj.io --no-headers | wc -l | tr -d ' ')
    ready=$(k -n argocd get applications.argoproj.io -o jsonpath='{range .items[*]}{.status.sync.status}{" "}{.status.health.status}{"\n"}{end}' \
      | grep -c '^Synced Healthy$' || true)
    echo "    $ready/$total Synced+Healthy"
    if [ "$ready" = "$total" ] && [ "$total" != "0" ]; then
      break
    fi
    sleep 5
  done
fi

echo "==> Current status:"
status_table
