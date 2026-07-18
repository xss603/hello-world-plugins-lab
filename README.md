# hello-world-plugins-lab

A sandbox repo for testing ArgoCD [Config Management Plugins (CMP)](https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/)
against the same trivial "hello world" app, rendered several ways: plain
Helm, Kustomize, a bash-script CMP plugin, and a CUE-based
[Timoni](https://timoni.sh) module CMP plugin — the last one shown twice,
once as a full module checked into the app's own path
([hello-timoni](apps/hello-timoni)) and once as just a `values.yaml`
rendered against a module baked into the plugin's sidecar image
([hello-timoni-values](apps/hello-timoni-values)).

Every variant deploys a single non-root nginx (or plugin-rendered) container
that serves `Hello World from <app-name>` on port 8080, with resource limits
and liveness/readiness probes. The Timoni module additionally supports
Ingress+TLS, a generic Secret, a PersistentVolumeClaim, a
`kubernetes.io/dockerconfigjson` image pull Secret, arbitrary extra objects,
and HashiCorp Vault Agent Injector annotations — all opt-in, all documented
in [apps/hello-timoni/README.md](apps/hello-timoni/README.md)'s config table.

## Prerequisites

Everything here was built and verified against a local
[kind](https://kind.sigs.k8s.io/) cluster. You'll want:

- `docker` — kind and the CMP sidecar image builds both need it
- `kind` and `kubectl`
- `argocd` CLI (`brew install argocd` or see the
  [install docs](https://argo-cd.readthedocs.io/en/stable/cli_installation/))
- `helm` and `timoni` (`brew install timoni-sh/tap/timoni`) — only needed if
  you want to render/apply the Helm or Timoni apps directly, outside ArgoCD
- `gh` CLI, authenticated — only needed for the GHCR image push workflow

## Structure

```
hello-world-plugins-lab/
├── apps/                    # the actual application manifests/sources
│   ├── hello-helm/          # plain Helm chart
│   ├── hello-kustomize/     # base + overlays/{dev,prod}
│   ├── hello-plugin/        # config consumed by plugins/custom-render-plugin
│   ├── hello-timoni/        # full Timoni (CUE) module consumed by plugins/timoni-plugin
│   └── hello-timoni-values/ # just a values.yaml, rendered against the module baked into the same plugin's image
├── plugins/                 # CMP sidecar definitions for argocd-repo-server
│   ├── helm-job-plugin/     # "Helm-as-Job": generate via `helm template` in a sidecar
│   ├── custom-render-plugin/# bash script that echoes raw manifests
│   └── timoni-plugin/       # generate via `timoni build` in a sidecar
├── argocd/
│   ├── appproject.yaml       # AppProject scoping this repo + namespace
│   ├── applications/         # one Application per app above
│   └── helm/values.yaml      # alternative install: argo-helm/argo-cd chart w/ CMP sidecars wired in declaratively
├── scripts/
│   ├── apply-argocd-manifests.sh    # apply the AppProject + Applications, with --wait
│   └── install-argocd-helm.sh       # install ArgoCD via Helm instead of the raw install manifest
├── docs/                     # tutorials and deeper-dive docs
└── ci/validate.yaml          # helm lint + kubeconform on every PR (mirrored to .github/workflows/)
```

## Apps

| App | Path | Rendering method | Local sync command |
|---|---|---|---|
| hello-helm | [apps/hello-helm](apps/hello-helm) | Helm | `argocd app sync hello-helm` |
| hello-kustomize (dev) | [apps/hello-kustomize/overlays/dev](apps/hello-kustomize/overlays/dev) | Kustomize | `argocd app sync hello-kustomize-dev` |
| hello-kustomize (prod) | [apps/hello-kustomize/overlays/prod](apps/hello-kustomize/overlays/prod) | Kustomize | `argocd app sync hello-kustomize-prod` |
| hello-plugin | [apps/hello-plugin](apps/hello-plugin) | Custom CMP (`custom-render-plugin`) | `argocd app sync hello-plugin` |
| hello-timoni | [apps/hello-timoni](apps/hello-timoni) | Timoni CMP (`timoni-plugin`), full module | `argocd app sync hello-timoni` |
| hello-timoni-values | [apps/hello-timoni-values](apps/hello-timoni-values) | Timoni CMP (`timoni-plugin`), values.yaml only | `argocd app sync hello-timoni-values` |

## Running locally against kind/minikube

1. Create a local cluster and install ArgoCD — two ways to do this:

   **a) Raw install manifest** (`--server-side` avoids a known `kubectl apply`
   failure on the `applicationsets.argoproj.io` CRD, whose
   `last-applied-configuration` annotation exceeds the 256KiB client-side limit):
   ```bash
   kind create cluster --name plugins-lab
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
   Then patch in the CMP sidecars manually — see step 2 below.

   **b) `argo-helm/argo-cd` chart**, with both CMP sidecars wired in
   declaratively via [argocd/helm/values.yaml](argocd/helm/values.yaml) —
   no manual `kubectl patch`/`create configmap` needed, and no step 2:
   ```bash
   kind create cluster --name plugins-lab
   ./scripts/install-argocd-helm.sh kind-plugins-lab
   ```
   Verified on a throwaway kind cluster: both sidecars come up `Running` on
   the first install, and `hello-timoni` syncs `Synced`/`Healthy` with zero
   extra steps. Produces identically-named resources to (a)
   (`argocd-repo-server`, etc. — the chart's `nameOverride` defaults to
   `argocd`), so every command elsewhere in this README works unmodified
   either way.

2. **Only if you installed via (a)** — patch the `argocd-repo-server`
   Deployment with the plugin sidecars described in
   [plugins/custom-render-plugin/README.md](plugins/custom-render-plugin/README.md),
   [plugins/helm-job-plugin/README.md](plugins/helm-job-plugin/README.md), and
   [plugins/timoni-plugin/README.md](plugins/timoni-plugin/README.md).
3. `argocd/appproject.yaml` and every file under
   [argocd/applications/](argocd/applications) already point `repoURL` at
   this repo's own GitHub origin — if you forked it, update `repoURL` in both
   places to your fork first (a plain find/replace on the URL is enough).
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
   argocd app sync hello-timoni-values
   ```
6. Verify:
   ```bash
   kubectl -n hello-world-plugins-lab port-forward svc/hello-helm 8080:8080
   curl localhost:8080
   ```

## Docs

- [docs/creating-timoni-modules.md](docs/creating-timoni-modules.md) — tutorial on building
  a Timoni (CUE) module from scratch, using [apps/hello-timoni](apps/hello-timoni) as the
  worked example.

## CI

Two workflows, both under [ci/](ci) and [.github/workflows/](.github/workflows)
(the former is the edited source; GitHub Actions only discovers workflows
under the latter, so it's kept as an exact mirror — see the comment at the
top of [ci/validate.yaml](ci/validate.yaml)):

- **[validate.yaml](ci/validate.yaml)**, on every push/PR to `main`:
  `helm lint` + `helm template` + `kubeconform` for hello-helm;
  `kubectl kustomize` + `kubeconform` for both Kustomize overlays;
  `timoni mod vet`/`build` + `kubeconform` for hello-timoni three times over
  (defaults only, `values.yaml`, and `values-full-example.yaml` — every
  field the schema accepts, set) plus once more for hello-timoni-values
  against the shared module; `shellcheck` across `plugins/` and `scripts/`.
  `kubeconform`/`timoni` versions are pinned (not "latest") for
  reproducibility — see the `env:` block at the top of the file.
- **[build-timoni-sidecar.yml](.github/workflows/build-timoni-sidecar.yml)**,
  on changes to the Timoni module or its Dockerfile: builds and pushes the
  `timoni-plugin` CMP sidecar image (linux/amd64 + linux/arm64) to
  `ghcr.io/<owner>/timoni-cmp-sidecar`, using the repo's built-in
  `GITHUB_TOKEN` (a personal `gh auth` token typically lacks the
  `write:packages` scope this needs).
