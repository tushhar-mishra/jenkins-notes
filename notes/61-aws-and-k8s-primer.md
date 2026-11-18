# 61 · AWS and Kubernetes Primer for Jenkins

> **Level:** ★★ intermediate · **Status:** 🆕 new topic (gathers the AWS/Kubernetes background Project 01 assumes)
>
> **You will learn:** the AWS and Kubernetes pieces the DevSecOps pipeline touches, and exactly how Jenkins uses each: IAM roles and **instance profiles** (no access keys), ECR, EKS and `eksctl`, kubeconfig and `aws eks update-kubeconfig`, how EKS authenticates IAM identities (access entries vs the legacy `aws-auth` ConfigMap), and the Kubernetes objects deployed (Namespace, Deployment, Service, RBAC).
>
> **You need:** topics 07, 24. Kubernetes background from your [Kubernetes notes](../../CKA-Certification-Course-2025/INDEX.md): [25 Deployments](../../CKA-Certification-Course-2025/notes/25-deployments.md), [31 NodePort](../../CKA-Certification-Course-2025/notes/31-services-nodeport-loadbalancer-externalname-headless.md), [26 namespaces](../../CKA-Certification-Course-2025/notes/26-namespaces.md), [57 RBAC](../../CKA-Certification-Course-2025/notes/57-rbac.md), [12 kubeconfig](../../CKA-Certification-Course-2025/notes/12-kubectl-kubeconfig-and-contexts.md), [46 topology spread](../../CKA-Certification-Course-2025/notes/46-pod-affinity-and-topology-spread.md).
>
> **From your original notes:** Project 01 › *Prerequisite: Grant Jenkins Agent Access to Amazon ECR* ("best practice is an IAM role, not long-lived access keys"), *Why edit aws-auth and how*, *Understanding the existing aws-auth entry*, *Why we do NOT add Jenkins to system:masters*, *Why we use only system:authenticated*.

---

## What it is

| Piece | Plain meaning | Jenkins uses it to… |
|---|---|---|
| **IAM role** | An AWS identity with permissions that something can *assume* temporarily | Let the agent call ECR/EKS APIs without stored keys |
| **Instance profile** | The wrapper that attaches a role to an EC2 instance | Give the agent VM that role automatically |
| **ECR** | Amazon Elastic Container Registry: private image registry | Push images (`docker push`) |
| **EKS** | Amazon Elastic Kubernetes Service: AWS-managed control plane + your worker nodes | Deploy the app |
| **eksctl** | CLI that creates EKS clusters from a YAML file | (admin, once) create the cluster |
| **kubeconfig** | File telling `kubectl` which cluster, how to authenticate, which namespace | Point the agent's `kubectl` at EKS |
| **Access entries / aws-auth** | How EKS maps an IAM identity to a Kubernetes user/group | Let the Jenkins role log in to the cluster |
| **RBAC** | Kubernetes permissions (Role/ClusterRole + bindings) | Allow only what the pipeline needs |

---

## Why it exists

Two separate questions guard every cluster: **"who are you?"** (authentication: IAM → EKS access entry) and **"what may you do?"** (authorization: Kubernetes RBAC). Getting them right is what makes a pipeline **least-privilege** instead of cluster-admin.

---

## Analogy

A **corporate office**: the IAM role is your company badge; ECR is the company warehouse; EKS is the factory floor. The access entry is the receptionist's list mapping badges to visitor names; RBAC is the list of rooms each visitor may enter. Being on the reception list (authenticated) doesn't open any doors by itself.

---

## How it works inside

### IAM roles on EC2 (no access keys)

