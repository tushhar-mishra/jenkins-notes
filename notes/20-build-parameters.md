# 20 · Build Parameters

> **Level:** ★ foundation · **Status:** 🔀 merged (Day 03 key point + Day 04 demos 1–2)
>
> **You will learn:** how to make one job reusable with typed inputs (boolean, choice, string), how parameters reach your shell as environment variables, how to build a chosen branch or tag, and why parameters matter for audit and rollback.
>
> **You need:** topics 17–19.
>
> **From your original notes:** Day 04 › *Mini Demos — your pipeline foundation* (intro), *Mini Demo 1 — Add Parameters (Boolean, Choice)* (setup, build step, post-build, production notes), *Mini Demo 2 — Git SCM + Branch as a Parameter* (setup, build step, production notes) · Day 03 › *Key points: Parameters*.

---

## What it is

A **build parameter** is a named input a user (or another job, or the API) supplies when starting a build. Ticking **This project is parameterized** changes **Build Now** into **Build with Parameters**, which shows a small form.

Common types:

| Type | Example | Value in the shell |
|---|---|---|
| **Boolean** | `RUN_TESTS` ☑ | `true` / `false` |
| **Choice** | `ENV` = dev / stage / prod | the chosen string |
| **String** | `BRANCH` = `main` | the text typed |
| **Password** | `API_KEY` | masked in the UI (but prefer **Credentials**, topic 23) |
| **Text**, **File**, and more via plugins (e.g. Active Choices) | | |

Every parameter becomes an **environment variable** of the same name in the build.

These demos are the building blocks for everything that follows: parameters, Git integration, triggers and a nightly job will become the base of the full pipelines we create later.

---

## Why it exists

Without parameters you clone a job per environment or per branch ("deploy-dev", "deploy-stage", "deploy-prod") and they drift apart. Parameters turn "mysterious shell flags" into **auditable inputs** visible on each build's page: who ran it, with which values.

---

## Analogy

A **coffee machine with buttons**: one machine, but you choose size, strength and milk. The receipt (build page) records exactly what you ordered.

---

## How it works inside

1. You click **Build with Parameters**, fill the form, submit.
2. The build is queued with a **ParametersAction**: the values are stored in `builds/<n>/build.xml`.
3. When steps run, Jenkins exports each parameter as an environment variable.
4. The build page's **Parameters** link shows the values for ever (until the build is discarded).
5. Two queued builds with **different** parameter values are kept as separate builds; identical ones may be merged by the queue.

---

## Config / Jenkinsfile / commands

### Mini demo 1: add parameters (Boolean, Choice)

**Goal:** let users toggle tests and pick a target environment; see how params appear as env vars.

**Setup:** edit a job (or create a new one) → **This project is parameterized** →
- **Boolean Parameter:** `RUN_TESTS` (default: ✅ true)
- **Choice Parameter:** `ENV`, choices (one per line): `dev`, `stage`, `prod`. The first line is the default.

**Build step (Execute shell):**
```bash
echo "RUN_TESTS=$RUN_TESTS ENV=$ENV"
echo "Report for #$BUILD_NUMBER (env=$ENV)" > report-$ENV.txt
if [ "$RUN_TESTS" = "true" ]; then
  echo "Running tests..."; sleep 1; echo "OK"
else
  echo "Skipping tests."
fi
```

**Post-build action:** Archive `report-*.txt`.

Console with `RUN_TESTS` unticked and `ENV=stage`:
```
Started by user admin
+ echo RUN_TESTS=false ENV=stage
RUN_TESTS=false ENV=stage
+ echo Report for #4 (env=stage)
+ [ false = true ]
+ echo Skipping tests.
Skipping tests.
Archiving artifacts
Finished: SUCCESS
```
`[ "$RUN_TESTS" = "true" ]` is a shell string comparison (Linux notes topic 042): the boolean arrives as the **text** `true`/`false`.

**Production note (why it matters):** parameters turn hidden shell flags into **auditable inputs** shown on the build page, which improves change control and rollback.
- **Hotfix example:** tick `RUN_TESTS=false` for a critical fix where unit tests take 20 minutes and the SLA is 5 minutes; straight after, re-run with `RUN_TESTS=true` on `dev` to validate. The build history shows exactly which run skipped tests, who ran it, and for which `ENV`.
- **Regulated teams:** keep `ENV` choices locked to `dev/stage/prod`. Release managers can enforce approvals per environment while engineers still use one job.
- **Rollback:** the archived `report-$ENV.txt` and the parameters stored on the build record give a clear breadcrumb of what was deployed where.

### Mini demo 2: Git SCM + branch as a parameter

**Goal:** check out a chosen branch and print commit info.

