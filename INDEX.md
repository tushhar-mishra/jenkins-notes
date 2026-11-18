# Jenkins: From Zero to Production

One learning path, in reading order. Each topic only uses ideas from topics before it. When a later idea has to appear early, it is explained right there in a line or two.

**Every topic has the same shape:** What it is · Why it exists · Analogy · How it works inside · Config / Jenkinsfile / commands (sample output, explained) · Hands-on lab · Where you'll use it · When it breaks · Quick recap + interview questions.

**Current Jenkins only (checked November 2026):** LTS line 2.568.x on **Java 21 or 25** (Java 17 is unsupported), packages signed with `jenkins.io-2026.key`, declarative Jenkinsfiles first, Pipeline Graph View for the UI. Deprecated things (Blue Ocean, the `jnlp`/Java Web Start launch, the legacy Docker builder, `aws-auth`, the `openjdk` images, Kaniko upstream) are marked **deprecated** where they come up and are never taught as the main way.

**Your lab:** Jenkins in Docker on the WSL2 Docker Engine from your [Docker notes](../Docker/INDEX.md). Agents run as local Docker containers, and Kubernetes agents run on kind (as in your [Kubernetes notes](../CKA-Certification-Course-2025/INDEX.md)). The AWS demos (EC2, ECR, EKS) are kept as clearly marked cloud labs.

**Related notes:** [Linux](../linux-mastery-rhel/INDEX.md) · [Docker](../Docker/INDEX.md) · [Kubernetes](../CKA-Certification-Course-2025/INDEX.md)

**Status:** ✅ your original material, rewritten · ➕ expanded with significant new material · 🔀 merged from several originals · 🆕 new topic.
**Levels:** ★ foundation · ★★ intermediate · ★★★ advanced.

---

## Part 1 · Why CI/CD exists (before Jenkins)

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 01 | ★ | 🔀➕ | [What is CI/CD](notes/01-what-is-ci-cd.md) | The pain of manual builds and late integration, "works on my machine", plain meanings of CI, CD (delivery) and CD (deployment), pipeline, artifact | D01, D02 |
| 02 | ★ | ✅ | [The SDLC and delivery models](notes/02-sdlc-and-delivery-models.md) | The 8 modern SDLC (Software Development Life Cycle) phases with production notes; Waterfall vs Agile/DevOps; shift-left | D01 |
| 03 | ★ | ✅➕ | [How code becomes runnable software](notes/03-how-code-becomes-software.md) | Compiled vs interpreted, bytecode and the JVM, artifact / runtime / middleware / dependencies, `.jar`/`.war`/`.ear`, build tools per language | D01 |
| 04 | ★ | ✅ | [Build processes: containerized vs not](notes/04-build-processes.md) | Two-step builds (compiled) vs one-step builds (interpreted), on VMs vs in images, venv/nvm/rbenv, config drift | D01 |
| 05 | ★ | ✅➕ | [Git essentials for CI/CD](notes/05-git-essentials-for-ci-cd.md) | Git recap: commits/SHAs, remotes and hosts, branches, PR/MR, protected branches, status checks, tags, merge vs rebase, forks, **what a webhook is** | D02 |
| 06 | ★★ | 🔀➕ | [The continuous practices](notes/06-continuous-practices.md) | CI, CT, CD, CDp, CM in depth; test types (unit → e2e, smoke, contract, load); SAST / SCA / DAST and tools; metrics/logs/traces, SLI/SLO/SLA, error budgets | D01, D02 |
| 07 | ★★ | 🔀➕ | [Artifacts, tags and digests](notes/07-artifacts-tags-and-digests.md) | Build once, promote many; immutability; tags vs digests; `manifest.json`; artifact repositories; SBOMs and signing | D01, D02 |
| 08 | ★★ | ✅ | [Branching strategies](notes/08-branching-strategies.md) | GitFlow environment branches, trunk-based, GitHub Flow, release trains, forking, monorepos, and where CI runs in each | D02 |
| 09 | ★★ | ✅➕ | [Promotion flows end to end](notes/09-promotion-flows.md) | feature → dev, dev → stage (deploy-before-merge), stage → prod gate, trunk-based promotions; rolling, blue-green, canary, feature flags, rollback; Helm and GitOps in one paragraph each | D02 |

