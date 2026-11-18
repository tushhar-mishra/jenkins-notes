# 68 · Backup, Restore and Upgrades

> **Level:** ★★ intermediate · **Status:** 🔀➕ merged and expanded
>
> **You will learn:** what to back up (and what not), three ways to back up `JENKINS_HOME`, a full **restore drill**, the `secrets/` trap, and a safe procedure for upgrading Java, Jenkins LTS and plugins.
>
> **You need:** topics 12, 16, 66, 67.
>
> **From your original notes:** Day 04 › *Backup Quick-Check* (back up / can exclude / restore tips) · Day 03 › `/var/jenkins_home` tips ("Back it up… Test backup/restore regularly"), the Note on reusing the volume ("Keep the Jenkins image/version consistent, ensure ownership, back up before changes"), VM notes ("resilient storage, snapshotting"), Kubernetes notes ("back up PVCs").

---

## What it is

- **Backup:** a copy of the controller's state (`JENKINS_HOME`, topic 16) you can restore after disk loss, corruption, a bad upgrade or a mistaken deletion.
- **Restore drill:** actually restoring a backup into a fresh Jenkins to prove it works.
- **Upgrade:** moving to a newer Java, Jenkins core and/or plugins without losing data.

---

## Why it exists

"We had backups" is worthless if nobody ever restored one. The classic failure: a restore works, but every credential is broken because `secrets/` wasn't included.

---

## Analogy

A spare house key is useless if you've never checked it fits the lock. Restore drills are trying the key.

---

## How it works inside

### What to back up (from Day 04, updated)

- **Must-have:** `jobs/` (configs + build history), `plugins/` (or your `plugins.txt`), **`secrets/`**, `users/`, `nodes/`, the global `*.xml` files (including `credentials.xml`), `secret.key`, `identity.key.enc`.
- **Can exclude (recreated on boot):** `workspace/`, `updates/`, `war/`, `caches/`, `tools/` (re-downloaded), `logs/` (unless needed for audit).
- **Restore tips:** keep the Jenkins and plugin versions compatible with the backup; **preserve the whole `secrets/` folder** (`master.key` + `hudson.util.Secret`) so credentials decrypt; keep file ownership `jenkins:jenkins` (UID 1000 in the Docker image).

With configuration as code (topic 67), config and plugins come from Git, and the backup is mainly **`jobs/` build history + `secrets/` + any UI-created credentials**.

### Ways to back up

| Method | How | Notes |
|---|---|---|
| **Volume/disk snapshots** | EBS snapshot, LVM snapshot, Kubernetes VolumeSnapshot, Velero | Fast, consistent if Jenkins is quiet or the FS supports crash-consistency; whole-disk restores |
| **File-level archive** | `tar` with excludes, to S3/NFS, on a schedule | Simple; do it during `/quietDown` for consistency |
| **ThinBackup plugin** | Scheduled full/differential backups from inside Jenkins | Convenient for single controllers |
| **Config as code** | Git for plugins/JCasC/jobs | Complements, doesn't replace, history/secrets backups |

**Encrypt** backups and restrict access: a backup contains everything needed to decrypt your credentials.

### Upgrade order

