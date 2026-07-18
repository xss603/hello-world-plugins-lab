# Creating Timoni modules

A tutorial on building [Timoni](https://timoni.sh) modules from scratch, using
[apps/hello-timoni](../apps/hello-timoni) in this repo as the worked example.
Timoni is a CUE-based alternative to Helm: instead of Go templates stitching
together YAML strings, you write a typed schema in [CUE](https://cuelang.org),
and the Kubernetes objects come out the other end statically validated —
resource requests can't be negative, images can't be missing, security
contexts can't accidentally allow privilege escalation, all as compile errors
rather than runtime surprises.

## Prerequisites

```shell
brew install timoni-sh/tap/timoni  # or see https://timoni.sh/install/
timoni version
```

`timoni` bundles its own CUE evaluator, so you don't strictly need the
standalone `cue` CLI — but installing it too is handy for quick syntax checks
(`brew install cue-lang/tap/cue`).

## 1. Scaffold a module

```shell
timoni mod init hello-timoni
cd hello-timoni
```

This generates:

```
hello-timoni/
├── cue.mod/
│   ├── module.cue          # module identity + CUE language version
│   ├── gen/                # vendored k8s.io CUE type definitions
│   └── pkg/timoni.sh/...   # timoni's own helper types (#Image, #Metadata, ...)
├── templates/
│   ├── config.cue          # the #Config schema — this is the module's real API
│   ├── deployment.cue
│   ├── service.cue
│   ├── configmap.cue
│   └── serviceaccount.cue
├── timoni.cue               # wires #Config + #Instance together
├── values.cue                # the module's default configuration
├── debug_values.cue          # alternate values for local debugging (@if(debug))
├── debug_tool.cue            # `cue cmd` helpers (build/ls) for local iteration
└── timoni.ignore              # like .helmignore — files excluded from `timoni mod push`
```

`cue.mod/gen` is large (~1MB, ~90 files) because it's the full vendored
`k8s.io/api` CUE schema, regenerated via `timoni mod vendor k8s`. Commit it —
it's what lets CUE type-check your Deployment/Service specs against the real
Kubernetes API, and there's no separate fetch step at build time the way Helm
resolves chart dependencies.

## 2. The schema is the module (`templates/config.cue`)

This is the part worth understanding deeply — everything else is plumbing.
`#Config` is a CUE definition (the `#` prefix matters — see [§6](#6-definitions-vs-plain-structs)):

```cue
#Config: {
	// Required: no default, caller MUST supply a value or the build fails.
	image!: timoniv1.#Image

	// Defaulted: caller MAY override, but the module works with zero values files.
	replicas: *1 | int & >0

	// Defaulted + nested + type-constrained.
	resources: timoniv1.#ResourceRequirements & {
		requests: {
			cpu:    *"10m" | timoniv1.#CPUQuantity   // #CPUQuantity is a regex-constrained string
			memory: *"32Mi" | timoniv1.#MemoryQuantity
		}
	}
}
```

The `*default | Type` syntax is CUE's disjunction with a preferred branch: if
the caller doesn't set the field, `*default` wins; if they do, it's checked
against `Type`. This is where Timoni's real advantage over Helm shows up —
`timoniv1.#CPUQuantity` is `string & =~"^[1-9]\\d*m$"`, so `resources.requests.cpu:
"lots"` is a **compile-time type error**, not a kubectl apply failure five
minutes into a rollout.

Required fields (`!`) are how you force callers to make an explicit choice —
use them for things with no safe default (an image, a domain name), not for
things you could reasonably default (a replica count, a port).

## 3. Wiring it together (`timoni.cue`)

```cue
package main

import templates "timoni.sh/hello-timoni/templates"

values: templates.#Config

timoni: {
	apiVersion: "v1alpha1"
	instance: templates.#Instance & {
		config: values
		config: {
			metadata: {
				name:      string @tag(name)      // from `timoni apply <name> ...`
				namespace: string @tag(namespace)  // from `-n <namespace>`
			}
			moduleVersion: string @tag(mv, var=moduleVersion)
			kubeVersion:   string @tag(kv, var=kubeVersion)
		}
	}
	apply: app: [for obj in instance.objects {obj}]
	if instance.config.test.enabled {
		apply: test: [for obj in instance.tests {obj}]
	}
}
```

The `@tag(...)` attributes are how the instance name, namespace, and cluster
version flow in from the CLI/CMP invocation without you writing any Go-template
`{{ .Release.Name }}`-style plumbing — `timoni` populates them automatically
per apply. `instance.objects` in `#Instance` (in `templates/config.cue`, further
down) is a struct of named Kubernetes objects (`sa`, `svc`, `cm`, `deploy`);
`timoni.cue` flattens it into the list `apply.app` that actually gets applied.

## 4. Writing a template (`templates/deployment.cue`)

```cue
package templates

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
)

#Deployment: appsv1.#Deployment & {
	#config:    #Config
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata:   #config.metadata
	spec: appsv1.#DeploymentSpec & {
		replicas: #config.replicas
		selector: matchLabels: #config.selector.labels
		template: {
			metadata: labels: #config.selector.labels
			spec: corev1.#PodSpec & {
				containers: [{
					name:  #config.metadata.name
					image: #config.image.reference   // computed: "repo:tag@digest"
					resources:       #config.resources
					securityContext: #config.securityContext
				}]
			}
		}
	}
}
```

Unifying with `appsv1.#Deployment` (the vendored k8s schema) is what catches
typos like `replicas: "3"` or a `Deployment` missing `spec.selector` — CUE
rejects it before `timoni build` ever prints YAML. `#config.image.reference`
is a derived field from `timoniv1.#Image` (in `cue.mod/pkg/timoni.sh/core/v1alpha1/image.cue`)
that concatenates `repository:tag@digest` conditionally depending on which of
`tag`/`digest` are set — a good example of CUE doing computation, not just
validation.

## 5. Build, vet, apply

```shell
# Render to stdout without touching the cluster (like `helm template`)
timoni build hello-timoni . -n my-namespace

# Static validation: schema constraints + that images actually resolve
timoni mod vet .

# Actually apply
timoni -n my-namespace apply hello-timoni .

# Tear down
timoni -n my-namespace delete hello-timoni
```

`timoni build`/`apply` require `kubeVersion` and `moduleVersion` — normally
supplied automatically (kubeVersion from a live cluster connection,
moduleVersion from the module's git tag or `0.0.0-devel` locally). If you're
building against a cluster that isn't reachable, pass them explicitly:
`--values` won't help here since these come from `@tag`, not `values`.

## 6. Definitions vs. plain structs

A quirk worth internalizing early: `#Config` (with the `#`) is a CUE
*definition* — closed by default, meaning an unknown field is a compile
error, which is exactly what you want for a public API surface (typos get
caught, not silently ignored). A plain struct literal like `{}` or the values
you pass via `--values` is *open* by default — it merges permissively. This
asymmetry is why `values.cue` declaring `values: {}` doesn't accidentally
"close off" the module: `{}` unified with the open defaults inside `#Config`
just contributes nothing, it doesn't forbid anything.

## 7. Overriding values

```shell
timoni build hello-timoni . -n my-namespace --values ./my-values.yaml
```

`--values` accepts CUE, YAML, or JSON — but **the file's top-level key must be
`values:`**, matching `values.cue`'s own structure:

```yaml
# Correct — this actually overrides message.
values:
  message: "Hello from staging"
```

```yaml
# Wrong — no top-level `values:` key. Fails with a generic "undefined value"
# error that gives no hint the wrapper key is what's missing.
message: "Hello from staging"
```

This tripped us up building [hello-timoni](../apps/hello-timoni) — the error
message doesn't mention the missing key at all, so if you hit `undefined
value` on an otherwise-valid override file, check the wrapper first.

## 8. A gotcha with required-file conventions

`timoni` (the CLI, not CUE itself) hard-requires a file literally named
`values.cue` to exist in the module directory — even if your schema's
defaults make it functionally empty. We initially tried deleting it entirely
in favor of a plain `values.yaml`, which failed with `required file not
found: values.cue`. If your module's defaults are fully baked into
`templates/config.cue` (see [hello-timoni's approach](../apps/hello-timoni/README.md)),
`values.cue` can be a one-line placeholder:

```cue
package main

values: {}
```

— it just needs to exist.

## 9. A gotcha with defaulting nested types that have derived fields

If a field's type computes something from its own subfields (like
`timoniv1.#Image.reference`, computed from `repository`/`tag`/`digest`), don't
default it as a whole-struct alternative:

```cue
// Wrong: picking the default branch bypasses #Image's own field logic —
// `reference` never gets computed, and building fails with
// "undefined field: reference".
image: *{repository: "nginx", tag: "latest", digest: ""} | timoniv1.#Image
```

Unify with the type and default each field individually instead, so the
result is still genuinely of type `#Image` with all its derived logic intact:

```cue
image: timoniv1.#Image & {
	repository: *"nginx" | string
	tag:        *"latest" | string
	digest:     *""       | string
}
```

## 10. Security context as a first-class default, not an afterthought

Because `podSecurityContext`/`securityContext` are just more `#Config`
fields, you can bake the [restricted Kubernetes pod security
standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
in as the *default*, not a recommendation buried in a README:

```cue
securityContext: corev1.#SecurityContext & {
	allowPrivilegeEscalation: *false | true
	runAsNonRoot:             *true  | bool
	capabilities: {
		drop: *["ALL"] | [...string]
		add:  *[]      | [...string]
	}
	seccompProfile: *{type: "RuntimeDefault"} | corev1.#SeccompProfile
}
```

Anyone instantiating the module gets a hardened pod by default; loosening it
requires an explicit override, which is the direction you want the path of
least resistance to point.

## 11. Publishing

Modules distribute as OCI artifacts, same registries as container images:

```shell
timoni mod push . oci://ghcr.io/<you>/hello-timoni -v 1.0.0
timoni -n my-namespace apply hello-timoni oci://ghcr.io/<you>/hello-timoni -v 1.0.0
```

For local iteration (this repo's approach), skip publishing entirely and
point `timoni` at the module's path directly — no registry needed until you
actually want to share it or version it independently of the consuming repo.

## Reference

- [apps/hello-timoni](../apps/hello-timoni) — the complete worked module referenced throughout
- [plugins/timoni-plugin](../plugins/timoni-plugin) — wiring a Timoni module into ArgoCD as a Config Management Plugin
- https://timoni.sh/concepts/ and https://timoni.sh/cue/lists-and-structs/ — upstream docs
