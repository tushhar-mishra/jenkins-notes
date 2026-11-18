# 39 · Parallel Stages and Matrix

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** how to run stages at the same time with `parallel`, fail fast when one branch fails, and test many combinations (OS × version) with `matrix`.
>
> **You need:** topics 31, 38.
>
> **From your original notes:** Day 06 › *Why pipelines*: "`parallel {}` for fast feedback"; Pipeline vs Freestyle table row *Parallelism*.

---

## What it is

- **`parallel`**: a stage whose sub-stages run **at the same time**. Each can have its own agent.
- **`matrix`**: generates a set of parallel stages from **axes** (e.g. `JDK: 17, 21` × `OS: linux, windows`) so you don't write each combination by hand.

---

## Why it exists

CI time is developer waiting time. Lint, unit tests and a security scan don't depend on each other, so running them side by side cuts a 15-minute CI to 6. Matrices test libraries against every supported version without copy-paste.

---

## Analogy

Cooking dinner: you boil pasta, fry the sauce and toss the salad **at the same time** on three burners instead of one after another. `failFast` = if the sauce burns, stop everything and order pizza.

---

## How it works inside

- Each parallel branch is a separate **thread of the pipeline program** on the controller; each `agent` inside it requests its **own executor**. Without per-branch agents, all branches share the parent's node and workspace (be careful with files).
- The `parallel` stage finishes when **all** branches finish. Its result is the worst branch result.
- `failFast true` aborts the other branches as soon as one fails.
- Capacity: 3 branches × separate agents need 3 free executors; otherwise some wait in the queue.

---

## Config / Jenkinsfile / commands

### Parallel stages

```groovy
pipeline {
  agent none
  options { parallelsAlwaysFailFast() }
  stages {
    stage('Checks') {
      parallel {
        stage('Lint') {
          agent { docker { image 'python:3.12-slim' } }
          steps { sh 'pip install -q ruff && ruff check .' }
        }
        stage('Unit tests') {
          agent { docker { image 'python:3.12-slim' } }
          steps { sh 'pip install -q -r requirements.txt pytest && pytest -q --junitxml=unit.xml' }
          post  { always { junit 'unit.xml' } }
        }
        stage('SCA scan') {
          agent { label 'docker' }
          steps { sh 'docker run --rm -v "$PWD":/src aquasec/trivy:latest fs --exit-code 1 --severity HIGH,CRITICAL /src' }
        }
      }
    }
    stage('Build image') {
      agent { label 'docker' }
      steps { sh 'docker build -t app:$BUILD_NUMBER .' }
    }
  }
}
```
Console lines are prefixed with the branch name:
```
[Lint] + ruff check .
[Unit tests] + pytest -q --junitxml=unit.xml
[SCA scan] + docker run --rm ... trivy ...
[Lint] All checks passed!
[Unit tests] 12 passed in 1.84s
```
In the Stages graph you see three boxes side by side.

### Matrix

```groovy
stage('Test matrix') {
  matrix {
    axes {
      axis { name 'PYTHON'; values '3.11', '3.12', '3.13' }
      axis { name 'DB';     values 'postgres', 'sqlite' }
    }
    excludes {
      exclude { axis { name 'PYTHON'; values '3.11' }; axis { name 'DB'; values 'sqlite' } }
    }
    agent { docker { image "python:${PYTHON}-slim" } }
    stages {
      stage('Test') { steps { sh 'echo "python $PYTHON with $DB"; python --version' } }
    }
  }
}
```
This creates 5 parallel cells (6 combinations minus 1 excluded). Axis values are available as environment variables (`$PYTHON`, `$DB`).

### Scripted-style dynamic parallel (when the branches come from data)

```groovy
script {
  def services = ['api', 'worker', 'scheduler']
  def branches = services.collectEntries { s -> [(s): { sh "make -C ${s} test" }] }
  parallel branches
}
```

---

## Deeper dive

### What actually runs in parallel

- Each branch is a separate **thread of the CPS program** on the controller. The Groovy decisions run on the controller; the `sh` steps run wherever each branch's `agent` is.
- **No agent in the branches** → all branches run on the **parent's executor and workspace**. Steps still interleave, but two branches writing `target/` at the same time will corrupt each other. Give branches their own agents, or their own folders with `dir('lint') { … }`.
- **Each branch with an agent** needs a free executor. With 3 branches but 1 executor, they queue and you gain nothing.

