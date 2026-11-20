#!/usr/bin/env bash
# NEW (not in the original course): grant jenkins-agent-role access to the EKS cluster with
# EKS access entries, the current replacement for editing the deprecated aws-auth ConfigMap (see aws-auth-edit).
# Run from an admin machine with cluster-admin rights. Then apply clusterrole-binding.yaml for RBAC.
set -euo pipefail

CLUSTER=cwvj-devsecops-eks
REGION=ap-south-1
ROLE_ARN=arn:aws:iam::<YOUR_ACCOUNT_ID>:role/jenkins-agent-role   # change to your account/role

# 1) authentication: map the IAM role to the Kubernetes username "jenkins-agent-role" (no admin policy attached)
aws eks create-access-entry --cluster-name "$CLUSTER" --region "$REGION" \
  --principal-arn "$ROLE_ARN" --username jenkins-agent-role

# 2) check
aws eks list-access-entries --cluster-name "$CLUSTER" --region "$REGION"

# 3) authorization: least-privilege RBAC bound to that username
kubectl apply -f clusterrole-binding.yaml
kubectl auth can-i create deployments -n cwvj-devsecops --as jenkins-agent-role   # expect: yes
kubectl auth can-i list nodes --as jenkins-agent-role                             # expect: no
