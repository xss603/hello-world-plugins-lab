package templates

import (
	networkingv1 "k8s.io/api/networking/v1"
)

#Ingress: networkingv1.#Ingress & {
	#config:    #Config
	apiVersion: "networking.k8s.io/v1"
	kind:       "Ingress"
	metadata:   #config.metadata
	if #config.ingress.annotations != _|_ {
		metadata: annotations: #config.ingress.annotations
	}
	spec: networkingv1.#IngressSpec & {
		if #config.ingress.className != _|_ {
			ingressClassName: #config.ingress.className
		}
		rules: [{
			if #config.ingress.host != _|_ {
				host: #config.ingress.host
			}
			http: paths: [{
				path:     "/"
				pathType: "Prefix"
				backend: service: {
					name: #config.metadata.name
					port: number: #config.service.port
				}
			}]
		}]
		if #config.ingress.tls.enabled {
			tls: [{
				if #config.ingress.host != _|_ {
					hosts: [#config.ingress.host]
				}
				if #config.ingress.tls.secretName != _|_ {
					secretName: #config.ingress.tls.secretName
				}
			}]
		}
	}
}
