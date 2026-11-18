# 42 · Scripted Pipelines

> **Level:** ★★★ advanced · **Status:** 🆕 new topic (expands the Day 06 "two pipeline styles" note)
>
> **You will learn:** the scripted pipeline syntax (`node`, `stage`, plain Groovy), how it compares to declarative, `script {}` blocks as the bridge, error handling with try/catch/finally, `@NonCPS` and serialisation rules, and **when scripted is still the right choice**.
>
> **You need:** topics 30, 32, 41.
>
> **From your original notes:** Day 06 › *Groovy: how much do you need?* (Scripted: `node { stage('…'){ … } }`, "drop to Scripted for advanced logic").

---

## What it is

**Scripted pipeline** is the original Pipeline syntax: the Jenkinsfile is a **Groovy program** that calls pipeline steps. There's no fixed structure: you allocate nodes with `node`, mark stages with `stage`, and use any (sandbox-approved) Groovy.

```groovy
node('docker') {                         // allocate an executor on a node with label "docker"
  stage('Checkout') { checkout scm }
  stage('Build')    { sh 'make build' }
  stage('Test')     { sh 'make test' }
}
```

---

## Why it exists

Declarative is easier and safer, but it's deliberately limited. Some pipelines are really **programs**: generating stages from a list of services read from a file, complex retry/branching logic, reusable library code (shared libraries are written in scripted style, Part 9).

---

## Analogy

Declarative is a **form**; scripted is a **blank sheet of paper**. Most of the time the form is better. Sometimes you need to draw something the form never imagined.

---

## How it works inside

- The whole file runs as CPS Groovy on the controller (topic 32). Nothing runs on an agent until you enter a `node { }` block, and **`sh` outside `node`** fails (`Required context class hudson.FilePath is missing`).
- No automatic checkout: call `checkout scm` yourself.
- No `post` section: use `try/catch/finally`.
- No `when`/`options` directives: use `if`, `timeout(…) { }`, `retry(…) { }` steps and `properties([...])`.
- No upfront validation: errors appear when that line runs.

### Declarative vs scripted

| | Declarative | Scripted |
|---|---|---|
| Structure | fixed, validated before running | free Groovy |
| Learning curve | low | higher |
| `post`, `when`, `options`, Restart from Stage | built in | do it yourself |
| Dynamic stages | `matrix`, limited | anything |
| Typical use | app Jenkinsfiles | shared-library internals, generators, legacy |

**Middle ground:** a `script { }` block inside declarative lets you run scripted Groovy in one step while keeping declarative structure (as in topics 30, 34). Most teams use declarative + `script` + shared libraries, and almost never write fully scripted Jenkinsfiles.

### Serialisation and `@NonCPS`

Every local variable must be serialisable between steps (topic 32). A method marked `@NonCPS` runs as **normal** Groovy (not CPS-transformed): faster, can use non-serialisable objects, but **must not call pipeline steps** (`sh`, `echo`…) and can't be paused.
```groovy
@NonCPS
def parseVersion(String text) {
  def m = (text =~ /version=(\S+)/)
  return m ? m[0][1] : null          // return a plain String
}
```

---

## Config / Jenkinsfile / commands

A complete scripted pipeline with error handling and properties:

```groovy
properties([
  buildDiscarder(logRotator(numToKeepStr: '20')),
  disableConcurrentBuilds(),
  parameters([choice(name: 'ENV', choices: ['dev', 'stage'])])
])

def services = ['api', 'worker']

node('docker') {
  try {
    timeout(time: 30, unit: 'MINUTES') {
      stage('Checkout') {
        def scmVars = checkout scm
        env.GIT_COMMIT = scmVars.GIT_COMMIT
      }
      stage('Build') {
        def builds = services.collectEntries { s ->
          [(s): { sh "docker build -t acme/${s}:${env.BUILD_NUMBER} ${s}/" }]
        }
        parallel builds
      }
      stage('Deploy') {
        if (env.BRANCH_NAME == 'main') {
          retry(2) { sh "./deploy.sh ${params.ENV}" }
        } else {
          echo "Skipping deploy on ${env.BRANCH_NAME}"
        }
      }
    }
    currentBuild.result = 'SUCCESS'
  } catch (err) {
    currentBuild.result = 'FAILURE'
    echo "Failed: ${err}"
    throw err                        // re-throw so Jenkins records the failure
  } finally {
    junit allowEmptyResults: true, testResults: '**/reports/*.xml'
    cleanWs()
  }
}
```
Notes:
- `properties([...])` sets job properties (like declarative `options`/`parameters`).
- `"…${s}…"` double quotes because `s` is a Groovy variable; no secrets here, so interpolation is fine.
- `finally` = `post { always/cleanup }`. Always re-throw in `catch`, or the build would show green.
- Catching `org.jenkinsci.plugins.workflow.steps.FlowInterruptedException` lets you treat aborts differently.

---

## Deeper dive

### Declarative → scripted translation table

When you read old Jenkinsfiles or write library code, you translate between the two constantly:

