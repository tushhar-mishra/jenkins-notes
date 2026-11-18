# Analysis of the original Jenkins notes

Source: `Desktop/Jenkins-Basics-To-Production` (backed up byte-for-byte to `Desktop/Jenkins-original-backup`, verified with `diff -rq`).

Files read in full: root `README.md`, `Day 01`–`Day 07` READMEs, `shared-library/README.md`, `Project 01/README.md` (2,792 lines), and every code file: 3 Jenkinsfiles (Day 06, Day 07, Project 01), the `Day 06/test` freestyle script, 4 shared-library Jenkinsfiles, 2 `vars/*.groovy`, 6 Dockerfiles, Flask apps, `pom.xml`, `App.java`, `AppTest.java`, `deploy-svc.yaml`, `clusterrole-binding.yaml`, `eks-config.yaml`, `aws-auth-edit`, `aws-kube-config-policy`, `.gitignore`. 30 images in `images/`.

Facts that change often were checked in November 2026 (sources at the end).

---

## 1. Topics covered

| Original | Topics |
|---|---|
| Day 01 | SDLC (8 phases with production notes), Waterfall vs Agile/DevOps, Git's role, compiled vs interpreted languages, Java artifacts (`.jar/.war/.ear/.class`), artifact/runtime/middleware/dependencies, two-step builds (compiled; containerized and not), one-step builds (interpreted; containerized and not), venv/nvm/rbenv, why build automation matters |
| Day 02 | Git essentials (commit, push/pull, remotes, branches, PR/MR, protected branches, status checks, glossary), CI/CT/CD/CDp/CM, CI and branching, GitFlow environment-branch CI/CD, promotion PR dev→stage (deploy-before-merge, manifest.json, digests, tags), stage→prod gate, speed vs safety, trunk-based promotions, Jenkins's place in the picture |
| Day 03 | What Jenkins is, 5 install options (Docker, VM, Kubernetes/Helm, marketplace, CloudBees) + chooser, Jenkins-in-Docker lab, `/var/jenkins_home`, admin vs user roles, first Freestyle job (shell, env vars, artifacts, Git SCM), Maven via Tools vs OS install |
| Day 04 | Full `$JENKINS_HOME` map, why "hudson", Jenkins as a WAR, workspaces and where jobs run, backup checklist, parameters, branch parameter, Poll SCM + `H`, webhooks, nightly cron + workspace cleanup |
| Day 05 | DooD (Docker-outside-of-Docker), `docker.sock`, socket permissions, Docker CLI in Jenkins, FAQ, Project 1: Flask → Docker Hub → run (Freestyle), GitHub PAT, credentials and secret injection |
| Day 06 | Why pipelines (vs chained Freestyle), inline vs SCM, Groovy level needed, declarative vs scripted, declarative blocks, skeleton pipeline, Snippet Generator, `git` + `withCredentials`, `environment`, full pipeline, `post`, deploy-info artifact + fingerprint, `cleanWs` |
| Day 07 | Multibranch Pipeline (MBP): what/why, discovery, trunk-based MBP flow (6 steps), branch strategies, PR Head/Merge/Both, fork PRs and trust, cheat sheet, full demo, GitHub branch protection |
| shared-library | The problem with duplication, `@Library`, `vars/` `src/` `resources/`, Jenkins on EC2 (controller runs builds), Docker Engine install, Demo 1 (`simpleEcho`), Demo 2 (private app1/app2 + private library), the "change once, both apps update" demo, centralising config |
| Project 01 | Jenkins controller on EC2, SSH agent (keys, `authorized_keys`, host-key strategies), SonarQube + PostgreSQL on EC2 (kernel tuning, systemd unit), 9-stage DevSecOps pipeline (checkout, Trivy FS, Maven+Sonar quality gate, ECR login with IAM role, image build, Trivy image, push, manifests with topology spread + `sed`, EKS via eksctl, IAM policy, aws-auth, RBAC, rollout/undo), `post`, push triggers, 12 production improvements |

## 2. Weak or surface-level explanations

