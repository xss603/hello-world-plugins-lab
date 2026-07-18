@if(!debug)

package main

values: {
	message: "Hello World"

	image: {
		repository: "cgr.dev/chainguard/nginx"
		tag:        "1.25.3"
		digest:     "sha256:3dd8fa303f77d7eb6ce541cb05009a5e8723bd7e3778b95131ab4a2d12fadb8f"
	}

	resources: {
		limits: {
			cpu:    "100m"
			memory: "64Mi"
		}
		requests: {
			cpu:    "50m"
			memory: "32Mi"
		}
	}

	// Comply with the restricted Kubernetes pod security standard.
	podSecurityContext: {
		runAsUser:  65532
		runAsGroup: 65532
		fsGroup:    65532
		seccompProfile: type: "RuntimeDefault"
	}
	securityContext: {
		allowPrivilegeEscalation: false
		readOnlyRootFilesystem:   false
		runAsNonRoot:             true
		capabilities: {
			drop: ["ALL"]
			add: []
		}
		seccompProfile: type: "RuntimeDefault"
	}

	service: port: 8080

	test: image: {
		repository: "cgr.dev/chainguard/curl"
		digest:     ""
		tag:        "latest"
	}
}
