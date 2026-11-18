# 67 · Configuration as Code

> **Level:** ★★★ advanced · **Status:** 🆕 new topic (JCasC is mentioned in Day 03 but never explained)
>
> **You will learn:** how to define the whole controller as files in Git: **JCasC** (Jenkins Configuration as Code) for system settings, security, credentials, clouds and libraries; a **custom Docker image** with plugins + JCasC; and **Job DSL** seed jobs (or Organization Folders) so even jobs are created from code. The result: a controller you can rebuild from scratch in minutes.
>
> **You need:** topics 14, 23, 50, 55, 65, 66.
>
> **From your original notes:** Day 03 › Kubernetes notes ("back up PVCs and configuration as code (JCasC)"), CloudBees notes ("standardising credentials/JCasC"); Day 04 › "configuration-as-code" under admin duties.

---

## What it is

- **JCasC** (the *Configuration as Code* plugin): reads YAML files (path in `CASC_JENKINS_CONFIG`) at startup (and on reload) and applies them to Jenkins, the same settings you'd click in **Manage Jenkins**.
- **Job DSL** (plugin): a Groovy DSL that **creates jobs** (pipelines, multibranch, folders) from a script. A **seed job** runs the script and creates/updates everything.
- Together with `plugins.txt` (topic 66) and Jenkinsfiles in app repos, **everything is code**.

---

## Why it exists

A hand-configured controller is a **snowflake**: nobody knows exactly how it's set up, upgrades are scary, and disaster recovery means restoring a giant backup. With configuration as code: changes are reviewed in PRs, staging is identical to production, and recovery = rebuild from Git + restore build history.

---

## Analogy

A building constructed from an **architect's blueprint** rather than improvised: if it burns down, you rebuild it exactly from the blueprint, and every renovation is a reviewed change to the drawings.

---

## How it works inside

1. The container starts with `CASC_JENKINS_CONFIG=/var/jenkins_home/casc` (a file, folder or URL).
2. JCasC reads every YAML file there, resolves `${VAR}` placeholders from environment variables, files (`/run/secrets/x`) or secret sources (Vault, Kubernetes secrets), and applies the config.
3. The YAML root keys: `jenkins:` (core: security, nodes, clouds, views…), `credentials:`, `unclassified:` (plugin global settings: location URL, GitHub servers, global libraries, Sonar servers…), `tool:` (Tools), `security:` (script approval, etc.), `jobs:` (Job DSL scripts).
4. **Manage Jenkins → Configuration as Code** lets you **view/export** the current config as YAML (a great way to learn the keys) and **reload** it.
5. Settings changed in the UI are **overwritten** at the next apply. Tell people with a system message.

---

## Config / Jenkinsfile / commands

### `casc/jenkins.yaml`

```yaml
jenkins:
  systemMessage: "Configured by JCasC from git@github.com:acme/jenkins-config.git. UI changes will be lost."
  numExecutors: 0
  mode: EXCLUSIVE
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: "${ADMIN_PASSWORD}"
  authorizationStrategy:
    globalMatrix:
      entries:
        - user: { name: admin, permissions: ["Overall/Administer"] }
        - group: { name: authenticated, permissions: ["Overall/Read", "Job/Read", "Job/Build"] }
  nodes:
    - permanent:
        name: agent1
        remoteFS: /home/jenkins/agent
        labelString: linux
        numExecutors: 2
        launcher:
          ssh:
            host: agent1
            credentialsId: agent1-ssh
            sshHostKeyVerificationStrategy: manuallyTrustedKeyVerificationStrategy

credentials:
  system:
    domainCredentials:
      - credentials:
          - usernamePassword:
              id: dockerhub
              scope: GLOBAL
              username: "${DOCKERHUB_USER}"
              password: "${DOCKERHUB_TOKEN}"
          - basicSSHUserPrivateKey:
              id: agent1-ssh
              scope: SYSTEM
              username: jenkins
              privateKeySource:
                directEntry:
                  privateKey: "${readFile:/run/secrets/agent1_key}"

unclassified:
  location:
    url: https://ci.example.com/
  globalLibraries:
    libraries:
      - name: platform-lib
        defaultVersion: v2
        implicit: false
        allowVersionOverride: true
        retriever:
          modernSCM:
            scm:
              git:
                remote: https://github.com/acme/platform-lib.git
                credentialsId: github-pat

tool:
  maven:
    installations:
      - name: maven3
        home: "/maven3"                # as in the official JCasC maven demo; the installer fills it in
        properties:
          - installSource:
              installers:
                - maven: { id: "3.9.9" }

jobs:
  - script: |
      folder('team-a')
      multibranchPipelineJob('team-a/loans') {
        branchSources {
          github {
            id('loans')
            repoOwner('acme'); repository('loans')
            scanCredentialsId('github-app')
          }
        }
        orphanedItemStrategy { discardOldItems { numToKeep(20) } }
      }
```
- `${ADMIN_PASSWORD}`, `${DOCKERHUB_TOKEN}`: **never** write secrets in the YAML; inject them from env vars / Docker secrets / Vault.
- `${readFile:/run/secrets/agent1_key}`: reads a mounted secret file.
- The `jobs:` section runs **Job DSL** (needs the Job DSL plugin). Many teams prefer a **GitHub Organization Folder** (one definition, all repos discovered) over listing jobs.
- Exact keys vary with plugin versions: **export** from a working controller to confirm.
- **Verification status of this example:** the `credentials:` block (`usernamePassword`, `basicSSHUserPrivateKey` → `privateKeySource` → `directEntry`, `scope: GLOBAL/SYSTEM`) and the `${readFile:…}` syntax match the JCasC plugin's official demos. JCasC also offers `${trim:${readFile:/path}}` to strip a trailing newline from secret files, and `${VAR:-default}` for defaults. The role-based example in topic 65 matches the `role-strategy` demo (`roles: global/items/agents`, `entries: - user:/- group:`). Also checked against the official JCasC demos (November 2026):
  - `globalMatrix` → `entries:` → `- user:`/`- group:` with `name` + `permissions` (the `matrix-auth` demo; the old `"Overall/Administer:admin"` string form is legacy).
  - `unclassified.globalLibraries.libraries[]` → `name` + `retriever.modernSCM.scm.git.{remote, credentialsId}` (the `pipeline-groovy-lib` demo). `defaultVersion`, `implicit` and `allowVersionOverride` are the same options as the Global Pipeline Libraries form (topic 55), but the demo doesn't show them, so confirm them in your export.
  - `tool.maven.installations[]` → `name`, `home`, `properties` → `installSource` → `installers` → `maven: { id }` (the `maven` demo).
  - The `nodes` (permanent SSH agent) block was **not** checked: export it from a controller where you've configured the agent by hand.

