package templates

import (
	"encoding/base64"
	"encoding/json"

	corev1 "k8s.io/api/core/v1"
	timoniv1 "timoni.sh/core/v1alpha1"
)

// A kubernetes.io/dockerconfigjson Secret for pulling images from a private
// registry, computed from imagePullSecret.{registry,username,password,email}.
// Named "<instance>-pull" (via #MetaComponent) so it never collides with the
// generic #Secret (templates/secret.cue), which uses the instance's own name.
#ImagePullSecret: corev1.#Secret & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "Secret"
	metadata: timoniv1.#MetaComponent & {
		#Meta:      #config.metadata
		#Component: "pull"
	}
	type: "kubernetes.io/dockerconfigjson"

	_auth: base64.Encode(null, "\(#config.imagePullSecret.username):\(#config.imagePullSecret.password)")
	_dockerconfig: {
		auths: {
			(#config.imagePullSecret.registry): {
				username: #config.imagePullSecret.username
				password: #config.imagePullSecret.password
				auth:     _auth
				if #config.imagePullSecret.email != _|_ {
					email: #config.imagePullSecret.email
				}
			}
		}
	}
	stringData: ".dockerconfigjson": json.Marshal(_dockerconfig)
}