1. **Agents** appear everywhere (Day 02–07) but are only *configured* at the very end (Project 01). There's no explanation of executors, labels, the queue, Remoting/`agent.jar`, inbound vs outbound agents, or cloud/ephemeral agents.
2. **What happens inside a build** is never traced end to end (webhook → controller → queue → executor → agent → workspace → steps → artifacts → status/notification).
3. **The Pipeline engine** is not explained: CPS (Continuation-Passing Style, how Groovy is made pausable), flyweight vs heavyweight executors, durability, `@tmp`/`@script` folders, Replay, Restart from Stage.
4. **Declarative directives** are listed in one line each (`options`, `parameters`, `when`, `tools`, `triggers`) and never taught or used: no `parallel`, `matrix`, `input`, `stash`, `timeout`, `retry`, `agent { docker }`, `junit`.
5. **Credentials**: no kinds/scopes/domains, how they're encrypted, masking limits, or the Groovy double-quote interpolation leak.
6. **Groovy**: "we'll teach as we go", but quoting rules (`'...'` vs `"..."` vs `'''...'''`) are what decides whether `$VAR` is expanded by Groovy or by the shell. That's never explained, though the Jenkinsfiles rely on it.
7. **Security of Jenkins itself**: only one-liners (RBAC/SSO). Missing: security realm, authorization strategy, CSRF crumbs, API tokens, script approval, 0 executors on the controller, plugin advisories.
8. **Plugins**: "rich ecosystem", but nothing about managing, pinning, upgrading or conflicts.
9. **JCasC** (Jenkins Configuration as Code) is mentioned twice and never explained.
10. **Backup/restore**: Day 04 has a file checklist, but no method, no restore drill, and no upgrade process.
11. **Maven, SonarQube, Trivy, IAM, EKS** are used with links to outside videos rather than explained.
12. **Testing results**: no `junit` step, UNSTABLE result, test trends or coverage publishing.
13. **Shared libraries**: no parameters (they read shell env vars), no versioning/tagging strategy, no trusted vs untrusted libraries, no testing.

## 3. Terms used without being explained (first-use list)

SHA, OCI, digest, SBOM, SAST/SCA/DAST, SLA/SLO/SLI, error budget, RPO/RTO, IaC, Helm, Kustomize, GitOps, canary, blue-green, feature flag, merge queue, CODEOWNERS, JNLP, JCasC, RBAC, SSO, OIDC, IRSA, CDF, WAR/JPI/HPI, Winstone/Jetty, servlet container, JVM `-Xms/-Xmx`, executor, node, label, workspace, Remoting, CSRF/crumb, DooD/DinD, Unix domain socket, IPC, PAT, webhook, cron syntax, thundering herd, fingerprint, changelog, Groovy sandbox, TOFU, `known_hosts`, ed25519, PVC, StorageClass, NetworkPolicy, Ingress, AZ, NodePort, ConfigMap, ClusterRole, aws-auth, eksctl, IAM role/instance profile, JUnit/Surefire/JaCoCo, quality gate, Elasticsearch, ulimit, sysctl, systemd unit, BuildKit, CPU platform/arch, orphaned item strategy, `milestone`, BYOL, MSP, TCO, Operations Center, Docker Swarm.

## 4. Dependency-order problems

| Where | Uses | Explained |
|---|---|---|
| Day 01 | Docker images, Dockerfile, SAST/SCA/DAST tools, canary, IaC, SLOs | never / Day 02 / outside |
| Day 02 | Helm, `kubectl --dry-run=server`, Kubernetes, digests, canary %, GitOps, Argo CD | never (Kubernetes only in Project 01) |
| Day 02 "Jenkins in this picture" | controller + agents, multibranch, shared libraries, webhooks, Credentials | Day 03–07, shared-library, Project 01 |
| Day 03 "What is Jenkins" | JNLP, Kubernetes plugin, JCasC, RBAC, External Secrets Operator | never |
| Day 03 Freestyle | `tools { maven }` Jenkinsfile; "Parameters" key point | Day 06; Day 04 |
| Day 04 `$JENKINS_HOME` | executors, agents, Remote root, `agent.jar` | Project 01 (last) |
| Day 04 webhooks | Jenkins URL, public tunnel | never (no tunnel how-to) |
| Day 05 DooD | Unix sockets, file modes `srw-rw----`, groups | Linux notes (not linked) |
| Day 07 | `disableConcurrentBuilds()`, `milestone()`, SBOM, DAST, ephemeral preview envs | never |
| shared-library | Jenkins-on-EC2 install duplicated, done before agents | Project 01 |
| Project 01 | agents (at the very end of the course), Maven, Sonar, Trivy, IAM, EKS, RBAC | outside links |

## 5. Errors and outdated information (each becomes a "⚠️ Corrected" note)

