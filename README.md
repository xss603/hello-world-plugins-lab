# hello-world-plugins-lab

A sandbox repo for testing ArgoCD [Config Management Plugins (CMP)](https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/)
against the same trivial "hello world" app, rendered four different ways:
plain Helm, Kustomize, a bash-script CMP plugin, and a CUE-based
[Timoni](https://timoni.sh) module CMP plugin.

Every variant deploys a single non-root nginx (or plugin-rendered) container
that serves `Hello World from <app-name>` on port 8080, with resource limits
and liveness/readiness probes.

## Structure

```
hello-world-plugins-lab/
├── apps/                    # the actual application manifests/sources
│   ├── hello-helm/          # plain Helm chart
│   ├── hello-kustomize/     # base + overlays/{dev,prod}
│   ├── hello-plugin/        # config consumed by plugins/custom-render-plugin
│   └── hello-timoni/        # Timoni (CUE) module consumed by plugins/timoni-plugin
├── plugins/                 # CMP sidecar definitions for argocd-repo-server
│   ├── helm-job-plugin/     # "Helm-as-Job": generate via `helm template` in a sidecar
│   ├── custom-render-plugin/# bash script that echoes raw manifests
│   └── timoni-plugin/       # generate via `timoni build` in a sidecar
├── argocd/
│   ├── appproject.yaml       # AppProject scoping this repo + namespace
│   └── applications/         # one Application per app above
└── ci/validate.yaml          # helm lint + kubeconform on every PR (mirrored to .github/workflows/)
```

## Apps

| App | Path | Rendering method | Local sync command |
|---|---|---|---|
| hello-helm | [apps/hello-helm](apps/hello-helm) | Helm | `argocd app sync hello-helm` |
| hello-kustomize (dev) | [apps/hello-kustomize/overlays/dev](apps/hello-kustomize/overlays/dev) | Kustomize | `argocd app sync hello-kustomize-dev` |
| hello-kustomize (prod) | [apps/hello-kustomize/overlays/prod](apps/hello-kustomize/overlays/prod) | Kustomize | `argocd app sync hello-kustomize-prod` |
| hello-plugin | [apps/hello-plugin](apps/hello-plugin) | Custom CMP (`custom-render-plugin`) | `argocd app sync hello-plugin` |
| hello-timoni | [apps/hello-timoni](apps/hello-timoni) | Timoni CMP (`timoni-plugin`) | `argocd app sync hello-timoni` |

## Running locally against kind/minikube

1. Create a local cluster and install ArgoCD (`--server-side` avoids a known
   `kubectl apply` failure on the `applicationsets.argoproj.io` CRD, whose
   `last-applied-configuration` annotation exceeds the 256KiB client-side limit):
   ```bash
   kind create cluster --name plugins-lab
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
2. If testing the CMP apps, patch the `argocd-repo-server` Deployment with the
   plugin sidecars described in
   [plugins/custom-render-plugin/README.md](plugins/custom-render-plugin/README.md),
   [plugins/helm-job-plugin/README.md](plugins/helm-job-plugin/README.md), and
   [plugins/timoni-plugin/README.md](plugins/timoni-plugin/README.md).
3. Push this repo somewhere reachable by your cluster (or use `argocd repo add`
   with a local path / `git-server` port-forward) and update the placeholder
   `repoURL` in [argocd/appproject.yaml](argocd/appproject.yaml) and each file
   under [argocd/applications/](argocd/applications).
4. Apply the project and applications:
   ```bash
   ./scripts/apply-argocd-manifests.sh kind-plugins-lab --wait
   ```
   (or plain `kubectl apply -f argocd/appproject.yaml && kubectl apply -f argocd/applications/`
   if you'd rather not use the script — it's a thin wrapper around the same two commands,
   plus a sync/health status check.)
5. Log in and sync (port-forward the argocd-server if needed):
   ```bash
   argocd login localhost:8080 --insecure
   argocd app sync hello-helm
   argocd app sync hello-kustomize-dev
   argocd app sync hello-kustomize-prod
   argocd app sync hello-plugin
   argocd app sync hello-timoni
   ```
6. Verify:
   ```bash
   kubectl -n hello-world-plugins-lab port-forward svc/hello-helm 8080:8080
   curl localhost:8080
   ```

## CI

[ci/validate.yaml](ci/validate.yaml) (mirrored to `.github/workflows/validate.yaml`
so GitHub Actions picks it up) runs `helm lint`, `helm template` + `kubeconform`,
`kubectl kustomize` + `kubeconform` for both overlays, and `timoni mod vet` +
`timoni build` + `kubeconform` for the Timoni module, on every PR.