## Part 2 · Meet Jenkins

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 10 | ★ | 🔀 | [What is Jenkins](notes/10-what-is-jenkins.md) | Open-source automation server, the Hudson → Jenkins fork (2011), CDF and CloudBees, plugins, what it isn't, alternatives, old "master/slave" names | D02, D03, D04 |
| 11 | ★★ | 🆕 | [Jenkins architecture and the life of a build](notes/11-jenkins-architecture.md) | Controller, nodes, agents, executors, labels, the queue, workspaces, items, Remoting. **Full trace:** `git push` → webhook → controller → queue → agent → workspace → stages → artifacts → status and notifications | D03, D04 |
| 12 | ★★ | ➕ | [Jenkins is a Java web app](notes/12-jenkins-is-a-java-web-app.md) | JVM, WAR, embedded Jetty (Winstone), ports 8080 and 50000, `JENKINS_HOME`, Java 21/25 requirement, LTS vs weekly, the 2+2+2 Java policy | D04 |
| 13 | ★ | ✅ | [Installation options](notes/13-installation-options.md) | Docker, VM/bare metal, Kubernetes (Helm), cloud marketplace, CloudBees CI, and a quick chooser | D03 |
| 14 | ★ | ✅➕ | [Lab: Jenkins in Docker](notes/14-lab-jenkins-in-docker.md) | Every `docker run` flag, named volume, a pinned image, Compose version, unlock and setup wizard; recap of the Docker ideas used | D03 |
| 15 | ★ | 🔀🆕 | [A tour of the UI and who uses Jenkins](notes/15-ui-tour-and-roles.md) | Dashboard, New Item types, Manage Jenkins, build page, Console Output, Pipeline Graph View (Blue Ocean deprecated), folders and views; admins vs users | D03 |
| 16 | ★★ | ✅➕ | [Inside `JENKINS_HOME`](notes/16-inside-jenkins-home.md) | Every file and folder, "why hudson", secrets and keys, `jobs/<name>/builds/<n>`, what lives on the controller vs agents | D03, D04 |

## Part 3 · Freestyle jobs (the classic way: learn the basics with it)

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 17 | ★ | ✅ | [Your first Freestyle job](notes/17-first-freestyle-job.md) | Execute shell, where commands run, built-in env vars, `env-vars.html`, `printenv`, why print build details | D03 |
| 18 | ★ | ✅➕ | [Workspaces, artifacts and fingerprints](notes/18-workspaces-artifacts-fingerprints.md) | Workspace lifecycle, archiving artifacts, fingerprints, build discarders, Jenkins artifacts vs artifact repositories | D03, D06 |
| 19 | ★★ | ✅➕ | [Git checkout and tools](notes/19-git-checkout-and-tools.md) | Git SCM, "command not found", tools live on nodes, Manage Jenkins → Tools vs OS install, a Maven primer | D03 |
| 20 | ★ | 🔀 | [Build parameters](notes/20-build-parameters.md) | Boolean, choice and string parameters; branch/tag as input; audit, hotfix and rollback uses | D03, D04 |
| 21 | ★★ | 🔀➕ | [Build triggers](notes/21-build-triggers.md) | Poll SCM, cron syntax and `H`, Build periodically, GitHub webhooks, the Jenkins URL, reaching a laptop Jenkins from GitHub, upstream/downstream | D04, P01 |
| 22 | ★ | ✅➕ | [Scheduled jobs and disk hygiene](notes/22-scheduled-jobs-and-disk-hygiene.md) | Nightly job, Workspace Cleanup plugin, `rm -rf` pitfalls, discarding old builds | D04, D05 |

## Part 4 · Credentials

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 23 | ★★ | 🔀➕ | [Credentials: the model](notes/23-credentials-model.md) | Kinds, scopes (System / Global / folder), IDs, how they're encrypted, GitHub PATs (classic vs fine-grained) and GitHub Apps | D05, D07, SL, P01 |
| 24 | ★★ | 🔀➕ | [Using credentials safely](notes/24-using-credentials-safely.md) | Freestyle bindings, `withCredentials`, `credentials()` in `environment`, masking and its limits, the Groovy-interpolation leak, external secret managers | D05, D06, P01 |

