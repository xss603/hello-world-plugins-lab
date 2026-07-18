package templates

import (
	"list"

	corev1 "k8s.io/api/core/v1"
)

#ServiceAccount: corev1.#ServiceAccount & {
	#config:          #Config
	#pullSecretName?: string
	apiVersion:       "v1"
	kind:             "ServiceAccount"
	metadata:         #config.metadata
	// Attaching pull secrets to the ServiceAccount (in addition to the
	// Deployment's pod spec — see templates/deployment.cue) means any other
	// pod that ends up using this ServiceAccount inherits them automatically,
	// without needing to repeat imagePullSecrets on every pod spec.
	if #config.imagePullSecrets != _|_ || #pullSecretName != _|_ {
		imagePullSecrets: list.Concat([
			if #config.imagePullSecrets != _|_ {#config.imagePullSecrets},
			if #pullSecretName != _|_ {[{name: #pullSecretName}]},
		])
	}
}
