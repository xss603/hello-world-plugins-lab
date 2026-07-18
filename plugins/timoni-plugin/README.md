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

### Image

[Dockerfile](Dockerfile) fetches the matching `timoni` release straight from
GitHub during the build (`ARG TARGETARCH`/`TARGETOS`, populated automatically
by BuildKit), so it builds multi-arch with no local pre-download step:

```shell
docker buildx build --platform linux/amd64,linux/arm64 -t <tag> plugins/timoni-plugin
```

[.github/workflows/build-timoni-sidecar.yml](../../.github/workflows/build-timoni-sidecar.yml)
builds and pushes this to `ghcr.io/<owner>/timoni-cmp-sidecar` (tags `latest`
and the pinned `TIMONI_VERSION`) whenever the Dockerfile changes on `main`, or
on demand via `gh workflow run build-timoni-sidecar.yml`. It needs no extra
secrets — the repo's built-in `GITHUB_TOKEN` already has `packages: write` in
Actions, unlike a personal `gh auth` token, which by default doesn't carry the
GHCR scopes needed to `docker push` from a local machine.

For a **kind-only** test where pushing anywhere is overkill, build locally for
your host's single arch and sideload it directly — no registry involved:
```shell
docker build -t timoni-cmp-sidecar:local plugins/timoni-plugin
kind load docker-image timoni-cmp-sidecar:local --name <cluster>
```

Verified end-to-end on a local kind cluster:

1. Get the image into the cluster — either the local kind-only build above, or
   `image: ghcr.io/<owner>/timoni-cmp-sidecar:latest` once the GHCR workflow
   has run at least once.
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
     image: ghcr.io/<owner>/timoni-cmp-sidecar:latest  # or timoni-cmp-sidecar:local for kind
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