### The custom image

```dockerfile
FROM jenkins/jenkins:2.568.2-lts-jdk21
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false -XX:MaxRAMPercentage=75"
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
COPY --chown=jenkins:jenkins casc/ /usr/share/jenkins/ref/casc/
```
`plugins.txt` must include `configuration-as-code` (and `job-dsl` for the `jobs:` section). `runSetupWizard=false` skips the wizard, since JCasC creates the admin user.
```bash
docker build -t acme/jenkins:2026.11 .
docker run -d --name jenkins-casc -p 8090:8080 \
  -e ADMIN_PASSWORD='change-me' -e DOCKERHUB_USER=you -e DOCKERHUB_TOKEN='…' \
  -v jenkins_casc_home:/var/jenkins_home acme/jenkins:2026.11
docker logs jenkins-casc 2>&1 | grep -i casc
```
```
INFO  i.j.p.casc.ConfigurationAsCode#configure: Configuration as Code: applying 1 configuration file(s)…
INFO  jenkins.InitReactorRunner$1#onAttained: Completed initialization
```

### Workflow

```
PR to jenkins-config repo (plugins.txt, casc/*.yaml, Dockerfile)
 → CI builds the image, starts it, runs smoke pipelines (staging)
 → merge → deploy the new image (Docker/Helm) → JCasC applies at start
```
On Kubernetes, the Helm chart does the same with `controller.installPlugins` + `controller.JCasC.configScripts` and a reload sidecar (topic 54).

---

## Deeper dive

### Several files, one configuration

`CASC_JENKINS_CONFIG` can point to a **folder**; every `*.yaml`/`*.yml` in it is merged. Split by concern so reviews stay small:
```
casc/
  01-core.yaml          # jenkins: systemMessage, numExecutors, security
  02-credentials.yaml   # credentials: (placeholders only)
  03-clouds.yaml        # jenkins: clouds: kubernetes …
  04-libraries.yaml     # unclassified: globalLibraries …
  05-jobs.yaml          # jobs: (Job DSL)
```
The same key defined in two files with different values is a **conflict**, and JCasC refuses to start. That's the default merge strategy, `errorOnConflict`, and it's the safest. Set the env var `CASC_MERGE_STRATEGY=override` (or the system property `casc.merge.strategy`) to let later files override earlier ones instead.

### Where secrets can come from

| Source | Syntax | Notes |
|---|---|---|
| Environment variable | `${GITHUB_TOKEN}` | simplest; visible to anything that can read the process environment |
| File | `${readFile:/run/secrets/token}` / `${file:…}` | Docker/Kubernetes secrets mounted as files; wrap in `${trim:…}` to drop a trailing newline |
| Secrets directory | `${token}` | JCasC also looks up a file named after the variable in the secrets directory (default `/run/secrets`, set with the `SECRETS` env var) |
| Default value | `${VAR:-fallback}` | |
| Escape a literal `${` | `^${not-a-variable}` | e.g. inside Job DSL scripts that contain shell `${…}` |
| External managers | plugins (e.g. Vault, AWS SSM/Secrets Manager secret sources for JCasC) | resolve values at startup |

