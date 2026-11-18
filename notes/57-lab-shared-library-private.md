# 57 · Lab: Private Repos + Shared Library

> **Level:** ★★ intermediate · **Status:** ✅ rewritten from your notes (three corrections in Step 11)
>
> **You will learn:** a production-like setup: two private app repos (`app1-private`, `app2-private`) and a private library (`shared-library-private`); authenticating Jenkins to private repos; moving `docker build` and `docker run` into `buildImage()`/`deployApp()`; and the "one change updates both apps" demonstration.
>
> **You need:** topics 23, 55–56; a Jenkins that can run Docker (the original uses the EC2 controller in lab mode from topic 49, steps 7–9; the DooD lab from topic 27 also works).
>
> **From your original notes:** shared-library › *Demo 2: Private repos + Jenkins Shared Library* (What are we going to do, Quick flow, Steps 1–11 incl. "First, verify the problem", "Apply the fix", label and restart explanations, verification steps 1–4), files `project-files/app1`, `app2`, `shared-library/vars/*`.
>
> 📁 Files: [`project-files/shared-library/`](../project-files/shared-library/)

---

## What it is

**What we are going to do:** a production-like flow where two private application repos (`app1-private`, `app2-private`) use a private shared library (`shared-library-private`) hosted on GitHub. You wire Jenkins to authenticate to private repos, register the library, and convert each app's pipeline to call two reusable steps: one to **build** the Docker image and one to **deploy** the container. Finally you prove that changing the build or deploy logic in a **single library file** immediately affects **both** apps, without editing their Jenkinsfiles.

**Quick flow (high level):**
- Create three private Git repos (app1, app2, shared-library).
- Add a GitHub PAT to Jenkins so it can access private repos.
- Push the app code and simple Jenkinsfiles to the app repos.
- Configure Jenkins jobs with **Pipeline script from SCM** for each app.
- Add the private library to Jenkins **Global Pipeline Libraries**.
- Move the `docker build` and `docker run` steps into `vars/buildImage.groovy` and `vars/deployApp.groovy`.
- Update the app Jenkinsfiles to import the library and call `buildImage()` and `deployApp()`.
- Run both jobs and verify; then change one line in the library and re-run to demonstrate the single-change effect.

---

## Why it exists

This is the real-world shape: private repos, credentials, and a platform-owned library that many apps depend on.

---

## Analogy

Two shops (app1, app2) using the same franchise manual (library). Head office updates the manual once ("always reopen after a power cut"), and both shops follow the new rule the next day.

---

## How it works inside

```
app1-job ──SCM──▶ app1-private/Jenkinsfile: @Library('my-first-shared-library@main') _
                    └─ Jenkins fetches shared-library-private@main (credential github-pat)
                    └─ buildImage() → sh 'docker build … "$REPO:$TAG" .'   (uses env REPO/TAG/PORT from app1's Jenkinsfile)
                    └─ deployApp()  → sh 'docker run … -p "$PORT:$PORT" …'
app2-job ── same library, different REPO/PORT
```

---

## Config / Jenkinsfile / commands

### Step 1: create private repositories

Create three private GitHub repos: `app1-private`, `app2-private`, `shared-library-private`. They hold the app code and the private library respectively.

### Step 2: create a GitHub PAT and add it to Jenkins credentials

1. **GitHub → Settings → Developer settings → Personal access tokens → Classic tokens.**
2. Create a classic PAT with scope **`repo`** (this also allows push). In production prefer least-privilege tokens, deploy keys or a GitHub App (topic 46).
3. Copy the token now; GitHub won't show it again.

Add it to Jenkins: **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**:
- Kind: **Username with password**
- Username: your GitHub username (`YOUR_GH_USER`)
- Password: your PAT
- ID: `github-pat`
- Description: e.g. `GitHub PAT for private repos`

Purpose: Jenkins uses this credential to check out the private repos for the pipeline jobs **and** to fetch the shared library.

### Step 3: prepare local project folders and files

On your laptop, create `project-files/` with three subfolders, `app1`, `app2`, `shared-library` (exactly what's in this course's `project-files/shared-library/`). Minimum contents:
- `app1/` → `app1.py`, `Dockerfile`, `Jenkinsfile` (+ `requirements.txt`)
- `app2/` → `app2.py`, `Dockerfile`, `Jenkinsfile` (+ `requirements.txt`)
- `shared-library/` → `vars/buildImage.groovy`, `vars/deployApp.groovy`, `README.md` (added below)

