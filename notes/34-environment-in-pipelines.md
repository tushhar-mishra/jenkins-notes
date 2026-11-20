# 34 · Environment Variables in Pipelines

> **Level:** ★★ intermediate · **Status:** 🔀 merged (Day 06 + Project 01)
>
> **You will learn:** the `environment` block (pipeline-level and stage-level), reading variables as `env.X` vs `$X`, building one variable from another, setting variables dynamically, which built-in Git variables exist in pipelines and when, and the "use DNS, not IPs" rule.
>
> **You need:** topics 17 (built-in vars), 30 (quoting), 31.
>
> **From your original notes:** Day 06 › *Step 2: Define reusable environment variables* · Project 01 › *environment { SONAR_IP = … }* (incl. the DNS production note), *environment { ECR_REGISTRY … }*, *environment { IMAGE_REPO = "${ECR_REGISTRY}/…" }*.

---

## What it is

Environment variables are **name=value pairs** given to every step. In a Jenkinsfile you get them from:
- **Built-ins:** `BUILD_NUMBER`, `JOB_NAME`, `WORKSPACE`, `NODE_NAME`, `BUILD_URL`, and in multibranch `BRANCH_NAME`, `CHANGE_ID` (the PR number), `CHANGE_TARGET`… (full list: `<JENKINS_URL>/env-vars.html` and **Pipeline Syntax → Global Variables → env**).
- **Your `environment {}` block.**
- **Credential bindings** (topic 24) and `withEnv([...]) { }` blocks.
- **Global properties** (**Manage Jenkins → System → Global properties → Environment variables**) and node properties.

---

## Why it exists

Image names, registry URLs and tags appear in many stages. Defining them **once** keeps stages short, avoids typos, and makes the pipeline easy to change.

---

## Analogy

The **sticky note on the fridge** with the Wi-Fi password and the plumber's number: written once, everybody in the house reads it, instead of each person keeping their own copy.

---

## How it works inside

- A top-level `environment {}` applies to **all stages**; one inside a `stage` applies to **that stage only** (and overrides the top-level one).
- Values are evaluated when the pipeline (or stage) starts. You can reference **earlier** variables in the same block (`IMAGE_REPO = "${ECR_REGISTRY}/repo"`), because Groovy interpolates them in order.
- They're exported to every `sh` process, so the shell can use `$IMAGE`. In Groovy, read them as `env.IMAGE`.
- Inside `environment {}` the values are **strings**. Booleans/numbers become `"true"`, `"7"`.
- To set a variable **at run time** (e.g. from command output), assign `env.NAME = …` inside a `script {}` block. It's visible to later steps.

### Git variables in pipelines

- With **declarative automatic checkout** (Pipeline from SCM / multibranch), `GIT_COMMIT`, `GIT_BRANCH`, `GIT_URL`, `GIT_PREVIOUS_SUCCESSFUL_COMMIT` are set in `env` for the rest of the build.
- With an explicit `git`/`checkout` step (inline scripts, scripted pipelines), capture them yourself:
  ```groovy
  script { def scmVars = checkout scm; env.GIT_COMMIT = scmVars.GIT_COMMIT }
  ```
  or `env.GIT_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()`.
- In multibranch jobs, prefer `BRANCH_NAME` (e.g. `main`, `PR-12`) over `GIT_BRANCH`.

That's why the Day 06 deploy-info file (topic 36) shows a real commit when the job uses **Pipeline script from SCM**, and an empty `commit:` line if you run the same file inline with a `git` step.

---

## Config / Jenkinsfile / commands

### Define reusable environment variables (Day 06)

We'll reference these in the **build/push/deploy** stages:
```groovy
environment {
  IMAGE = 'docker.io/<your-dockerhub-user>/cwvj-flask'   // use your namespace/repo
  TAG   = "${env.BUILD_NUMBER}"                     // easy, unique tag per run
}
```
*(You could also scope `environment {}` inside a single stage, but top-level makes them available everywhere.)*