1. **Java first** if the new LTS needs it (e.g. Java 17 → 21 for Jenkins 2.555.1+, topic 12). Controller *and* agents.
2. **Jenkins core** to the new LTS baseline (read the [LTS upgrade guide](https://www.jenkins.io/doc/upgrade-guide/)).
3. **Plugins** to versions compatible with that core (`jenkins-plugin-cli --available-updates`).
4. Restart safely; verify; keep the backup until you're confident.

Downgrading after plugins have migrated their data isn't always clean, which is why you snapshot before.

---

## Config / Jenkinsfile / commands

### File-level backup of the Docker lab (quiet, consistent)

```bash
TOKEN=… ; J=http://localhost:8080
curl -X POST -u admin:$TOKEN $J/quietDown                      # no new builds start
# (wait for running builds to finish, or check /computer/api/json for busy executors)
docker run --rm -v jenkins_home:/src:ro -v "$PWD":/backup alpine \
  tar czf /backup/jenkins-home-$(date +%F).tgz -C /src \
  --exclude=./workspace --exclude=./caches --exclude=./war --exclude=./updates --exclude=./logs .
curl -X POST -u admin:$TOKEN $J/cancelQuietDown
ls -lh jenkins-home-*.tgz
```
- `/quietDown` puts Jenkins in "preparing for shutdown" mode: running builds continue, no new ones start.
- `:ro` mounts the volume read-only for the backup container.

### Nightly backup on a VM (systemd timer or a Jenkins job on a dedicated label)

```bash
tar czf /backup/jenkins-$(date +%F).tgz -C /var/lib/jenkins \
  --exclude=./workspace --exclude=./caches --exclude=./war . \
  && aws s3 cp /backup/jenkins-$(date +%F).tgz s3://acme-jenkins-backups/ --sse aws:kms \
  && find /backup -name 'jenkins-*.tgz' -mtime +7 -delete
```

### Restore drill

```bash
docker volume create jenkins_restore
docker run --rm -v jenkins_restore:/dst -v "$PWD":/backup alpine \
  sh -c 'tar xzf /backup/jenkins-home-2026-11-18.tgz -C /dst && chown -R 1000:1000 /dst'
docker run -d --name jenkins-restore -p 8095:8080 -v jenkins_restore:/var/jenkins_home jenkins/jenkins:lts-jdk21
```
Then check, on `http://localhost:8095`:
1. You can log in with your usual user (no setup wizard).
2. Jobs and **build history** are there.
3. **Credentials work**: run a job that checks out a private repo. If it fails with authentication errors and the credential shows empty, `secrets/` was missing or from another instance.
4. Agents reconnect (if they're reachable from the restored controller).
Then remove it: `docker rm -f jenkins-restore && docker volume rm jenkins_restore`.

### Upgrade the Docker lab

```bash
# 1) take a backup first (the quietDown + tar commands above)
docker pull jenkins/jenkins:2.568.3-lts-jdk21    # the new exact version
docker rm -f jenkins
docker run -d --name jenkins … jenkins/jenkins:2.568.3-lts-jdk21   # same volume and flags as before
docker logs -f jenkins                           # watch for plugin load errors
```
Then **Manage Jenkins → Plugins → Updates**, update compatible plugins, safe restart. On a VM: `sudo apt update && sudo apt install jenkins` (LTS repo) and `systemctl restart jenkins`; on Helm: bump the image tag/plugins in values and `helm upgrade` (topic 54).

---

## Deeper dive

### Set RPO and RTO for Jenkins

Treat Jenkins like any production service (topic 02):
- **RPO** (how much data you can lose): with nightly backups, up to 24 h of build history and UI-made changes. With config as code, config loss is ~0 (it's in Git); only build history and UI-created credentials are at risk. Snapshot every few hours if history matters (audit).
- **RTO** (how fast you must be back): a VM restore from snapshot is ~15–30 min; an image + JCasC rebuild plus history restore, ~30–60 min; a manual rebuild with no backups, days.

Write both numbers down and test them in the restore drill.

### What about agents?

Agents are **stateless** by design: nothing on them needs backing up except their *definition* (`nodes/` on the controller, or JCasC/cloud templates). If an agent dies, recreate it. If you keep important caches on agents (Maven repos), that's a performance concern, not a backup one.

### Restoring a single job or build history

```bash
# from a backup tarball, restore only one job
tar xzf jenkins-home-2026-11-18.tgz -C /tmp/restore ./jobs/loans
sudo systemctl stop jenkins      # or do it live, then Reload Configuration from Disk
sudo cp -a /tmp/restore/jobs/loans /var/lib/jenkins/jobs/
sudo chown -R jenkins:jenkins /var/lib/jenkins/jobs/loans
sudo systemctl start jenkins
```
**Manage Jenkins → Reload Configuration from Disk** works without a restart, but it reloads *everything* from disk and can disrupt running builds, so prefer a quiet moment.

### Moving jobs to another controller

Copy `jobs/<name>` (and folders) to the new controller's `JENKINS_HOME`, make sure the same plugins and **credential IDs** exist there (credentials don't travel with the job: they're encrypted with the *old* controller's keys), then reload. With multibranch/organization folders and JCasC, you usually just recreate the folder job and let it rescan.

### Upgrade checklist (LTS baseline change)

1. Read the **LTS upgrade guide** for every baseline you skip (e.g. jumping two baselines = two guides).
2. Check the Java requirement (controller *and* agents).
3. Check plugin compatibility: `jenkins-plugin-cli --available-updates` against the new core; look for plugins with no compatible version (they block the upgrade, so find replacements first).
4. **Restore the latest backup into a staging controller** with the new image and run representative pipelines (this also tests the backup).
5. Announce a window; `quietDown`; snapshot; upgrade; watch the startup log; check **Manage Jenkins** for warnings (old data, dependency errors, reverse proxy).
6. Keep the old image and snapshot until a few days of normal use have passed.

### Practising disaster recovery

Once a quarter: pretend the controller is gone. Using only Git (`plugins.txt`, JCasC, Dockerfile) and the latest backup, rebuild it in another account/region, time it, and run a credentialed pipeline. Update the runbook with whatever surprised you.

---

## Hands-on lab

Do the lab backup, the restore drill (including the credential check), and an upgrade to a newer LTS point release. Then repeat the restore **without** `secrets/` (`--exclude=./secrets`) to see exactly how credentials break, so you'll recognise it in real life.

---

## Where you'll use it

Every production controller: scheduled backups, quarterly restore drills, every upgrade.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| After restore, credentials fail / show blank | `secrets/` missing or from another instance | Restore the matching `secrets/` |
| `Permission denied` on start after restore | Ownership changed (root-owned files) | `chown -R 1000:1000` (Docker) / `jenkins:jenkins` (VM) |
| Restored Jenkins shows plugin errors | Backup from a different plugin/core version | Restore with the same versions, then upgrade |
| Backup tar "file changed as we read it" | Builds running during backup | `/quietDown`, or snapshot-based backups |
| Upgrade: Jenkins won't start, Java error | New LTS needs a newer Java | Upgrade Java first |

---

## Quick recap

- Back up `jobs/`, `plugins/`, **`secrets/`**, `users/`, `nodes/`, global XML, keys; exclude workspaces/caches/war/updates.
- Snapshots, tar archives or ThinBackup; encrypt and restrict backups.
- Run **restore drills** and check that credentials work.
- Upgrade order: Java → core LTS → plugins, with a backup first and staging tests.

**Interview questions**

1. **Q: What's the most common mistake when restoring Jenkins?**
   A: Not restoring the `secrets/` directory with the rest, so credentials can't be decrypted. Also restoring with mismatched plugin/core versions or wrong file ownership.

2. **Q: How do you take a consistent backup of a live Jenkins?**
   A: Put it in quiet-down mode (no new builds), wait for running builds, then snapshot the volume or archive `JENKINS_HOME` (excluding workspaces/caches), then cancel the quiet-down.

3. **Q: What order do you upgrade Java, Jenkins and plugins in?**
   A: Java (if the new LTS requires it), then the Jenkins core LTS, then plugins compatible with it, after a backup and a staging test.
