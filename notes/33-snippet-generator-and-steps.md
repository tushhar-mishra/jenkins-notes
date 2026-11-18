# 33 · Snippet Generator and Step Reference

> **Level:** ★ foundation · **Status:** ✅➕ rewritten and expanded
>
> **You will learn:** how to stop guessing step syntax: the **Pipeline Syntax** page (Snippet Generator), the **Declarative Directive Generator**, the **Global Variables Reference**, the online steps reference, and how to **lint** a Jenkinsfile before you commit it.
>
> **You need:** topic 31.
>
> **From your original notes:** Day 06 › *Build a Production-grade Jenkinsfile → Step 1: Add credentials via the Snippet Generator* (A Git checkout incl. changelog note, B Docker Hub login, "Why these two?"), the tip "If unsure a step exists, use the Snippet Generator".

---

## What it is

- **Snippet Generator** (`<JENKINS_URL>/job/<any-pipeline-job>/pipeline-syntax/` or `<JENKINS_URL>/pipeline-syntax/`): choose a **step** from a dropdown, fill a form, click **Generate Pipeline Script**, copy the Groovy.
- **Declarative Directive Generator** (same page, left menu): the same for **directives** (`agent`, `options`, `triggers`, `when`, `post`, `parameters`…).
- **Global Variables Reference** (left menu): what `env`, `params`, `currentBuild`, `docker`, `scm` offer, *for the plugins installed on this controller*.
- **Steps reference online:** [jenkins.io/doc/pipeline/steps](https://www.jenkins.io/doc/pipeline/steps/), every step of every plugin.

Because the generator only shows steps from **installed** plugins, it also answers "does this step exist here?".

---

## Why it exists

Step arguments are long and plugin-specific. Generated snippets are always valid for your exact plugin versions, which avoids `No such DSL method` and wrong-argument errors.

---

## Analogy

A **phrasebook** for a language you're learning: pick what you want to say, and it gives you the correct sentence.

---

## How it works inside

Each step's form is built from the plugin's own description of its parameters, so the generated code matches the installed version. The generator doesn't run anything; it only renders text.

---

## Config / Jenkinsfile / commands

### A) Git checkout (private repo)

> ⚠️ **Corrected:** your Day 06 notes open `http://localhost:8080/job/pipeline-1/pipeline-syntax/`, but the job created earlier is `flask-pipeline`. Use **your own job name** (`/job/flask-pipeline/pipeline-syntax/`) or the job-independent `http://localhost:8080/pipeline-syntax/`. The link must point at an existing pipeline job.

- **Sample Step:** `git: Git`
- **Repository URL:** your private repo (e.g. `https://github.com/CloudWithVarJosh/cwvj-private-repo.git`)
- **Branch:** `main`
- **Credentials:** your GitHub PAT (`github-pat`)
- Optional: **Include in polling?** off (we trigger manually); **Include in changelog?** on

> When **changelog: true** (the box is checked), Jenkins records the commit messages, authors, timestamps and commit IDs between the last built revision and the new one (the build's **Changes** page).

Generated:
```groovy
git branch: 'main', credentialsId: 'github-pat', poll: false,
    url: 'https://github.com/CloudWithVarJosh/cwvj-private-repo.git'
```
(In a pipeline from SCM you don't need this; declarative checks out automatically, topic 31. Use `git` for a *second* repo.)

The more flexible `checkout` step (Sample Step: `checkout: Check out from version control`) supports every Git option (shallow clone, sparse checkout, submodules):
```groovy
checkout scmGit(branches: [[name: '*/main']],
  extensions: [cloneOption(depth: 1, shallow: true, noTags: true)],
  userRemoteConfigs: [[credentialsId: 'github-pat', url: 'https://github.com/you/big-repo.git']])
```
`depth: 1, shallow: true` = fetch only the latest commit, which is much faster for big repos.

### B) Docker Hub login

- **Sample Step:** `withCredentials: Bind credentials to variables`
- **Binding:** *Username and password (separated)*: credentials `dockerhub`, username variable `DOCKERHUB_USER`, password variable `DOCKERHUB_PWD`

Generated wrapper:
```groovy
withCredentials([usernamePassword(credentialsId: 'dockerhub',
  usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PWD')]) {
  // docker commands go here
}
```
> **Why these two?** `git` with `credentialsId` is the safe, fast way to check out. `withCredentials` injects the Docker Hub secret just for the block (masked in logs, not saved in `.git/config` or `ps`). Topic 24 covers this fully.

### Directive Generator example

Choose `options` → add *Timeout* (30 min) and *Timestamps* → generated:
```groovy
options {
  timeout(time: 30, unit: 'MINUTES')
  timestamps()
}
```

### Lint a Jenkinsfile before committing

The declarative linter validates syntax on the controller without running anything:
```bash
# via HTTP (needs an API token; crumb not needed with a token)
curl -s -u admin:$TOKEN -X POST -F "jenkinsfile=<Jenkinsfile" http://localhost:8080/pipeline-model-converter/validate
```
```
Jenkinsfile successfully validated.
```
or, with an error:
```
Errors encountered validating Jenkinsfile:
WorkflowScript: 7: Missing required section "steps" @ line 7, column 5.
```
Also available through the Jenkins CLI (`declarative-linter`, topic 70) and as editor extensions (VS Code "Jenkins Pipeline Linter Connector").

---

## Hands-on lab

1. Open `/pipeline-syntax/`. Generate: `sh` with **returnStdout**, `archiveArtifacts` with fingerprint, `withCredentials` (Secret text), `junit`.
2. Open **Global Variables Reference** and read what `currentBuild` provides (`result`, `number`, `durationString`, `getBuildCauses()`).
3. Save your skeleton Jenkinsfile locally, break it, and run the `curl` linter. Fix it until it says *successfully validated*.

---

## Where you'll use it

Every time you add a step you haven't used before, and before every Jenkinsfile commit (the linter).

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `No such DSL method 'cleanWs'` | Plugin (Workspace Cleanup) not installed | Install it; the generator wouldn't list it |
| Step not in the dropdown | Plugin missing or not compatible | Check **Manage Jenkins → Plugins** |
| Linter returns `403` | No auth / wrong token | `-u user:API_TOKEN` |
| Generated snippet works in one Jenkins but not another | Different plugin versions | Pin plugin versions across controllers (topic 66) |

---

## Quick recap

- **Pipeline Syntax** page = Snippet Generator + Directive Generator + Global Variables Reference.
- It only shows steps from installed plugins, so it doubles as a "does this exist?" check.
- `changelog: true` records commits between builds.
- Lint Jenkinsfiles via `/pipeline-model-converter/validate` before committing.

**Interview questions**

1. **Q: How do you find the correct syntax for a pipeline step?**
   A: Use the Snippet Generator on the Pipeline Syntax page (or the steps reference); it generates valid code for the installed plugin versions.

2. **Q: How can you validate a declarative Jenkinsfile without running it?**
   A: POST it to the declarative linter endpoint, `/pipeline-model-converter/validate`, or use the CLI `declarative-linter` command.

3. **Q: A pipeline fails with `No such DSL method`. What does it mean?**
   A: The step name is misspelt, or the plugin that provides it isn't installed or enabled on that controller.