The apps are small Flask services; `app1` listens on **5000**, `app2` on **5050**. Their Dockerfiles use `python:3.11-slim`, install requirements with `python -m pip`, and switch to a non-root `appuser` (a good practice: the container doesn't run as root).

**Note:** first verify the apps work **without** the library, then wire it in.

### Step 4: initialise Git and push each repo

> Use your PAT only in the one-time push command, or configure a Git credential helper. Never hard-code tokens in files.

Example for **app1** (replace `YOUR_GH_USER` and `YOUR_PAT_HERE`):
```bash
cd app1
git init
git add .
git commit -m "Initial commit with app1 code & Jenkinsfile"
git branch -M main
git remote add private-repo https://github.com/YOUR_GH_USER/app1-private.git
git remote set-url private-repo https://<YOUR_PAT_HERE>@github.com/<YOUR_GH_USER>/app1-private.git
git push private-repo main
```
Repeat for **app2** (`app2-private`). For the **shared library**, push to `shared-library-private` (important: **don't** push the library into the app1 repo):
```bash
cd shared-library
git init
git add .
git commit -m "Initial commit with shared library steps"
git branch -M main
git remote add private-repo https://github.com/YOUR_GH_USER/shared-library-private.git
git remote set-url private-repo https://<YOUR_PAT_HERE>@github.com/<YOUR_GH_USER>/shared-library-private.git
git push private-repo main
```
**Security note:** after pushing, remove the token from the remote URL (`git remote set-url private-repo https://github.com/YOUR_GH_USER/<repo>.git`), or use the credential helper/`gh auth login` (topic 47), so the token isn't kept in `.git/config`.

### Step 5: create Pipeline jobs in Jenkins (app1-job + app2-job)

Use **Pipeline script from SCM** so Jenkins checks out the app repo and runs its `Jenkinsfile`. For **app1-job**:
- Name `app1-job` · Type **Pipeline**
- **Definition: Pipeline script from SCM** · SCM **Git** · URL `https://github.com/YOUR_GH_USER/app1-private.git` · Credentials `github-pat` · Branch `*/main` · Script Path `Jenkinsfile`
- Save. Repeat for **app2-job** with `app2-private`.

### Step 6: verify the jobs build without the shared library (smoke test)

The original app Jenkinsfile (`project-files/shared-library/app1/Jenkinsfile`):
```groovy
pipeline {
    agent any
    environment {
        REPO = "app1-flask"
        TAG   = "${BUILD_NUMBER}"
        PORT = "5000"
    }

    stages {
        stage('build') {
            steps {
                sh 'docker build -t "$REPO:$TAG" .'
            }
        }
        stage('deploy') {
            steps {
                sh 'docker rm -f $REPO || true'
                sh 'docker run -d --name $REPO -p "$PORT:$PORT" "$REPO:$TAG"'
            }
        }
    }
}
```
(app2's is identical except `REPO = "app2-flask"`, `PORT = "5050"`.) Here `REPO` is used both as the **local image name** and the **container name**; nothing is pushed to a registry.

- **Build Now** for `app1-job` and `app2-job`; check Console Output for the `docker build`/`docker run` lines.
- On the Jenkins host:
  ```bash
  docker images
  docker ps
  ```
- Endpoints (replace `JENKINS_HOST` with the host running the containers):
  - `http://JENKINS_HOST:5000` for app1
  - `http://JENKINS_HOST:5050` for app2

Confirm both respond before wiring the library.

### Step 7: add the private shared library to Global Pipeline Libraries

1. **Manage Jenkins → System → Global Pipeline Libraries → Add.**
2. Name: `my-first-shared-library` (or any logical name).
3. Default version: `main`.
4. Load implicitly: **unchecked** (recommended).
5. Allow default version to be overridden: **checked**.
6. Retrieval method: **Modern SCM → Git**: URL `https://github.com/YOUR_GH_USER/shared-library-private.git`, Credentials `github-pat`.
7. Save and verify Jenkins can fetch the repo.

This makes the private library available to pipelines that explicitly import it with `@Library(...)`.

### Step 8: move build & deploy logic into the library

In `shared-library-private`, create `vars/` with two files.

**`vars/buildImage.groovy`**
```groovy
// vars/buildImage.groovy
def call() {
  sh 'docker build -t "$REPO:$TAG" .'
}
```
**`vars/deployApp.groovy`**
```groovy
// vars/deployApp.groovy
def call() {
    sh 'docker rm -f $REPO || true'
    sh 'docker run -d --name $REPO -p "$PORT:$PORT" "$REPO:$TAG"'
}
```
**Notes:**
- These steps read the pipeline's environment variables **through the shell** (`$REPO`, `$TAG`, `$PORT` inside single-quoted `sh`).
  > ⚠️ **Corrected:** the original says "These shared steps read pipeline environment variables directly using `env.*`." Now: they don't use Groovy's `env.*` at all. Because the `sh` strings are single-quoted, the **shell** expands `$REPO`/`$TAG`/`$PORT` from the build's environment, which the app Jenkinsfile's `environment {}` block populates. (Reading `env.REPO` in Groovy would also work; it's simply not what this code does.)
- Jenkinsfiles that call these steps must set `REPO`, `TAG` and `PORT` in their `environment` block.
- This style keeps Jenkinsfiles simple and suits a beginner-friendly demo (topic 58 shows the parameterised production style).

Commit and push these two files to `shared-library-private`.

### Step 9: update each app's Jenkinsfile to use the library

**`Jenkinsfile` (app1)** (the repo file is `Jenkinsfile_new`):
```groovy
@Library('my-first-shared-library@main') _

pipeline {
  agent any

  environment {
    REPO = "app1-flask"
    TAG  = "${BUILD_NUMBER}"
    PORT = "5000"
  }

  stages {
    stage('Build') {
      steps {
        buildImage()
      }
    }

    stage('Deploy') {
      steps {
        deployApp()
      }
    }
  }
}
```
Make the same change in `app2` (`REPO = "app2-flask"`, `PORT = "5050"`; its container is named after `REPO`, i.e. `app2-flask`). Commit and push both Jenkinsfiles.

### Step 10: run the jobs and verify (final)

- **Build Now** for `app1-job` and `app2-job`.
- In Console Output, confirm the library loaded (`Loading library my-first-shared-library@main`) and the steps ran (`docker build`, then `docker run`).
- On the Jenkins host, check `docker ps` and `docker images`.
- Endpoints: `http://JENKINS_HOST:5000` (app1), `http://JENKINS_HOST:5050` (app2).

If something fails, check:
- the top lines of the Console Output for library-fetch or SCM errors,
- the Global Pipeline Libraries entry and its credentials,
- that the `vars/*.groovy` files are on the `main` branch of `shared-library-private`.

### Step 11: demonstrate the power of the shared library

Both apps are deployed through the library. Now see why this design matters. Your team lead says:

> After our patching activity on the Docker host, both app1 and app2 containers stopped and did not auto-start when the host came back. We want these apps to always start automatically after a reboot.
> Also, add a label in the Docker image that contains the owner's email address.

Without a shared library you'd change **two separate Jenkinsfiles** (or twenty, with twenty microservices). With it, you change **one file per behaviour**, and both apps inherit the change.

**First, verify the problem.** Restart Docker on the Ubuntu VM:
```bash
sudo systemctl restart docker
docker ps -a
```
**app1** and **app2** are stopped and didn't auto-start. That's the problem to solve.

**Apply the fix in the shared library.**

**1. Add an image label in `buildImage.groovy`.**

> ⚠️ **Corrected:** the original shows the "current command" as `sh "docker build -t ${repo}:${tag} ."` and the replacement as `sh "docker build --label maintainer=cloudwithvarjosh@gmail.com -t ${repo}:${tag} ."`. Now edit the **actual** line, keeping the shell variables and single quotes, because the library has no Groovy variables named `repo`/`tag`. Copying the Groovy-interpolated version would fail with `groovy.lang.MissingPropertyException: No such property: repo`. (Your committed `vars/buildImage.groovy` is already correct.)

Current:
```groovy
sh 'docker build -t "$REPO:$TAG" .'
```
Replace with:
```groovy
sh 'docker build --label maintainer=cloudwithvarjosh@gmail.com -t "$REPO:$TAG" .'
```
(Use your own email address.)

**What does `--label` mean?** `--label key=value` attaches **metadata** to the image (stored in its config; Docker notes topic 18). It's useful for ownership tracking, automation, cleanup policies and identifying who built the image. View it later with:
```bash
docker inspect <image> | grep -A5 Labels
```

**2. Add auto-restart behaviour in `deployApp.groovy`.**

> ⚠️ **Corrected:** same issue: the original shows `sh "docker run -d --name ${containerName} -p ${port}:${port} ${repo}:${tag}"` → `… --restart unless-stopped …` with Groovy variables that don't exist. Edit the real line instead.

Current:
```groovy
sh 'docker run -d --name $REPO -p "$PORT:$PORT" "$REPO:$TAG"'
```
Replace with:
```groovy
sh 'docker run -d --name $REPO --restart unless-stopped -p "$PORT:$PORT" "$REPO:$TAG"'
```

**What does `--restart unless-stopped` mean?** It tells Docker to:
- start the container automatically when the Docker daemon starts,
- start it automatically after a host reboot,
- keep it running **unless you explicitly stop it**.

A very common production flag for workloads that must survive host restarts (Docker notes topic 32).

Your committed library files after the change (`project-files/shared-library/shared-library/vars/`):
```groovy
// buildImage.groovy
def call() {
    sh 'docker build --label maintainer=cloudwithvarjosh@gmail.com -t "$REPO:$TAG" .'
}
// deployApp.groovy
def call() {
                sh 'docker rm -f $REPO || true'
                sh 'docker run -d --name $REPO --restart unless-stopped -p "$PORT:$PORT" "$REPO:$TAG"'
}
```
Commit and push them to `shared-library-private`.

**Verification steps**

1. **Re-run both Jenkins jobs** (`app1-job`, `app2-job`). This rebuilds the images with the new label and redeploys the containers with the restart policy.
2. **Verify the image labels:**
   > ⚠️ **Corrected:** the original runs `docker inspect app1-flask:latest`, but these jobs only tag `"$REPO:$TAG"` (the build number); there is no `:latest` tag. Inspect the build-number tag (or the container's image).
   ```bash
   docker inspect app1-flask:<BUILD_NUMBER> | grep -A5 Labels
   # or, without knowing the number:
   docker inspect "$(docker inspect -f '{{.Image}}' app1-flask)" | grep -A5 Labels
   ```
   You should see:
   ```
   "maintainer": "cloudwithvarjosh@gmail.com"
   ```
3. **Verify the restart policy:**
   > ⚠️ **Corrected:** the original runs `docker inspect app1 | grep RestartPolicy -A3`, but the container is named after `REPO`, i.e. **`app1-flask`** (and `app2-flask`, not `app2`). With `app1`, Docker answers `Error: No such object: app1`.
   ```bash
   docker inspect app1-flask | grep RestartPolicy -A3
   ```
   Expected:
   ```
   "Name": "unless-stopped"
   ```
4. **Restart Docker again** to test auto-start:
   ```bash
   sudo systemctl restart docker
   docker ps
   ```
   Both **app1-flask** and **app2-flask** are running again without manual intervention.

This is exactly the benefit of a shared library: **one change, two apps updated, zero changes to their Jenkinsfiles.**

---

## Hands-on lab

Do steps 1–11. Then:
1. Pin app2 to the old behaviour with `@Library('my-first-shared-library@<old-commit-sha>') _` and confirm app2 doesn't get the label: per-app version pinning.
2. Break the library (a syntax error in `deployApp.groovy`) and push: **both** jobs fail. The power cuts both ways, which is why libraries need versioning and testing (topic 58).

---

## Where you'll use it

Any organisation with several services sharing build/deploy/scan logic.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `Could not fetch library … Authentication failed` | Library retrieval has no/invalid credentials | Set `github-pat` on the library's SCM config |
| `No such DSL method 'buildImage'` | Files not on `main` / not under `vars/` | Push to the right repo/branch (not into app1) |
| `docker: invalid reference format` | `REPO`/`TAG` not set in the app's `environment` | Define them (the library depends on them) |
| `No such property: repo` | Copied the Groovy-variable version of the commands | Use the single-quoted shell form |
| `Error: No such object: app1` | Wrong container name | `app1-flask` |

---

## Quick recap

- Private repos + one credential (`github-pat`) used for both app checkout and library retrieval.
- `buildImage()`/`deployApp()` read `REPO`/`TAG`/`PORT` from the app's environment through the shell.
- Adding `--label` and `--restart unless-stopped` in the library updated both apps at once.
- The same power means a broken library breaks every pipeline: version and test it.

**Interview questions**

1. **Q: How does Jenkins access a private shared library?**
   A: The Global Pipeline Libraries entry uses a Modern SCM (Git) retrieval with credentials (PAT/GitHub App/SSH key) that can read the library repo.

2. **Q: You fix a deploy bug once in the library. Which pipelines pick it up?**
   A: Every pipeline loading that library version (e.g. `@main`) on its next run. Pipelines pinned to an older tag/commit don't.

3. **Q: What does `docker run --restart unless-stopped` do?**
   A: Restarts the container whenever the Docker daemon starts (including after reboots) unless it was explicitly stopped.
