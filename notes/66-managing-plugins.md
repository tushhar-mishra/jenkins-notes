# 66 · Managing Plugins

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** how plugins are installed and updated (the update center), how dependencies work, how to keep a **minimal, pinned** plugin set in a `plugins.txt` with the **plugin installation manager tool**, how to upgrade safely, how to spot deprecated or vulnerable plugins, and how to fix plugin conflicts.
>
> **You need:** topics 12, 16.
>
> **From your original notes:** Day 02 › "Minimal, curated plugins"; Day 03 › *Rich plugin ecosystem*; Day 04 › `plugins/` directory, `.jpi/.hpi`; Day 03 CloudBees notes ("curated plugin baselines").

---

## What it is

A **plugin** is a `.jpi` file (a zip of Java classes) in `$JENKINS_HOME/plugins/`. Almost every feature you've used is a plugin: Git, Pipeline, Credentials Binding, GitHub Branch Source, Docker Pipeline, Kubernetes, Workspace Cleanup. Plugins **depend** on other plugins and on a **minimum Jenkins core version**.

The **update center** (`updates.jenkins.io`) publishes a catalogue of plugin versions compatible with your core version; **Manage Jenkins → Plugins** uses it (tabs: *Updates*, *Available*, *Installed*, *Advanced*).

---

## Why it exists

Plugins are Jenkins' biggest strength and its biggest operational risk: each one adds upgrade risk, attack surface and memory use. Many outages are "we updated plugins and Jenkins didn't come back".

---

## Analogy

Apps on a phone: useful, but each one can break after an OS update, ask for too many permissions, or be abandoned by its developer. Install few, from trusted developers, and update them deliberately.

---

## How it works inside