**Setup:**
- Add a **String Parameter**: `BRANCH`, default `main`.
- **SCM → Git** → repo URL, credentials → **Branches to build:** `$BRANCH` (or `*/$BRANCH`).

**Build step (Execute shell):**
```bash
echo "Built from BRANCH=$BRANCH"
git --version
echo "Latest commit:"
git log --oneline -n 1 || true
echo "Jenkins vars: GIT_BRANCH=$GIT_BRANCH GIT_COMMIT=$GIT_COMMIT"
```
```
+ echo Built from BRANCH=release/1.8
+ git log --oneline -n 1
a7c3e19 fix: CVE patch for loan calc
+ echo Jenkins vars: GIT_BRANCH=origin/release/1.8 GIT_COMMIT=a7c3e19f2…
```
Note `GIT_BRANCH` includes the remote name (`origin/…`), and `GIT_COMMIT` is the full 40-character SHA.

**Production note:** branch/tag as an input lets you **promote or backport** without cloning jobs or editing XML.
- **Release backport:** a security fix needs to ship on `release/1.8`. Set `BRANCH=release/1.8` and run. The build records `GIT_COMMIT`, so you can later prove which commit went to which environment.
- **Tag pinning:** for reproducible deployments, accept a `TAG` instead of a `BRANCH` (branch spec `refs/tags/v1.8.3`). Each release becomes a **commit-anchored artifact**, easy to diff and roll back.
- **Ops handover:** SREs can deploy the same artifact to `stage` and `prod` by changing parameters, not jobs, reducing drift.

### Pipeline equivalent (preview of topic 37)

```groovy
pipeline {
  agent any
  parameters {
    booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run unit tests?')
    choice(name: 'ENV', choices: ['dev', 'stage', 'prod'], description: 'Target environment')
    string(name: 'BRANCH', defaultValue: 'main', description: 'Branch to build')
  }
  stages {
    stage('Info') { steps { echo "ENV=${params.ENV} RUN_TESTS=${params.RUN_TESTS}" } }
  }
}
```
In pipelines, read them as `params.NAME` (typed: a boolean really is a boolean) or `env.NAME` (always a string).

### Starting a parameterised build from the command line

```bash
curl -X POST -u admin:$TOKEN \
  "http://localhost:8080/job/intro-freestyle/buildWithParameters?ENV=stage&RUN_TESTS=false"
```
(Topic 70 covers the API, tokens and CSRF.)

---

## Hands-on lab

1. Add `RUN_TESTS`, `ENV` and `BRANCH` to `intro-freestyle` as above.
2. Create a `release/1.8` branch in your `jenkins-lab` repo with a different commit.
3. Build with `BRANCH=release/1.8`, `ENV=stage`, tests off. Then `BRANCH=main`, `ENV=dev`, tests on.
4. Compare the two builds' **Parameters** pages and archived reports.
5. Trigger one build with the `curl` command above (create an API token first).

---

## Where you'll use it

- One deploy job for all environments (with approval rules per environment, topic 38).
- Backports, hotfixes and re-deploys of an older tag.
- Manual "ops" jobs (rotate a key, clear a cache) with safe, limited inputs.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `$ENV` is empty in the build | Typo in the parameter name, or the build was started without parameters (plain Build Now via API) | Match names exactly; use `buildWithParameters` |
| Choice default isn't what you expected | The first line of the choice list is the default | Reorder the choices |
| Branch param ignored, always builds `main` | Branch spec still hard-coded | Use `$BRANCH` in **Branches to build** |
| Secret visible in build parameters | Used a String/Password parameter for a secret | Use Credentials + binding (topics 23–24) |
| Pipeline: new parameters don't appear | Declarative `parameters {}` only registers after the first run | Run once, then **Build with Parameters** appears |

---

## Quick recap

- Parameters make one job reusable; each becomes an environment variable.
- Boolean values arrive in the shell as `true`/`false` strings.
- Branch/tag parameters enable backports and reproducible deploys of exact commits.
- Parameters are stored on each build: an audit trail of who ran what, with which inputs.
- Never pass secrets as parameters.

**Interview questions**

1. **Q: How do parameters reach a shell step?**
   A: Jenkins exports each one as an environment variable with the same name, e.g. `$ENV`. In pipelines you can also use `params.ENV`, which keeps the type.

2. **Q: Why are parameters useful for audit?**
   A: Each build stores the parameter values and who started it, so you can see exactly which inputs (environment, branch, flags) produced each deploy.

3. **Q: Should you pass a password as a build parameter?**
   A: No. Store it in Jenkins Credentials and bind it at run time; parameters are visible on the build page and in the API.
