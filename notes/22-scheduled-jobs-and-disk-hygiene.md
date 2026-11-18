# 22 · Scheduled Jobs and Disk Hygiene

> **Level:** ★ foundation · **Status:** ✅➕ rewritten and expanded
>
> **You will learn:** how to build a nightly job, the safe ways to clean workspaces (Workspace Cleanup plugin vs `rm -rf`), how Jenkins protects itself when disks fill up, and the habits that keep controllers and agents healthy.
>
> **You need:** topics 18, 21.
>
> **From your original notes:** Day 04 › *Mini Demo 5 — Scheduled Nightly (Cron) + Workspace Cleanup* (setup, build step, production notes), *Conclusion* · Day 05 › *E) (Optional, at the very end) Workspace cleanup*.

---

## What it is

- A **scheduled job** runs on a timer (**Build periodically**, cron syntax from topic 21), whether or not code changed.
- **Disk hygiene** = the practices that stop workspaces, build records and Docker images from filling the disks of the controller and agents.

---

## Why it exists

Disk-full is one of the most common Jenkins outages. Multibranch jobs create a workspace per branch and PR; Docker builds leave images and build cache behind; old builds keep logs and artifacts. When an agent's disk fills, builds fail strangely (`No space left on device`, Git corruption) and Jenkins takes the agent offline.

---

## Analogy

A **shared kitchen** at night: the cleaning crew comes at 1:30 AM (nightly job), clears every workstation (workspace cleanup) and empties the bins (old builds, Docker images), so the morning shift starts on clean, empty counters.

---

## How it works inside

### Ways to clean a workspace

