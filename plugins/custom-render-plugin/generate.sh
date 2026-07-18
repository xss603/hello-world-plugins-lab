#!/usr/bin/env bash
# CMP generate script: reads config.env from the Application's source path
# (mounted read-only by argocd-repo-server) and echoes rendered manifests to stdout.
set -euo pipefail

APP_NAME="${ARGOCD_APP_NAME:-hello-plugin}"
NAMESPACE="${ARGOCD_APP_NAMESPACE:-default}"

if [ -f config.env ]; then
  # shellcheck disable=SC1091
  source config.env
fi

MESSAGE="${MESSAGE:-Hello World from ${APP_NAME}}"
REPLICAS="${REPLICAS:-1}"

cat <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
spec:
  replicas: ${REPLICAS}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${APP_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${APP_NAME}
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${APP_NAME}
          image: nginxinc/nginx-unprivileged:1.27-alpine
          command: ["/bin/sh", "-c"]
          args:
            - "echo '${MESSAGE}' > /usr/share/nginx/html/index.html && exec nginx -g 'daemon off;'"
          ports:
            - name: http
              containerPort: 8080
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 3
            periodSeconds: 5
          resources:
            limits:
              cpu: 100m
              memory: 64Mi
            requests:
              cpu: 50m
              memory: 32Mi
---
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: ${APP_NAME}
  ports:
    - name: http
      port: 8080
      targetPort: http
EOF
