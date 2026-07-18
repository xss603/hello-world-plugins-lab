# custom-render-plugin

A minimal ArgoCD Config Management Plugin (CMP v2, sidecar pattern) that renders
plain Kubernetes manifests from a bash script instead of Helm/Kustomize.

`generate.sh` reads `config.env` from the Application's source path (if present)
for `MESSAGE` / `REPLICAS` overrides, then echoes a Deployment + Service to stdout.

## Wiring it into argocd-repo-server

CMP v2 plugins run as a sidecar container on `argocd-repo-server`. Register this
plugin by:

1. Mounting this `plugins/custom-render-plugin/` directory (and `plugin.yaml`)
   into the sidecar at `/home/argocd/cmp-server/plugins/custom-render-plugin`.
2. Adding a sidecar container to the `argocd-repo-server` Deployment, e.g.:

```yaml
- name: custom-render-plugin
  image: argoproj/argocd:latest
  command: ["/var/run/argocd/argocd-cmp-server"]
  volumeMounts:
    - mountPath: /var/run/argocd
      name: var-files
    - mountPath: /home/argocd/cmp-server/plugins
      name: plugins
    - mountPath: /home/argocd/cmp-server/config/plugin.yaml
      subPath: plugin.yaml
      name: custom-render-plugin-config
    - mountPath: /tmp
      name: cmp-tmp
  securityContext:
    runAsNonRoot: true
    runAsUser: 999
```

3. Referencing the plugin by name (`custom-render-plugin`) in the Application's
   `spec.source.plugin.name` field — see
   [../../argocd/applications/hello-plugin.yaml](../../argocd/applications/hello-plugin.yaml).

See the upstream docs: https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/