### Project 01 environment, explained

```groovy
environment {
  SONAR_IP     = '172.31.21.44'
  ECR_REGISTRY = '<YOUR_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com'
  IMAGE_REPO   = "${ECR_REGISTRY}/cwvj-devsecops-demo"
}
```
- `SONAR_IP` stores the **private IP** of the SonarQube server. It could be defined **inside the stage**, but it's global here so all variables stay in one place for learning clarity.
  > **Note (production):** use **DNS names** (e.g. `sonar.internal.company.local`) instead of IPs. DNS allows **certificate validation** (TLS certificates are issued to names, not private IPs), easier rotation, and portability between environments. An IP that changes after a rebuild silently breaks the pipeline.
- `ECR_REGISTRY` stores the private **ECR** (Amazon Elastic Container Registry) hostname so long URLs aren't repeated inside stages. Format: `<account-id>.dkr.ecr.<region>.amazonaws.com`.
- `IMAGE_REPO = "${ECR_REGISTRY}/cwvj-devsecops-demo"` builds one variable from another (double quotes, so Groovy interpolates). It's used for tagging and pushing in every later stage.

### Stage-level, dynamic and temporary variables

```groovy
pipeline {
  agent any
  environment { APP = 'loans' }
  stages {
    stage('Meta') {
      steps {
        script {
          env.SHORT_SHA = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_SHA}"
        }
        sh 'echo "tag will be $IMAGE_TAG"'
      }
    }
    stage('Deploy stage') {
      environment { TARGET = 'stage' }          // only in this stage
      steps {
        withEnv(['REPLICAS=2']) {               // only inside this block
          sh 'echo "deploy $APP:$IMAGE_TAG to $TARGET x$REPLICAS"'
        }
      }
    }
  }
}
```
```
+ echo tag will be 12-9f3c2e7
tag will be 12-9f3c2e7
+ echo deploy loans:12-9f3c2e7 to stage x2
```

---

## Hands-on lab

1. Add the Day 06 `environment` block to your `flask-pipeline` and `sh 'printenv | sort | grep -E "^(IMAGE|TAG|BUILD_|GIT_|JOB_)"'`.
2. Run it inline (no Git vars) and from SCM (Git vars present). Compare.
3. Add the `Meta` stage above and use `IMAGE_TAG` in a later stage.
4. Try setting `env.X = 'a'` *outside* `script {}` in `steps` and read the validation error.

---

## Where you'll use it

Every pipeline: image names, registries, tags, target environments, tool versions.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `GIT_COMMIT` empty | Inline script with `git` step / scripted pipeline | Capture from `checkout scm` or `git rev-parse` |
| `${ECR_REGISTRY}` appears literally | Single quotes in `environment` | Double quotes when referencing other vars |
| Variable set in one stage not visible later | Used `def x` (local) instead of `env.x` | Assign to `env.NAME` |
| `env.FLAG == true` is never true | env values are strings | Compare with `'true'`, or use `params.FLAG` |
| Pipeline breaks after the server was rebuilt | Hard-coded IP | Use DNS names |

---

## Quick recap

- `environment {}` at pipeline or stage level; read as `$X` in shell, `env.X` in Groovy.
- Reference earlier vars with double quotes; set dynamic ones via `env.X =` inside `script {}`.
- Git vars come automatically with declarative checkout from SCM.
- Use DNS names, not IPs, for servers.

**Interview questions**

1. **Q: How do you set an environment variable from a command's output in declarative?**
   A: Inside `script {}`: `env.X = sh(script: '…', returnStdout: true).trim()`. Later steps see it.

2. **Q: Pipeline-level vs stage-level `environment`?**
   A: Pipeline-level applies to all stages; stage-level only to that stage and overrides same-named pipeline variables.

3. **Q: Why prefer DNS names over IPs in pipelines?**
   A: IPs change when servers are rebuilt or scaled, and TLS certificates validate names. DNS keeps pipelines portable and secure.
