# Coverage: Where Every Original Note Went

This file is the **proof that nothing was lost** when `Jenkins-Basics-To-Production/` (10 READMEs, 30 images, 38 code/config files) was reorganised into the 77 topics in [INDEX.md](INDEX.md). The untouched original is backed up at `Desktop/Jenkins-original-backup` (verified identical with `diff -rq` before any work started).

## How to read this

- One section per original file. Each table maps **every heading** of that README (`#`–`####`, including the ones inside lists; headings inside code blocks are ignored) to the topic(s) that now contain its content: rewritten in simpler language, expanded, and corrected where needed. **Bold topic** = main home; others = also used there.
- **Corrections** are listed in the last column, with a ⚠️ box in the topic itself ("⚠️ Corrected: was X, now Y because Z"). All 33 are also listed in [ANALYSIS.md](ANALYSIS.md#5-errors-and-outdated-information-each-becomes-a--corrected-note).
- **Not carried over as content (navigation only):** each README's "⭐ Support the Project" star request, "🌟 Star this Repository!", and "Table of Contents" blocks. The topic files have their own structure and [INDEX.md](INDEX.md) is the table of contents. They remain in the backup. Nothing else was dropped.
- **Video links:** every "Video reference" link is kept at the top of its main topic as "🎥 Original video".
- **References:** every original "References" list is kept, verbatim, at the end of its main topic.
- **Duplicates merged:** the Jenkins-on-EC2 install appears in both `shared-library` and `Project 01`; the `post` explanation and the PAT/credential steps appear several times. Each was merged into one topic, and the table shows both sources pointing there. Wording differences between the copies (e.g. one runs `systemctl start`, the other doesn't) are noted in the topic.

---

## Root `README.md`

| Original section | New home | Notes |
|---|---|---|
| # Jenkins: Basics to Production Course (title, badge, welcome) | [INDEX](INDEX.md) "Source course" | |
| ### Course Introduction (video) | [INDEX](INDEX.md), **[01](notes/01-what-is-ci-cd.md)** | |
| ### Course Playlist | [INDEX](INDEX.md), **[01](notes/01-what-is-ci-cd.md)** | |
| ## What You'll Find in This Repository | [INDEX](INDEX.md) (structure, Jenkinsfiles in `project-files/`) | The "organised by Days" structure is replaced by the 77-topic reading order |
| ## Why Follow This Course? (hands-on, beginner-friendly, production-oriented) | The design of every topic (Hands-on lab, simple language, "Where you'll use it") | |
| ## 🌟 Star this Repository! | not carried (navigation/promotion) | in backup |
| ## How to Use This Repository (`git clone`, `cd …/Day1`) | [INDEX](INDEX.md) repo link | ⚠️ `cd …/Day1`: the folder is `Day 01` ([ANALYSIS #32](ANALYSIS.md)) |
| ## Stay Connected (LinkedIn, YouTube, GitHub) | [INDEX](INDEX.md) "Source course" (author links) | |

## `Day 01/README.md`: Modern SDLC & build automation

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[02](notes/02-sdlc-and-delivery-models.md)** | |
| ⭐ Support / Table of Contents | not carried (navigation) | |
| ## Introduction | **[01](notes/01-what-is-ci-cd.md)** | |
| ## The Software Development Life Cycle (SDLC) | **[02](notes/02-sdlc-and-delivery-models.md)** | |
| ### Phases of SDLC (all 8 phases with examples and production notes; Backbone: Source Control; Continuous by Design) | **[02](notes/02-sdlc-and-delivery-models.md)**; testing/security lists also in [06](notes/06-continuous-practices.md) | ⚠️ SAST/SCA/image-scan/runtime classification (02) |
| ### Waterfall vs Agile/DevOps | **[02](notes/02-sdlc-and-delivery-models.md)** | |
| ### Waterfall vs Agile/DevOps – Key Differences (table) | **[02](notes/02-sdlc-and-delivery-models.md)** | |
| ### Role of Git in Modern SDLC | **[02](notes/02-sdlc-and-delivery-models.md)**, [05](notes/05-git-essentials-for-ci-cd.md) | |
| ### From SDLC to Build Automation | **[03](notes/03-how-code-becomes-software.md)** | |
| ### Compiled vs. Interpreted Languages (+ image 1b) | **[03](notes/03-how-code-becomes-software.md)** | |
| #### Compiled Languages | **[03](notes/03-how-code-becomes-software.md)** | ⚠️ Java bytecode doesn't run directly on the CPU (JIT) |
| #### Java Artifact Formats (table) | **[03](notes/03-how-code-becomes-software.md)** | ⚠️ Java EE → Jakarta EE |
| #### Interpreted Languages (+ JIT note) | **[03](notes/03-how-code-becomes-software.md)** | ⚠️ CPython bytecode nuance |
| ### Build Processes in the Real World (key terms, end-user installations note, image 1c) | **[03](notes/03-how-code-becomes-software.md)** | |
| ### Compiled Languages – Two-Step Build | **[04](notes/04-build-processes.md)** | |
| #### Containerized Workloads: Compiled Languages (+ table, Dockerfile, image 1d) | **[04](notes/04-build-processes.md)** (table also in [03](notes/03-how-code-becomes-software.md)) | ⚠️ `openjdk` images deprecated; `COPY app.jar` missing a destination |
| #### Non-Containerized Workloads: Compiled Languages (image 1e) | **[04](notes/04-build-processes.md)** | |
| #### Key Takeaway | **[04](notes/04-build-processes.md)** | |
| ### Interpreted Languages – One-Step Build | **[04](notes/04-build-processes.md)** | |
| #### Non-Containerized Workloads (venv/nvm/rbenv, image 1g) | **[04](notes/04-build-processes.md)** | |
| #### Containerized Workloads (Dockerfile, image 1f) | **[04](notes/04-build-processes.md)** | |
| #### Key Takeaways | **[04](notes/04-build-processes.md)** | |
| ### Why Build Automation Matters | **[01](notes/01-what-is-ci-cd.md)** | |
| ## Conclusion | [01](notes/01-what-is-ci-cd.md), [04](notes/04-build-processes.md) | |
| ## References | **[02](notes/02-sdlc-and-delivery-models.md)** (end) | |

## `Day 02/README.md`: CI/CD & branching strategies

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ⭐ Support / Table of Contents | not carried | |
| ## Introduction (learning outcomes) | [05](notes/05-git-essentials-for-ci-cd.md), [09](notes/09-promotion-flows.md) | |
| ## Git & Branching: The Essentials for CI/CD (image 2a) | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ### What is Git? | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ### Where to host your Git repo (remotes) | **[05](notes/05-git-essentials-for-ci-cd.md)** | ⚠️ CodeCommit back in GA (Nov 2025); GCP CSR closed |
| ### What are branches? | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ### What is a PR/MR? | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ### Protected branches & status checks | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ### How Git fits CI/CD (quick mental model) | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ### Quick glossary | **[05](notes/05-git-essentials-for-ci-cd.md)** | |
| ## Continuous Practices in DevOps | **[06](notes/06-continuous-practices.md)** | |
| ### What is CI/CD? (+ release-metadata note) | **[06](notes/06-continuous-practices.md)**, [01](notes/01-what-is-ci-cd.md), [07](notes/07-artifacts-tags-and-digests.md) | |
| ### The core "continuous" practices (image 2b) | **[06](notes/06-continuous-practices.md)** | |
| #### 1. CI · 2. CT (+ pipeline definition) · 3. CD · 4. CDp · 5. CM; both mental-model notes | **[06](notes/06-continuous-practices.md)** | |
| ## Continuous Integration (CI) (+ PR/MR note) | **[06](notes/06-continuous-practices.md)** | |
| ### Where CI fits in your branching strategy (image 2c; GitFlow, Trunk-based, mental model, also seen in the wild, likely in practice) | **[08](notes/08-branching-strategies.md)** | The stray chat phrase "Great point—here's a cleaned-up mental model that reflects that:" was dropped; the mental model itself is kept |
| ## GitFlow-Based CI/CD: Environment Branches (image 2d, protected-branch note) | **[09](notes/09-promotion-flows.md)** | |
| ### Step-by-step (1–6) + both key-idea notes | **[09](notes/09-promotion-flows.md)** | |
| ## Promotion PR: dev → stage (Deploy-Before-Merge Flow) | **[09](notes/09-promotion-flows.md)** | |
| ### What happened earlier on dev (build once, digest, manifest, deploy by digest, example manifest.json, why multiple tags, TL;DR) | **[07](notes/07-artifacts-tags-and-digests.md)**, summarised in [09](notes/09-promotion-flows.md) | |
| ### Stage PR gates (repo rules) | **[09](notes/09-promotion-flows.md)** | |
| ### 1 Open PR: dev → stage (image 2e, PR template) | **[09](notes/09-promotion-flows.md)** | |
| ### 2 Stage Promotion Pipeline (2.1 preflight, 2.2 deploy, 2.3 post-deploy) | **[09](notes/09-promotion-flows.md)** | |
| ### 3 Stage environment | **[09](notes/09-promotion-flows.md)** | |
| ### 4 PR status & merge decision | **[09](notes/09-promotion-flows.md)** | |
| ### Why the strategies differ: speed vs safety (1, 2, Analogy) | **[09](notes/09-promotion-flows.md)** | |
| ## Promotion PR: stage → prod (image 2f) | **[09](notes/09-promotion-flows.md)** | |
| ## Trunk-Based CI/CD: Environment Promotions (overview) | **[09](notes/09-promotion-flows.md)** | |
| ### Diagram at a glance (image 2g) | **[09](notes/09-promotion-flows.md)** | |
| ### Guardrails on main | **[09](notes/09-promotion-flows.md)** | |
| ### End-to-end flow, #### 1)–9) | **[09](notes/09-promotion-flows.md)** | |
| ## Jenkins in this picture (what, why, how it usually runs, what it isn't, alternatives) | **[10](notes/10-what-is-jenkins.md)**; alternatives also [76](notes/76-jenkins-vs-others-and-next-steps.md) | ⚠️ plugin count ~2,000 |
| ## Conclusion (key takeaways) | [09](notes/09-promotion-flows.md) recap | |
| ## References | **[09](notes/09-promotion-flows.md)** (end) | |

## `Day 03/README.md`: What is Jenkins, install options, Docker lab, Freestyle

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[10](notes/10-what-is-jenkins.md)** | |
| ⭐ Support / Table of Contents | not carried | |
| ## Introduction | [10](notes/10-what-is-jenkins.md), [13](notes/13-installation-options.md) | |
| ## What is Jenkins (all paragraphs: OSS server, orchestrator, Jenkinsfile, plugins + cloud examples, Git workflow + flow + note, runs anywhere, controller/agents, credentials & policies, CloudBees/CDF; image 3b) | **[10](notes/10-what-is-jenkins.md)**; controller/agents also [11](notes/11-jenkins-architecture.md), [50](notes/50-agents-explained.md) | ⚠️ "JNLP" → inbound agents (50) |
| ## Jenkins Installation Options (image 3c) | **[13](notes/13-installation-options.md)** | |
| ### 1) Docker Container (+ scaling note) | **[13](notes/13-installation-options.md)** | |
| ### 2) VM / Bare Metal (example + notes) | **[13](notes/13-installation-options.md)**, [49](notes/49-lab-install-jenkins-on-a-vm.md) | ⚠️ 2026 repo key; ⚠️ Java 21 not 17 |
| ### 3) Kubernetes (example + notes + "not every org runs K8s") | **[13](notes/13-installation-options.md)**, **[54](notes/54-jenkins-on-kubernetes-helm.md)** | ⚠️ Helm admin password → `controller.admin.existingSecret` |
| ## 4) Cloud Marketplace Images | **[13](notes/13-installation-options.md)** | |
| ## 5) CloudBees Jenkins (Enterprise CI) | **[13](notes/13-installation-options.md)** | |
| ### Quick chooser | **[13](notes/13-installation-options.md)** | |
| ## Lab setup: Jenkins in Docker | **[14](notes/14-lab-jenkins-in-docker.md)** | |
| ### Run Jenkins (Docker) + flag breakdown + non-root note | **[14](notes/14-lab-jenkins-in-docker.md)** | ⚠️ pin `lts-jdk21` / exact version |
| ### First-time setup | **[14](notes/14-lab-jenkins-in-docker.md)** | |
| ### Handy commands | **[14](notes/14-lab-jenkins-in-docker.md)** | |
| ### Understanding /var/jenkins_home (tips + note) | **[14](notes/14-lab-jenkins-in-docker.md)**, [16](notes/16-inside-jenkins-home.md), [68](notes/68-backup-restore-upgrades.md) | |
| ## Who uses Jenkins: roles and responsibilities (image 3d) | **[15](notes/15-ui-tour-and-roles.md)** | |
| ## First steps with Jenkins jobs (start with Freestyle) | **[17](notes/17-first-freestyle-job.md)**, [15](notes/15-ui-tour-and-roles.md) (job types) | |
| ### Step 0 — Create the job | **[17](notes/17-first-freestyle-job.md)** | |
| ### Step 1 — Where do commands run? (built-in vars, env-vars.html, printenv, why print) | **[17](notes/17-first-freestyle-job.md)** | |
| ### Step 2 — Produce and archive an artifact | **[18](notes/18-workspaces-artifacts-fingerprints.md)** | |
| ### Step 3 — SCM checkout (Git) + tool requirements (fix options) | **[19](notes/19-git-checkout-and-tools.md)** | ⚠️ the official image already contains Git |
| ## Using Maven (two approaches) | **[19](notes/19-git-checkout-and-tools.md)** | |
| #### A) Manage Jenkins → Tools (+ pipeline snippet, pros, gotcha) | **[19](notes/19-git-checkout-and-tools.md)** | |
| #### B) OS-level install on the node | **[19](notes/19-git-checkout-and-tools.md)** | |
| ### Which to pick (+ tip) | **[19](notes/19-git-checkout-and-tools.md)** | |
| ### Key points to remember | **[19](notes/19-git-checkout-and-tools.md)** | |
| ## Conclusion | [19](notes/19-git-checkout-and-tools.md), [13](notes/13-installation-options.md) | |
| ## References | **[13](notes/13-installation-options.md)** (end) | |

## `Day 04/README.md`: JENKINS_HOME, parameters, triggers, cron

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[16](notes/16-inside-jenkins-home.md)** | |
| ⭐ Support / table of contents list | not carried | |
| # Introduction | [16](notes/16-inside-jenkins-home.md), [20](notes/20-build-parameters.md) | |
| # Inside $JENKINS_HOME | **[16](notes/16-inside-jenkins-home.md)** | |
| ## Top-Level Configuration (Files) (+ Why you still see "hudson") | **[16](notes/16-inside-jenkins-home.md)**; hudson history also [10](notes/10-what-is-jenkins.md) | |
| ## Security & Identity | **[16](notes/16-inside-jenkins-home.md)** | ⚠️ `secrets/master.key` + `hudson.util.Secret` decrypt credentials, not `secret.key` |
| ## Core Directories (+ Jenkins is a Java web app (WAR)) | **[16](notes/16-inside-jenkins-home.md)**, **[12](notes/12-jenkins-is-a-java-web-app.md)** | |
| ## Workspaces & Queues (+ Where jobs live vs where they run, image 4a) | **[16](notes/16-inside-jenkins-home.md)**, [11](notes/11-jenkins-architecture.md) | |
| ## Backup Quick-Check | **[16](notes/16-inside-jenkins-home.md)**, **[68](notes/68-backup-restore-upgrades.md)** | |
| # Mini Demos — your pipeline foundation | **[20](notes/20-build-parameters.md)** | |
| ## Mini Demo 1 — Parameters (setup, step, post-build, production notes) | **[20](notes/20-build-parameters.md)** | |
| ## Mini Demo 2 — Git SCM + Branch as a Parameter | **[20](notes/20-build-parameters.md)** | |
| ## Mini Demo 3 — Poll SCM Trigger (+ H explanation, production notes) | **[21](notes/21-build-triggers.md)** | |
| ## Mini Demo 4 — Webhook Trigger (+ Jenkins URL note) | **[21](notes/21-build-triggers.md)**, [46](notes/46-github-integration.md) | |
| ## Mini Demo 5 — Scheduled Nightly (Cron) + Workspace Cleanup | **[22](notes/22-scheduled-jobs-and-disk-hygiene.md)** | ⚠️ `rm -rf $WORKSPACE/*` misses dotfiles; archive before cleaning |
| # Conclusion | **[22](notes/22-scheduled-jobs-and-disk-hygiene.md)** (end, kept verbatim) | |
| # References | **[16](notes/16-inside-jenkins-home.md)** (end) | |

## `Day 05/README.md`: Project 1, Flask with DooD (Freestyle)

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[27](notes/27-lab-dood-setup.md)** | |
| ⭐ Support / Table of Contents (incl. the stray "Here's the updated clickable Table of Contents…" line) | not carried | |
| ## Introduction | **[27](notes/27-lab-dood-setup.md)**, [28](notes/28-project-1-freestyle-flask.md) | |
| ## Why we're doing this | **[25](notes/25-docker-recap-for-jenkins.md)** | |
| ### What approach we'll use (DooD) (image 5a, reading the diagram, DooD in one minute, production note) | **[26](notes/26-ways-to-build-images.md)** | ⚠️ Kaniko upstream archived (June 2025) |
| ## Step 1: Recreate Jenkins with the socket mounted (what this does, what is docker.sock, note) | **[27](notes/27-lab-dood-setup.md)**; socket theory in **[25](notes/25-docker-recap-for-jenkins.md)** | |
| ## Step 2: Allow the Jenkins user to talk to the socket | **[27](notes/27-lab-dood-setup.md)** | ⚠️ `chmod 666` → `--group-add <GID>` |
| ## Step 3: Install the Docker CLI inside the Jenkins container | **[27](notes/27-lab-dood-setup.md)** | ⚠️ `get.docker.com` installs the whole engine → `docker-ce-cli` in a Dockerfile |
| ## Step 4: Verify from inside Jenkins | **[27](notes/27-lab-dood-setup.md)** | |
| ### Quick FAQ | **[27](notes/27-lab-dood-setup.md)**, [26](notes/26-ways-to-build-images.md) | |
| # Demo — Build, Push & Deploy a Flask App (DooD) / ### What we'll do (image 5b) | **[28](notes/28-project-1-freestyle-flask.md)** | |
| ## 0) Create a private GitHub repo (app.py, requirements.txt, Dockerfile, .dockerignore) | **[28](notes/28-project-1-freestyle-flask.md)** | |
| ## 1) Create a GitHub PAT | **[28](notes/28-project-1-freestyle-flask.md)**, **[23](notes/23-credentials-model.md)** | |
| ## 2) Add credentials in Jenkins (A GitHub PAT, B Docker Hub, the "don't paste secrets" tip) | **[23](notes/23-credentials-model.md)**, [24](notes/24-using-credentials-safely.md), [28](notes/28-project-1-freestyle-flask.md) | |
| ## 3) Create the Freestyle job: A SCM, B secret bindings, C parameters, D Execute shell, E cleanup | **[28](notes/28-project-1-freestyle-flask.md)**; B also [24](notes/24-using-credentials-safely.md); E also [22](notes/22-scheduled-jobs-and-disk-hygiene.md) | ⚠️ String-parameter default `${BUILD_NUMBER}` isn't expanded |
| ## 4) Run it end-to-end | **[28](notes/28-project-1-freestyle-flask.md)** | improved smoke test added |
| ## Conclusion | **[28](notes/28-project-1-freestyle-flask.md)** (end, kept) | |
| ## References | **[28](notes/28-project-1-freestyle-flask.md)** (end) | |

## `Day 06/README.md`: from Freestyle to Pipeline

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[29](notes/29-why-pipelines.md)** | |
| ⭐ Support / Table of Contents | not carried | |
| ## Introduction | **[29](notes/29-why-pipelines.md)** | |
| ## Prerequisites | **[29](notes/29-why-pipelines.md)** | |
| ## Why Pipelines? (the big wins) | **[29](notes/29-why-pipelines.md)** | |
| ### Pipeline Job vs Chained Freestyle / Pipeline vs Freestyle — Top 5 | **[29](notes/29-why-pipelines.md)** | |
| ### Bottom line | **[29](notes/29-why-pipelines.md)** | |
| ## Two ways to use a Pipeline | **[31](notes/31-declarative-pipeline-anatomy.md)** | ⚠️ all pipelines are sandboxed (not just inline scripted) |
| ## Groovy: how much do you need? (+ two pipeline styles) | **[30](notes/30-just-enough-groovy.md)**, [31](notes/31-declarative-pipeline-anatomy.md), [42](notes/42-scripted-pipelines.md) | |
| ## Declarative Pipeline — the core building blocks (Minimal shape, What each block means, Useful companions) | **[31](notes/31-declarative-pipeline-anatomy.md)**; companions expanded in [34](notes/34-environment-in-pipelines.md), [35](notes/35-post-conditions.md), [37](notes/37-options-parameters-triggers.md), [38](notes/38-when-input-milestone-lock.md), [19](notes/19-git-checkout-and-tools.md) | |
| ## Create a Skeleton Jenkinsfile (1–3, Why this?, Next) | **[31](notes/31-declarative-pipeline-anatomy.md)** | |
| # Build a Production-grade Jenkinsfile (replicates Day-5) | **[36](notes/36-project-2-flask-pipeline.md)** | |
| ## Step 1: Add credentials via the Snippet Generator (A git, B Docker login, changelog note, "Why these two?") | **[33](notes/33-snippet-generator-and-steps.md)**, [24](notes/24-using-credentials-safely.md) | ⚠️ `/job/pipeline-1/` doesn't match the job name |
| ## Step 2: Define reusable environment variables | **[34](notes/34-environment-in-pipelines.md)** | |
| ## Step 3: Full Jenkinsfile | **[36](notes/36-project-2-flask-pipeline.md)** | |
| # Improving our Day-5 flow with a Jenkinsfile (intro list) | **[36](notes/36-project-2-flask-pipeline.md)** | |
| ## 1) Use Pipeline Script from SCM (+ "keep the Jenkinsfile in the same repo" note) | **[36](notes/36-project-2-flask-pipeline.md)**, **[31](notes/31-declarative-pipeline-anatomy.md)** | |
| ## 2) Post actions | **[35](notes/35-post-conditions.md)**, [36](notes/36-project-2-flask-pipeline.md) | |
| ## 3) Generate and archive deploy-info.txt | **[36](notes/36-project-2-flask-pipeline.md)**, [18](notes/18-workspaces-artifacts-fingerprints.md) | |
| ## 4) Clean the workspace | **[36](notes/36-project-2-flask-pipeline.md)**, [22](notes/22-scheduled-jobs-and-disk-hygiene.md) | ⚠️ cleanup stage → `post { cleanup }` |
| # Consolidated Jenkinsfile | **[36](notes/36-project-2-flask-pipeline.md)** | ⚠️ test stage `curl localhost` can never fail |
| ## Conclusion | **[36](notes/36-project-2-flask-pipeline.md)** (end, kept) | |
| ## References | **[36](notes/36-project-2-flask-pipeline.md)** (end) | |

## `Day 07/README.md`: Multibranch pipelines

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[43](notes/43-multibranch-pipelines.md)** | |
| ⭐ Support / Table of Contents | not carried | |
| ## Introduction | **[43](notes/43-multibranch-pipelines.md)** | |
| # Multi-Branch Pipelines (MBP) / ### What they are and why they matter (image 7a, all bullets + use cases, closing quote) | **[43](notes/43-multibranch-pipelines.md)** | |
| ## How Jenkins discovers and builds | **[43](notes/43-multibranch-pipelines.md)** | |
| ## Trunk-Based CI/CD: Multibranch Flow (image 7b), ### 1)–6) | **[45](notes/45-trunk-based-flow-with-mbp.md)** | squash/rebase SHA note added |
| # Demo: Jenkins MBP (image 7c) | **[47](notes/47-project-3-multibranch-lab.md)** | |
| ## Why MBP (vs a single Pipeline) | **[43](notes/43-multibranch-pipelines.md)** | |
| ## What we'll do | **[47](notes/47-project-3-multibranch-lab.md)** | |
| ## Prerequisites | **[47](notes/47-project-3-multibranch-lab.md)** | |
| ## Step 0: Create the MBP job / ### Branch Sources → GitHub (+ plugin note) | **[43](notes/43-multibranch-pipelines.md)**, [47](notes/47-project-3-multibranch-lab.md) | |
| ## Build strategies / ### Branch build strategy / ### PRs from origin / ### PRs from forks (+ trust policy, example trust flow) / ### Quick cheat-sheet (+ quick example) | **[44](notes/44-multibranch-build-strategies.md)** | |
| ### What you should see | **[43](notes/43-multibranch-pipelines.md)** | |
| ## Step 1: Create another branch locally and push | **[47](notes/47-project-3-multibranch-lab.md)** | ⚠️ token in clone URL → `gh auth`/credential helper |
| ## Step 2: Let MBP discover and build | **[47](notes/47-project-3-multibranch-lab.md)** | |
| ## Steps 3–6 (ports heads-up) / ### 3) Open PR (+ Protecting main note) / ### 4) Gate / ### 5) Merge / ### 6) Cleanup | **[47](notes/47-project-3-multibranch-lab.md)**; the protecting-main note in **[46](notes/46-github-integration.md)** | ⚠️ the Jenkinsfile deploys from every branch/PR → `when { branch 'main' }`; build-number tags collide |
| ### Verify the result (A–D) | **[47](notes/47-project-3-multibranch-lab.md)** | |
| ## Conclusion | **[47](notes/47-project-3-multibranch-lab.md)** (end, kept) | |
| ## References | **[47](notes/47-project-3-multibranch-lab.md)** (end) | |

## `shared-library/README.md`

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[55](notes/55-shared-libraries-concepts.md)**, [49](notes/49-lab-install-jenkins-on-a-vm.md) | |
| ⭐ Support / Table of Contents | not carried | |
| # Introduction | **[55](notes/55-shared-libraries-concepts.md)** | |
| # Why Jenkins Shared Library? (image sl1) | **[55](notes/55-shared-libraries-concepts.md)** | |
| ## Challenges / ### 1. Massive Duplication / ### 2. Inconsistent Pipelines / ### 3. High Maintenance Overhead / ### 4. Difficult Onboarding | **[55](notes/55-shared-libraries-concepts.md)** | |
| # Enter Jenkins Shared Library (image sl2) / ## Why This Is Powerful | **[55](notes/55-shared-libraries-concepts.md)** | |
| # Using a Shared Library / ### 1. Import / ### 2. Call | **[55](notes/55-shared-libraries-concepts.md)** | |
| # Shared Library Directory Structure (image sl3) / ## 1. vars/ / ## 2. src/ / ## 3. resources/ | **[55](notes/55-shared-libraries-concepts.md)** | |
| # Lab: Install Jenkins Controller on EC2 / ## Prerequisites / ## 1–6 / ### Set JVM timezone | **[49](notes/49-lab-install-jenkins-on-a-vm.md)** (merged with Project 01's copy) | ⚠️ 2026 repo key; keep `java.awt.headless` in the override |
| ## 7 - Run pipeline workloads on the controller (lab mode) | **[49](notes/49-lab-install-jenkins-on-a-vm.md)** | |
| ## 8 - Install Docker Engine on the controller | **[49](notes/49-lab-install-jenkins-on-a-vm.md)** | |
| ## 9 - Allow Jenkins user to run Docker | **[49](notes/49-lab-install-jenkins-on-a-vm.md)**, [25](notes/25-docker-recap-for-jenkins.md) | |
| ## Lab notes and security reminders | **[49](notes/49-lab-install-jenkins-on-a-vm.md)** | |
| # Demo 1 / ## Step 1 (layout, .groovy note, simpleEcho, explanations) / ## Step 2 (all options) / ## Step 3 (script + explanation + note) / ## Step 4 | **[56](notes/56-lab-shared-library-simple.md)**; options table also **[55](notes/55-shared-libraries-concepts.md)** | |
| # Demo 2 (what, quick flow) / ## Steps 1–10 | **[57](notes/57-lab-shared-library-private.md)** | ⚠️ "reads env.\*" → reads shell env vars |
| ## Step 11 / ### First, verify the problem / ## Apply the fix / ### 1. Add an image label / ### What does --label mean? / ### 2. Auto-restart / ### What does --restart unless-stopped mean? / ## Verification steps / ### 1–4 | **[57](notes/57-lab-shared-library-private.md)** | ⚠️ Groovy `${repo}` snippets don't match the real code; ⚠️ `app1-flask:latest` tag doesn't exist; ⚠️ container is `app1-flask`/`app2-flask`, not `app1`/`app2` |
| ## Why centralising config matters | **[58](notes/58-shared-libraries-production.md)** | |
| # Conclusion | **[58](notes/58-shared-libraries-production.md)** (end, kept) | |
| # References | **[58](notes/58-shared-libraries-production.md)** (end) | |

## `Project 01/README.md`: DevSecOps pipeline on EKS

| Original section | New home | Corrections |
|---|---|---|
| Video reference | **[59](notes/59-tool-primers-maven-sonar-trivy.md)**, [49](notes/49-lab-install-jenkins-on-a-vm.md) | |
| ⭐ Support / Table of Contents | not carried | |
| # Introduction | **[59](notes/59-tool-primers-maven-sonar-trivy.md)** | |
| ## Pre-requisites / #### 1. SDLC · 2. CI/CD · 3. Maven · 4. SonarQube (links + why this helps) | **[59](notes/59-tool-primers-maven-sonar-trivy.md)** (links kept; mapped to topics 02, 06–09, 19, 59) | |
| ## Lab: Install Jenkins Controller on EC2 / ## 1–6 / ### Set JVM timezone (systemd) | **[49](notes/49-lab-install-jenkins-on-a-vm.md)** | ⚠️ 2026 repo key |
| ## Lab: Configure SSH-based Jenkins Agent on EC2 / ### 1–4 (+ port 50000 note) | **[51](notes/51-lab-ssh-agent.md)**; Linux parts in [48](notes/48-linux-recap-users-ssh-services.md) | |
| ## Lab: Add the jenkins-agent to the Controller (image me2) / ### 1. Generate SSH key / ### 2. Copy the public key / #### Manual copy / ### 3. Configure the agent in Jenkins UI (host-key strategies, advanced, expected result, verification) | **[51](notes/51-lab-ssh-agent.md)** | ⚠️ `sudo su - jenkins` doesn't set a password |
| ## Lab: Install SonarQube on EC2 / ### 1–11 | **[60](notes/60-lab-install-sonarqube.md)** | |
| # Demo / ## What are we going to do? (image me1) | **[62](notes/62-project-4-part-1-scan-build-push.md)** | |
| ## Stage 1 (### Objective, #### 0–6) | **[62](notes/62-project-4-part-1-scan-build-push.md)**; PAT/credentials also [23](notes/23-credentials-model.md) | |
| ## Stage 2 (Objective, Why Trivy FS when Sonar, Add stage, Explanation, Install Trivy, Commit, Run, Example report, Simulate a problem) | **[62](notes/62-project-4-part-1-scan-build-push.md)**; "why both" also **[59](notes/59-tool-primers-maven-sonar-trivy.md)** | ⚠️ `AKIA…` is an access key ID, not a secret |
| ## Stage 3 (Objective, ### 1–6, Pipeline, Explanations incl. tools/environment/withCredentials/mvn, Run, For demo purposes only) | **[62](notes/62-project-4-part-1-scan-build-push.md)**; Maven/Sonar concepts **[59](notes/59-tool-primers-maven-sonar-trivy.md)**; environment [34](notes/34-environment-in-pipelines.md) | ⚠️ gate condition "is greater than" → "is less than"; ⚠️ `sonarqube-token-new` vs `sonarqube-token`; ⚠️ "Global Tool Configuration" → Tools |
| ## Stage 4 (Objective, Prerequisite AWS CLI & Docker 1–2, Prerequisite IAM role, Create ECR repo, Pipeline, Explanation, Run) | **[62](notes/62-project-4-part-1-scan-build-push.md)**; IAM theory [61](notes/61-aws-and-k8s-primer.md) | |
| ## Stage 5 (Objective, Create Dockerfile, Crisp explanation, Commit, Pipeline, Explanation, Run) | **[62](notes/62-project-4-part-1-scan-build-push.md)** | ⚠️ `DOCKER_BUILDKIT=0` (legacy builder deprecated) |
| ## Stage 6 (Objective, Why image scan is important, How it differs 1–3, Pipeline, Explanation, Outcome) | **[62](notes/62-project-4-part-1-scan-build-push.md)**, **[59](notes/59-tool-primers-maven-sonar-trivy.md)** | |
| ## Stage 7 (Objective, Snippet, Why, Explanation, Verify) | **[62](notes/62-project-4-part-1-scan-build-push.md)** | |
| ## Stage 8 (Objective, Deployment, Service, topologySpreadConstraints, Snippet, sed step-by-step, Commit) | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** | |
| ## Stage 9 (Objective, Snippet, What it does, Pre-steps, eks-config + #### Install Required Tools (image me3), Install kubectl, Modify role (inline policy), Why edit aws-auth, Understanding the existing entry, Why NOT system:masters/node groups, Why only system:authenticated, Add role to aws-auth, Verify mapping, Grant RBAC, Line-by-line explanation, Verification, Notes & gotchas) | **[63](notes/63-project-4-part-2-deploy-to-eks.md)**; aws-auth/IAM theory **[61](notes/61-aws-and-k8s-primer.md)** | ⚠️ aws-auth deprecated → access entries; ⚠️ EKS 1.32 → 1.36; ⚠️ `desiredCapacity: 1` < `minSize: 2`; ⚠️ `kubectl create ns` isn't idempotent (+ shebang disables `-e`); ⚠️ Service name `cwvj-devsecops-svc` → `cwvj-devsecops-demo-svc` |
| ## Post Actions (Snippet, Explanation, Why outside stages, correct structure) | **[35](notes/35-post-conditions.md)**, [63](notes/63-project-4-part-2-deploy-to-eks.md) | |
| ## Trigger pipeline on Git push (recommended steps 1–5, Poll SCM alternative, security tips) | **[21](notes/21-build-triggers.md)**, [46](notes/46-github-integration.md) | |
| ### Real-world usage by outcome | **[35](notes/35-post-conditions.md)** | |
| ## How this pipeline can be improved / ### 1–12 (incl. ingress video/notes links, MBP links) | **[64](notes/64-improving-the-pipeline.md)**; #3 also [72](notes/72-jenkins-and-gitops.md); #7 also [24](notes/24-using-credentials-safely.md) | |
| # Conclusion | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** (end, kept) | |
| # References (Jenkins, SonarQube, Trivy, ECR, EKS, Kubernetes) | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** (end) | |

---

## Images → used in

| Image | Original note | Now in |
|---|---|---|
| 1a | Day 01 SDLC phases | [02](notes/02-sdlc-and-delivery-models.md) |
| 1b | Day 01 compiled vs interpreted | [03](notes/03-how-code-becomes-software.md) |
| 1c | Day 01 build processes | [03](notes/03-how-code-becomes-software.md) |
| 1d, 1e, 1f, 1g | Day 01 build types | [04](notes/04-build-processes.md) |
| 2a | Day 02 Git & branching | [05](notes/05-git-essentials-for-ci-cd.md) |
| 2b | Day 02 continuous practices | [06](notes/06-continuous-practices.md) |
| 2c | Day 02 branching strategies | [08](notes/08-branching-strategies.md) |
| 2d, 2e, 2f, 2g | Day 02 promotion flows (2g was used twice) | [09](notes/09-promotion-flows.md) |
| 2h | **not referenced by any original note** | [10](notes/10-what-is-jenkins.md) (matches "Jenkins in this picture") |
| 3b | Day 03 what is Jenkins | [10](notes/10-what-is-jenkins.md) |
| 3c | Day 03 install options | [13](notes/13-installation-options.md) |
| 3d | Day 03 roles | [15](notes/15-ui-tour-and-roles.md) |
| 4a | Day 04 controller vs agents | [11](notes/11-jenkins-architecture.md), [16](notes/16-inside-jenkins-home.md) |
| 5a | Day 05 DooD | [26](notes/26-ways-to-build-images.md) |
| 5b | Day 05 Flask flow | [28](notes/28-project-1-freestyle-flask.md) |
| 7a | Day 07 MBP | [43](notes/43-multibranch-pipelines.md) |
| 7b | Day 07 trunk flow | [45](notes/45-trunk-based-flow-with-mbp.md) |
| 7c | Day 07 demo | [47](notes/47-project-3-multibranch-lab.md) |
| me1 | Project 01 pipeline | [62](notes/62-project-4-part-1-scan-build-push.md) |
| me2 | Project 01 controller + agent | [51](notes/51-lab-ssh-agent.md) |
| me3 | Project 01 EKS cluster | [63](notes/63-project-4-part-2-deploy-to-eks.md) |
| sl1, sl2, sl3 | shared-library | [55](notes/55-shared-libraries-concepts.md) |

All 30 images are copied unchanged to `images/`. (Note: there are no `2i` or `3a` images; the numbering gaps are in the original.)

**New diagrams (not from the originals):** `d-life-of-a-build.svg` (topic 11), `d-pipeline-execution.svg` (32), `d-image-build-options.svg` (26), `d-credentials-flow.svg` (23, 24), `d-agent-connections.svg` (50), `d-k8s-agent-pod.svg` (53), `d-security-layers.svg` (65), `d-gitops-flow.svg` (72).

## Sentence-level check

Beyond the heading map above, every prose line (8+ words, outside code blocks) of all 10 original READMEs was compared mechanically against the new notes: the share of the line's three-word sequences found anywhere in `notes/`. Every line scoring below 35% (Day 02 and Project 01) or below 15% (the other Days) was then reviewed by hand. Almost all were rewordings of content that is present. The genuinely missing pieces found, and restored:
- Day 01's introduction and conclusion → end of topic [04](notes/04-build-processes.md)
- Day 02's learning goals → top of topic [09](notes/09-promotion-flows.md); Day 02's conclusion → end of [09](notes/09-promotion-flows.md)
- Day 03's conclusion → end of topic [19](notes/19-git-checkout-and-tools.md)
- Project 01's "why this helps" text for each prerequisite and its "actual production implementations" line → topic [59](notes/59-tool-primers-maven-sonar-trivy.md)
- Project 01's "`system:nodes` is a privileged node identity meant only for kubelets / not for CI or humans" → topic [61](notes/61-aws-and-k8s-primer.md)

Lines intentionally not carried: navigation ("We'll dive into both next…", "coming soon"), the stray "Great point—here's a cleaned-up mental model" chat phrase, star requests, tables of contents.

## Code and config files → used in

All originals are copied **unchanged** into `project-files/`; corrected versions are **separate files** next to them.

| Original file | Copied to | Walked through in | Corrected copy |
|---|---|---|---|
| `.gitignore` | `project-files/repo.gitignore` | n/a (repo housekeeping; ignores secrets like `*.pem`, `.env`, which [24](notes/24-using-credentials-safely.md) relies on) | n/a |
| `Day 02/Dockerfile` (`alpine:3.19`, `echo hello-from-image`) | `project-files/day-01-02-examples/Dockerfile` | [04](notes/04-build-processes.md) (minimal Dockerfile; the Day 02 README doesn't reference it) | n/a |
| `Day 05/python/{app.py, requirements.txt, Dockerfile, .dockerignore}` | `project-files/project-1-flask-freestyle/python/` | **[28](notes/28-project-1-freestyle-flask.md)** | n/a |
| `Day 06/test` (the Freestyle Execute-shell script) | `project-files/project-1-flask-freestyle/freestyle-execute-shell.sh` | **[28](notes/28-project-1-freestyle-flask.md)** | n/a |
| `Day 06/Jenkinsfile`, `Day 06/python/*` | `project-files/project-2-flask-pipeline/` | **[36](notes/36-project-2-flask-pipeline.md)** | `Jenkinsfile.corrected` |
| `Day 07/Jenkinsfile`, `Day 07/python/*` | `project-files/project-3-multibranch/` | **[47](notes/47-project-3-multibranch-lab.md)** | `Jenkinsfile.corrected` |
| `shared-library/project-files/app1/*`, `app2/*` (incl. `Jenkinsfile`, `Jenkinsfile_new`) | `project-files/shared-library/app1`, `app2` | **[57](notes/57-lab-shared-library-private.md)** | n/a (code is correct; README errors fixed in the topic) |
| `shared-library/project-files/shared-library/vars/{buildImage,deployApp}.groovy` | `project-files/shared-library/shared-library/vars/` | **[57](notes/57-lab-shared-library-private.md)**, [58](notes/58-shared-libraries-production.md) | n/a |
| `Project 01/java-maven/{pom.xml, src/main/.../App.java, src/test/.../AppTest.java}` | `project-files/project-4-devsecops-eks/java-maven/` | **[59](notes/59-tool-primers-maven-sonar-trivy.md)**, [62](notes/62-project-4-part-1-scan-build-push.md) | n/a |
| `Project 01/project_files/Jenkinsfile` | `project-files/project-4-devsecops-eks/project_files/` | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** (full listing), [62](notes/62-project-4-part-1-scan-build-push.md) | `Jenkinsfile.corrected` |
| `Project 01/project_files/Dockerfile` | same folder | **[62](notes/62-project-4-part-1-scan-build-push.md)** | n/a |
| `Project 01/project_files/deploy-svc.yaml` | same folder | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** | n/a |
| `Project 01/project_files/eks-config.yaml` | same folder | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** | `eks-config.corrected.yaml` |
| `Project 01/project_files/clusterrole-binding.yaml` | same folder | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** | n/a |
| `Project 01/project_files/aws-auth-edit` | same folder | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** (legacy method) | new `access-entry-commands.sh` (current method) |
| `Project 01/project_files/aws-kube-config-policy` | same folder | **[63](notes/63-project-4-part-2-deploy-to-eks.md)** | n/a |

## New material (not from the originals)

Topics marked 🆕 in [INDEX](INDEX.md) are new: 11, 25, 30, 32, 37–42, 48, 50, 52, 53, 61, 65–77, plus new sections inside many ✅/➕ topics (every "Analogy", "How it works inside", "Hands-on lab", "When it breaks" and "Quick recap + interview questions" section that the originals didn't have).

## Self-check performed

- Every heading above was extracted mechanically from the original READMEs (skipping fenced code blocks) and mapped by hand.
- Every link in `INDEX.md` resolves to an existing topic file; every relative link inside the topics (images, project files, your Linux/Docker/Kubernetes notes) resolves to an existing file.
- Every original image is referenced by at least one topic.
- `diff -rq Jenkins-Basics-To-Production Jenkins-original-backup` showed no differences before work began; the original folder was never modified.
