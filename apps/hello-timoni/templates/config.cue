package templates

import (
	corev1 "k8s.io/api/core/v1"
	timoniv1 "timoni.sh/core/v1alpha1"
)

// Config defines the schema and defaults for the Instance values.
#Config: {
	// The kubeVersion is a required field, set at apply-time
	// via timoni.cue by querying the user's Kubernetes API.
	kubeVersion!: string
	// Using the kubeVersion you can enforce a minimum Kubernetes minor version.
	// By default, the minimum Kubernetes version is set to 1.20.
	clusterVersion: timoniv1.#SemVer & {#Version: kubeVersion, #Minimum: "1.20.0"}

	// The moduleVersion is set from the user-supplied module version.
	// This field is used for the `app.kubernetes.io/version` label.
	moduleVersion!: string

	// The Kubernetes metadata common to all resources.
	// The `metadata.name` and `metadata.namespace` fields are
	// set from the user-supplied instance name and namespace.
	metadata: timoniv1.#Metadata & {#Version: moduleVersion}

	// The labels allows adding `metadata.labels` to all resources.
	// The `app.kubernetes.io/name` and `app.kubernetes.io/version` labels
	// are automatically generated and can't be overwritten.
	metadata: labels: timoniv1.#Labels

	// The annotations allows adding `metadata.annotations` to all resources.
	metadata: annotations?: timoniv1.#Annotations

	// The selector allows adding label selectors to Deployments and Services.
	// The `app.kubernetes.io/name` label selector is automatically generated
	// from the instance name and can't be overwritten.
	selector: timoniv1.#Selector & {#Name: metadata.name}

	// The image allows setting the container image repository,
	// tag, digest and pull policy.
	// Defaults to the pinned hello-world nginx image used by this lab;
	// override via values.yaml (--values) if you need a different one.
	image: timoniv1.#Image & {
		repository: *"cgr.dev/chainguard/nginx" | string
		tag:        *"1.25.3" | string
		digest:     *"sha256:3dd8fa303f77d7eb6ce541cb05009a5e8723bd7e3778b95131ab4a2d12fadb8f" | string
	}

	// The resources allows setting the container resource requirements.
	resources: timoniv1.#ResourceRequirements & {
		limits: {
			cpu:    *"100m" | timoniv1.#CPUQuantity
			memory: *"64Mi" | timoniv1.#MemoryQuantity
		}
		requests: {
			cpu:    *"50m" | timoniv1.#CPUQuantity
			memory: *"32Mi" | timoniv1.#MemoryQuantity
		}
	}

	// The number of pods replicas.
	// By default, the number of replicas is 1.
	replicas: *1 | int & >0

	// The securityContext allows setting the container security context.
	// Defaults comply with the restricted Kubernetes pod security standard.
	securityContext: corev1.#SecurityContext & {
		allowPrivilegeEscalation: *false | true
		readOnlyRootFilesystem:   *false | true
		runAsNonRoot:             *true | bool
		privileged:               *false | true
		capabilities: {
			drop: *["ALL"] | [...string]
			add: *[] | [...string]
		}
		seccompProfile: *{type: "RuntimeDefault"} | corev1.#SeccompProfile
	}

	// The service allows setting the Kubernetes Service annotations and port.
	service: {
		annotations?: timoniv1.#Annotations

		port: *8080 | int & >0 & <=65535
	}

	// Pod optional settings.
	podAnnotations?: {[string]: string}
	podSecurityContext: *{
		runAsUser:  65532
		runAsGroup: 65532
		fsGroup:    65532
		seccompProfile: type: "RuntimeDefault"
	} | corev1.#PodSecurityContext
	imagePullSecrets?: [...timoniv1.#ObjectReference]
	tolerations?: [...corev1.#Toleration]
	affinity?: corev1.#Affinity
	topologySpreadConstraints?: [...corev1.#TopologySpreadConstraint]

	// Test Job disabled by default.
	test: {
		enabled: *false | bool
		image: timoniv1.#Image & {
			repository: *"cgr.dev/chainguard/curl" | string
			tag:        *"latest" | string
			digest:     *"" | string
		}
	}

	// Ingress exposes the Service externally. Disabled by default — it's
	// only meaningful with an Ingress controller installed in the cluster.
	ingress: {
		enabled: *false | bool
		className?: string
		host?: string
		annotations?: timoniv1.#Annotations
		tls: {
			// Requires `ingress.host` and either an existing `tls.secretName`
			// (e.g. managed by cert-manager) or `secret.enabled` with cert/key
			// data supplied via `secret.stringData`.
			enabled: *false | bool
			secretName?: string
		}
	}

	// Secret allows adding an application Secret with arbitrary string data —
	// consumed as container env vars via envFrom, or as TLS material for
	// ingress.tls.secretName. Disabled by default: there's no safe default
	// for secret data, and its presence is opt-in on purpose.
	secret: {
		enabled: *false | bool
		stringData?: {[string]: string}
	}

	// Persistence adds a PersistentVolumeClaim mounted into the container.
	// Disabled by default — this module's own content (nginx config, static
	// HTML) is already served from the immutable ConfigMap, not a volume.
	persistence: {
		enabled:           *false | bool
		size:              *"1Gi" | string
		storageClassName?: string
		accessModes:       *["ReadWriteOnce"] | [...string]
		mountPath:         *"/data" | string
	}

	// App settings.
	message: *"Hello World" | string
}

// Instance takes the config values and outputs the Kubernetes objects.
#Instance: {
	config: #Config

	objects: {
		sa: #ServiceAccount & {#config: config}
		svc: #Service & {#config: config}
		cm: #ConfigMap & {#config: config}

		deploy: #Deployment & {
			#config: config
			#cmName: objects.cm.metadata.name
			if config.persistence.enabled {
				#pvcName: objects.pvc.metadata.name
			}
		}

		if config.ingress.enabled {
			ing: #Ingress & {#config: config}
		}
		if config.secret.enabled {
			secret: #Secret & {#config: config}
		}
		if config.persistence.enabled {
			pvc: #PersistentVolumeClaim & {#config: config}
		}
	}

	tests: {
		"test-svc": #TestJob & {#config: config}
	}
}
