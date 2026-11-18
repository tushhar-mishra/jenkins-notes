# 31 · Declarative Pipeline Anatomy

> **Level:** ★ foundation · **Status:** 🔀 merged from Day 06 sections
>
> **You will learn:** the required blocks of a declarative Jenkinsfile (`pipeline`, `agent`, `stages`, `stage`, `steps`), the optional ones you'll meet next, the two ways to give Jenkins the pipeline (inline vs **Pipeline script from SCM**), where the Jenkinsfile should live, and how to run a skeleton pipeline and read its stage view.
>
> **You need:** topics 29–30.
>
> **From your original notes:** Day 06 › *Two ways to use a Pipeline*, *Groovy: two pipeline styles*, *Declarative Pipeline — the core building blocks* (Minimal shape, What each block means, Useful companions), *Create a Skeleton Jenkinsfile* (steps 1–3, Why this?, Next), *1) Use Pipeline Script from SCM* (incl. the note on keeping the Jenkinsfile with the app code).

---

## What it is

A **declarative pipeline** is a Jenkinsfile with a fixed, readable structure. Jenkins checks the structure *before* running anything, so typos fail fast with clear messages.

### Minimal shape

```groovy
pipeline {
  agent any                       // where the build runs
  stages {
    stage('checkout') {
      steps {
        echo 'Checking out from private repo'
      }
    }
  }
}
```

### What each block means

- **`pipeline { }`**: the required top-level block. Everything goes inside.
- **`agent`**: where to execute (which node; topic 11):
  - `agent any` → any available node/executor.
  - `agent { label 'docker' }` → only nodes with the label `docker`.
  - `agent none` → no global agent; each stage declares its own (topic 40).
  - also `agent { docker { image '…' } }`, `agent { kubernetes { … } }` (topics 40, 53).
- **`stages`**: the ordered list of **`stage('name')`** blocks. Each stage shows as one box in the UI.
- **`steps`**: the actual work inside a stage: `sh`, `echo`, `git`, `archiveArtifacts`, etc.

### Useful companions (each has its own topic)

| Directive | Purpose | Topic |
|---|---|---|
| `environment { }` | set env vars (e.g. `IMAGE`, `TAG`) | 34 |
| `options { }` | timeouts, timestamps, build discarder, concurrency | 37 |
| `parameters { }` | user inputs (e.g. `string(name: 'TAG', …)`) | 37 |
| `triggers { }` | cron, pollSCM, upstream | 37 |
| `tools { }` | auto-provision Maven/JDK for the run | 19 |
| `when { }` | conditional stage (e.g. only on `main`) | 38 |
| `post { }` | always/success/failure/… actions (e.g. `cleanWs()`) | 35 |
| `parallel { }`, `matrix { }` | concurrent stages | 39 |
| `input { }` | wait for approval | 38 |

### Two pipeline styles

- **Declarative** (newer, simpler): `pipeline { agent any; stages { … } }`.
- **Scripted** (flexible, Groovy-first): `node { stage('…') { … } }`.

We use **Declarative** throughout; you can drop to Scripted (or a `script {}` block) for advanced logic (topic 42).

---

## Why it exists

A fixed structure means every team's Jenkinsfile looks the same, the UI can draw stages, Jenkins can validate the file before running it, and features like Restart from Stage and `post` conditions work reliably.

---

## Analogy

A **form with labelled sections** (Declarative) vs a **blank page** (Scripted). The form is quicker to fill in and harder to get wrong; the blank page lets you write anything.

---

## How it works inside

### Two ways to give Jenkins the pipeline

1. **From SCM (recommended for production):** **Pipeline → Definition: Pipeline script from SCM** → point at your repo/branch. Jenkins loads `Jenkinsfile` from the repo.
   *Benefits:* version control, code review, simple rollbacks.
2. **Inline (script in the job):** **Definition: Pipeline script**, paste the Jenkinsfile into the job UI.
   *Use for labs or quick tests.*

> ⚠️ **Corrected:** was "For inline Scripted Groovy, Jenkins may use the Groovy Sandbox to require approvals for dangerous APIs." Now: **every** pipeline runs in the **Groovy sandbox** by default, declarative or scripted. **Pipeline script from SCM is always sandboxed.** Only an *inline* script can untick **Use Groovy Sandbox**, and then the whole script needs an administrator's approval before it can run (topic 65). Non-whitelisted methods in a sandboxed script fail with `Scripts not permitted to use method …`.

### What happens when the job starts (from SCM)

1. Jenkins does a **lightweight checkout** (when possible): it fetches **only** the `Jenkinsfile` (via the Git host API or `git archive`) to the controller.
2. The pipeline engine **parses and validates** the declarative structure. Errors appear before any stage runs: `WorkflowScript: 5: Missing required section "steps"`.
3. When the `agent` is allocated, declarative does an **automatic checkout** (`checkout scm`) of the **same commit** into the workspace (the stage shows as *Declarative: Checkout SCM*). You don't need a separate `git` step. Turn it off with `options { skipDefaultCheckout() }`.
4. Stages run in order; each `sh` runs on the agent.

