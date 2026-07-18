@if(!debug)

package main

// timoni requires this file to exist, but this module's production defaults
// now live directly in templates/config.cue's #Config schema (image,
// resources, security context, message, etc. all have concrete defaults
// there), so `timoni build`/`apply` works with zero values files. Override
// individual fields at apply-time with a values.yaml (see values.yaml in
// this directory for the format) passed via `--values`.
values: {}