| Declarative | Scripted equivalent |
|---|---|
| `agent { label 'x' }` | `node('x') { … }` |
| automatic checkout | `checkout scm` (explicitly) |
| `stage('A') { steps { … } }` | `stage('A') { … }` |
| `environment { X = 'y' }` | `withEnv(['X=y']) { … }` |
| `environment { T = credentials('id') }` | `withCredentials([string(credentialsId: 'id', variable: 'T')]) { … }` |
| `options { timeout(...) }` | `timeout(time: 30, unit: 'MINUTES') { … }` |
| `options { retry(3) }` | `retry(3) { … }` |
| `options { timestamps() }` | `timestamps { … }` |
| `options { buildDiscarder(...) }`, `parameters {}`, `triggers {}` | `properties([buildDiscarder(...), parameters([...]), pipelineTriggers([...])])` |
| `when { branch 'main' }` | `if (env.BRANCH_NAME == 'main') { … }` (the stage still shows, as run) |
| `post { always {} failure {} }` | `try { … } catch (e) { …; throw e } finally { … }` |
| `parallel { stage… }` | `parallel(a: { … }, b: { … }, failFast: true)` |
| `agent { docker { image 'i' } }` | `docker.image('i').inside { … }` |
| `input { … }` directive | `input message: '…', submitter: '…'` |

Skipped stages: in scripted, an `if` around a stage simply doesn't run it. To show it as *skipped* in the graph, use `org.jenkinsci.plugins.pipeline.modeldefinition.Utils.markStageSkippedForConditional('name')` (this needs script approval) or prefer declarative.

### Loading Groovy from the repo: `load`

```groovy
node {
  checkout scm
  def helpers = load 'ci/helpers.groovy'     // file must end with "return this"
  helpers.notify('built')
}
```
`ci/helpers.groovy`:
```groovy
def notify(String msg) { echo "NOTIFY: ${msg}" }
return this
```
`load` is fine for small repo-local helpers. For anything shared between repos, use a shared library (Part 9): versioned, trusted, cached.

### Common CPS pitfalls in scripted code

| Code | Problem | Fix |
|---|---|---|
| `list.sort { a, b -> … }` / `.collect { }` with closures inside pipeline code | Some Groovy closure methods misbehave under CPS ("expected to call … but wound up catching …") | Move them into an `@NonCPS` method that returns a plain value |
| `new JsonSlurper().parseText(…)` held in a variable across `sh` | `LazyMap` isn't serialisable → `NotSerializableException` | `readJSON` step (Pipeline Utility Steps), or parse inside `@NonCPS` and return plain maps |
| `for (x in map)` over a `Map` | Map entry iterators aren't serialisable | Iterate `map.keySet().toList()` |
| `sh` called inside `@NonCPS` | Steps can't run in non-CPS code | Return data from `@NonCPS`, call steps outside |
| Long-running loops polling an API in Groovy | Burns controller CPU, huge program state | Use a shell loop, or `waitUntil { … }` with a sleep |

### `waitUntil` and `sleep`

```groovy
timeout(10) {
  waitUntil(initialRecurrencePeriod: 5000) {           // retries the block until it returns true
    sh(script: 'curl -fsS http://svc/health', returnStatus: true) == 0
  }
}
```
That's the CPS-friendly way to poll; the pipeline pauses (and survives restarts) between attempts.

---

## Hands-on lab

1. Convert your topic 36 Jenkinsfile to scripted (node, stages, try/catch/finally) and run it.
2. Remove the `throw err` and make a stage fail: the build shows FAILURE only because we set `currentBuild.result`. Remove that too: now it's (wrongly) green. Put both back.
3. Call `sh` outside `node {}` and read the error.
4. Write a `@NonCPS` helper that parses a version string and use it from a stage.

---

## Where you'll use it

- Reading older Jenkinsfiles (lots of legacy scripted code exists).
- Writing shared-library steps (`vars/*.groovy` are scripted code, Part 9).
- Rare, highly dynamic pipelines.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `Required context class hudson.FilePath is missing. Perhaps you forgot to surround the code with a step that provides this, such as: node` | `sh`/`checkout` outside `node` | Wrap it in `node { }` |
| Build green despite a failure | Exception caught and not re-thrown | `throw err` in `catch` |
| `NotSerializableException` | Non-serialisable object held across a step | `@NonCPS` helper (topic 32) |
| `expected to call … but wound up catching …` | Pipeline steps called inside `@NonCPS`, or CPS closures passed to `sort`/`collect` in a NonCPS context | Keep `@NonCPS` free of steps |
| `Scripts not permitted to use method …` | Sandbox | Use a step or get approval (topic 65) |

---

## Quick recap

- Scripted = plain Groovy with `node`/`stage`; no structure, validation, `post` or `when` built in.
- Use `try/catch/finally` (and re-throw), `timeout`/`retry` steps, `properties([...])`.
- Prefer declarative + `script {}` + shared libraries; scripted mainly lives inside libraries and legacy jobs.
- `@NonCPS` for pure helper methods only.

**Interview questions**

1. **Q: Declarative vs scripted pipeline?**
   A: Declarative has a fixed, validated structure with built-in `post`, `when`, `options` and Restart from Stage. Scripted is free-form Groovy with `node`/`stage`, more flexible but harder to read and maintain.

2. **Q: How do you do "always run" cleanup in scripted?**
   A: `try { … } catch (e) { …; throw e } finally { cleanup }`.

3. **Q: What is `@NonCPS` for?**
   A: Marking helper methods that run as plain Groovy: they can use non-serialisable objects and run faster, but can't call pipeline steps or be paused.
