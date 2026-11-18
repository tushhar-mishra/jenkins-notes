# 64 · Improving the Pipeline

> **Level:** ★★ intermediate · **Status:** ✅➕ rewritten and expanded
>
> **You will learn:** the twelve production upgrades to the Project 4 pipeline from your notes, each with *why*, *how* and a concrete snippet: Ingress/Gateway API, multibranch, GitOps with Argo CD, DNS instead of IPs, deploying by digest, signed images + admission policies, central secrets, observability, policy-as-code, Helm/Kustomize, progressive delivery, and cleanup/cost.
>
> **You need:** topics 07, 09, 43, 62–63.
>
> **From your original notes:** Project 01 › *How this pipeline can be improved (Production Enhancements)* 1–12 (incl. the video/notes links).

---

## What it is

The pipeline you built is intentionally simple so you can learn every moving part. Real DevSecOps teams extend it with stronger automation, GitOps, better deploy strategies and enterprise security. These are the most important upgrades.

---

## Why it exists

Interviewers love "how would you improve this pipeline?". Each item below is a production concern with a standard answer.

---

## Analogy

You've built a working car. These are the seat belts, airbags, GPS, service history and anti-theft system that make it road-legal for a fleet.

---

## How it works inside: the twelve upgrades

### 1. Kubernetes Ingress / Gateway API instead of NodePort (highly recommended)

We used a **NodePort** for simplicity. In production, teams use **Ingress controllers** (e.g. the AWS Load Balancer Controller) or the **Gateway API** (the newer Kubernetes routing API) for **TLS termination**, **host/path routing** and managed **load balancers**, so users hit `https://loans.example.com` instead of `node-ip:31000`.
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: demo, namespace: cwvj-devsecops }
spec:
  parentRefs: [{ name: public-gateway, namespace: infra }]
  hostnames: ["demo.example.com"]
  rules: [{ backendRefs: [{ name: cwvj-devsecops-demo-svc, port: 80 }] }]
```
Original lecture on the AWS Load Balancer Controller, TLS and routing: [video](https://www.youtube.com/watch?v=ngyegIE_5FM&list=PLmPit9IIdzwSv2zwizysG6OwWUACpQFN0&index=3&t=1s) · [notes](https://github.com/CloudWithVarJosh/YouTube-Standalone-Lectures/tree/main/Lectures/03-ing-eks). Your Kubernetes notes cover it in topics 69–73. (Note: the community **ingress-nginx** controller is being retired; prefer the Gateway API or a maintained controller for new setups.)

### 2. Multibranch pipelines (critical for real CI/CD)

Real teams don't push to `main` directly. A **multibranch pipeline** discovers branches and PRs, runs CI on each, and only merges when checks pass. The demo was kept single-branch for simplicity. This course: topics 43–47 (original [video](https://www.youtube.com/watch?v=Eq-HHLtSJM4&list=PLmPit9IIdzwSiYCKOtXUGNwytXXiJ8Rv8&index=7) · [notes](https://github.com/CloudWithVarJosh/Jenkins-Basics-To-Production/tree/main/Day%2007)). Add `when { branch 'main' }` to the ECR push/deploy stages.

### 3. GitOps with Argo CD (the true production pattern)

**Argo CD** implements a **pull-based** deployment model: a controller inside the cluster continuously syncs Kubernetes from a Git repo. Git becomes the **single source of truth**, with automated sync, **drift detection** (it notices and reverts manual changes) and instant rollbacks (revert a commit). Jenkins stops running `kubectl apply` and instead **commits the new image digest** to an environment-config repo. It wasn't covered in the original course; topic 72 here shows the Jenkins → Argo CD hand-off.

### 4. Use DNS names instead of IPs (always in production)

We used raw IPs for the Jenkins agent and SonarQube (and the SonarQube IP changed between recordings). In production always use **DNS**: Route 53 private hosted zones, internal load-balancer names, service discovery. DNS gives reliability, identity (**TLS certificates validate names**) and portability; IP rotation or autoscaling never breaks the pipeline.
```groovy
environment { SONAR_HOST = 'https://sonar.internal.example.com' }
```

### 5. Deploy by image digest instead of tag (enterprise best practice)

Enterprises deploy immutable **SHA-256 digests**, not tags. A digest guarantees the exact scanned, approved artifact is what runs, with no tag drift or overwrites (topic 07). Get the digest after the push:
```bash
DIGEST=$(aws ecr describe-images --repository-name cwvj-devsecops-demo --image-ids imageTag=$BUILD_NUMBER \
          --query 'imageDetails[0].imageDigest' --output text)