Since the agent runs on **EC2**, the best practice is an **IAM role** rather than long-lived access keys:
1. Create a role trusted by `ec2.amazonaws.com`, attach policies (e.g. `AmazonEC2ContainerRegistryPowerUser`).
2. Attach it to the instance (via an instance profile).
3. On the instance, the AWS CLI automatically fetches **temporary credentials** from the **instance metadata service** (IMDS, `http://169.254.169.254`), rotated by AWS every few hours. Nothing is stored in Jenkins.
```bash
aws sts get-caller-identity
```
```json
{ "Account": "386275436648", "Arn": "arn:aws:sts::386275436648:assumed-role/jenkins-agent-role/i-0abc123…" }
```
`assumed-role/jenkins-agent-role/i-…` proves the CLI is using the instance role. (Use **IMDSv2**, which requires a session token and blocks some SSRF attacks; it's the default on new instances.)

### ECR authentication

`aws ecr get-login-password` exchanges the role's credentials for a **12-hour registry password**; `docker login --username AWS --password-stdin <registry>` stores it for Docker. Registry hostname format: `<account>.dkr.ecr.<region>.amazonaws.com`.

### EKS authentication: how `kubectl` proves who it is

1. `aws eks update-kubeconfig --name <cluster> --region <r>` writes a kubeconfig entry whose user section runs `aws eks get-token` (needs `eks:DescribeCluster` to fetch the endpoint and CA).
2. Every `kubectl` call gets a short-lived token signed with the role's credentials and sends it to the EKS API server.
3. EKS verifies the IAM identity and **maps it to a Kubernetes username and groups** using:
   - **Access entries** (current way: the EKS **Cluster Access Management API**, cluster auth mode `API` or `API_AND_CONFIG_MAP`), or
   - the **`aws-auth` ConfigMap** in `kube-system` (legacy way, auth mode `CONFIG_MAP`/`API_AND_CONFIG_MAP`).
4. Kubernetes **RBAC** then decides what that username/group may do.

> ⚠️ **Corrected (status):** Project 01 grants access by editing the **`aws-auth` ConfigMap**. That ConfigMap is now **deprecated** by AWS in favour of **EKS access entries** (`aws eks create-access-entry` / `associate-access-policy`, or `accessConfig` in eksctl). Access entries are managed through the AWS API (so they work with Terraform/CloudFormation, appear in CloudTrail, and can't be broken by a YAML typo that locks everyone out), and they take precedence when both exist. New clusters should use auth mode **`API`**. Topic 63 shows both: access entries as the main way, and the original aws-auth flow as legacy knowledge (still common in existing clusters and in interviews).

### The groups you must not use for CI (from Project 01, still true)

The `aws-auth` entry `eksctl` creates for worker nodes:
```yaml
mapRoles: |
  - rolearn: arn:aws:iam::386275436648:role/eksctl-cwvj-devsecops-eks-nodegrou-NodeInstanceRole-J3Szf4uMWv1R
    groups:
    - system:bootstrappers
    - system:nodes
    username: system:node:{{EC2PrivateDNSName}}
```
- `system:bootstrappers`: lets nodes **join the cluster** securely during bootstrapping.
- `system:nodes`: lets nodes read/write node objects, report status, attach volumes, register with the scheduler, etc. A **powerful group**; nodes need it, but humans and CI should **never** be in it. Together, `system:nodes` and `system:bootstrappers` are a **privileged node identity**, meant only for kubelets (the agent on each node). These permissions are intended only for Kubernetes nodes, not CI/CD systems or humans; granting them to Jenkins would effectively give it node-level or near-cluster-admin rights, which is unnecessary and insecure.
- `username: system:node:{{EC2PrivateDNSName}}`: each worker node appears as a Kubernetes user named after its private DNS name.

Giving Jenkins these permissions would let it act like a node, update node status, read secrets through node privileges, and perform node-level actions across namespaces. That violates least privilege and is **dangerous**.

**Why not `system:masters` either:** `system:masters` = **full cluster admin**, unrestricted (nodes, secrets, CRDs, everything), and it bypasses RBAC entirely. Pipelines should **never** deploy with cluster-admin privileges.

**Why only `system:authenticated`:** this group means "you're a known, authenticated user", **with no permissions by default**. RBAC then grants exactly what Jenkins needs. Authentication (who) and authorization (what) stay separate, keeping the cluster secure and predictable. With access entries you get the same effect: create the entry with a **username** and no access policy, and bind RBAC to that username (or attach an EKS **access policy** scoped to a namespace).

### The Kubernetes objects deployed

- **Namespace** `cwvj-devsecops`: a folder for resources.
- **Deployment** (2 replicas): keeps 2 pods of the image running, does rolling updates, supports `rollout undo`.
- **Service** type **NodePort** (`80 → 8080`, nodePort 31000): exposes the pods on port 31000 of every node.
- **topologySpreadConstraints**: spreads the replicas across Availability Zones.
- **ClusterRole + ClusterRoleBinding** `jenkins-deployer-*`: exactly the verbs the pipeline needs.

---

## Config / Jenkinsfile / commands

Admin-side checks you'll run in topic 63:
```bash
aws eks describe-cluster --name cwvj-devsecops-eks --query 'cluster.accessConfig'   # auth mode
aws eks list-access-entries --cluster-name cwvj-devsecops-eks
kubectl auth can-i create deployments -n cwvj-devsecops --as jenkins-agent-role     # RBAC check
kubectl auth can-i list nodes --as jenkins-agent-role                                # should be "no"
```
```
{ "authenticationMode": "API_AND_CONFIG_MAP" }
yes
no
```

---

## Hands-on lab

Without AWS: in a kind cluster, create a user-like identity check with RBAC impersonation:
```bash
kubectl create ns demo
kubectl create clusterrole deployer --verb=get,list,create,update,patch,delete --resource=deployments,services
kubectl create rolebinding jenkins-deployer -n demo --clusterrole=deployer --user=jenkins-agent-role
kubectl auth can-i create deployments -n demo --as jenkins-agent-role   # yes
kubectl auth can-i create deployments -n default --as jenkins-agent-role # no
kubectl auth can-i get secrets -n demo --as jenkins-agent-role           # no
```
That's the authorization half of what topic 63 does on EKS.

---

## Where you'll use it

Any Jenkins that deploys to AWS: ECR pushes, EKS deploys, least-privilege reviews.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `Unable to locate credentials` | No instance role attached (or IMDS blocked) | Attach the role; check IMDS hop limit for containers |
| `AccessDeniedException … eks:DescribeCluster` | Role lacks that permission | Add the inline policy (topic 63) |
| `error: You must be logged in to the server (Unauthorized)` | IAM identity not mapped (no access entry / aws-auth entry) | Create the access entry |
| `Error from server (Forbidden): … cannot create resource "deployments"` | Mapped but no RBAC | ClusterRole/Role + binding |
| `no basic auth credentials` on `docker push` to ECR | Not logged in, or login expired (12 h) | `aws ecr get-login-password …` before pushing |

---

## Quick recap

- EC2 agents get AWS permissions from an **IAM role** via the instance profile; no keys in Jenkins.
- ECR login = a 12-hour token from `aws ecr get-login-password`.
- EKS: IAM identity → **access entry** (current) or `aws-auth` (deprecated) → Kubernetes user/group → **RBAC**.
- Never map CI to `system:masters` or node groups; authenticate only, then grant minimal RBAC.

**Interview questions**

1. **Q: How should a Jenkins agent on EC2 authenticate to AWS?**
   A: With an IAM role attached through an instance profile; the CLI gets short-lived credentials from instance metadata, so no access keys are stored in Jenkins.

2. **Q: Authentication vs authorization in EKS?**
   A: Authentication maps the IAM identity to a Kubernetes user/group (access entries or aws-auth). Authorization is Kubernetes RBAC deciding what that user/group may do.

3. **Q: Why not add the CI role to `system:masters`?**
   A: It's unrestricted cluster-admin that bypasses RBAC; a compromised pipeline could do anything in the cluster. Grant only the verbs and resources the deploy needs.
