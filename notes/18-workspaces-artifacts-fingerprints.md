# 18 · Workspaces, Artifacts and Fingerprints

> **Level:** ★ foundation · **Status:** ✅➕ rewritten and expanded
>
> **You will learn:** the life of a workspace, how to save ("archive") files from a build as **artifacts**, what **fingerprints** are and why they help traceability, how **build discarders** keep disk under control, and why Jenkins archives aren't an artifact repository.
>
> **You need:** topics 16, 17.
>
> **From your original notes:** Day 03 › *Step 2 — Produce and archive an artifact*, *Key points: Artifacts* · Day 06/07 Jenkinsfile comment on `fingerprint: true`.

---

## What it is

- **Workspace:** the folder on the build node where a job's files live while it runs (`$WORKSPACE`). It's **scratch space**: it can be wiped any time, and it's shared by consecutive builds of the same job on the same node.
- **Artifact (in Jenkins):** a file you **archive** from the workspace so it's **kept with the build record** on the controller (`$JENKINS_HOME/jobs/<job>/builds/<n>/archive/`). You can download it from the build page later.
- **Fingerprint:** an **MD5 hash** (a short checksum computed from the file's bytes) that Jenkins records for a file, plus which builds produced or used it. It answers "which build made this exact file, and where else was it used?"
- **Build discarder:** a rule that deletes old builds (and their logs/artifacts), e.g. "keep the last 20 builds".

---

## Why it exists

Workspaces are temporary and live on agents that may disappear. If a build produced something you need later (a report, a deploy record, a small binary), you must copy it to a safe place **with the build record**. Fingerprints connect files across jobs for audits. Discarders stop `JENKINS_HOME` from filling up.

---

## Analogy

A **workbench and a filing cabinet**. You build on the workbench (workspace) and clear it often. Anything worth keeping goes in a labelled folder in the cabinet (archived artifact), with a stamped serial number (fingerprint). Once a year you shred the oldest folders (build discarder).

---

## How it works inside

### Workspace lifecycle

1. First build on a node: Jenkins creates `<node-root>/workspace/<job>`.
2. Later builds of the same job **reuse** it. Files from the previous build are still there unless you clean them (a common source of "it passed because an old file was lying around").
3. If two builds of the same job run at once on one node, the second gets `<job>@2`.
4. Pipelines also create helper folders next to it: `<job>@tmp` (temporary scripts, secret files) and `<job>@script`/`@libs` (topic 32).
5. Workspaces are only deleted if you clean them (Workspace Cleanup, `cleanWs()`, topic 22), the agent is ephemeral, or multibranch orphan cleanup removes the job (topic 43).

### Archiving

The **Archive the artifacts** post-build action (Freestyle) or the `archiveArtifacts` step (Pipeline) takes **Ant-style patterns** (`**/*.jar` = any `.jar` in any subfolder; `reports/*.html`), copies the matching files **from the agent over Remoting to the controller**, and stores them under `builds/<n>/archive/`. Large files make this slow and fill the controller disk.

### Fingerprints

With fingerprinting on, Jenkins computes each archived file's MD5 and stores a record in `$JENKINS_HOME/fingerprints/`. If another job later fingerprints the **same file** (e.g. a deploy job that downloaded that `.jar`), Jenkins links the two builds. On a build page, **See Fingerprints** shows "this file was created by `build-app #42` and used by `deploy-stage #17`".

> From your Jenkinsfile: `fingerprint: true` tells Jenkins to compute and store a unique hash (a "fingerprint") for the archived file.

### Jenkins archives vs real artifact repositories

| | Jenkins archived artifacts | Registry / Nexus / Artifactory |
|---|---|---|
| Purpose | Build records: reports, logs, small outputs, `manifest.json`, deploy-info | The real deployable artifacts |
| Lifetime | Deleted with the build by the discarder | Your retention policy |
| Access | Jenkins users | Every environment, every tool |
| Scale | Lives on the controller disk | Built for it |

Rule: **archive small records; publish real artifacts to a registry/repository** (topic 07).

---

## Config / Jenkinsfile / commands

### Freestyle: produce and archive an artifact

- **Edit job → Build Steps → Execute shell** (append):
  ```bash
  echo "Report for build #$BUILD_NUMBER" > build-report.txt
  ls -l
  ```
- **Post-build Actions → Archive the artifacts:** `build-report.txt`. Under **Advanced**, tick **Fingerprint all archived artifacts** (on by default in newer versions).
- **Build Now → open the build → Artifacts:** download `build-report.txt`.

Console (shape):
```
+ echo Report for build #3
+ ls -l
-rw-r--r-- 1 jenkins jenkins 20 Nov 18 10:12 build-report.txt
Archiving artifacts
Recording fingerprints
Finished: SUCCESS
```

> **Takeaway:** **artifacts** are files saved from `$WORKSPACE` with the build record.

### Pipeline equivalent (preview of Part 6)

```groovy
archiveArtifacts artifacts: 'build-report.txt, reports/**/*.html', fingerprint: true, allowEmptyArchive: false
```
- `artifacts`: comma-separated Ant patterns, relative to the workspace.
- `fingerprint: true`: record MD5s.
- `allowEmptyArchive: false` (the default): **fail** the build if nothing matched, which catches broken paths early.

### Build discarder (keep disk under control)

Freestyle: **Configure → General → Discard old builds** → *Max # of builds to keep* = `20`, *Max # of builds to keep with artifacts* = `5`.

Pipeline:
```groovy
options { buildDiscarder(logRotator(numToKeepStr: '20', artifactNumToKeepStr: '5')) }
```
Keeps the last 20 builds, but artifacts only for the last 5. Older builds disappear from `jobs/<job>/builds/` at the next build.

You can also mark a build **Keep this build forever** (build page) for releases you must keep for audit.

---

## Hands-on lab

1. Add the archive step above to `intro-freestyle`, build 3 times, download the report from build #2.
2. Look on disk:
   ```bash
   docker exec jenkins ls /var/jenkins_home/jobs/intro-freestyle/builds/3/archive
   docker exec jenkins ls /var/jenkins_home/fingerprints | head
   ```
3. Click **See Fingerprints** on a build. Note the MD5 and "Introduced" build.
4. Prove workspace reuse: add `ls -l; date >> history.txt; cat history.txt` to the shell step and build 3 times. `history.txt` grows, because the workspace persists between builds.
5. Set **Discard old builds → keep 2**, build again, and watch the older builds disappear.

---

## Where you'll use it

- Archiving test reports, coverage HTML, SBOMs, `manifest.json`, deploy-info files (topic 36).
- Proving in an audit which build produced a deployed file (fingerprints).
- Preventing controller disk-full outages (discarders).

---

## When it breaks

| Message / symptom | Meaning | Fix |
|---|---|---|
| `ERROR: No artifacts found that match the file pattern "target/*.jar"` | Wrong path, or the build didn't produce it | Check `ls -R` in the workspace; fix the pattern |
| Archiving takes minutes | Large files copied over Remoting to the controller | Publish to a registry/S3 instead; archive only small records |
| Controller disk full | Unlimited builds and artifacts | Build discarders everywhere; JCasC default discarder |
| Build passed using a stale file | Workspace reused | Clean the workspace at start or end (topic 22) |

---

## Quick recap

- The **workspace** is scratch space on the build node, reused between builds.
- **Archive** small, valuable outputs; they're stored with the build on the controller.
- **Fingerprints** (MD5) link files to the builds that made and used them.
- Use **build discarders** to cap disk usage.
- Real artifacts belong in registries/repositories, not Jenkins archives.

**Interview questions**

1. **Q: Where are archived artifacts stored?**
   A: On the controller, in `$JENKINS_HOME/jobs/<job>/builds/<n>/archive/`, copied from the agent's workspace.

2. **Q: What's a fingerprint in Jenkins?**
   A: An MD5 checksum of a file that Jenkins records along with the builds that produced and used it, so you can trace a file across jobs.

3. **Q: Why not use Jenkins as your artifact repository?**
   A: Archives live on the controller disk, are deleted with old builds, are slow to transfer, and aren't accessible to other systems the way Nexus, Artifactory or a registry are.
