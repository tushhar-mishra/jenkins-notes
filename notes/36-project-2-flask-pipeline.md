# 36 · Project 2: The Flask Flow as a Jenkinsfile

> **Level:** ★★ intermediate · **Status:** ✅ rewritten from your notes (two improvements marked)
>
> **You will learn:** how to rebuild Project 1 (checkout → build → push → deploy → test) as a real Jenkinsfile, then improve it with Pipeline-from-SCM, `post` actions, a **deploy-info** artifact with a fingerprint, and workspace cleanup.
>
> **You need:** topics 24, 28, 31, 33–35.
>
> **From your original notes:** Day 06 › *Build a Production-grade Jenkinsfile (replicates Day-5)*: Step 3 *Full Jenkinsfile*; *Improving our Day-5 flow with a Jenkinsfile*: 1) Pipeline script from SCM, 2) Post actions, 3) Generate and archive deploy-info.txt, 4) Clean the workspace; *Consolidated Jenkinsfile*; *Conclusion* · file `Day 06/Jenkinsfile`.
>
> 📁 Files: [`project-files/project-2-flask-pipeline/`](../project-files/project-2-flask-pipeline/) (`Jenkinsfile` = your original, `Jenkinsfile.corrected` = with the fixes below)

---

## What it is

The **same flow** as Project 1, now in a **Jenkinsfile**, plus four small improvements:
1. Use **Pipeline script from SCM**.
2. Add **post actions**: what to do on success, on failure, and always.
3. Generate a **deploy-info.txt** (deployment details) and archive it.
4. **Clean the workspace** at the end.

---

## Why it exists

Same result as Freestyle, but versioned, reviewable, with clear stages, and a traceable record of each deployment.

---

## Analogy

Writing down the recipe you've been cooking from memory, then adding a label to every jar you fill ("batch 12, made from recipe v3, on this date").

---

## How it works inside

With **Pipeline script from SCM**, Jenkins reads `Jenkinsfile` from the repo, declarative auto-checks out the same commit (so `GIT_COMMIT`/`GIT_BRANCH` exist), each stage runs `docker …` against the host daemon (DooD, topic 27), the deploy stage writes and archives a record, and `post` reports the result.

---

## Config / Jenkinsfile / commands

### Step 3: full Jenkinsfile (simple, clear, production-ish)

```groovy
pipeline {
  agent any

  environment {
    IMAGE = 'docker.io/<your-dockerhub-user>/cwvj-flask'   // change to your namespace/repo
    TAG   = "${env.BUILD_NUMBER}"
  }

  stages {
    stage('checkout') {
      steps {
        git branch: 'main',
            credentialsId: 'github-pat',
            poll: false,
            url: 'https://github.com/CloudWithVarJosh/cwvj-private-repo.git'
      }
    }

    stage('build') {
      steps {
        sh 'docker build -t "$IMAGE:$TAG" -t "$IMAGE:latest" .'
      }
    }

    stage('push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
          usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PWD')]) {
          sh 'echo "$DOCKERHUB_PWD" | docker login -u "$DOCKERHUB_USER" --password-stdin'
          sh 'docker push "$IMAGE:$TAG"'
          sh 'docker push "$IMAGE:latest"'
        }
      }
    }

    stage('deploy') {
      steps {
        sh 'docker pull "$IMAGE:$TAG"'
        sh 'docker rm -f cwvj-flask || true'
        sh 'docker run -d --name cwvj-flask -p 5000:5000 "$IMAGE:$TAG"'
      }
    }

    stage('test') {
      steps {
        sh 'sleep 2; curl -s http://localhost:5000 || true'
      }
    }
  }
}
```
Every `sh` uses **single quotes**, so the shell expands `$IMAGE`, `$TAG` and the credentials (topic 30).

### Improvement 1: use Pipeline script from SCM (checkout happens automatically)

Job → **Configure → Definition: Pipeline script from SCM** · **SCM:** Git · **Repository URL:** your private repo · **Credentials:** GitHub PAT · **Branches to build:** `main`. Put the **Jenkinsfile** in that repo and **delete the `checkout` stage** (declarative checks out automatically, topic 31).

### Improvement 2: post actions

```groovy
post {
  success { echo "Build ${env.BUILD_NUMBER} succeeded" }
  failure { echo "Build ${env.BUILD_NUMBER} failed" }
  always  { echo "Build ${env.BUILD_NUMBER} finished" }
}
```