sed -i "s|image:.*|image: $ECR_REGISTRY/cwvj-devsecops-demo@$DIGEST|" deploy-svc.yaml
```

### 6. Signed images + policy enforcement

Modern clusters only run **signed** images. Sign after pushing with **Cosign** (Sigstore; key-based, or keyless with OIDC identities) or **Notation** (the Notary Project, "Notary v2"); enforce at admission time with **Kyverno**, **OPA Gatekeeper** or **Sigstore policy-controller**, so only compliant, trusted containers reach production. This protects the cluster from tampered or unverified images.
```bash
cosign sign --yes --key awskms:///alias/ci-signing "$ECR_REGISTRY/cwvj-devsecops-demo@$DIGEST"
cosign verify --key awskms:///alias/ci-signing "$ECR_REGISTRY/cwvj-devsecops-demo@$DIGEST"
```
Add an SBOM attestation too: `trivy image --format cyclonedx -o sbom.json …` then `cosign attest --type cyclonedx --predicate sbom.json …`.

### 7. Centralised secrets management

Instead of keeping everything in Jenkins Credentials, enterprises integrate **Vault** or **AWS Secrets Manager**, which provide **short-lived secrets**, **automatic rotation** and strong encryption; no secrets appear in logs or long-lived environment variables. Even better: no secret at all (IAM roles, IRSA, OIDC). Topic 24.

### 8. Observability integration

Teams wire **CloudWatch, Prometheus/Grafana or Datadog** to track build → deploy → runtime behaviour, which makes rollbacks easy and links performance problems to specific builds. Add build-number/commit **annotations** to deployments for traceability:
```bash
kubectl annotate deployment/cwvj-devsecops-demo -n cwvj-devsecops --overwrite \
  ci.jenkins.io/build="$BUILD_URL" app.kubernetes.io/version="$BUILD_NUMBER"
```
and send a deployment event/marker to your monitoring tool from `post { success { … } }` (topic 69 covers monitoring Jenkins itself).

### 9. Policy-as-code and compliance scans

Insert **Conftest** (OPA/Rego policies), **Checkov** or **Trivy config** checks to validate Kubernetes manifests and Terraform **before** deploying, so every resource follows security standards and company policy (no `:latest`, resource limits required, no privileged containers). Especially important in regulated environments.
```groovy
stage('Policy check') { steps { sh 'trivy config --exit-code 1 --severity HIGH,CRITICAL deploy-svc.yaml' } }
```

### 10. Helm or Kustomize to manage manifests

Instead of raw YAML plus `sed`, enterprises package deployments with **Helm charts** or **Kustomize** overlays: modular, repeatable, environment-aware, with clean configuration. Jenkins templates Helm values and deploys chart releases (Kubernetes notes topics 64–65):
```bash
helm upgrade --install demo ./chart -n cwvj-devsecops \
  --set image.repository="$ECR_REGISTRY/cwvj-devsecops-demo" --set image.digest="$DIGEST" \
  -f chart/values-prod.yaml --atomic --timeout 5m
```
`--atomic` rolls back automatically if the release fails: the Helm equivalent of the `rollout undo` block.

### 11. Argo Rollouts / blue-green / canary deployments

Once the basic pipeline is stable, add **progressive delivery** (topic 09): **Argo Rollouts**, **Flagger** or ingress/mesh canary strategies give partial rollouts, traffic shifting and **automatic rollback** on bad metrics, greatly reducing deployment risk.

### 12. Automated cleanup & cost optimisation

Auto-delete unused images, clean the Docker cache, remove old workspaces, and expire old ECR images with **ECR lifecycle policies** (e.g. keep the last 30 build tags, delete untagged after 7 days). Enterprises tune CI runtime for speed and cost: caches, ephemeral Spot agents, right-sized executors (topics 22, 53).
```json
{ "rules": [ { "rulePriority": 1, "description": "expire untagged after 7d",
  "selection": { "tagStatus": "untagged", "countType": "sinceImagePushed", "countUnit": "days", "countNumber": 7 },
  "action": { "type": "expire" } } ] }
```

---

## Config / Jenkinsfile / commands

The improved shape of Project 4 (stages only):
```
Checkout → Trivy FS → Build & Sonar (junit, coverage) → Policy check (manifests)
→ Build image (BuildKit) → Trivy image + SBOM → Push → Resolve digest → Sign + attest
→ [main only] Commit digest to env-config repo (GitOps) → Argo CD syncs dev → approval → stage/prod via Argo Rollouts canary
post: notify Slack, annotate monitoring, cleanup
```

---

## Hands-on lab

Pick three upgrades and implement them on your Project 4 (or a local version): **5** (digest), **9** (`trivy config` gate) and **12** (an ECR lifecycle policy, or a scheduled `docker image prune` on the agent). Then write a one-paragraph "how I'd improve this pipeline" answer that uses all twelve.

---

## Where you'll use it

Every pipeline review, and the "improve this" interview question.

---

## When it breaks

| Upgrade | Typical pitfall |
|---|---|
| Digest deploys | Forgetting to resolve the digest *after* the push |
| Signing | Admission policy turned on before all images are signed: deploys blocked. Roll out in audit mode first |
| GitOps | Jenkins still running `kubectl apply` too: two writers fight. Pick one |
| Policy-as-code | Hundreds of violations on day one: start with warnings, fix, then enforce |
| Lifecycle policies | Deleting images still running in prod: keep released tags/digests |

---

## Quick recap

Ingress/Gateway · multibranch · GitOps · DNS · digests · signing + admission · central secrets · observability · policy-as-code · Helm/Kustomize · progressive delivery · cleanup/cost.

**Interview questions**

1. **Q: How would you make this pipeline's deployments safer?**
   A: Deploy by digest, sign images and enforce signatures at admission, check manifests with policy-as-code, deploy through GitOps, and use canary/blue-green with automatic rollback on SLO metrics.

2. **Q: Why GitOps instead of `kubectl apply` from Jenkins?**
   A: Git becomes the source of truth, the cluster pulls changes (no cluster credentials in CI), drift is detected and reverted, and rollback is a Git revert with a full audit trail.

3. **Q: What's the benefit of an admission policy that requires signed images?**
   A: Only images built and signed by your trusted pipeline can run, so tampered images, or images pushed outside the pipeline, are rejected by the cluster.
