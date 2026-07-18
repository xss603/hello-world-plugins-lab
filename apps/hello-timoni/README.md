# hello-timoni

A [timoni.sh](http://timoni.sh) (CUE-based) module for the hello-world app used to
test the `timoni-plugin` ArgoCD CMP — see
[../../plugins/timoni-plugin](../../plugins/timoni-plugin). Adapted from
`timoni mod init`'s built-in hello-world scaffold: hardened to the restricted pod
security standard and pinned to this repo's resource limits.

Unlike the upstream scaffold, this module's production defaults live directly
in [templates/config.cue](templates/config.cue)'s `#Config` schema (image,
resources, security context, message, service port — all concrete defaults,
not required fields). [values.cue](values.cue) is a near-empty placeholder;
timoni requires that exact filename to exist, but doesn't require it to
carry any data. **This means `timoni build`/`apply` needs no values file at
all** — that's deliberate, so the CMP's `generate` command
(`timoni build "$ARGOCD_APP_NAME" .`, see
[../../plugins/timoni-plugin/plugin.yaml](../../plugins/timoni-plugin/plugin.yaml))
doesn't need to know about or pass any values file.

This module is used locally (by path), not pushed to an OCI registry, so install
it by pointing `timoni` at this directory instead of an `oci://` reference:

## Install

To create an instance using the default values:

```shell
timoni -n hello-world-plugins-lab apply hello-timoni ./apps/hello-timoni
```

To override specific fields, create a values file — CUE, YAML, or JSON all
work — and pass it via `--values`. [values.yaml](values.yaml) in this
directory is a worked (optional) example:

```yaml
# Note the top-level `values:` key: --values files are unified into the
# module the same way values.cue is, and values.cue's own top-level field
# is also named `values`. A flat file without that wrapper key fails with
# a generic "undefined value" error that gives no hint the wrapper is
# what's missing — easy to lose time on.
values:
  message: "Hello World"
  replicas: 1
```

```shell
timoni -n hello-world-plugins-lab apply hello-timoni ./apps/hello-timoni \
  --values ./apps/hello-timoni/values.yaml
```

For a lookup of every field the schema accepts, set explicitly, see
[values-full-example.yaml](values-full-example.yaml) — not a recommended
config (this module needs no values file at all by default), just a
reference. `timoni mod vet`/`build` against it are part of CI, so it can't
silently drift out of sync with the schema.

## Uninstall

To uninstall an instance and delete all its Kubernetes resources:

```shell
timoni -n hello-world-plugins-lab delete hello-timoni
```

## Configuration

### General values

All defaults below live in [templates/config.cue](templates/config.cue); this
column is what you get with zero values files, not a suggestion.