### Sequential stages inside a parallel branch

A branch can contain a whole sequence:
```groovy
stage('Platforms') {
  parallel {
    stage('Linux') {
      agent { label 'linux' }
      stages {                                         // sequential inside this branch
        stage('Build') { steps { sh 'make' } }
        stage('Test')  { steps { sh 'make test' } }
      }
    }
    stage('Windows') {
      agent { label 'windows' }
      stages {
        stage('Build') { steps { bat 'build.cmd' } }
        stage('Test')  { steps { bat 'test.cmd' } }
      }
    }
  }
}
```
Declarative allows `parallel` → `stage` → `stages`, but not `parallel` directly inside another `parallel`.

### Results and failFast

- The parallel stage's result = the **worst** branch result.
- Without failFast, the other branches **finish** even after one fails. That's useful for collecting all test results.
- With `failFast true` (or `parallelsAlwaysFailFast()`), the others are **aborted** when one fails. They show as ABORTED, and their `post { always }` still runs.
- Combine with `catchError` inside a branch if one branch is "optional" and must never cancel the others.

### Matrix details

```groovy
matrix {
  agent { label "${PLATFORM}" }                 // axis values usable in agent labels
  when { anyOf { expression { env.BRANCH_NAME == 'main' }; expression { PYTHON == '3.13' } } }
  axes {
    axis { name 'PLATFORM'; values 'linux', 'windows' }
    axis { name 'PYTHON';   values '3.12', '3.13' }
  }
  stages {
    stage('Test') { steps { echo "Testing ${PYTHON} on ${PLATFORM}" } }
  }
  post { always { echo "cell ${PLATFORM}/${PYTHON} done" } }
}
```
- Cells are named after their axis values, e.g. `Matrix - PLATFORM = 'linux', PYTHON = '3.12'`.
- `when` at matrix level filters cells (here: all cells on `main`, only Python 3.13 elsewhere).
- Big matrices multiply fast (3 × 4 × 3 = 36 cells): watch executor capacity and use `excludes`.

### Throttling and capacity

- Limit how many parallel builds hit a shared resource with `lock(label: …, quantity: n)` (topic 38) or the *Throttle Concurrent Builds* plugin.
- Rough capacity check: if a PR pipeline runs 4 parallel branches on separate agents and 10 PRs push at once, you need about 40 executors to avoid queueing.

---

## Hands-on lab

1. Turn the three checks above into a pipeline for your Flask repo (any small checks work: `sleep 20; echo lint` etc. if you don't have tests).
2. Compare total time with the same three stages run one after another.
3. Make one branch fail and watch `failFast` abort the others (`Failed in branch Lint`).
4. Set the built-in node to 1 executor with `agent { label 'built-in' }` per branch, and watch branches queue.

---

## Where you'll use it

- PR CI: lint + unit + scans in parallel.
- Libraries/SDKs: matrices of language versions and OSes.
- Monorepos: build changed services in parallel.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Branches overwrite each other's files | Shared parent workspace | Separate agents per branch, or separate subdirectories (`dir('x')`) |
| Parallel stage is no faster | Not enough executors | Add agents/executors; check the queue |
| `Invalid config option "parallel" for agent type …` / nesting errors | `parallel` inside `parallel` (declarative forbids deep nesting) | Flatten, or use `matrix` |
| One flaky branch keeps cancelling the others | failFast on flaky tests | Fix the flakiness; only use failFast for real gates |

---

## Quick recap

- `parallel { stage… }` runs sub-stages simultaneously; each can have its own agent.
- `failFast` / `parallelsAlwaysFailFast()` stop siblings on the first failure.
- `matrix` = axes × values (+ excludes) → generated parallel cells.
- Parallelism is limited by free executors.

**Interview questions**

1. **Q: How do you speed up a slow CI pipeline?**
   A: Run independent checks in parallel on separate agents, cache dependencies, move slow suites out of the merge gate, and make sure there are enough executors.

2. **Q: What does `failFast` do?**
   A: As soon as one parallel branch fails, the other branches are aborted instead of running to completion.

3. **Q: When would you use `matrix`?**
   A: To run the same stages across combinations of variables (e.g. language versions × OS) without duplicating stage code.
