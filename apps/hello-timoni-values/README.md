# hello-timoni-values

Same rendered output family as [hello-timoni](../hello-timoni), but this
directory contains nothing except [values.yaml](values.yaml) — no CUE, no
`cue.mod`. It's rendered against the `hello-timoni` module baked into the
`timoni-plugin` CMP sidecar's image, demonstrating that adding a new instance
of an existing module needs no CUE authoring, just a values file.

See [plugins/timoni-plugin/README.md](../../plugins/timoni-plugin/README.md)
for how `generate.sh` picks this mode over the full-module one, and
[docs/creating-timoni-modules.md](../../docs/creating-timoni-modules.md) for
how the module itself is built.
