# timoni-plugin

A CMP wrapping [timoni.sh](http://timoni.sh), a CUE-based alternative to Helm. The
`generate` command shells out to `timoni build`, which renders the module's
Kubernetes objects to stdout without touching the cluster (equivalent to `helm
template`) — ArgoCD then diffs/applies the result like any other source.

Rendered against [apps/hello-timoni](../../apps/hello-timoni):

```shell
timoni build hello-timoni apps/hello-timoni -n hello-world-plugins-lab
```

## Wiring it into argocd-repo-server

Same CMP v2 sidecar mechanism as [custom-render-plugin](../custom-render-plugin)
and [helm-job-plugin](../helm-job-plugin), with one difference: the sidecar image
needs the `timoni` binary on `$PATH` (it isn't in the stock `argocd` image the way
`helm` is). Build a small derivative image, e.g.:

```dockerfile
FROM quay.io/argoproj/argocd:v3.2.1
USER root
RUN curl -sSL https://get.timoni.sh | bash
USER argocd
```

then mount this plugin directory into the sidecar at
`/home/argocd/cmp-server/plugins/timoni-plugin` (with `plugin.yaml` at
`/home/argocd/cmp-server/config/plugin.yaml`) the same way as the other plugins.
See https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/

Referenced by an Application via `spec.source.plugin.name: timoni-plugin` — see
[../../argocd/applications/hello-timoni.yaml](../../argocd/applications/hello-timoni.yaml).
