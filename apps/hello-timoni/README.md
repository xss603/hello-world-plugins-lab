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
| `imagePullSecrets:`          | `[...timoniv1.ObjectReference]`         | `[]`                                                                                      | [Kubernetes image pull secrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod)                 |
| `tolerations:`               | `[ ...corev1.#Toleration]`              | `[]`                                                                                      | [Kubernetes toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration)                                        |
| `affinity:`                  | `corev1.#Affinity`                      | `{}`                                                                                      | [Kubernetes affinity and anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) |
| `topologySpreadConstraints:` | `[...corev1.#TopologySpreadConstraint]` | `[]`                                                                                      | [Kubernetes pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints)            |
| `service: annotations:`      | `{[ string]: string}`                   | `{}`                                                                                      | Annotations applied to the Kubernetes Service                                                                                                |
