# custom-render-plugin

A minimal ArgoCD Config Management Plugin (CMP v2, sidecar pattern) that renders
plain Kubernetes manifests from a bash script instead of Helm/Kustomize.

`generate.sh` reads `config.env` from the Application's source path (if present)
for `MESSAGE` / `REPLICAS` overrides, then echoes a Deployment + Service to stdout.

## Wiring it into argocd-repo-server

CMP v2 plugins run as a sidecar container on `argocd-repo-server`, sharing two
volumes with the main container: `var-files` (has the `argocd-cmp-server`
binary the init container copies in) and `plugins` (an emptyDir all sidecars
mount at `/home/argocd/cmp-server/plugins` — that's where each CMP server
binds its `<name>.sock`, which is how the main container discovers it; it is
**not** a place to put your own plugin files). `plugin.yaml` and `generate.sh`
go under `/home/argocd/cmp-server/config/` instead, each its own ConfigMap.

Verified against the stock `quay.io/argoproj/argocd:v3.4.5` image (already has
bash) — no custom image needed for this plugin:

1. Create the two ConfigMaps from this directory's files:
   ```shell
   kubectl -n argocd create configmap custom-render-plugin-config \
     --from-file=plugin.yaml=plugins/custom-render-plugin/plugin.yaml
   kubectl -n argocd create configmap custom-render-plugin-files \
     --from-file=generate.sh=plugins/custom-render-plugin/generate.sh
   ```
2. Add a sidecar container to the `argocd-repo-server` Deployment:

```yaml
- name: custom-render-plugin
  image: quay.io/argoproj/argocd:v3.4.5
  command: ["/var/run/argocd/argocd-cmp-server"]
  securityContext:
    runAsNonRoot: true
    runAsUser: 999
    allowPrivilegeEscalation: false
    capabilities: { drop: ["ALL"] }
    seccompProfile: { type: RuntimeDefault }
  volumeMounts:
    - mountPath: /var/run/argocd
      name: var-files
    - mountPath: /home/argocd/cmp-server/plugins
      name: plugins
    - mountPath: /home/argocd/cmp-server/config/plugin.yaml
      subPath: plugin.yaml
      name: custom-render-plugin-config
    - mountPath: /home/argocd/cmp-server/config/generate.sh
      subPath: generate.sh
      name: custom-render-plugin-files
    - mountPath: /tmp
      name: custom-render-plugin-tmp
```

and the matching volumes (`custom-render-plugin-config`/`custom-render-plugin-files`
as `configMap` — set `defaultMode: 0755` on the latter so `bash -c <path>` can
exec it — and `custom-render-plugin-tmp` as `emptyDir: {}`).

3. `plugin.yaml` deliberately omits `spec.version` — if set, the CMP server
   binds `<name>-<version>.sock` instead of `<name>.sock`, which won't match
   an Application's `spec.source.plugin.name` unless you set it to
   `<name>-<version>` too. Simplest to just leave it unset.
4. Reference the plugin by name (`custom-render-plugin`) in the Application's
   `spec.source.plugin.name` field — see
   [../../argocd/applications/hello-plugin.yaml](../../argocd/applications/hello-plugin.yaml).

See the upstream docs: https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/
