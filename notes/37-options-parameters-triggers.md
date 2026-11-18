# 37 · `options`, `parameters` and `triggers`

> **Level:** ★★ intermediate · **Status:** 🆕 new topic (expands Day 06's "useful companions")
>
> **You will learn:** the declarative directives that control *how* a pipeline runs: `options` (timeouts, retries, timestamps, build discarder, concurrency, checkout behaviour), `parameters` (inputs as code) and `triggers` (cron, pollSCM, upstream), with production defaults you can copy.
>
> **You need:** topics 20, 21, 31.
>
> **From your original notes:** Day 06 › *Useful companions you'll meet shortly* (`options`, `parameters`) · Day 07 › ops tip "add `disableConcurrentBuilds()`".

---

## What it is

| Directive | Where | Purpose |
|---|---|---|
| `options { }` | pipeline or stage | Behaviour settings for the run |
| `parameters { }` | pipeline only | Build inputs (the "Build with Parameters" form) |
| `triggers { }` | pipeline only | What starts the pipeline automatically |

---

## Why it exists

Without them, pipelines hang forever on a stuck command, keep thousands of old builds, run two deploys at once, and depend on someone remembering to click "Build". Putting these settings **in the Jenkinsfile** means they're reviewed and versioned like everything else.

---

## Analogy

The **house rules** on a shared kitchen: "no cooking longer than an hour" (timeout), "one person at the stove at a time" (disableConcurrentBuilds), "clear out the fridge weekly" (buildDiscarder), "the cleaner comes at 2 AM" (cron trigger).

---

## How it works inside

- `options` are applied when the pipeline/stage starts. A pipeline-level `timeout` aborts the whole build (result **ABORTED**) when exceeded; a stage-level one only that stage.
- `parameters` and `triggers` are **job properties**: Jenkins only learns about them **after the Jenkinsfile has run once**. The first build uses defaults; after that, "Build with Parameters" and the schedule appear. In multibranch jobs each branch job has its own properties.
- If you delete `triggers` from the Jenkinsfile, the schedule is removed after the next run.

---

## Config / Jenkinsfile / commands

### A production-ready header

```groovy
pipeline {
  agent { label 'docker' }

  options {
    timeout(time: 45, unit: 'MINUTES')                     // kill hung builds
    timestamps()                                           // time on every log line
    buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '5'))
    disableConcurrentBuilds(abortPrevious: true)           // a new build aborts the older running one
    skipStagesAfterUnstable()                              // stop after tests go UNSTABLE
    durabilityHint('PERFORMANCE_OPTIMIZED')                // fewer state saves (topic 32)
    // skipDefaultCheckout()                               // if you want to control checkout yourself
    // retry(2)                                            // retry the whole pipeline (rarely wise)
  }

  parameters {
    choice(name: 'ENV', choices: ['dev', 'stage', 'prod'], description: 'Where to deploy')
    booleanParam(name: 'RUN_E2E', defaultValue: false, description: 'Run slow end-to-end tests')
    string(name: 'IMAGE_TAG', defaultValue: '', description: 'Leave empty to use the build number')
    text(name: 'RELEASE_NOTES', defaultValue: '', description: 'Optional notes')
  }

  triggers {
    pollSCM('H/15 * * * *')                                // only if webhooks are impossible
    cron('TZ=Asia/Kolkata\nH 2 * * 1-5')                  // weekday nightly run
    // upstream(upstreamProjects: 'lib-core/main', threshold: hudson.model.Result.SUCCESS)
  }

  stages {
    stage('Info') {
      steps {
        script { env.TAG = params.IMAGE_TAG ?: env.BUILD_NUMBER }
        echo "ENV=${params.ENV} E2E=${params.RUN_E2E} TAG=${env.TAG}"
      }
    }
    stage('Slow tests') {
      when { expression { params.RUN_E2E } }
      options { timeout(time: 20, unit: 'MINUTES'); retry(2) }   // stage-level options
      steps { sh './run-e2e.sh' }
    }
  }
}
```

What each option does:

| Option | Effect |
|---|---|
| `timeout(time, unit)` | Aborts after the time. Combine with `activity: true` to time out only after N minutes of **no log output** |
| `timestamps()` | Prefixes log lines with time (Timestamper plugin) |
| `buildDiscarder(logRotator(...))` | Keep N builds / N with artifacts (topic 18) |
| `disableConcurrentBuilds()` | Only one build of this job at a time; others wait. `abortPrevious: true` aborts the running one instead (good for PR builds: the newest push wins) |
| `skipStagesAfterUnstable()` | Once the build is UNSTABLE, skip later stages |
| `retry(n)` | Retry the block (pipeline or stage) up to n times on failure. Use for flaky *infrastructure* steps, not to hide flaky tests |
| `skipDefaultCheckout()` | Don't auto-checkout (topic 31) |
| `quietPeriod(10)` | Wait seconds after the trigger before starting |
| `preserveStashes(buildCount: 5)` | Keep stashes for Restart from Stage (topic 40) |
| `parallelsAlwaysFailFast()` | Make every `parallel` fail fast (topic 39) |

Parameter types: `string`, `text`, `booleanParam`, `choice`, `password` (prefer credentials), plus plugin types. Read them as `params.NAME` (typed).

Trigger types: `cron('…')`, `pollSCM('…')`, `upstream(...)`. Webhooks don't need a `triggers` entry for multibranch (the branch source handles them); for a single Pipeline job, enable "GitHub hook trigger" in the job (topic 21) or use `githubPush()` in `triggers`.

Sample output with `timestamps()` and a timeout:
```
10:02:11  + ./integration.sh
10:47:11  Timeout has been exceeded
10:47:11  Cancelling nested steps due to timeout
10:47:12  Sending interrupt signal to process
Finished: ABORTED
```

### Retry a flaky network step only

```groovy
retry(3) { sh 'curl -fsSL -o tool.tgz https://example.com/tool.tgz' }
```
Combine with a pause between attempts in scripted logic, or the `retry(count: 3, conditions: [agent(), nonresumable()])` form, which retries only when the **agent** was lost (great with spot/ephemeral agents).

---

## Deeper dive

### Two kinds of options (why some can't go on a stage)

`options` entries come in two flavours, and that decides where you may put them:

| Kind | Examples | Pipeline level | Stage level |
|---|---|---|---|
| **Job properties** (saved on the job, apply before the build starts) | `buildDiscarder`, `disableConcurrentBuilds`, `durabilityHint`, `quietPeriod`, `preserveStashes`, `overrideIndexTriggers` | ✅ | ❌ |
| **Wrappers** (wrap the steps while they run) | `timeout`, `retry`, `timestamps` | ✅ | ✅ |
| **Declarative-only flags** | `skipDefaultCheckout`, `skipStagesAfterUnstable`, `checkoutToSubdirectory('src')`, `newContainerPerStage()`, `parallelsAlwaysFailFast()` | ✅ | some |

Putting a job-property option inside a stage fails validation with `Invalid option type "buildDiscarder". Valid option types: [...]`.

### Job properties are written by the Jenkinsfile, so the Jenkinsfile wins

Each run of a declarative pipeline **rewrites** the job's properties from the `options`, `parameters` and `triggers` blocks. Consequences:
- If someone adds a parameter in the job's UI, the next run **removes** it.
- If you delete the `triggers` block, the cron stops after the next run (not before).
- In multibranch jobs each branch job gets its own properties. A `cron` trigger in `main`'s Jenkinsfile only schedules `main`.
- `overrideIndexTriggers(false)` tells a multibranch branch job **not** to build on branch-indexing events (useful for heavy release branches you only want to build on schedule).

### `timeout` details

```groovy
options { timeout(time: 20, unit: 'MINUTES', activity: true) }   // abort after 20 min with NO log output
```
- Default `activity: false` = wall-clock limit.
- When the timeout fires, Jenkins sends an interrupt; `sh` processes get SIGTERM, then are killed. The result is **ABORTED** (not FAILURE), so `post { aborted { } }` runs.
- A timeout around `input` (topic 38) is the standard way to stop approvals waiting for ever.

### `retry` details

```groovy
retry(count: 3, conditions: [agent(), nonresumable()]) {          // only retry if the AGENT died / step can't resume
  node('spot') { sh 'make integration' }
}
```
- Plain `retry(3)` retries on **any** failure, including real test failures. That hides bugs.
- `conditions: [agent()]` retries only when the agent connection was lost (Spot instance reclaimed, pod evicted): exactly the case where a retry is safe.
- `kubernetesAgent()` is a similar condition from the Kubernetes plugin (pod deleted/evicted).

### Parameter gotchas

- `params` is **read-only**; to compute a value from a parameter, assign to `env` (`env.TAG = params.TAG ?: env.BUILD_NUMBER`).
- A **choice** parameter's first item is the default; scheduled (cron) builds always use defaults, so make the default the **safe** option (e.g. `dev`, not `prod`).
- A `booleanParam` is a real boolean in `params.X` but the string `'true'`/`'false'` in `env.X`.
- Validating input: there's no built-in validation; fail fast in the first stage:
  ```groovy
  stage('Validate') { steps { script {
    if (!(params.IMAGE_TAG ==~ /^[a-z0-9._-]{0,64}$/)) { error "Bad IMAGE_TAG: ${params.IMAGE_TAG}" }
  } } }
  ```
  (Unvalidated string parameters pasted into `sh` can inject shell commands; pass them through `withEnv` and single quotes.)

### Trigger reference

| Trigger | Syntax | Notes |
|---|---|---|
| Cron | `cron('H 2 * * 1-5')` | runs whether or not code changed |
| Poll SCM | `pollSCM('H/15 * * * *')` | builds only on new commits |
| Upstream | `upstream(upstreamProjects: 'lib/main', threshold: hudson.model.Result.SUCCESS)` | build after another job succeeds |
| GitHub push (single Pipeline jobs) | `githubPush()` | needs the webhook (topic 21); multibranch doesn't need it |
| Parameterized cron (plugin) | `parameterizedCron('H 3 * * * % ENV=stage')` | *Parameterized Scheduler* plugin: cron with parameter values |

---

## Hands-on lab

1. Add the `options` block above to `flask-pipeline`. Add a stage `sh 'sleep 120'` with stage-level `timeout(time: 1, unit: 'MINUTES')`: see it ABORT.
2. Add the `parameters` block, run once, then check that **Build with Parameters** appears.
3. Add `disableConcurrentBuilds(abortPrevious: true)` and start two builds quickly: the first is aborted.
4. Add `cron('H/5 * * * *')`, wait for a timer-triggered build, then remove it.

---

## Where you'll use it

Every production Jenkinsfile: timeouts and discarders are a must; concurrency control for deploys; parameters for manual promotion jobs; cron for nightly pipelines.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| "Build with Parameters" missing | Pipeline hasn't run since adding `parameters` | Run once |
| Parameters reset to defaults after every run | Another job/JCasC overwrites properties, or `properties([])` in scripted code | Define them in one place only |
| Schedule doesn't fire | Branch job never built, or the trigger was removed | Run once; check **View Configuration** of the job |
| Two deploys ran at once and clashed | No `disableConcurrentBuilds()` / `lock` | Add it (or `lock`, topic 38) |
| Builds hang for days | No timeout | Pipeline-level `timeout` |

---

## Quick recap

- `options`: `timeout`, `timestamps`, `buildDiscarder`, `disableConcurrentBuilds`, `retry`, `skipDefaultCheckout`, `durabilityHint`.
- `parameters` and `triggers` register after the first run.
- Use stage-level options for stage-specific timeouts/retries.
- Retries are for flaky infrastructure, not flaky tests.

**Interview questions**

1. **Q: How do you stop a pipeline from hanging forever?**
   A: `options { timeout(time: 30, unit: 'MINUTES') }` at pipeline level (plus stage-level timeouts for risky stages); `activity: true` times out on no output.

2. **Q: How do you make sure only the newest PR build runs?**
   A: `disableConcurrentBuilds(abortPrevious: true)`, or `milestone` steps (topic 38).

3. **Q: Why don't new parameters show up immediately?**
   A: Declarative `parameters` become job properties only when the Jenkinsfile runs, so they appear after the first build.