1. Installing plugin X downloads X **and its dependencies** (each at a version satisfying X's minimums).
2. Most changes need a **restart** to fully apply (`/safeRestart` waits for running builds to finish).
3. At startup Jenkins loads plugins in dependency order; if a dependency is missing or too old, X **fails to load** and shows on Manage Jenkins with an error.
4. **Pinning:** if you installed a specific older version manually, `x.jpi.pinned` stops automatic upgrades of it as a dependency.
5. **Health signals** on each plugin page (plugins.jenkins.io): installs, release history, open security warnings, "deprecated"/"up for adoption" labels, and a **health score**.

### Minimal and pinned: plugins as code

Keep the exact list in Git and build the controller from it:

`plugins.txt`:
```
configuration-as-code:1953.v148f87d74b_1e
workflow-aggregator:608.v67378e9d3db_1
git:5.7.0
github-branch-source:1810.v913311241fa_9
credentials-binding:687.v619cb_15e923f
pipeline-graph-view:340.v28cecee8b_25f
ws-cleanup:0.48
timestamper:1.28
```
(The exact versions here are format examples; generate your real list from a working controller, below.)

Generate it from a running controller with the **Script Console** (Manage Jenkins → Script Console, admins only):
```groovy
Jenkins.instance.pluginManager.plugins.sort { it.shortName }.each { println "${it.shortName}:${it.version}" }
```
```
ant:511.v0a_a_1a_334f41b_
antisamy-markup-formatter:173.v680e3a_b_69ff3
...
```
Copy the output into `plugins.txt` (and delete the plugins you don't actually need).

> Note: `jenkins-plugin-cli --list` does **not** read a running controller's `JENKINS_HOME`. It lists what's in the tool's **plugin download directory** (default `/usr/share/jenkins/ref/plugins` in the official image) plus bundled plugins and the plugins it would download. Point it at a folder with `--plugin-download-directory <dir>` if you want it to inspect one, e.g. `docker exec jenkins jenkins-plugin-cli --list --plugin-download-directory /var/jenkins_home/plugins`.
Install into a custom image (topic 67):
```dockerfile
FROM jenkins/jenkins:2.568.2-lts-jdk21
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
```
`jenkins-plugin-cli` (the **plugin installation manager tool**) resolves dependencies **at image build time** and fails the build if versions are incompatible, so problems appear in CI, not in production.

Check for updates and security issues:
```bash
jenkins-plugin-cli --plugin-file plugins.txt --available-updates --output txt
jenkins-plugin-cli --plugin-file plugins.txt --view-all-security-warnings
```
Flags (checked against the tool's README): `--plugin-file`/`-f` (a plugins.txt or YAML file), `--plugins`/`-p` (plugins on the command line), `--available-updates`, `--output stdout|yaml|txt`, `--list`/`-l`, `--view-all-security-warnings` (show every plugin with known warnings), `--hide-security-warnings`, `--plugin-download-directory`/`-d`.

### Safe upgrade procedure

1. Read the changelogs of what's being updated (especially core LTS baselines and Pipeline/Git/Kubernetes plugins).
2. **Back up** `JENKINS_HOME` (or snapshot the volume) first (topic 68).
3. Upgrade in a **staging controller** built from the same `plugins.txt` + JCasC; run a few representative pipelines.
4. Roll to production in a maintenance window: `/quietDown` (stop new builds), wait, upgrade, restart.
5. If it breaks: restore the previous image/plugin set (and the backup if data migrated).

### Remove what you don't use

Every plugin is attack surface. **Manage Jenkins → Plugins → Installed**: uninstall unused ones (check "used by" first). Avoid deprecated ones (e.g. **Blue Ocean**, deprecated since July 2026, topic 15; prefer Pipeline Graph View).

---

## Config / Jenkinsfile / commands

```bash
# Safe restart after plugin changes (waits for running builds)
curl -X POST -u admin:$TOKEN http://localhost:8080/safeRestart
```
Startup log when a dependency is missing:
```
SEVERE  jenkins.InitReactorRunner$1#onTaskFailed: Failed Loading plugin GitHub Branch Source Plugin v1810.v913311241fa_9 (github-branch-source)
java.io.IOException: Failed to load: GitHub Branch Source Plugin (github-branch-source 1810.v913311241fa_9)
 - Update required: GitHub API Plugin (github-api 1.318-461.v7a_c09c9fa_d63) to be updated to 1.321-468.v6a_3a_9a_b_a_1b_8 or higher
```
Read it bottom-up: the fix is to update the named dependency.

---

## Deeper dive

### How dependencies are decided

Each plugin's manifest (`META-INF/MANIFEST.MF` inside the `.jpi`) declares:
- `Jenkins-Version`: the **minimum core** version it needs;
- `Plugin-Dependencies`: other plugins with minimum versions, some marked `resolution:=optional` (used only if present).

You can read it on any controller: `unzip -p $JENKINS_HOME/plugins/git.jpi META-INF/MANIFEST.MF | grep -E 'Jenkins-Version|Plugin-Dependencies'`.

**Detached plugins:** features that used to be inside core were moved out into plugins over the years (e.g. some SCM and build-step features). When an old plugin depends on such a feature, Jenkins treats the detached plugin as an **implied dependency** and installs it. That's why a "minimal" controller still has a few plugins you never chose.

### Where the update center gets versions from

- Jenkins downloads `update-center.json` from `updates.jenkins.io`, already filtered for **your core version**, so "Available" only offers compatible versions.
- An *experimental* update center exists for alpha/beta plugin releases. Never use it in production.
- Air-gapped sites point Jenkins at an internal mirror (**Manage Jenkins → Plugins → Advanced → Update Site**) or, better, build images with `jenkins-plugin-cli` against a mirror.

### Choosing compatible versions: the plugin BOM

The Jenkins project publishes a **plugin BOM** (Bill of Materials, `jenkinsci/bom` on GitHub): sets of plugin versions tested together against each LTS line. Plugin developers use it; you can use its version lists as a sanity check when pinning `plugins.txt` for a given LTS.

### Judging a plugin before installing it

On plugins.jenkins.io check: **health score**; last release date; open security warnings; "Deprecated" or "Up for adoption" banners; number of installs; whether it's maintained by the Jenkins project or one individual; and whether there's a **built-in or more popular alternative** (e.g. Pipeline Graph View instead of Blue Ocean, `withCredentials` instead of old per-tool credential plugins).

### Removing a plugin safely

1. **Manage Jenkins → Plugins → Installed**: the uninstall button is disabled if other plugins depend on it, which shows you the dependants.
2. Check jobs/pipelines that use its steps (search Jenkinsfiles/config.xml for the step names).
3. Uninstall → safe restart.
4. **Manage Jenkins → Manage Old Data** may list config fields left by the plugin; discard them once you're sure.

### Typical upgrade incident, step by step

```
Symptom : Jenkins up, but every pipeline fails "No such DSL method 'withCredentials'"
Cause   : credentials-binding failed to load after an update (needs newer credentials plugin)
Evidence: Manage Jenkins shows "There are dependency errors loading some plugins"
Fix     : update the named dependency (or roll back the image); safe restart
Prevent : build images with jenkins-plugin-cli (it resolves dependencies at build time) + staging
```

---

## Hands-on lab

1. Export your lab controller's plugin list to `plugins.txt` and commit it to a repo.
2. Run `--view-all-security-warnings` and `--available-updates` against it.
3. Uninstall one plugin you don't use (e.g. an unused SCM) and restart safely.
4. Build the custom image from topic 67 with your `plugins.txt` and start it next to your lab: same plugins, no clicking.

---

## Where you'll use it

Every controller upgrade; every security review; every "Jenkins won't start after the update" incident.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Plugin failed to load, `Update required: …` | Dependency too old/missing | Update the dependency; prefer image builds with `jenkins-plugin-cli` |
| `… requires a newer version of Jenkins` | Plugin newer than core | Upgrade core LTS first, or pin an older plugin |
| Jenkins doesn't come back after an update | Incompatible plugin set | Roll back to the previous image/backup; test in staging |
| Red security banner | Vulnerable plugin/core | Update, or remove if unused |
| Memory climbs after adding plugins | Heavy plugins | Remove what's unused; size the heap (topic 69) |

---

## Quick recap

- Plugins = `.jpi` files with dependencies and minimum core versions.
- Keep a **minimal, pinned `plugins.txt`** in Git; install with `jenkins-plugin-cli` in an image.
- Upgrade: changelog → backup → staging → maintenance window → safe restart; roll back if needed.
- Watch advisories and deprecation labels; remove unused plugins.

**Interview questions**

1. **Q: How do you manage Jenkins plugins reproducibly?**
   A: A pinned `plugins.txt` in Git, installed with the plugin installation manager tool into a custom controller image (or Helm `installPlugins`), tested on staging before production.

2. **Q: Jenkins won't start after a plugin update. What do you do?**
   A: Read the startup log for the failing plugin and dependency, restore the previous image/plugin versions (or the backup), then fix the dependency set in staging.

3. **Q: Why keep the plugin count low?**
   A: Each plugin adds upgrade conflicts, security vulnerabilities and memory use; fewer, well-maintained plugins mean a stable, safer controller.
