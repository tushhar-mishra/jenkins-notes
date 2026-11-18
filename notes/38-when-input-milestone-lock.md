# 38 · `when`, Approvals and Locks

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** how to run a stage only under certain conditions (`when`: branch, tag, changed files, expressions, environment), how to pause for a human approval (`input`), how to make sure older builds never deploy after newer ones (`milestone`), and how to stop two builds from using the same environment at once (`lock`).
>
> **You need:** topics 09 (promotion flows), 31, 37.
>
> **From your original notes:** Day 06 › *Why pipelines* (`when {}`, `input` approvals) · Day 07 › *Ops tip:* `disableConcurrentBuilds()` + `milestone()` so the newest push wins · Day 02 › approvals before production.

---

## What it is

| Feature | Purpose |
|---|---|
| `when { }` | Decide whether a **stage** runs |
| `input` | Pause until an authorised human clicks **Proceed** (or **Abort**) |
| `milestone(n)` | Builds passing milestone *n* cancel **older** builds that haven't reached it yet |
| `lock('name')` | A named mutex: only one build at a time may hold it (Lockable Resources plugin) |

---

## Why it exists

One Jenkinsfile must behave differently per branch (deploy only from `main`), wait for approvals before production, and never let two deploys overwrite each other or an old build deploy over a new one.

---

## Analogy

An airport: `when` is the gate check ("only passengers for flight X"); `input` is passport control (a human must stamp it); `milestone` stops a late passenger from boarding a flight that has already left with newer passengers; `lock` is the single runway: one plane at a time.

---

## How it works inside

- `when` is evaluated when the stage is reached. If false, the stage shows as **skipped** (grey) and its `post` doesn't run. By default it's evaluated **after** the stage's agent is allocated; `beforeAgent true` checks first (saves spinning up an agent), and `beforeInput true` checks before an `input`.
- `input` creates a paused step. **While paused inside an `agent`, it holds an executor**, so put `input` in a stage with **no agent** (or use the stage-level `input` directive, which is evaluated before the agent). Always wrap it in a `timeout`.
- `milestone` ordinals must increase through the pipeline. When build #12 passes milestone 2, any older build (#11) still before milestone 2 is aborted.
- `lock` waits in a queue until the resource is free, then holds it for the block.

---

## Config / Jenkinsfile / commands

### `when` conditions

```groovy
stage('Deploy dev') {
  when { branch 'main' }                         // only on main (multibranch BRANCH_NAME)
  steps { sh './deploy.sh dev' }
}
stage('Release') {
  when { buildingTag() }                         // any tag build; or: tag pattern: 'v*', comparator: 'GLOB'
  steps { sh './release.sh' }
}
stage('Docs only') {
  when { changeset 'docs/**' }                   // files changed in this build
  steps { sh 'make docs' }
}
stage('PR checks') {
  when { changeRequest target: 'main' }          // PR builds targeting main
  steps { sh 'make lint' }
}
stage('E2E') {
  when {
    beforeAgent true
    allOf {
      branch 'main'
      expression { params.RUN_E2E }              // any Groovy boolean
      not { environment name: 'SKIP_E2E', value: 'true' }
    }
  }
  agent { label 'e2e' }
  steps { sh './e2e.sh' }
}
```
Other conditions: `anyOf`, `triggeredBy 'TimerTrigger'` / `'SCMTrigger'` / `cause: 'UserIdCause'`, `equals expected: 'x', actual: env.Y`.

### `input`: approvals

Stage-level directive (preferred, no executor held while waiting):
```groovy
stage('Deploy prod') {
  when { branch 'main' }
  options { timeout(time: 4, unit: 'HOURS') }
  input {
    message 'Deploy to PRODUCTION?'
    ok 'Deploy'
    submitter 'release-managers,alice'          // users or groups allowed to approve
    parameters { string(name: 'CHANGE_TICKET', description: 'CR number') }
  }
  agent { label 'deploy' }
  steps { sh './deploy.sh prod "$CHANGE_TICKET"' }
}
```
Console while waiting:
```
Deploy to PRODUCTION?
Deploy or Abort
```
The build page shows **Paused for Input**, with buttons. After approval:
```
Approved by alice
```
The approver's name is recorded: an audit trail for change control.

### `milestone`: the newest build wins

```groovy
stages {
  stage('Build')   { steps { milestone(1); sh 'make build' } }
  stage('Approve') { steps { milestone(2); input 'Deploy?' } }
  stage('Deploy')  { steps { milestone(3); sh './deploy.sh' } }
}
```
If #11 is waiting at the approval and #12 reaches milestone 2, #11 is aborted: `Superseded by #12`. Approving a stale build is no longer possible.

### `lock`: one build per environment

```groovy
stage('Deploy stage') {
  options { lock(resource: 'env-stage') }          // whole stage under the lock
  steps { sh './deploy.sh stage' }
}
// or around a block:
lock(resource: 'env-stage', inversePrecedence: true) { sh './deploy.sh stage' }
```
`inversePrecedence: true` gives the lock to the **newest** waiting build. Resources can be predefined in **Manage Jenkins → System → Lockable Resources**, or created on the fly.

---

## Deeper dive

### The evaluation order of a stage

For each stage, declarative does these steps in this order (and the `before…` flags move `when` earlier):

```
1. when            ← if beforeAgent / beforeInput / beforeOptions is true, evaluated first
2. options         (stage-level timeout/retry/lock start here)
3. input           (pause for approval)
4. agent           (get an executor; container started)
5. when            ← default position: AFTER the agent is allocated
6. environment
7. steps
8. post
```
So without `beforeAgent true`, a skipped stage still **waits for and allocates an agent** (maybe spins up a pod) just to decide to skip. With an `input` stage you usually want `beforeInput true`, so nobody is asked to approve a stage that won't run.

