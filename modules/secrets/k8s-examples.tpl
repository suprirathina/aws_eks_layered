# Kubernetes Secret Examples for External Secrets Operator
# Generated for: ${project_name}-${environment}

---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${region}
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets

---
# ClusterSecretStore for cluster-wide access
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager-cluster
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${region}
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets-system

%{ for secret_name, secret in secrets ~}
---
# External Secret for: ${secret_name}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${secret_name}
  namespace: default
spec:
  refreshInterval: 300s
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: ${secret_name}
    creationPolicy: Owner
    deletionPolicy: Retain
  dataFrom:
  - extract:
      key: ${secret.name}

%{ endfor ~}

---
# Example Pod using the secrets
apiVersion: v1
kind: Pod
metadata:
  name: example-app
  namespace: default
spec:
  serviceAccountName: external-secrets
  containers:
  - name: app
    image: nginx:alpine
    env:
%{ for secret_name, secret in secrets ~}
    - name: ${upper(replace(secret_name, "-", "_"))}_SECRET
      valueFrom:
        secretKeyRef:
          name: ${secret_name}
          key: # specify the key you want to use
%{ endfor ~}
    ports:
    - containerPort: 80

---
# Service Account for External Secrets Operator
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets
  namespace: default
  annotations:
%{ if external_secrets_role_arn != "" ~}
    eks.amazonaws.com/role-arn: ${external_secrets_role_arn}
%{ endif ~}

---
# ClusterRole for External Secrets Operator
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-secrets-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch"]
- apiGroups: ["external-secrets.io"]
  resources: ["secretstores", "clustersecretstores", "externalsecrets"]
  verbs: ["get", "list"]

---
# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-secrets-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-secrets-reader
subjects:
- kind: ServiceAccount
  name: external-secrets
  namespace: default