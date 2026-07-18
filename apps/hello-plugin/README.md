# hello-plugin

This "app" has no Helm chart or Kustomize base — it's just `config.env`, a set of
key/value overrides consumed at sync time by the
[custom-render-plugin](../../plugins/custom-render-plugin) CMP, which generates
the actual Deployment/Service manifests on the fly.

See [plugins/custom-render-plugin/README.md](../../plugins/custom-render-plugin/README.md)
for how the plugin is wired into `argocd-repo-server`, and
[argocd/applications/hello-plugin.yaml](../../argocd/applications/hello-plugin.yaml)
for the Application that references it.
