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
(see that README for the shared `plugins`/`var-files` volume mechanics), with
one difference: the sidecar image needs the `timoni` binary on `$PATH` (it
isn't in the stock `argocd` image the way `helm` is).

Verified end-to-end on a local kind cluster:

1. Build a small derivative image with the `timoni` binary baked in. `get.timoni.sh`
   may not be reachable from every build environment (it wasn't from this one) —
   download the matching release tarball from GitHub directly instead and `COPY`
   the binary in:
   ```dockerfile
   FROM quay.io/argoproj/argocd:v3.4.5
   USER root
   COPY timoni /usr/local/bin/timoni
   RUN chmod +x /usr/local/bin/timoni
   USER 999
   ```
   (fetch the linux/amd64 or linux/arm64 tarball matching your cluster nodes from
   https://github.com/stefanprodan/timoni/releases, extract the `timoni` binary
   next to this Dockerfile before building). For kind, load the built image with
   `kind load docker-image timoni-cmp-sidecar:local --name <cluster>` — no
   registry push needed.
2. Create the plugin's ConfigMap:
   ```shell
   kubectl -n argocd create configmap timoni-plugin-config \
     --from-file=plugin.yaml=plugins/timoni-plugin/plugin.yaml
   ```
3. Add the sidecar container (same `plugins`/`var-files`/`tmp` volume pattern as
   custom-render-plugin, but only one ConfigMap is needed since there's no
   separate script file — `timoni build` is invoked directly):
   ```yaml
   - name: timoni-plugin
     image: timoni-cmp-sidecar:local
     imagePullPolicy: IfNotPresent
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
         name: timoni-plugin-config
       - mountPath: /tmp
         name: timoni-plugin-tmp
   ```
   (`timoni-plugin-config` as a `configMap` volume, `timoni-plugin-tmp` as `emptyDir: {}`).
4. `plugin.yaml` deliberately omits `spec.version` — see
   [custom-render-plugin/README.md](../custom-render-plugin/README.md) point 3
   for why (unversioned socket name has to match the Application's
   `spec.source.plugin.name` exactly).

See https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/

Referenced by an Application via `spec.source.plugin.name: timoni-plugin` — see
[../../argocd/applications/hello-timoni.yaml](../../argocd/applications/hello-timoni.yaml).
