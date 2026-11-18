# 35 · `post` Conditions

> **Level:** ★★ intermediate · **Status:** 🔀 merged (Day 06 + Project 01)
>
> **You will learn:** the `post` section: where it goes, every condition (`always`, `success`, `failure`, `unstable`, `aborted`, `changed`, `fixed`, `regression`, `unsuccessful`, `cleanup`), the order they run in, stage-level `post`, and real uses per outcome.
>
> **You need:** topic 31.
>
> **From your original notes:** Day 06 › *2) Post actions* · Project 01 › *Post Actions in Jenkins Pipeline* (pipeline snippet, explanation, why outside `stages`, correct structure), *Real-world usage by outcome*.

---

## What it is

A **`post`** block defines actions Jenkins runs **after** the pipeline (or a stage) finishes, depending on the **result**. It's the pipeline's `finally`: notifications, reports, cleanup.

```groovy
post {
  success { echo "Build ${env.BUILD_NUMBER} succeeded" }
  failure { echo "Build ${env.BUILD_NUMBER} failed" }
  always  { echo "Build ${env.BUILD_NUMBER} finished" }
}
```

---

## Why it exists

Without `post`, a failing stage stops the pipeline and your notification or cleanup code never runs. `post` guarantees "always do this", and "do this only on failure".

---

## Analogy

The **closing checklist** at a shop: whatever kind of day it was, you always lock up (`always`/`cleanup`); on a good day you post the takings (`success`); on a bad day you call the manager (`failure`).

---

## How it works inside

### Where it goes

From Project 01: the `post` block sits at the end of the Jenkinsfile, **outside `stages {}`**, because it applies to the *pipeline as a whole*, not to a stage. Inside `stages`, Jenkins would expect a `stage` and throw a validation error.

```groovy
pipeline {
  agent any

  stages {
    stage('Build') { ... }
    stage('Deploy') { ... }
  }

  post {
    success { ... }
    failure { ... }
    always  { ... }
  }
}
```
You can **also** put a `post` inside a `stage` (after its `steps`); it runs when that stage ends.

### The conditions

| Condition | Runs when |
|---|---|
| `always` | every time, whatever the result |
| `success` | result is SUCCESS |
| `failure` | result is FAILURE |
| `unstable` | result is UNSTABLE (e.g. tests failed but the build continued, topic 41) |
| `aborted` | someone/something aborted the build (manually, timeout) |
| `unsuccessful` | result is anything except SUCCESS |
| `changed` | result differs from the previous build's |
| `fixed` | this build succeeded and the previous one failed/was unstable |
| `regression` | this build failed/unstable/aborted and the previous one succeeded |
| `cleanup` | **last**, after all other conditions, every time |

**Order:** `always` → `changed` → `fixed` → `regression` → `aborted` → `failure` → `success` → `unstable` → `unsuccessful` → `cleanup`. That's why cleanup belongs in `cleanup`: it runs after notifications and archiving have used the workspace.

### Explanation (from Project 01)

- `post { … }`: a global section that defines actions Jenkins runs after the pipeline completes, regardless of what happened inside the stages.
- `success { … }`: runs only when the **entire pipeline** succeeds. Common uses: deployment notifications, pushing artifacts, tagging builds as stable.
- `failure { … }`: runs when **any stage fails**. Production uses: alerts, paging on-call, creating Jira tickets, logging failure metrics.
- `always { … }`: runs **every time**, even if the pipeline was aborted, unstable or failed. Production uses: workspace cleanup, log archiving, closing external sessions, Slack notifications, cleaning Docker images, deleting temp files.

### Real-world usage by outcome

**Success:**
- Notifications: Slack, Teams, email for successful builds.
- Git ops: tag commits or comment on PRs when builds pass.
- Reports: publish JUnit, coverage and security summaries.

**Failure:**
- Notifications: alert developers or on-call immediately.
- Rollbacks: trigger rollback pipelines or mark the deployment failed.
- Debug data: upload logs or diagnostic bundles for triage.

**Always:**
- Cleanup: remove temp files, old artifacts, Docker images.
- Observability: push metrics/logs to CloudWatch, Datadog, Prometheus, ELK.
- Housekeeping: archive artifacts and close active sessions.

---

## Config / Jenkinsfile / commands

A production-shaped `post`:
```groovy
post {
  always {
    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
    archiveArtifacts artifacts: 'deploy-info-*.txt', allowEmptyArchive: true, fingerprint: true
  }
  failure   { echo "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER} ${env.BUILD_URL}" }   // → Slack, topic 71
  fixed     { echo "Back to green: ${env.JOB_NAME}" }
  cleanup   {
    sh 'docker image prune -f || true'
    cleanWs()
  }
}
```
Console on a failed build (shape):
```
[Pipeline] { (Declarative: Post Actions)
[Pipeline] junit
Recording test results
[Pipeline] archiveArtifacts
[Pipeline] echo
FAILED: flask-pipeline #12 http://localhost:8080/job/flask-pipeline/12/
[Pipeline] sh
+ docker image prune -f
[Pipeline] cleanWs
[WS-CLEANUP] Deleting project workspace...
Finished: FAILURE
```

Stage-level `post`:
```groovy
stage('Integration tests') {
  steps { sh './run-it.sh' }
  post  { always { junit 'it-reports/*.xml' } }
}
```

---

## Hands-on lab

1. Add the Day 06 three-condition `post` to `flask-pipeline`, run green.
2. Add `sh 'exit 1'` to a stage: see `failure` and `always` run, not `success`.
3. Fix it: on the next build, add `fixed { echo 'fixed!' }` and see it fire once.
4. Abort a running build (`sleep 60` stage, then click ✖): see `aborted`.
5. Move your `cleanWs()` from a `cleanup` stage into `post { cleanup { … } }`.

---

## Where you'll use it

Every production pipeline: test reports, notifications, cleanup.

---

## When it breaks

| Error / symptom | Cause | Fix |
|---|---|---|
| `Unknown stage section "post"` / `Expected a stage` | `post` placed inside `stages {}` | Move it after the `stages` block (or inside a `stage`) |
| Cleanup never runs when the build fails | Cleanup is a *stage*, which is skipped after a failure | Put it in `post { cleanup {} }` (topic 36) |
| `post` step fails: `No workspace` / `Required context class hudson.FilePath is missing` | `agent none` at the top: post has no node | Wrap in `node('label') { … }` or give the pipeline an agent |
| Notification sent twice | Same message in `always` and `failure` | Pick one condition per message |

---

## Quick recap

- `post` goes after `stages` (pipeline level) or inside a `stage`.
- Conditions: `always`, `success`, `failure`, `unstable`, `aborted`, `unsuccessful`, `changed`, `fixed`, `regression`, `cleanup`.
- `cleanup` runs last, every time: put workspace cleanup there.
- Use `success`/`failure`/`fixed` for notifications and `always` for reports.

**Interview questions**

1. **Q: Why must `post` be outside `stages`?**
   A: `stages` may only contain `stage` blocks. `post` at pipeline level applies to the whole run, after all stages, whatever their result.

2. **Q: Difference between `always` and `cleanup`?**
   A: Both run every time, but `cleanup` runs after every other post condition, so it's the safe place to delete the workspace after reports and notifications have used it.

3. **Q: What's the difference between `fixed` and `success`?**
   A: `success` runs on every successful build; `fixed` only when this build succeeds after a failed or unstable one. It's good for "back to green" notifications.