## Part 5 · Jenkins + Docker

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 25 | ★★ | 🆕 | [Docker and Linux recap for Jenkins](notes/25-docker-recap-for-jenkins.md) | CLI → socket → daemon, Unix domain sockets, file modes and groups, "`docker` group = root" (links to your Docker/Linux notes) | D05 |
| 26 | ★★ | ➕ | [Ways to build images in Jenkins](notes/26-ways-to-build-images.md) | DooD vs DinD vs Docker-enabled agents vs daemonless (BuildKit rootless, Buildah; Kaniko's archive and forks), with security trade-offs | D05 |
| 27 | ★★ | ✅ | [Lab: Docker-outside-of-Docker setup](notes/27-lab-dood-setup.md) | Socket mount, safe group-based permissions, installing **only** the Docker CLI, verification | D05 |
| 28 | ★★ | ✅ | [Project 1: Build, push and run a Flask app (Freestyle)](notes/28-project-1-freestyle-flask.md) | Private repo, PAT, Docker Hub credentials, the Freestyle job, end-to-end run and smoke test | D05 |

## Part 6 · Pipeline as code (the main way)

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 29 | ★ | ✅ | [Why pipelines](notes/29-why-pipelines.md) | Pipeline vs chained Freestyle (top 5), when Freestyle is still used | D06 |
| 30 | ★ | 🆕 | [Just enough Groovy](notes/30-just-enough-groovy.md) | Quotes and interpolation (Groovy `$` vs shell `$`), variables, lists/maps, closures, calls without parentheses | D06 |
| 31 | ★ | 🔀 | [Declarative pipeline anatomy](notes/31-declarative-pipeline-anatomy.md) | `pipeline` / `agent` / `stages` / `stage` / `steps`; inline vs from SCM; Jenkinsfile in the app repo; sandbox; skeleton lab | D06 |
| 32 | ★★★ | 🆕 | [What happens when a pipeline runs](notes/32-what-happens-when-a-pipeline-runs.md) | CPS engine, flyweight vs heavyweight executors, `checkout scm`, `@tmp`/`@script`, durability, Replay, Restart from Stage | — |
| 33 | ★ | ✅➕ | [Snippet Generator and step reference](notes/33-snippet-generator-and-steps.md) | Pipeline Syntax page, Directive Generator, Global Variables, linting a Jenkinsfile | D06 |
| 34 | ★★ | 🔀 | [Environment variables in pipelines](notes/34-environment-in-pipelines.md) | The `environment` block, `env.*`, `BUILD_NUMBER`, when `GIT_COMMIT` exists, per-stage env | D06, P01 |
| 35 | ★★ | 🔀 | [`post` conditions](notes/35-post-conditions.md) | success / failure / always + unstable / changed / fixed / regression / aborted / cleanup; why `post` sits outside `stages`; real-world uses by outcome | D06, P01 |
| 36 | ★★ | ✅ | [Project 2: The Flask flow as a Jenkinsfile](notes/36-project-2-flask-pipeline.md) | Day 5 rebuilt as code: build, push, deploy, test, deploy-info artifact + fingerprint, cleanup | D06 |
| 37 | ★★ | 🆕 | [`options`, `parameters` and `triggers`](notes/37-options-parameters-triggers.md) | `timeout`, `retry`, `timestamps`, `buildDiscarder`, `disableConcurrentBuilds`, `skipDefaultCheckout`; parameters and cron in code | D06 |
| 38 | ★★ | 🆕 | [`when`, approvals and locks](notes/38-when-input-milestone-lock.md) | `when` (branch, tag, changeset, expression, `beforeAgent`), `input` approvals, `milestone`, `lock` | D06, D07 |
| 39 | ★★ | 🆕 | [Parallel stages and matrix](notes/39-parallel-and-matrix.md) | `parallel`, `failFast`, `matrix` | D06 |
| 40 | ★★ | 🆕 | [Per-stage agents, Docker agents, stash](notes/40-per-stage-and-docker-agents.md) | `agent none`, `agent { docker }` / `dockerfile`, `reuseNode`, `stash` / `unstash` | — |
| 41 | ★★ | 🆕 | [Build results, tests and reports](notes/41-results-tests-reports.md) | SUCCESS / UNSTABLE / FAILURE / ABORTED / NOT_BUILT, `junit`, `catchError`, `error`, `currentBuild`, coverage | — |
| 42 | ★★★ | 🆕 | [Scripted pipelines](notes/42-scripted-pipelines.md) | `node`/`stage`, `script {}` inside declarative, try/catch/finally, `@NonCPS`, NotSerializableException, when scripted is still used | D06 |

## Part 7 · Branches and pull requests

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 43 | ★★ | ✅ | [Multibranch pipelines](notes/43-multibranch-pipelines.md) | What/why, scans and webhooks, traits, orphaned-item cleanup, branch-source plugins, organisation folders | D07 |
| 44 | ★★ | ✅ | [Multibranch build strategies](notes/44-multibranch-build-strategies.md) | Branch strategies, PR Head / Merge / Both, fork PRs and trust policies, cheat sheet | D07 |
| 45 | ★★ | ✅ | [Trunk-based CI/CD with multibranch](notes/45-trunk-based-flow-with-mbp.md) | The 6-step flow: branch job, PR job, gating the merge, merge to `main`, cleanup | D07 |
| 46 | ★★ | 🔀➕ | [GitHub integration](notes/46-github-integration.md) | GitHub App vs PAT, commit statuses / Checks, webhook secrets, branch protection and rulesets, auto-delete branches | D04, D07, P01 |
| 47 | ★★ | ✅➕ | [Project 3: Multibranch lab](notes/47-project-3-multibranch-lab.md) | The full Day 7 demo, plus the fix: deploy only from `main` | D07 |

## Part 8 · Agents and scaling

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 48 | ★★ | 🆕 | [Linux recap: users, SSH, services](notes/48-linux-recap-users-ssh-services.md) | Service users, home dirs, permissions, `sudo`/`su`, SSH keys, `authorized_keys`, `known_hosts`, systemd and journalctl | P01, SL |
| 49 | ★★ | 🔀 | [Lab: Install Jenkins on a Linux VM](notes/49-lab-install-jenkins-on-a-vm.md) | Java 21, the 2026 repo key, apt (and dnf), systemd override (`JAVA_OPTS`), unlock, security groups; EC2 version | D03, SL, P01 |
| 50 | ★★ | 🆕 | [Agents explained](notes/50-agents-explained.md) | Permanent vs cloud agents, outbound SSH vs inbound (TCP/WebSocket), executors, labels, usage modes, 0 executors on the controller | D03, D04 |
| 51 | ★★ | ✅➕ | [Lab: SSH agent](notes/51-lab-ssh-agent.md) | Local version with a Docker container agent, plus the EC2 version: `jenkins` user, keys, permissions, host-key strategies, node config | P01 |
| 52 | ★★ | 🆕 | [Lab: Inbound agent](notes/52-lab-inbound-agent.md) | `jenkins/inbound-agent`, the agent secret, WebSocket mode | — |
| 53 | ★★★ | 🆕 | [Kubernetes and cloud agents](notes/53-kubernetes-and-cloud-agents.md) | Kubernetes plugin, pod templates, the `jnlp` container, `agent { kubernetes }`, lab on kind; Docker and EC2 clouds | D03 |
| 54 | ★★★ | ✅➕ | [Jenkins on Kubernetes with Helm](notes/54-jenkins-on-kubernetes-helm.md) | Chart install, persistence, ingress, admin secret (fixed key), JCasC through the chart | D03 |

## Part 9 · Reuse at scale: shared libraries

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 55 | ★★ | ✅ | [Shared libraries: why and how](notes/55-shared-libraries-concepts.md) | The duplication problem, `@Library`, `vars/` `src/` `resources/`, every Global Pipeline Libraries option | SL |
| 56 | ★★ | ✅ | [Lab: Your first shared library](notes/56-lab-shared-library-simple.md) | `simpleEcho` end to end | SL |
| 57 | ★★ | ✅ | [Lab: Private repos + shared library](notes/57-lab-shared-library-private.md) | app1/app2 + private library, then the "one change updates both apps" demo (corrected) | SL |
| 58 | ★★★ | ➕ | [Shared libraries in production](notes/58-shared-libraries-production.md) | Map parameters and defaults, centralised config, `src/` classes, `libraryResource`, version tags, trusted vs untrusted, folder libraries, testing | SL |

## Part 10 · Production DevSecOps project (AWS EKS)

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 59 | ★★ | 🔀➕ | [Tool primers: Maven, SonarQube, Trivy](notes/59-tool-primers-maven-sonar-trivy.md) | Maven lifecycle, Surefire/JUnit/JaCoCo, Sonar projects/tokens/quality gates, Trivy `fs` vs `image`, SAST vs SCA | P01 |
| 60 | ★★ | ✅ | [Lab: Install SonarQube](notes/60-lab-install-sonarqube.md) | PostgreSQL, kernel limits, `sonar` user, systemd unit, troubleshooting, production notes, Docker alternative | P01 |
| 61 | ★★ | 🆕 | [AWS and Kubernetes primer for Jenkins](notes/61-aws-and-k8s-primer.md) | IAM roles vs keys, instance profiles, ECR, EKS, eksctl; Deployment/Service/namespace/RBAC recap (links to your K8s notes) | P01 |
| 62 | ★★★ | ✅ | [Project 4, part 1: Scan, build, push](notes/62-project-4-part-1-scan-build-push.md) | Stages 1–7: checkout, Trivy FS, Maven + Sonar gate, ECR login, image build, Trivy image, push | P01 |
| 63 | ★★★ | ✅➕ | [Project 4, part 2: Deploy to EKS](notes/63-project-4-part-2-deploy-to-eks.md) | Stages 8–9: manifests, topology spread, `sed`, cluster, kubectl, IAM, **access entries** (and legacy aws-auth), RBAC, the deploy script line by line, `post`, push triggers | P01 |
| 64 | ★★ | ✅➕ | [Improving the pipeline](notes/64-improving-the-pipeline.md) | Your 12 production upgrades, each expanded: Ingress/Gateway, MBP, GitOps, DNS, digests, signing, secrets, observability, policy-as-code, Helm/Kustomize, progressive delivery, cleanup | P01 |

## Part 11 · Running Jenkins in production

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 65 | ★★★ | 🆕 | [Securing Jenkins](notes/65-securing-jenkins.md) | Security realms (local/LDAP/SSO/OIDC), authorization (matrix, role-based, project), CSRF crumbs, API tokens, script approval, agent → controller security, advisories, TLS + reverse proxy | D03 |
| 66 | ★★ | 🆕 | [Managing plugins](notes/66-managing-plugins.md) | Update center, `plugins.txt`, plugin installation manager, pinning, dependency conflicts, safe upgrades, pruning | D03 |
| 67 | ★★★ | 🆕 | [Configuration as Code](notes/67-configuration-as-code.md) | JCasC YAML, a custom image (plugins + casc), Job DSL seed jobs, "everything as code" | D03 |
| 68 | ★★ | 🔀➕ | [Backup, restore and upgrades](notes/68-backup-restore-upgrades.md) | What to back up, how, restore drills, the `secret.key` trap, the LTS upgrade procedure, Java upgrades | D03, D04 |
| 69 | ★★★ | 🆕 | [Monitoring, performance and HA](notes/69-monitoring-performance-ha.md) | Prometheus metrics, JVM heap/GC, queue and executor health, logs, disk, HA/DR realities in open-source Jenkins | — |
| 70 | ★★ | 🆕 | [Jenkins CLI and REST API](notes/70-cli-and-rest-api.md) | API tokens, triggering builds with curl (with parameters), crumbs, `jenkins-cli.jar`, the Script Console (handle with care) | — |
| 71 | ★ | 🆕 | [Notifications](notes/71-notifications.md) | Email Extension, Slack, Git status, wired through `post` | P01 |
| 72 | ★★★ | 🆕 | [Jenkins + GitOps with Argo CD](notes/72-jenkins-and-gitops.md) | Jenkins does CI, Argo CD does CD: updating the environment repo, promoting by digest | D02, P01 |

## Part 12 · Troubleshooting and interviews

| # | Lvl | Status | Topic | What you'll learn | From |
|---|---|---|---|---|---|
| 73 | ★★ | 🆕 | [Troubleshooting method and catalog](notes/73-troubleshooting.md) | Where to look (console, system log, agent log, Replay); agent offline, permission denied, credentials not found, No such DSL method, script approval, NotSerializableException, disk full, plugin conflicts, webhook not firing, docker.sock, kubectl Forbidden, Sonar gate timeouts | all |
| 74 | ★★★ | 🆕 | [Production scenarios](notes/74-production-scenarios.md) | Realistic incidents, walked through step by step | — |
| 75 | ★★ | 🆕 | [Interview question bank](notes/75-interview-question-bank.md) | Questions grouped by topic, with short model answers and follow-ups | — |
| 76 | ★ | 🆕 | [Jenkins vs other CI tools, and what next](notes/76-jenkins-vs-others-and-next-steps.md) | GitHub Actions, GitLab CI, Tekton, Argo CD; when Jenkins wins; what to learn next | D02 |
| 77 | ★ | 🆕 | [Cheat sheet](notes/77-cheat-sheet.md) | Jenkinsfile skeletons, directives, env vars, cron, CLI/API, paths, debug commands | — |

---

**Corrections:** wherever your original notes were wrong or outdated, the topic shows a **⚠️ Corrected: was X, now Y because Z** box. [ANALYSIS.md](ANALYSIS.md) lists all of them in one place.

**Sample outputs** show the *shape* of real output; versions, IDs, hashes and IPs are illustrative, and plugin version strings in example `plugins.txt`/values files show the format only. The commands were not run while writing these notes, so your terminal is the source of truth: run every lab, and when the output differs, trust the output.

**Also in this folder:**
- `images/`: all 30 original images, unchanged (`2h.png`, unused in the originals, now appears in topic 10), plus 8 new diagrams (`d-*.svg`): the life of a build (11), where pipeline code runs (32), image-build options (26), the credentials flow (23, 24), agent connections (50), Kubernetes agent pods (53), security layers (65), and GitOps with Argo CD (72).

**Verification status (November 2026):** facts that change often (Java/LTS, the repo key, Blue Ocean, EKS access entries and versions, CodeCommit, Kaniko) were checked online. The plugin-manager flags, Kubernetes-plugin RBAC/WebSocket/`jnlp` behaviour, BuildKit rootless requirements, GitHub App rate limits, and the JCasC credentials/role-strategy/OIDC syntax were checked against official docs and fixed where needed. The Helm chart keys (topic 54) and the JCasC `globalMatrix`, `globalLibraries`, `tool`, reload and merge-strategy settings (topic 67) were checked against the chart's `values.yaml`/`VALUES.md` and the official JCasC demos. **Still not verified:** the JCasC `nodes` block (topic 67 says to export it), three Helm `persistence` defaults (seen only in doc summaries), and every lab. **Labs were not executed**, so sample outputs show the expected shape, not captured output.
- [`project-files/`](project-files/): every original app, Jenkinsfile, manifest and library file, organised by project, **unchanged**. Corrected versions sit next to them as `*.corrected` files with `⚠️ Corrected` comments: `project-2-flask-pipeline/Jenkinsfile.corrected`, `project-3-multibranch/Jenkinsfile.corrected`, `project-4-devsecops-eks/project_files/Jenkinsfile.corrected` and `eks-config.corrected.yaml`, plus a new `access-entry-commands.sh`.
- [ANALYSIS.md](ANALYSIS.md): the analysis of the original notes (topics, gaps, dependency problems, every error found).
- [COVERAGE.md](COVERAGE.md): proof that nothing was lost. Every original file, section, image and code file → its new home.
- The untouched original folder is backed up at `Desktop/Jenkins-original-backup`.

**Source course:** *Jenkins: Basics to Production* by CloudWithVarJosh ([course intro](https://www.youtube.com/watch?v=bBx6UfQP1Lo&ab_channel=CloudWithVarJosh) · [playlist](https://www.youtube.com/playlist?list=PLmPit9IIdzwSiYCKOtXUGNwytXXiJ8Rv8) · [repo](https://github.com/CloudWithVarJosh/Jenkins-Basics-To-Production) · author links: [LinkedIn](https://www.linkedin.com/in/varun-joshi-2b516752/), [YouTube](https://www.youtube.com/@CloudWithVarJosh), [GitHub](https://github.com/CloudWithVarJosh)). The video links from each original Day are kept in the matching topic ("🎥 Original video").
