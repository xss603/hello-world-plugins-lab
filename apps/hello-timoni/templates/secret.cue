package templates

import (
	corev1 "k8s.io/api/core/v1"
)

// A plain (mutable) Secret, unlike #ConfigMap which uses the immutable/
// content-hashed pattern — app secrets (API keys, TLS material) are more
// often rotated in place than redeployed with a new name.
#Secret: corev1.#Secret & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "Secret"
	metadata:   #config.metadata
	type:       "Opaque"
	if #config.secret.stringData != _|_ {
		stringData: #config.secret.stringData
	}
}