**Jenkins platform**
1. Day 03 VM example installs `openjdk-17-jre-headless`. **Java 17 is no longer supported**: weekly dropped it at 2.545 (Jan 2026), LTS at 2.541.3 (Mar 2026). Jenkins 2.555.1+ needs **Java 21 or 25**. The current LTS line is 2.568.x.
2. Day 03, shared-library and Project 01 use **`jenkins.io-2023.key`**. That key expired on 2026-03-26. LTS packages since 2.541.1 (Jan 2026) are signed with **`jenkins.io-2026.key`**. The old commands now fail with a GPG/NO_PUBKEY error.
3. `jenkins/jenkins:lts` floats. Pin `jenkins/jenkins:<version>-lts-jdk21` (or `lts-jdk21`) for reproducibility.
4. Project 01 says "Manage Jenkins → **Global Tool Configuration**". It's been **Manage Jenkins → Tools** since 2.4xx (Day 03 already uses the new name).
5. "JNLP" for port 50000 is the old name. Agents are now called **inbound agents** (TCP or **WebSocket**). "JNLP" (Java Network Launch Protocol) and Java Web Start launching are removed. The `jnlp` name only survives as the default container name in Kubernetes agent pods.
6. **Blue Ocean has been deprecated since July 2026** (no fixes). Use **Pipeline Graph View** (Day 06's "Stages tab"). Stage View is legacy.
7. Day 02/03 "1,800+ plugins" is now about 2,000. That's minor, but I'll update it.
8. Day 06: "For inline Scripted Groovy, Jenkins *may* use the Groovy Sandbox". In fact, **all** Pipelines (declarative or scripted) run in the sandbox. Pipeline-from-SCM is *always* sandboxed. Only inline scripts can turn it off, which needs admin approval.
9. Day 06 Snippet Generator URL `/job/pipeline-1/...` doesn't match the job created (`flask-pipeline`).

**Docker in Jenkins**
10. Day 05: "We're installing **only the client**" but runs `get.docker.com`, which installs the **full engine** (dockerd, containerd). Correct: install only `docker-ce-cli` (plus buildx plugin).
11. Day 05: `chmod 666 /var/run/docker.sock` gives every process root-equivalent access. Correct: match the socket's group GID (`--group-add`). Also: anyone in the `docker` group is effectively root.
12. Project 01: `export DOCKER_BUILDKIT=0`. The **legacy builder is deprecated** (BuildKit has been the default since Engine 23; your Docker notes are on Engine 29). Use BuildKit and `--platform`.
13. Day 01: `FROM openjdk:17-jdk-slim` uses the **deprecated `openjdk` images** (no updates since 2022), so use `eclipse-temurin`. Also `COPY app.jar` has no destination (syntax error).
14. Day 05 / Project 01: Kaniko is offered as a daemonless builder. **Google archived Kaniko in June 2025**. Chainguard and others maintain forks. Prefer BuildKit rootless / buildx with a remote builder, or Buildah.

**Pipelines and Groovy**
15. Day 06/07: `cleanWs()` as the last *stage* is skipped whenever an earlier stage fails. It belongs in `post { cleanup { ... } }`.
16. Day 07: the same Jenkinsfile **deploys from every branch and PR job** to the same container on port 5000, so PR builds overwrite `main`. Fix: `when { branch 'main' }`.
17. Shared-library Step 11 shows `sh "docker build -t ${repo}:${tag} ."` with Groovy variables that don't exist (the real files use shell `$REPO`/`$TAG`). The notes also say the steps "read `env.*`", but they actually read shell env vars.
18. Shared-library: the container is named `$REPO` (`app1-flask`), but verification runs `docker inspect app1`, and the text says "container name `app2`".

**Security tooling (Project 01)**
19. SonarQube quality gate condition "Coverage **is greater than** 80" is backwards. Gate conditions describe *failure*, so the condition should be "Coverage **is less than** 80".
20. Credential ID drift: `sonarqube-token` is created, but the pipeline uses `sonarqube-token-new`, and the final file uses `sonarqube-token`.
21. Day 01 classes Trivy image scanning as SAST, and runtime security as "DAST extended". Image/dependency scanning is **SCA**, and runtime security is its own category.
22. Trivy demo "secret" `AWS_SECRET_ACCESS_KEY=AKIA...`: `AKIA…` is an access-key **ID** pattern, not a secret key.

**Linux / SSH**
23. Project 01: "`sudo su - jenkins` will prompt you to set the password for the jenkins user" is wrong. `sudo` asks for *your* password (none on EC2 `ubuntu`), and never sets the target's password.

**Kubernetes / AWS**
24. **`aws-auth` ConfigMap is deprecated.** Use **EKS access entries** (Cluster Access Management API, auth mode `API`). The original flow stays as a "legacy, still seen in interviews" section.
25. EKS `version: "1.32"` is past standard support. Update to a currently supported EKS version (checked when writing that topic).
26. README `eks-config` has `desiredCapacity: 1` with `minSize: 2`, which is invalid (the actual file has 2). With 1 node, the `DoNotSchedule` topology spread would leave a pod Pending.
27. "`kubectl create ns` is simple and idempotent" is wrong. It fails with `AlreadyExists` on the second run. It only appears to work because a `#!/bin/bash -l` shebang turns off Jenkins's default `set -e`. Correct: `kubectl create ns X --dry-run=client -o yaml | kubectl apply -f -`, or a Namespace manifest. Also explain that a shebang removes `-xe`.
28. Verification uses `cwvj-devsecops-svc`, but the Service is `cwvj-devsecops-demo-svc`.
29. Helm chart `--set controller.jenkinsAdminPassword=admin123`: the chart key is now `controller.admin.password` (better: an existing Secret). Plain passwords in `--set` end up in shell history.

**Git / misc**
30. Day 02: AWS CodeCommit and GCP Cloud Source Repositories are listed as hosts. CSR is closed to new customers. CodeCommit's status changed in 2024–25, so I'll recheck it when writing.
31. PAT in clone URLs (Day 07, shared-library): it's risky and stays in shell history. Recommend a credential helper or `gh auth`, and a **GitHub App** credential for Jenkins (higher API rate limits, no personal token).
32. Root README: `cd Jenkins-Basics-To-Production/Day1`, but the folder is `Day 01`.
33. Java EE → Jakarta EE rename (Day 01 `.ear` row).

**Terminology:** your notes already use **controller/agent**. I'll add a one-line "old names: master/slave" note for interviews.

## 6. Missing topics needed for production and interviews

- Jenkins architecture deep dive + full `git push` trace
- LTS vs weekly releases, Java support policy ("2+2+2")
- UI tour (Pipeline Graph View, folders, views)
- Credentials model in depth (kinds, scopes, folder credentials, encryption, masking, Groovy interpolation leak)
- Groovy just-enough
- Pipeline engine internals (CPS, durability, Replay, Restart from Stage)
- Declarative: `options`, `parameters`, `triggers`, `when`, `input`, `milestone`/`lock`, `parallel`, `matrix`, per-stage agents, `agent { docker }`/`dockerfile`, `stash`/`unstash`
- Build results, `junit`, UNSTABLE, `catchError`
- Scripted pipelines (when still used), `@NonCPS`, NotSerializableException
- Agents: outbound SSH vs inbound (TCP/WebSocket), executors/labels, controller executors = 0, a **local** SSH agent lab with Docker containers (no AWS bill)
- Cloud agents: Kubernetes plugin + pod templates (lab on kind, matching your CKA notes), Docker/EC2 clouds
- GitHub App auth, Checks API, organisation folders
- Security hardening (realms, authorization, CSRF, API tokens, script approval, agent→controller, advisories, TLS/reverse proxy)
- Plugin management (`plugins.txt`, plugin installation manager, pinning, conflicts)
- JCasC + Job DSL (Domain-Specific Language) seed jobs + custom Jenkins image
- Backup/restore + upgrade procedure; monitoring (Prometheus metrics, JVM heap/GC, queue), performance, HA/DR (high availability / disaster recovery) realities
- Jenkins CLI and REST API (Representational State Transfer; trigger with curl)
- Notifications (email-ext, Slack)
- Jenkins + Argo CD GitOps hand-off
- Secret managers (Vault, AWS Secrets Manager credential provider)
- Troubleshooting catalog, production scenarios, interview bank, Jenkins vs GitHub Actions/GitLab CI/Tekton, cheat sheet

## Sources checked (Nov 2026)

- [Jenkins Java Support Policy](https://www.jenkins.io/doc/book/platform-information/support-policy-java/) · [LTS Changelog](https://www.jenkins.io/changelog-stable/) · [Java 17 EOL thread](https://community.jenkins.io/t/java-17-end-of-life-warning-still-running-on-lts-2-541-x-safe-to-continue/36772)
- [Repository signing keys changing (Dec 2025)](https://www.jenkins.io/blog/2025/12/23/repository-signing-keys-changing/) · [pkg.jenkins.io/debian](https://pkg.jenkins.io/debian)
- [Blue Ocean docs (deprecated)](https://www.jenkins.io/doc/book/blueocean/index.html) · [Plugin of the Month: Pipeline Graph View](https://www.jenkins.io/blog/2026/04/06/plugin-of-the-month/)
- [EKS cluster access management best practices](https://docs.aws.amazon.com/eks/latest/best-practices/cluster-access-management.html) · [aws-auth ConfigMap docs](https://docs.aws.amazon.com/us_en/eks/latest/userguide/auth-configmap.html)
- [Chainguard: Kaniko fork](https://www.chainguard.dev/unchained/fork-yeah-were-bringing-kaniko-back) · [The New Stack: Kaniko lives on](https://thenewstack.io/kaniko-lives-on-chainguard-forks-googles-dumped-tool/)
