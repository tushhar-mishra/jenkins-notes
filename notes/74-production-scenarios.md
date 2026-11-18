# 74 · Production Scenarios

> **Level:** ★★★ advanced · **Status:** 🆕 new topic
>
> **You will learn:** to apply the whole course to realistic incidents and design problems, each walked through as **symptom → investigation → root cause → fix → prevention**, the way you'd answer a senior DevOps/SRE scenario question.
>
> **You need:** the whole course (each scenario links its topics).

---

## What it is

Ten scenarios that combine several topics. Try to answer each yourself before reading the walk-through.

---

## Why it exists

Interviews for mid/senior roles are mostly "tell me how you'd handle…" questions. Real incidents are never about one topic.

---

## Analogy

Flight-simulator emergencies: you've learnt every instrument; now practise the engine failure on take-off.

---

## How it works inside: the scenarios

### 1. "Jenkins is down after the weekend plugin updates"

- **Symptom:** the controller restarts in a loop; the UI shows "Jenkins is starting" forever or a stack trace.
- **Investigate:** `journalctl -u jenkins` / `docker logs` → `Failed Loading plugin … Update required: X to be updated to …` or `… requires a newer version of Jenkins`.
- **Root cause:** someone clicked "update all" on production; one plugin needs a newer core, cascading failures.
- **Fix:** roll back to the last known-good image/plugin set (or restore the snapshot taken before; topic 68). Then reproduce the update on staging, fix versions, and roll forward in a window.
- **Prevention:** pinned `plugins.txt` + custom image + staging + JCasC (topics 66–67); restrict Overall/Administer.

### 2. "Builds wait for hours every morning"

- **Investigate:** the queue's `why` = `Waiting for next available executor on 'docker'`; Load Statistics shows queue spikes at 9–10 AM; agents fine.
- **Root cause:** capacity: static agents sized for an average day; everyone pushes after stand-up.
- **Fix/prevention:** cloud/Kubernetes agents that scale with demand (topic 53); `disableConcurrentBuilds(abortPrevious: true)` on PR jobs so superseded pushes don't consume executors (topic 37); parallel stages on separate agents; move nightly heavy jobs out of working hours.

### 3. "An AWS key leaked from a build log"

- **Investigate:** someone printed `env` in a debug step, or the secret was used in a double-quoted `sh` string and appeared in a transformed form (base64), unmasked.
- **Root cause:** a long-lived secret in Jenkins + careless pipeline code.
- **Fix:** **revoke/rotate the key immediately**; delete the build logs; check CloudTrail for misuse.
- **Prevention:** IAM roles/IRSA/OIDC instead of keys (topics 24, 61); single-quoted `sh`; folder-scoped credentials; PR review of Jenkinsfiles; secret scanning of logs.

### 4. "PR builds overwrite the staging app"

- **Symptom:** QA reports staging randomly shows unmerged features.
- **Root cause:** one Jenkinsfile for all branches with an unconditional deploy stage (exactly the original Day 07 Jenkinsfile, topic 47).
- **Fix:** `when { branch 'main' }` on deploy stages; ephemeral PR previews; tag images by commit SHA.
- **Prevention:** a shared-library template with these rules built in (topic 58).

### 5. "Agents keep going offline in the afternoon"

- **Investigate:** node logs → `Disk space is too low`; on the agent, `docker system df` shows 60 GB of images and build cache; `du` shows hundreds of PR workspaces.
- **Fix:** prune Docker, clean workspaces, bring the nodes online.
- **Prevention:** scheduled cleanup job (topic 22), `post { cleanup { cleanWs() } }`, multibranch orphan strategy, ephemeral agents, disk alerts (topic 69).

### 6. "The deploy succeeded but production is broken"

- **Investigate:** `kubectl rollout status` returned success after 60 s, but the app returns 500s; the Deployment has no readiness probe.
- **Root cause:** Kubernetes considered pods "ready" as soon as the process started; the pipeline's rollback check had nothing meaningful to check (topic 63).
- **Fix:** roll back (`kubectl rollout undo` / revert the GitOps commit).
- **Prevention:** readiness/liveness probes; post-deploy smoke tests that can fail; canary with SLO-based automatic rollback (topics 09, 64).

### 7. "Restore drill: credentials are all broken"

