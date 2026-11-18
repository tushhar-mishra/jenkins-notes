# 76 · Jenkins vs Other CI Tools, and What Next

> **Level:** ★ foundation · **Status:** 🆕 new topic (expands Day 02's "Alternatives / complements")
>
> **You will learn:** how Jenkins compares with GitHub Actions, GitLab CI, Tekton, Argo CD/Flux and CloudBees CI, when each wins, how concepts map between them, and what to learn next after this course.
>
> **You need:** the whole course.
>
> **From your original notes:** Day 02 › *Jenkins in this picture → Alternatives / complements*, *What it isn't* · Day 03 › CloudBees.

---

## What it is

| Tool | Model | Where it runs | Pipeline file |
|---|---|---|---|
| **Jenkins** | Self-hosted automation server + plugins | Anywhere you run it | `Jenkinsfile` (Groovy DSL) |
| **GitHub Actions** | CI/CD built into GitHub; hosted or self-hosted runners | GitHub cloud / your runners | `.github/workflows/*.yml` |
| **GitLab CI/CD** | Built into GitLab; shared or own runners | GitLab SaaS / self-managed | `.gitlab-ci.yml` |
| **Tekton** | Kubernetes-native CI building blocks (CRDs) | Your Kubernetes cluster | `Task`/`Pipeline` YAML |
| **Argo CD / Flux** | GitOps continuous **delivery** (not CI) | Your cluster | Kubernetes manifests in Git |
| **CloudBees CI** | Commercial Jenkins | Your infra / managed | `Jenkinsfile` |

From Day 02: GitHub Actions or GitLab CI can do similar CI/CD. Argo CD/Flux excel at **GitOps promotions** (Jenkins can open the PRs they sync). Jenkins stays popular when you want **maximum portability and customisation** across many tools and environments. And Jenkins is not a Git server, registry or monitoring stack: it **calls** them.

---

## Why it exists

Interviewers ask "why Jenkins?", and real teams migrate in both directions. Knowing the trade-offs, and that the **concepts transfer**, makes you tool-agnostic.

---

## Analogy

Jenkins is a **workshop you own**: any tool, any machine, but you maintain the building. GitHub Actions is a **co-working space** attached to your office: convenient, metered, less control. Argo CD is the **delivery service** that takes finished goods to the shops.

---

## How it works inside: comparison

| | Jenkins | GitHub Actions | GitLab CI |
|---|---|---|---|
| Hosting | You run it | SaaS (+ self-hosted runners) | SaaS or self-managed |
| Cost model | Your infra + ops time | Per-minute (hosted), free for public repos | Per-minute / licence tiers |
| Extensibility | ~2,000 plugins, shared libraries, Groovy | Marketplace actions (YAML, JS, containers) | Templates, components, `include:` |
| Git host | Any | GitHub | GitLab (others via mirroring) |
| Air-gapped / on-prem | ✅ Excellent | Partial (GHES) | ✅ (self-managed) |
| Ops burden | **High** (upgrades, plugins, security) | Low | Low (SaaS) / medium |
| Big strengths | Flexibility, legacy integrations, complex orchestration, no vendor lock-in | Tight GitHub integration, zero setup, OIDC to clouds | All-in-one DevSecOps platform |

**Concept mapping:**

| Jenkins | GitHub Actions | GitLab CI |
|---|---|---|
| Jenkinsfile | workflow YAML | `.gitlab-ci.yml` |
| stage / steps | job / steps | stage / job `script` |
| agent + label | `runs-on:` runner label | `tags:` runner |
| `parallel` / `matrix` | parallel jobs / `strategy.matrix` | parallel jobs / `parallel:matrix` |
| credentials + `withCredentials` | `secrets.X` (+ environments) | CI/CD variables (masked/protected) |
| shared library | reusable workflows / composite actions | `include:` templates / CI components |
| `input` | environment protection rules (required reviewers) | `when: manual` + protected environments |
| `archiveArtifacts` / `stash` | `actions/upload-artifact` | `artifacts:` |
| multibranch | built in (on: push/pull_request) | built in |

### When Jenkins still wins (2026)

- Strict on-prem / air-gapped / regulated environments with many internal systems.
- Many Git hosts, or no single platform.
- Complex, long-running orchestration (approvals, locks, cross-repo flows), heavy customisation.
- An existing large estate (migration cost).
- Avoiding per-minute costs for very heavy builds on your own hardware.

### When something else wins

- GitHub-centric teams with simple-to-medium pipelines → **GitHub Actions** (less to operate).
- Teams wanting one platform for repo + CI + registry + security → **GitLab**.
- Kubernetes-native platform teams building their own CI → **Tekton** (+ Argo Workflows).
- Deployments to Kubernetes, whatever the CI → **Argo CD / Flux**.

---

## Config / Jenkinsfile / commands

The same tiny CI in three tools:

```groovy
// Jenkinsfile
pipeline { agent { label 'linux' }
  stages { stage('test') { steps { sh 'pip install -r requirements.txt && pytest -q' } } } }
```
```yaml
# .github/workflows/ci.yml
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r requirements.txt && pytest -q
```
```yaml
# .gitlab-ci.yml
test:
  image: python:3.12-slim
  script: [ "pip install -r requirements.txt", "pytest -q" ]
```

---

## Hands-on lab

Take your Project 2 Jenkinsfile (topic 36) and rewrite it as a GitHub Actions workflow (build, login with `docker/login-action` and a repository secret, push). Note what you didn't have to operate, and what you lost (e.g. the local DooD deploy).

---

## Where you'll use it

Interviews ("Jenkins vs Actions?"), tool selection, migrations.

---

## When it breaks

Common migration traps: assuming plugins have 1:1 equivalents; forgetting that self-hosted runners have the same security issues as Jenkins agents (untrusted PR code + secrets); moving deploy credentials into CI instead of adopting GitOps.

---

## Quick recap

- Jenkins = maximum flexibility and portability, highest ops burden.
- Actions/GitLab = integrated, low-ops, platform-bound; Tekton = Kubernetes-native CI; Argo CD/Flux = GitOps CD.
- Concepts (stages, runners/agents, secrets, artifacts, templates, approvals) transfer between tools.

### What to learn next

1. **Argo CD** in depth (Applications, ApplicationSets, sync waves, Rollouts), the natural partner of Jenkins (topic 72).
2. **GitHub Actions** (OIDC to AWS, reusable workflows), so you're tool-agnostic.
3. **Supply-chain security:** Sigstore/Cosign, SLSA provenance, SBOMs, admission policies (Kyverno).
4. **Terraform** for infrastructure pipelines (plan in PR, apply on merge).
5. **Observability:** Prometheus/Grafana, OpenTelemetry, SLOs for your pipelines.
6. **Helm/Kustomize** packaging (your Kubernetes notes topics 64–65).
7. Revisit your [Linux](../../linux-mastery-rhel/INDEX.md), [Docker](../../Docker/INDEX.md) and [Kubernetes](../../CKA-Certification-Course-2025/INDEX.md) notes: most CI/CD problems are really problems in one of those layers.

**Interview questions**

1. **Q: Why would a company choose Jenkins over GitHub Actions?**
   A: Self-hosting and air-gapped needs, many Git hosts and legacy systems, complex orchestration and customisation, an existing estate, or cost control for heavy builds on their own hardware.

2. **Q: Is Argo CD a replacement for Jenkins?**
   A: No. Argo CD handles GitOps delivery to Kubernetes; Jenkins (or another CI) still builds, tests, scans and publishes. They're commonly used together.

3. **Q: What's the biggest cost of running Jenkins?**
   A: Operations: upgrades, plugin management, security patching, scaling agents and backups, all of which hosted CI services do for you.