### Improvement 3: generate and archive `deploy-info.txt`

Right after deploying, write a small file and **archive** it with the build:
```groovy
stage('deploy') {
  steps {
    sh 'docker pull "$IMAGE:$TAG"'
    sh 'docker rm -f cwvj-flask || true'
    sh 'docker run -d --name cwvj-flask -p 5000:5000 "$IMAGE:$TAG"'

    sh '''
      cat > deploy-info-$BUILD_NUMBER.txt <<EOF
build: $BUILD_NUMBER
image: $IMAGE:$TAG
commit: ${GIT_COMMIT}
branch: $GIT_BRANCH
time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
url: $BUILD_URL
EOF
    '''

    archiveArtifacts artifacts: "deploy-info-${BUILD_NUMBER}.txt", fingerprint: true
  }
}
```
- `sh '''…'''`: a triple-single-quoted multi-line script, so Groovy doesn't touch it and the **shell** expands everything.
- `cat > file <<EOF … EOF` is a **heredoc** (Linux notes topic 016): the lines up to `EOF` become the file's content, with variables expanded. The closing `EOF` must start at column 0.
- `$(date -u +…)` = command substitution: the current UTC time in ISO 8601 format.
- `${GIT_COMMIT}`/`$GIT_BRANCH` are only set when using Pipeline script from SCM (topic 34).
- `archiveArtifacts … fingerprint: true` (double quotes: Groovy expands `${BUILD_NUMBER}` in the file name). `fingerprint: true` tells Jenkins to compute and store a unique hash ("fingerprint") for the file (topic 18). Your repo file also passes `followSymlinks: false` (don't follow symbolic links when archiving).

### Improvement 4: clean the workspace

Add a final cleanup stage:
```groovy
stage('cleanup') {
  steps { cleanWs() }
}
```
(If unsure a step exists, use the Snippet Generator at `http://localhost:8080/pipeline-syntax/`.)

### Consolidated Jenkinsfile (simple + improvements), as in your notes

```groovy
pipeline {
  agent any

  environment {
    IMAGE = 'docker.io/<your-dockerhub-user>/cwvj-flask'   // change to your namespace/repo
    TAG   = "${env.BUILD_NUMBER}"                     // simple, unique per run
  }

  stages {

    // Jenkins auto-checks out when using "Pipeline script from SCM"

    stage('build') {
      steps {
        sh 'docker build -t "$IMAGE:$TAG" -t "$IMAGE:latest" .'
      }
    }

    stage('push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
          usernameVariable: 'DOCKERHUB_USER', passwordVariable: 'DOCKERHUB_PWD')]) {
          sh 'echo "$DOCKERHUB_PWD" | docker login -u "$DOCKERHUB_USER" --password-stdin'
          sh 'docker push "$IMAGE:$TAG"'
          sh 'docker push "$IMAGE:latest"'
        }
      }
    }

    stage('deploy') {
      steps {
        sh 'docker pull "$IMAGE:$TAG"'
        sh 'docker rm -f cwvj-flask || true'
        sh 'docker run -d --name cwvj-flask -p 5000:5000 "$IMAGE:$TAG"'

        // write deploy info with build number in the filename
        sh '''
          cat > deploy-info-$BUILD_NUMBER.txt <<EOF
build: $BUILD_NUMBER
image: $IMAGE:$TAG
commit: ${GIT_COMMIT}
branch: $GIT_BRANCH
time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
url: $BUILD_URL
EOF
        '''

        // archive and fingerprint it
        archiveArtifacts artifacts: "deploy-info-${BUILD_NUMBER}.txt", fingerprint: true
      }
    }

    stage('test') {
      steps {
        sh 'sleep 2; curl -s http://localhost:5000 || true'
      }
    }

    stage('cleanup') {
      steps {
        cleanWs()
      }
    }
  }

  post {
    success { echo "Build ${env.BUILD_NUMBER} succeeded" }
    failure { echo "Build ${env.BUILD_NUMBER} failed" }
    always  { echo "Build ${env.BUILD_NUMBER} finished" }
  }
}
```
**That's it.** Same Project 1 workflow, now as a Jenkinsfile, plus post actions, a deploy record you can download, and a clean workspace, with the **image tag kept simple** (the build number).

Your committed `Day 06/Jenkinsfile` is the same, except its `test` stage only prints a hint: `sh 'sleep 2; echo "Hit http://localhost:5000 to see the app."'`.

### Two fixes (in `Jenkinsfile.corrected`)

> ⚠️ **Corrected (test stage):** was `sh 'sleep 2; curl -s http://localhost:5000 || true'`. Now:
> ```groovy
> stage('test') {
>   steps {
>     sh 'docker run --rm --network container:cwvj-flask curlimages/curl -fsS --retry 5 --retry-connrefused http://localhost:5000'
>   }
> }
> ```
> The original **can never fail**, for two reasons. The `sh` step runs **inside the Jenkins container**, where `localhost:5000` is the Jenkins container itself (the app is a sibling container, topic 26), so curl gets "connection refused". And `|| true` hides that. Running curl inside the app container's network namespace with `-f` (fail on HTTP errors) and no `|| true` makes it a real smoke test.

> ⚠️ **Corrected (cleanup):** was a `cleanup` **stage** at the end. Now `post { cleanup { cleanWs() } }`, because a stage is **skipped when any earlier stage fails**, so failed builds (the ones most likely to leave junk) never got cleaned. `post { cleanup }` runs every time, after the other post conditions (topic 35).

---

## Hands-on lab

1. Commit `project-files/project-2-flask-pipeline/Jenkinsfile.corrected` as `Jenkinsfile` in your private repo next to the app files (change `IMAGE` to your namespace).
2. Configure `flask-pipeline` as **Pipeline script from SCM** and build.
3. Download `deploy-info-N.txt` from the build's **Artifacts**; check that `commit:` matches `git log -1` in your repo.
4. Stop the app container on the host (`docker rm -f cwvj-flask`) right after the deploy stage (add a `sleep 20` to give yourself time) and watch the **corrected** test stage fail the build.
5. Look at the build's **Stages** view: one box per stage, with timings.

---

## Where you'll use it

The template for any single-host container deploy, and the starting point for multibranch (topic 47) and shared libraries (topic 57).

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `commit:` line empty in deploy-info | Inline script with a `git` step | Use Pipeline script from SCM (topic 34) |
| `No such DSL method 'cleanWs'` | Workspace Cleanup plugin missing | Install it |
| `ERROR: No artifacts found that match the file pattern "deploy-info-12.txt"` | Heredoc failed (e.g. `EOF` indented) | Keep the closing `EOF` at column 0 |
| `permission denied … docker.sock` | DooD group missing | Topic 27 |
| Push succeeds, deploy runs the old version | Deployed `latest` from a stale local cache | Deploy `$IMAGE:$TAG` (as here) |

---

## Quick recap

- Project 1 as code: build → push → deploy → test, with credentials by ID and single-quoted `sh`.
- Pipeline from SCM gives automatic checkout and Git variables.
- `deploy-info-N.txt` (archived + fingerprinted) records what was deployed.
- Real smoke tests must be able to fail; cleanup belongs in `post { cleanup }`.

**Interview questions**

1. **Q: How do you record what a pipeline deployed?**
   A: Write a small deploy record (build number, image + tag/digest, commit, branch, time, build URL) and archive it with a fingerprint, or publish it to a release/manifest store.

2. **Q: Why might `curl localhost` in a Jenkins stage not test your app?**
   A: The step runs on the Jenkins node (here, inside the Jenkins container), so localhost is that node, not the app's container or server. Test from the app's network or via its real address.

3. **Q: Why move cleanup from a stage into `post`?**
   A: Stages after a failure are skipped; `post { cleanup }` always runs.

---

*Day 06 conclusion, kept:* you took a working Freestyle flow and turned it into a clear, maintainable **Pipeline** with environment variables, secure credential use, post actions, deploy metadata and cleanup. You now have the structure to grow: parameters, conditionals, parallel stages, and Pipeline from SCM for real projects. Next we iterate on this Jenkinsfile: guards and tests (topics 37–41), and promotion patterns.

---

## References (from your original Day 06 notes)

* [Jenkins Pipeline (Overview)](https://www.jenkins.io/doc/book/pipeline/)
* [Declarative Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
* [Pipeline Syntax Snippet Generator](https://www.jenkins.io/doc/book/pipeline/getting-started/#snippet-generator)
* [Using Credentials in Jenkins Pipelines](https://www.jenkins.io/doc/book/using/using-credentials/)
* [Docker: `docker login` and image tagging](https://docs.docker.com/reference/cli/docker/)
