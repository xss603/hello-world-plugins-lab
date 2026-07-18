package templates

import (
	"list"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
)

#Deployment: appsv1.#Deployment & {
	#config:          #Config
	#cmName:          string
	#pvcName?:        string
	#pullSecretName?: string
	apiVersion:       "apps/v1"
	kind:             "Deployment"
	metadata:         #config.metadata
	spec: appsv1.#DeploymentSpec & {
		replicas: #config.replicas
		selector: matchLabels: #config.selector.labels
		template: {
			metadata: {
				labels: #config.selector.labels
				if #config.podAnnotations != _|_ {
					annotations: #config.podAnnotations
				}
			}
			spec: corev1.#PodSpec & {
				serviceAccountName: #config.metadata.name
				containers: [
					{
						name:            #config.metadata.name
						image:           #config.image.reference
						imagePullPolicy: #config.image.pullPolicy
						ports: [
							{
								name:          "http"
								containerPort: 8080
								protocol:      "TCP"
							},
						]
						livenessProbe: {
							httpGet: {
								path: "/healthz"
								port: "http"
							}
						}
						readinessProbe: {
							httpGet: {
								path: "/healthz"
								port: "http"
							}
						}
						volumeMounts: [
							{
								mountPath: "/etc/nginx/conf.d"
								name:      "config"
							},
							{
								mountPath: "/usr/share/nginx/html"
								name:      "html"
							},
							if #config.persistence.enabled {
								{
									mountPath: #config.persistence.mountPath
									name:      "data"
								}
							},
						]
						if #config.secret.enabled {
							envFrom: [{
								secretRef: name: #config.metadata.name
							}]
						}
						resources:       #config.resources
						securityContext: #config.securityContext
					},
				]
				volumes: [
					{
						name: "config"
						configMap: {
							name: #cmName
							items: [{
								key:  "nginx.default.conf"
								path: key
							}]
						}
					},
					{
						name: "html"
						configMap: {
							name: #cmName
							items: [{
								key:  "index.html"
								path: key
							}]
						}
					},
					if #config.persistence.enabled {
						{
							name: "data"
							persistentVolumeClaim: claimName: #pvcName
						}
					},
				]
				if #config.podSecurityContext != _|_ {
					securityContext: #config.podSecurityContext
				}
				if #config.topologySpreadConstraints != _|_ {
					topologySpreadConstraints: #config.topologySpreadConstraints
				}
				if #config.affinity != _|_ {
					affinity: #config.affinity
				}
				if #config.tolerations != _|_ {
					tolerations: #config.tolerations
				}
				if #config.imagePullSecrets != _|_ || #pullSecretName != _|_ {
					imagePullSecrets: list.Concat([
						if #config.imagePullSecrets != _|_ {#config.imagePullSecrets},
						if #pullSecretName != _|_ {[{name: #pullSecretName}]},
					])
				}
			}
		}
	}
}