### Where should the Jenkinsfile live?

> Keep the **Jenkinsfile in the same repo as the app code**: it versions with the code, works per branch, and avoids drift.
> Put reusable logic in a **Jenkins Shared Library** (a separate repo) and call it from the Jenkinsfile (Part 9).
> Use a separate "pipeline repo" only for centralised templates/governance, not for everyday app pipelines.

The default path is `Jenkinsfile` at the repo root (**Script Path** setting). Monorepos use paths like `services/api/Jenkinsfile`.

---

## Config / Jenkinsfile / commands

### Create a skeleton Jenkinsfile

**1) Make a Pipeline job:** **New Item → Pipeline →** name it `flask-pipeline` → **OK**. Scroll to **Pipeline** → **Definition: Pipeline script**.

**2) Paste this minimal Jenkinsfile:**
```groovy
pipeline {
  agent any

  stages {
    stage('checkout') {
      steps {
        echo 'this is checkout step'
      }
    }
    stage('build') {
      steps {
        echo 'this is build step'
      }
    }
    stage('push') {
      steps {
        echo 'this is push step'
      }
    }
    stage('deploy') {
      steps {
        echo 'this is deploy step'
      }
    }
    stage('test') {
      steps {
        echo 'this is test step'
      }
    }
  }
}
```

**3) Run it:**
- **Save**, then **Build Now**.
- Open the build → **Stages** (Pipeline Graph View, topic 15): one box per stage (green = passed, red = failed).
- Click a stage to jump straight to its logs.
- **Console Output** shows the full log, as in Freestyle:
  ```
  [Pipeline] Start of Pipeline
  [Pipeline] node
  Running on Jenkins in /var/jenkins_home/workspace/flask-pipeline
  [Pipeline] {
  [Pipeline] stage
  [Pipeline] { (checkout)
  [Pipeline] echo
  this is checkout step
  [Pipeline] }
  ...
  [Pipeline] End of Pipeline
  Finished: SUCCESS
  ```
  `[Pipeline] …` lines are the engine reporting each step; `{ (checkout)` marks entering a stage.

**Why this?**
- The stages mirror **Project 1** (checkout → build → push → deploy → test).
- We just echo for now to learn the **syntax and the stage view**. Topic 36 replaces the echoes with real steps.

**Next:** move this Jenkinsfile **into your repo (Pipeline script from SCM)** so it's versioned and reviewable:
- Job → **Configure → Definition: Pipeline script from SCM**
  - **SCM:** Git · **Repository URL:** your private repo · **Credentials:** `github-pat` · **Branches to build:** `*/main` · **Script Path:** `Jenkinsfile`
- Commit `Jenkinsfile` to the repo root.

---

## Hands-on lab

1. Run the skeleton inline.
2. Break it on purpose: delete one `steps {` line and build. Read the validation error (it names the line), and note that **no stage ran**.
3. Make one stage fail with `sh 'exit 1'`. See it red in the graph, and see that later stages show as *skipped*.
4. Commit the skeleton as `Jenkinsfile` to `jenkins-lab` and switch the job to **Pipeline script from SCM**. Build: there's now a *Declarative: Checkout SCM* stage, and the console says `Obtained Jenkinsfile from git …`.

---

## Where you'll use it

Every Jenkinsfile you'll ever write starts from this shape.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `Missing required section "stages"` / `"steps"` / `"agent"` | Structure incomplete | Add the section |
| `Unknown stage section "step"` | Typo (`step` vs `steps`) | Fix spelling |
| `ERROR: Unable to find Jenkinsfile` | Wrong branch or Script Path in "from SCM" | Check the branch spec and path |
| `No such DSL method 'foo' found among steps` | Step name typo, or its plugin isn't installed | Check the Snippet Generator (topic 33) |
| `Expected a symbol` / `Not a valid stage section definition` | Groovy code directly inside `steps`/`stage` that declarative doesn't allow | Wrap logic in `script { }` |

---

## Quick recap

- Required: `pipeline` → `agent` → `stages` → `stage` → `steps`.
- Optional directives: `environment`, `options`, `parameters`, `triggers`, `tools`, `when`, `post`, `parallel`, `input`.
- Prefer **Pipeline script from SCM**; keep the Jenkinsfile in the app repo.
- Declarative does an automatic `checkout scm` of the same commit; all pipelines are sandboxed.

**Interview questions**

1. **Q: What are the mandatory sections of a declarative pipeline?**
   A: `pipeline`, `agent`, `stages`, and inside each `stage` a `steps` block (or nested stages/parallel).

2. **Q: Inline pipeline script vs Pipeline script from SCM?**
   A: Inline lives in the job config: fine for experiments, but unreviewed and unversioned. From SCM loads the Jenkinsfile from Git, so it's versioned, reviewed and per-branch.

3. **Q: Do you need a `git` step in a declarative pipeline from SCM?**
   A: No. Declarative automatically runs `checkout scm` for the same commit when the agent starts, unless you set `skipDefaultCheckout()`.