- **Root cause:** the backup excluded `secrets/` ("it looked sensitive").
- **Fix:** restore `secrets/` from the same instance's backup; if lost, every credential must be re-entered.
- **Prevention:** backup includes `secrets/` (encrypted at rest); quarterly restore drills that actually run a credentialed job (topic 68); credentials from an external manager so they can be re-synced.

### 8. "A contributor's fork PR tried to print our secrets"

- **Investigate:** a fork PR modified the `Jenkinsfile` to `curl` credentials to an external server.
- **Why it (probably) failed:** with the trust policy "users with Admin or Write permission", untrusted fork PRs run the **target branch's** Jenkinsfile (topic 44).
- **But:** the fork's *code* still ran (tests, build scripts). If that stage had credentials bound, they were exposed.
- **Prevention:** no credentials in stages that run fork code; separate untrusted agent pool; `when { not { changeRequest fork: '.*' } }` for secret stages.

### 9. "Design: CI/CD for 40 microservices on one Jenkins"

A strong answer:
- **Organization Folder** for the GitHub org: every repo with a Jenkinsfile gets a multibranch job automatically (topic 43); a **GitHub App** credential (topic 46).
- A **trusted shared library** with a versioned standard pipeline template (test, scan, build, sign, push, GitOps update) (topic 58).
- **Kubernetes agents** with per-language pod templates; a dependency proxy for caches (topic 53).
- **JCasC + plugins.txt** in a `jenkins-config` repo, custom image, staging controller (topics 66–67).
- **SSO** + role/folder permissions; 0 controller executors (topic 65).
- **Argo CD** for deployments; promotions by PR; deploy by digest (topic 72).
- Monitoring with Prometheus/Grafana; backups + drills (topics 68–69).
- If it grows further: split into several controllers per business unit.

### 10. "Migrate 200 Freestyle jobs to pipelines"

- **Inventory:** export job configs (`/job/X/config.xml`) and group them by pattern (most are 5–10 templates).
- **Build templates** as shared-library steps/pipelines matching those patterns.
- **Move each repo** to a Jenkinsfile calling the template; run old and new in parallel for a while; compare results.
- **Retire** the Freestyle jobs; keep the config XML archived.
- **Guardrails:** JCasC/Job DSL so new Freestyle jobs can't appear by hand.

---

## Config / Jenkinsfile / commands

The scenarios reference commands from their topics. The three you'll use most in incidents:
```bash
journalctl -u jenkins -n 200 --no-pager            # controller start/plugin errors (VM)
curl -s -u admin:$TOKEN "$J/queue/api/json?tree=items[why,task[name]]"   # why builds wait
sudo -i -u jenkins bash -c 'cd ~/workspace/<job> && <failing command>'    # reproduce on the agent
```

---

## Hands-on lab

Pick scenarios 4, 5 and 6 and **recreate them** in your lab (the original Day 07 Jenkinsfile; a filled agent disk; a Deployment without probes on kind). Fix each, then add the prevention.

---

## Where you'll use it

Senior interviews; real incidents; postmortems.

---

## When it breaks

Common interview mistakes: jumping to a fix without investigating; fixing the symptom (raise the gate threshold, `|| true`, `chmod 666`) instead of the cause; forgetting prevention and the postmortem.

---

## Quick recap

For every scenario: **symptom → evidence (logs/metrics) → root cause → immediate fix → prevention**, and mention the trade-offs.

**Interview questions**

1. **Q: Walk me through how you'd handle a leaked credential from a CI log.**
   A: Revoke and rotate immediately, purge the logs, investigate usage (e.g. CloudTrail), then remove the root cause: short-lived identities instead of static keys, single-quoted shell usage, scoped credentials and pipeline code review.

2. **Q: How would you design Jenkins for many teams?**
   A: Organization folders, a versioned trusted shared library, ephemeral Kubernetes agents, JCasC + pinned plugins, SSO with folder permissions, GitOps for deploys, monitoring and tested backups, and splitting controllers when they get large.

3. **Q: A deploy pipeline reported success but production broke. What failed?**
   A: The verification: no readiness probes or real smoke tests, so "rolled out" didn't mean "healthy". Add probes, failing smoke tests and progressive delivery with automatic rollback.
