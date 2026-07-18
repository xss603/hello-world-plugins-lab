package templates

import (
	corev1 "k8s.io/api/core/v1"
)

#ServiceAccount: corev1.#ServiceAccount & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata:   #config.metadata
	// Attaching pull secrets to the ServiceAccount (in addition to the
	// Deployment's pod spec — see templates/deployment.cue) means any other
	// pod that ends up using this ServiceAccount inherits them automatically,
	// without needing to repeat imagePullSecrets on every pod spec.
	if #config.imagePullSecrets != _|_ {
		imagePullSecrets: #config.imagePullSecrets
	}
}