### Condition semantics you'll trip over

- **`changeset`** compares against the **previous build of this job**. On the first build of a branch there's no changeset, so the condition is **false** and the stage is skipped. Add `anyOf { changeset '…'; expression { currentBuild.previousBuild == null } }` if the first build must run it.
- **`branch 'main'`** matches `BRANCH_NAME`, which only exists in multibranch jobs. For PR builds `BRANCH_NAME` is `PR-12`, so `branch 'main'` is false on PRs (usually what you want). Patterns: `branch pattern: 'release/.*', comparator: 'REGEXP'`.
- **`changeRequest`** attributes: `changeRequest target: 'main'`, `branch: 'feature/*'`, `fork: '.*'` (true for fork PRs), `author: 'dependabot*'`.
- **`buildingTag()`** only fires if tag discovery is on and the tag build was triggered (multibranch tag builds aren't automatic, topic 43).
- **`expression { … }`** must return a real boolean; `env.X` values are strings (`env.FLAG == 'true'`).

### `input` in depth

```groovy
stage('Prod approval') {
  when { beforeInput true; branch 'main' }
  options { timeout(time: 2, unit: 'HOURS') }
  input {
    message 'Deploy to PRODUCTION?'
    ok 'Deploy'
    submitter 'release-managers'
    submitterParameter 'APPROVER'           // the approver's user ID lands in env.APPROVER
    parameters { choice(name: 'STRATEGY', choices: ['canary', 'blue-green']) }
  }
  steps { sh './deploy.sh prod "$STRATEGY" "$APPROVER"' }
}
```
- Parameters and `submitterParameter` become **environment variables** inside that stage.
- `submitter` takes user IDs or **group names** from your security realm (topic 65). Admins can always approve.
- The `input` *step* (inside `steps`/`script`) returns the submitted value(s) instead: `def r = input(message: '…', parameters: [...])`. If used inside an agent block it holds the executor while waiting; prefer the directive.
- An approval can also be given through the API: `POST /job/<job>/<n>/input/<id>/proceedEmpty` (the id is shown on the paused build's page).

### `milestone` semantics

- Ordinals must **increase** along the pipeline (`milestone(1)`, `milestone(2)`…; without arguments Jenkins numbers them automatically).
- Rule: *when build N passes milestone M, any older build that hasn't passed M yet is aborted*. Older builds already past M aren't touched.
- Builds are compared **per job** (per branch job in multibranch).
- Typical placement: one before the expensive part, one just before each deploy/approval.

### `lock` in depth (Lockable Resources plugin)

```groovy
lock(resource: 'env-stage', inversePrecedence: true) { … }      // one named resource
lock(label: 'device-farm', quantity: 2, variable: 'DEVICES') {  // any 2 resources labelled device-farm
  sh 'echo "using $DEVICES"'                                    // e.g. "phone-03,phone-07"
}
```
- Resources live globally (Manage Jenkins → Lockable Resources), so locks work **across jobs**, unlike `disableConcurrentBuilds`.
- `inversePrecedence: true`: the newest waiter gets the lock next (combine with `milestone` so older ones are aborted).
- Locks are released when the block ends, even on failure or abort.

---

## Hands-on lab

1. In your multibranch lab (topic 47), or with an inline pipeline using `when { expression { env.BRANCH_NAME == 'main' } }`, make the deploy stage skip on non-main branches.
2. Add the `Deploy prod` stage with `input`; run it, approve it; run it again and click **Abort** (result: ABORTED); run it again and let a 1-minute timeout expire.
3. Add milestones; start two builds; approve neither; watch the older one get superseded once the newer reaches milestone 2.
4. Add `lock('env-stage')` around a `sleep 30` deploy and run two builds: the second waits (`Trying to acquire lock on [Resource: env-stage]`).

---

## Where you'll use it

- `when { branch 'main' }` in nearly every multibranch Jenkinsfile.
- `input` for production gates and change-ticket capture.
- `lock`/`milestone` for shared environments and fast-moving PRs.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `when { branch 'main' }` never true | Not a multibranch job (no `BRANCH_NAME`) | Use multibranch, or `expression { env.GIT_BRANCH == 'origin/main' }` |
| All executors busy, builds waiting at input | `input` inside an agent holds executors | Stage-level `input` directive / agent-less stage |
| Approval waits forever | No timeout | `timeout` around the input |
| Anyone can approve | No `submitter` | Set submitter users/groups (needs proper authorization, topic 65) |
| `No such DSL method 'lock'` | Lockable Resources plugin missing | Install it |

---

## Quick recap

- `when` gates stages (branch, tag, changeset, changeRequest, expression, environment; `beforeAgent`).
- `input` = human approval; use the stage directive, a `submitter` and a `timeout`.
- `milestone` aborts older builds; `lock` serialises access to a shared resource.

**Interview questions**

1. **Q: How do you deploy only from `main` in a multibranch pipeline?**
   A: `when { branch 'main' }` on the deploy stages, usually with `beforeAgent true`.

2. **Q: What's the problem with `input` inside an `agent` block?**
   A: The paused build holds an executor (and the workspace) while waiting. Use the stage-level `input` directive or an agent-less stage, with a timeout.

3. **Q: `lock` vs `disableConcurrentBuilds`?**
   A: `disableConcurrentBuilds` prevents concurrent builds of *one job*. `lock` protects a *named resource* across many jobs, e.g. one deploy to the staging environment at a time.