| Key                          | Type                                    | Default (baked into config.cue)                                                        | Description                                                                                                                                  |
|------------------------------|-----------------------------------------|------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| `message:`                   | `string`                                | `"Hello World"`                                                                          | Rendered into the served index.html as `<message> from <instance name>!`                                                                    |
| `image: repository:`         | `string`                                | `cgr.dev/chainguard/nginx`                                                               | Container image repository                                                                                                                   |
| `image: tag:`                | `string`                                | `1.25.3`                                                                                 | Container image tag                                                                                                                          |
| `image: digest:`             | `string`                                | `sha256:3dd8fa30…` (pinned)                                                              | Container image digest, takes precedence over `tag` when specified                                                                          |
| `image: pullPolicy:`         | `string`                                | `IfNotPresent`                                                                           | [Kubernetes image pull policy](https://kubernetes.io/docs/concepts/containers/images/#image-pull-policy)                                     |
| `replicas:`                  | `int`                                   | `1`                                                                                      | Number of pod replicas                                                                                                                       |
| `resources:`                 | `timoniv1.#ResourceRequirements`        | `limits: {cpu: 100m, memory: 64Mi}`, `requests: {cpu: 50m, memory: 32Mi}`                | [Kubernetes resource requests and limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers)                     |
| `service: port:`             | `int`                                   | `8080`                                                                                   | Kubernetes Service HTTP port                                                                                                                 |
| `podSecurityContext:`        | `corev1.#PodSecurityContext`            | `runAsUser/runAsGroup/fsGroup: 65532`, `seccompProfile: RuntimeDefault`                  | [Kubernetes pod security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context) — restricted PSS compliant       |
| `securityContext:`           | `corev1.#SecurityContext`               | `allowPrivilegeEscalation: false`, `runAsNonRoot: true`, `capabilities: {drop: [ALL]}`   | [Kubernetes container security context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context) — restricted PSS compliant |
| `test: enabled:`             | `bool`                                  | `false`                                                                                  | Run end-to-end tests at install and upgrades                                                                                                 |
| `test: image:`                | `timoniv1.#Image`                      | `cgr.dev/chainguard/curl:latest`                                                         | Image used by the Job when `test.enabled` is true                                                                                            |
| `metadata: labels:`          | `{[ string]: string}`                   | `{}`                                                                                     | Common labels for all resources                                                                                                              |
| `metadata: annotations:`     | `{[ string]: string}`                   | `{}`                                                                                     | Common annotations for all resources                                                                                                         |
| `podAnnotations:`            | `{[ string]: string}`                   | `{}`                                                                                     | Annotations applied to pods                                                                                                                  |
| `imagePullSecrets:`          | `[...timoniv1.ObjectReference]`         | `[]`                                                                                      | [Kubernetes image pull secrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod) — attached to both the pod spec and the ServiceAccount, so anything else using this ServiceAccount inherits them too |
| `tolerations:`               | `[ ...corev1.#Toleration]`              | `[]`                                                                                      | [Kubernetes toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration)                                        |
| `affinity:`                  | `corev1.#Affinity`                      | `{}`                                                                                      | [Kubernetes affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| `topologySpreadConstraints:` | `[...corev1.#TopologySpreadConstraint]` | `[]`                                                                                      | [Kubernetes pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints)            |
| `service: annotations:`      | `{[ string]: string}`                   | `{}`                                                                                      | Annotations applied to the Kubernetes Service                                                                                                |

### Optional resources

All disabled by default — enabling them adds the resource, no other defaults change.

| Key                             | Type     | Default    | Description                                                                                     |
|----------------------------------|----------|------------|---------------------------------------------------------------------------------------------------|
| `ingress: enabled:`               | `bool`   | `false`    | Create an `Ingress` (requires an Ingress controller to do anything)                              |
| `ingress: className:`             | `string` | unset      | `spec.ingressClassName`                                                                          |
| `ingress: host:`                  | `string` | unset      | Rule host; omit for a catch-all rule                                                              |
| `ingress: annotations:`           | `{[string]: string}` | `{}` | e.g. controller-specific annotations (`nginx.ingress.kubernetes.io/...`)                          |
| `ingress: tls: enabled:`          | `bool`   | `false`    | Add a `spec.tls` entry for `ingress.host`                                                          |
| `ingress: tls: secretName:`       | `string` | unset      | Existing TLS Secret (e.g. managed by cert-manager), or one created via `secret.enabled`            |
| `secret: enabled:`                | `bool`   | `false`    | Create a plain (mutable) `Secret`, unlike the immutable/hashed `ConfigMap`                        |
| `secret: stringData:`             | `{[string]: string}` | unset | Secret key/value pairs; also injected into the container via `envFrom` when `secret.enabled`      |
| `persistence: enabled:`           | `bool`   | `false`    | Create a `PersistentVolumeClaim` and mount it into the container                                  |
| `persistence: size:`              | `string` | `1Gi`      | `spec.resources.requests.storage`                                                                  |
| `persistence: storageClassName:`  | `string` | unset      | `spec.storageClassName` (uses the cluster default when unset)                                     |
| `persistence: accessModes:`       | `[...string]` | `[ReadWriteOnce]` | `spec.accessModes`                                                                       |
| `persistence: mountPath:`         | `string` | `/data`    | Where the PVC is mounted in the container                                                         |
| `imagePullSecret: enabled:`       | `bool`   | `false`    | Create a `kubernetes.io/dockerconfigjson` Secret (named `<instance>-pull`) for a private registry, instead of referencing one created out-of-band via the plain `imagePullSecrets` field |
| `imagePullSecret: registry:`      | `string` | `""`       | Registry hostname, e.g. `registry.example.com`                                                     |
| `imagePullSecret: username:`      | `string` | `""`       | Registry username                                                                                  |
| `imagePullSecret: password:`      | `string` | `""`       | Registry password/token                                                                            |
| `imagePullSecret: email:`         | `string` | unset      | Optional; some registries require it                                                               |

`imagePullSecret` and the plain `imagePullSecrets` field are additive, not
either/or — both get combined onto `imagePullSecrets` on the pod spec and the
ServiceAccount. Since `secret.enabled` and `imagePullSecret.enabled` create
distinctly-named Secrets (`<instance>` vs. `<instance>-pull`), enabling both
at once is safe.

Example enabling all four (verified against a local kind cluster with the
default `standard`/`local-path` StorageClass — PVC bound, Secret injected via
`envFrom`, the dockerconfigjson Secret's content and type confirmed directly
via `kubectl get secret -o jsonpath`, pod stayed `Running`/`Ready`; Ingress
needs an actual controller installed to do anything beyond rendering
correctly):

```yaml
values:
  ingress:
    enabled: true
    className: nginx
    host: hello-timoni.example.com
    tls:
      enabled: true
      secretName: hello-timoni-tls
  secret:
    enabled: true
    stringData:
      API_KEY: "super-secret-value"
  persistence:
    enabled: true
    size: "5Gi"
    storageClassName: standard
  imagePullSecret:
    enabled: true
    registry: registry.example.com
    username: myuser
    password: mypassword
    email: ops@example.com
```