Never commit real values. A good test: the YAML in Git should be safe to make public.

### Reloading without a restart

- UI: **Manage Jenkins → Configuration as Code → Reload existing configuration**.
- Automation with a token: set the env var `CASC_RELOAD_TOKEN=<random>` (or the system property `-Dcasc.reload.token=<random>`; the env var wins if both are set), then `curl -X POST "$JENKINS_URL/reload-configuration-as-code/?casc-reload-token=<random>"`. This endpoint is **disabled** unless a token is set. (The Helm chart's config-reload sidecar does this for you, topic 54.)
- Automation as an admin: `POST /configuration-as-code/reload` with an API token, or the CLI command `reload-jcasc-configuration`. A reload already in progress returns **HTTP 409**.
- Some changes (new plugins, security realm swaps) still need a restart to be safe.

### Job DSL in practice

A typical seed setup: one JCasC `jobs:` entry creates a single **seed job**; the seed job checks out a `jobs/` folder from Git and runs every `*.groovy` in it:
```groovy
// created by JCasC
pipelineJob('seed') {
  definition {
    cps {
      script('''
        node {
          checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: 'https://github.com/acme/jenkins-jobs.git', credentialsId: 'github-app']], branches: [[name: 'main']]]
          jobDsl targets: 'jobs/**/*.groovy', removedJobAction: 'DELETE', removedViewAction: 'DELETE'
        }
      '''.stripIndent())
      sandbox(true)
    }
  }
}
```
- `removedJobAction: 'DELETE'`: jobs removed from Git are deleted from Jenkins, so Git really is the source of truth.
- Job DSL scripts are subject to script security; running them sandboxed or via JCasC avoids per-script approvals.
- Many teams need far fewer seeded jobs once they use **Organization Folders** (topic 43): one folder job discovers every repo.

### Testing configuration changes in CI

```bash
docker build -t jenkins-test .
docker run -d --name jt -e ADMIN_PASSWORD=x jenkins-test
for i in $(seq 1 60); do docker logs jt 2>&1 | grep -q 'Jenkins is fully up and running' && break; sleep 5; done
docker logs jt 2>&1 | grep -E 'SEVERE|ConfiguratorException|UnknownAttributesException' && exit 1
echo "JCasC applied cleanly"; docker rm -f jt
```
Run this on every PR to the `jenkins-config` repo: a broken YAML never reaches production.

---

## Hands-on lab

1. On your lab controller, open **Manage Jenkins → Configuration as Code → View Configuration**, download the YAML, and read it: these are your clicks as code.
2. Create `plugins.txt` (topic 66) + a small `casc/jenkins.yaml` (system message, admin user via env var, `numExecutors: 0`, one credential via env var, Maven tool).
3. Build and run the image on port 8090. Log in: no wizard, everything configured.
4. Change the system message in the YAML, rebuild/restart (or copy into the volume and click **Reload existing configuration**): it's updated.
5. Add a `jobs:` Job DSL block creating a folder and a pipeline job; restart and see them appear.

---

## Where you'll use it

Every serious Jenkins platform: reproducible controllers, staging = prod, fast disaster recovery, audited config changes.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `io.jenkins.plugins.casc.UnknownAttributesException: … No configurator for the following root elements …` | Key wrong or its plugin not installed | Export from a live controller; add the plugin |
| `Invalid configuration elements for type … : foo` | Attribute renamed in a newer plugin | Re-export, update YAML |
| Secrets show as literal `${X}` | Variable not provided | Set the env var / mount the secret file |
| UI changes vanish | JCasC re-applied | Make changes in Git |
| Job DSL `ERROR: script not yet approved for use` | Script security on Job DSL | Configure script approval for the seed, or use JCasC `jobs:` (runs as system) |

---

## Quick recap

- JCasC = controller settings as YAML (`jenkins:`, `credentials:`, `unclassified:`, `tool:`, `security:`, `jobs:`); secrets via `${…}`.
- Custom image = pinned core + `plugins.txt` + casc files; skip the setup wizard.
- Job DSL seed jobs or Organization Folders create jobs from code.
- Export from a live controller to learn keys; UI changes are overwritten.

**Interview questions**

1. **Q: How would you make a Jenkins controller reproducible?**
   A: A custom image with a pinned core and `plugins.txt`, JCasC YAML for all system configuration (secrets injected from a secret store), jobs created by Job DSL or Organization Folders, and Jenkinsfiles in app repos. Only build history needs backing up.

2. **Q: How do you keep secrets out of JCasC files?**
   A: Use `${VAR}` placeholders resolved from environment variables, mounted secret files (`${readFile:…}`), Kubernetes secrets or Vault, never literal values in Git.

3. **Q: What is a seed job?**
   A: A job that runs a Job DSL script to create and update other jobs from code.