| Method | Where | Notes |
|---|---|---|
| **Workspace Cleanup plugin**, Freestyle **Build Environment → Delete workspace before build starts** | start of build | Guarantees a fresh checkout; can exclude patterns (e.g. keep a cache folder) |
| **Post-build Actions → Delete workspace when build is done** | end of build | Options: only on success/failure, patterns, run "asynchronously" (deletes in the background) |
| Pipeline `cleanWs()` | anywhere, best in `post { cleanup { … } }` | Same plugin; topic 35 |
| Pipeline `deleteDir()` | built in | Deletes the *current directory* (the workspace if you're at its root) |
| `rm -rf "$WORKSPACE"/*` in a shell step | end of build | Works, but see the correction below |
| Multibranch **orphaned item strategy** | when a branch/PR is deleted | Removes the job and its workspaces (topic 43) |
| Ephemeral agents (containers/pods) | after every build | The whole agent disappears: cleanest of all (topic 53) |

### How Jenkins reacts to low disk

**Node monitors** (topic 16: `nodeMonitors.xml`) check each node's **Free Disk Space**, **Free Temp Space**, clock and response time every few minutes. If free space drops below the threshold (default **1 GiB**), Jenkins **marks the node offline** (`Disk space is too low. Only 0.812GiB left on /home/jenkins`) so new builds don't land there. Thresholds are in **Manage Jenkins → Nodes → Node Monitoring** (configure them as a percentage or size).

### What eats disk, and where

| Grows on | Culprit | Cure |
|---|---|---|
| **Controller** (`JENKINS_HOME`) | Unlimited build history, big archived artifacts, controller workspaces | Build discarders (topic 18), 0 controller executors |
| **Agents** | Workspaces per job/branch/PR, `@tmp` dirs, tool caches | Cleanup steps, orphan strategy, ephemeral agents |
| **Agents with Docker** | Old images, stopped containers, BuildKit cache | `docker system prune` / `docker builder prune` on a schedule (Docker notes topic 13) |
| **Agents with Maven/npm** | `~/.m2`, `~/.npm` caches | Keep (they speed builds) but cap or rotate them |

---

## Config / Jenkinsfile / commands

### Mini demo 5: scheduled nightly (cron) + workspace cleanup

**Goal:** run at 1:30 AM every night and clean the workspace afterwards.

**Setup:**
- **Build Triggers → Build periodically:** `30 1 * * *` (minute 30, hour 1, every day). Add a `TZ=Asia/Kolkata` first line if the controller isn't in your timezone. For many nightly jobs, prefer `H 1 * * *` so they don't all start at 01:30 exactly.
- Cleanup via the **Workspace Cleanup** plugin (before or after the build), or a shell step.

**Build step (Execute shell):**
```bash
echo "Nightly maintenance on $NODE_NAME"
echo "Workspace: $WORKSPACE" > report.txt
echo "Backing up artifacts"
echo "Cleaning workspace..."
rm -rf "$WORKSPACE"/* || true
```

> ⚠️ **Corrected:** was `rm -rf "$WORKSPACE"/*` presented as the cleanup. Now prefer the **Workspace Cleanup plugin** (or `cleanWs()`/`deleteDir()` in pipelines), because the glob `*` **doesn't match hidden files** (`.git/`, `.env`, `.cache/`), so the old checkout and any secrets written to dotfiles survive. Also, running it in the same step that produced `report.txt` deletes the report **before** a post-build archive step can collect it. If you do use the shell: `find "$WORKSPACE" -mindepth 1 -delete`, and only after archiving.

**Production note:** nightly jobs reduce **daytime risk**; cleanup controls disk growth.
- **Licence/report tasks:** generate dependency licence reports and SBOMs and push them to S3 each night, which keeps release time fast.
- **Cache refresh:** pre-warm Maven/npm caches on agents after weekly base-image updates, so the first builds of the day aren't slow.
- **Disk hygiene:** workspaces from multibranch builds balloon quickly; scheduled cleanup stops agents running out of disk (or the filesystem going read-only) during working hours.

### Workspace cleanup at the end of a deploy job (from Day 05)

After you've confirmed a job works, enable cleanup to save disk:
- **Post-build Actions → Delete workspace when build is done** (Workspace Cleanup plugin), **or** add a final shell step:
  ```bash
  echo "Cleaning workspace..."
  rm -rf "$WORKSPACE"/* || true    # see the correction above: prefer the plugin
  ```

### A real nightly agent-maintenance pipeline (preview of Part 6)

```groovy
pipeline {
  agent { label 'docker' }
  triggers { cron('TZ=Asia/Kolkata\nH 2 * * *') }
  options { timeout(time: 30, unit: 'MINUTES'); buildDiscarder(logRotator(numToKeepStr: '14')) }
  stages {
    stage('Report') {
      steps { sh 'df -h / ; docker system df' }
    }
    stage('Prune Docker') {
      steps { sh 'docker image prune -af --filter "until=168h"; docker builder prune -af --filter "until=168h"' }
    }
  }
  post { cleanup { cleanWs() } }
}
```
- `--filter "until=168h"` only removes things older than 7 days, keeping recent cache for fast builds.
- `post { cleanup { cleanWs() } }` always runs last, even on failure (topic 35).

Sample output:
```
+ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        30G   24G  6.0G  80% /
+ docker system df
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          41        3         17.2GB    15.9GB (92%)
Build Cache     212       0         4.1GB     4.1GB
...
Total reclaimed space: 19.6GB
```

---

## Hands-on lab

1. Create `nightly-maintenance` (Freestyle), **Build periodically** `H/5 * * * *` for testing (every ~5 min), with the Execute shell above but **without** the `rm` line.
2. **Post-build:** Archive `report.txt`, then **Delete workspace when build is done**.
3. Wait for two scheduled builds. Check the cause is `Started by timer`, the report is archived, and the workspace link says the workspace is gone.
4. Change the schedule to `H 1 * * *` (nightly).
5. Open **Manage Jenkins → Nodes**, look at the **Free Disk Space** column and the monitoring thresholds.

---

## Where you'll use it

- Nightly security scans, SBOM/licence reports, dependency-update jobs.
- Scheduled agent and registry cleanups.
- Every multibranch setup (orphan cleanup + workspace cleanup).

---

## When it breaks

| Message | Meaning | Fix |
|---|---|---|
| `No space left on device` | Disk full on the build node | Clean workspaces/Docker; add disk; ephemeral agents |
| Node shows offline: `Disk space is too low` | Node monitor protection | Free space, then **Bring this node back online** |
| Cleanup step fails: `Permission denied` deleting files | Files created by a container as root inside the workspace | Run containers with `-u $(id -u):$(id -g)`, or clean in a container as root |
| Nightly job "didn't run" | Controller timezone differs from yours | Add `TZ=…` to the schedule |
| Report missing from archive | Workspace cleaned before archiving | Archive first, clean last (`post { cleanup {} }`) |

---

## Quick recap

- **Build periodically** = cron schedule; prefer `H` and set `TZ`.
- Clean workspaces with the **Workspace Cleanup** plugin / `cleanWs()`; `rm -rf *` misses dotfiles.
- Archive first, clean last.
- Jenkins takes nodes offline when free disk drops below the monitor threshold.
- Prune Docker on agents on a schedule; prefer ephemeral agents.

**Interview questions**

1. **Q: An agent keeps going offline with "Disk space is too low". What do you do?**
   A: Free space now (workspaces, Docker images/build cache), then fix the cause: cleanup steps, the multibranch orphan strategy, build discarders, scheduled `docker prune`, or ephemeral agents.

2. **Q: Why is `rm -rf $WORKSPACE/*` not a full cleanup?**
   A: The `*` glob skips hidden files and folders like `.git/`, so the old checkout and any dotfile secrets remain. Use the Workspace Cleanup plugin or `deleteDir()`.

3. **Q: Where do you put cleanup in a pipeline?**
   A: In `post { cleanup { cleanWs() } }`, so it runs last and always, after archiving and notifications, even when the build fails.

---

*Day 04 conclusion, kept:* you now know what Jenkins stores, where builds actually run, and how to make Freestyle jobs behave like grown-up CI: typed parameters for safe inputs, Git checkout with traceable SHAs, event-driven or scheduled triggers, and responsible cleanup after archiving results. These patterns reduce surprises and make later pipeline work feel natural.
