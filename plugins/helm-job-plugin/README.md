# helm-job-plugin

Demonstrates the "Helm-as-Job" CMP pattern: rather than using ArgoCD's native
Helm source type, the plugin's `generate` command shells out to `helm template`
directly inside the CMP sidecar. This buys you an escape hatch for anything the
built-in Helm integration doesn't support — `helm dependency build`, injecting
values from an external secret store, running `helm template --validate`
against a schema, etc. — while still emitting plain manifests for ArgoCD to
diff and apply.

Not currently wired to any app in `apps/` (the `hello-helm` app uses ArgoCD's
native Helm source instead, see
[argocd/applications/hello-helm.yaml](../../argocd/applications/hello-helm.yaml)).
This plugin is here as a reference manifest for testing the pattern against
any Helm chart in this repo, and to sidecar-register alongside
[custom-render-plugin](../custom-render-plugin) on the same `argocd-repo-server`.

## Wiring it into argocd-repo-server

Same sidecar mechanism as `custom-render-plugin` — mount this directory plus
`plugin.yaml` into a sidecar container on the `argocd-repo-server` Deployment,
with `helm` available on the sidecar's `$PATH`. See
https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/
