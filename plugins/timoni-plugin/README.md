# timoni-plugin

A CMP wrapping [timoni.sh](http://timoni.sh), a CUE-based alternative to Helm.
[generate.sh](generate.sh) supports **two** ways an app can be rendered
through the exact same sidecar image:

1. **Full module in the app's own source path** — [apps/hello-timoni](../../apps/hello-timoni)
   ships its own `timoni.cue`/`templates`/`cue.mod`. `generate.sh` detects
   `timoni.cue` and builds the app's own path directly:
   ```shell
   timoni build hello-timoni apps/hello-timoni -n hello-world-plugins-lab
   ```
2. **Just a `values.yaml`, nothing else** — [apps/hello-timoni-values](../../apps/hello-timoni-values)
   contains *only* a `values.yaml`. `generate.sh` falls back to the
   `hello-timoni` module baked into this sidecar's image at
   `/opt/timoni-modules/hello-timoni` (see [Dockerfile](Dockerfile)), passing
   the app's own `values.yaml` as an override:
   ```shell
   timoni build hello-timoni-values /opt/timoni-modules/hello-timoni \
     -n hello-world-plugins-lab --values ./values.yaml
   ```

Mode 2 is the interesting one: it means adding a new app instance of the
same module needs **zero CUE authoring** — just a values file. See
[docs/creating-timoni-modules.md](../../docs/creating-timoni-modules.md) for
how the module itself is built; this plugin is what lets many apps reuse one
without copy-pasting the schema/templates into every app directory.

Either way, `timoni build` only renders to stdout — it never touches the
cluster (equivalent to `helm template`); ArgoCD diffs/applies the result like
any other source.

## Wiring it into argocd-repo-server

Same CMP v2 sidecar mechanism as [custom-render-plugin](../custom-render-plugin)
(see that README for the shared `plugins`/`var-files` volume mechanics), with
two differences: the sidecar image needs the `timoni` binary on `$PATH` (it
isn't in the stock `argocd` image the way `helm` is), and it needs
`generate.sh` mounted the same way `custom-render-plugin` mounts its own
script (via `/home/argocd/cmp-server/config/`, **not** the shared `plugins`
volume — see that plugin's README point about why).

### Image

[Dockerfile](Dockerfile) does two things: fetches the matching `timoni`
release straight from GitHub during the build (`ARG TARGETARCH`/`TARGETOS`,
populated automatically by BuildKit, so it builds multi-arch with no local
pre-download step), and `COPY`s the `hello-timoni` module's schema/templates
in from [apps/hello-timoni](../../apps/hello-timoni) to
`/opt/timoni-modules/hello-timoni` — just the reusable engine, not
`values.cue`/`values.yaml`/`README`/debug files, which are per-app concerns.

**Build context must be the repo root**, not this directory, since the
Dockerfile `COPY`s from outside it:

```shell
docker buildx build --platform linux/amd64,linux/arm64 \
  -f plugins/timoni-plugin/Dockerfile -t <tag> .
```

A gotcha we hit building this: `COPY` preserves the *host* filesystem's mode
bits, which had left `cue.mod/gen`/`cue.mod/pkg` at `750` (unreadable by
anyone but their owning group) from however they were originally created —
fine for the root-owned build step, but the sidecar runs as non-root `USER
999`. The Dockerfile has an explicit `chmod -R a+rX` after the `COPY`s to
stop this from depending on the build machine's umask.

[.github/workflows/build-timoni-sidecar.yml](../../.github/workflows/build-timoni-sidecar.yml)
builds and pushes this to `ghcr.io/<owner>/timoni-cmp-sidecar` (tags `latest`
and the pinned `TIMONI_VERSION`) whenever the Dockerfile or the baked-in
module's source changes on `main`, or on demand via
`gh workflow run build-timoni-sidecar.yml`. It needs no extra secrets — the
repo's built-in `GITHUB_TOKEN` already has `packages: write` in Actions,
unlike a personal `gh auth` token, which by default doesn't carry the GHCR
scopes needed to `docker push` from a local machine.

For a **kind-only** test where pushing anywhere is overkill, build locally for
your host's single arch and sideload it directly — no registry involved:
```shell
docker build -t timoni-cmp-sidecar:local -f plugins/timoni-plugin/Dockerfile .
kind load docker-image timoni-cmp-sidecar:local --name <cluster>
```

Verified end-to-end on a local kind cluster, both modes:

1. Get the image into the cluster — either the local kind-only build above, or
   `image: ghcr.io/<owner>/timoni-cmp-sidecar:latest` once the GHCR workflow
   has run at least once.
2. Create the plugin's ConfigMaps (`plugin.yaml` **and** `generate.sh` this
   time, unlike the single-file version this plugin started as):
   ```shell
   kubectl -n argocd create configmap timoni-plugin-config \
     --from-file=plugin.yaml=plugins/timoni-plugin/plugin.yaml
   kubectl -n argocd create configmap timoni-plugin-files \
     --from-file=generate.sh=plugins/timoni-plugin/generate.sh
   ```
3. Add the sidecar container:
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
       - mountPath: /home/argocd/cmp-server/config/generate.sh
         subPath: generate.sh
         name: timoni-plugin-files
       - mountPath: /tmp
         name: timoni-plugin-tmp
   ```
   (`timoni-plugin-config`/`timoni-plugin-files` as `configMap` volumes —
   give `timoni-plugin-files` `defaultMode: 0755` so `bash` can exec it —
   `timoni-plugin-tmp` as `emptyDir: {}`).
4. `plugin.yaml` deliberately omits `spec.version` — see
   [custom-render-plugin/README.md](../custom-render-plugin/README.md) point 3
   for why (unversioned socket name has to match the Application's
   `spec.source.plugin.name` exactly).
5. `discover.find.command`'s match signal is **non-empty stdout, not exit
   code**. We first wrote it as `test -f timoni.cue -o -f values.yaml`, which
   is silent even on success (`test` never prints anything) — ArgoCD logged
   `"Plugin command returned zero output"` and refused to use the plugin at
   all (`could not find cmp-server plugin ... supporting the given
   repository`), even though `source.plugin.name` was set explicitly.
   Explicit naming does **not** skip the discovery check. Use `find` instead,
   since it prints the matched filename on success:
   ```shell
   find . -maxdepth 1 \( -name timoni.cue -o -name values.yaml \) -print -quit
   ```

See https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/

Referenced by an Application via `spec.source.plugin.name: timoni-plugin` — see
[../../argocd/applications/hello-timoni.yaml](../../argocd/applications/hello-timoni.yaml)
and [../../argocd/applications/hello-timoni-values.yaml](../../argocd/applications/hello-timoni-values.yaml).
