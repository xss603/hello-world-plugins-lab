package templates

import (
	corev1 "k8s.io/api/core/v1"
)

#PersistentVolumeClaim: corev1.#PersistentVolumeClaim & {
	#config:    #Config
	apiVersion: "v1"
	kind:       "PersistentVolumeClaim"
	metadata:   #config.metadata
	spec: corev1.#PersistentVolumeClaimSpec & {
		accessModes: #config.persistence.accessModes
		if #config.persistence.storageClassName != _|_ {
			storageClassName: #config.persistence.storageClassName
		}
		resources: requests: storage: #config.persistence.size
	}
}
