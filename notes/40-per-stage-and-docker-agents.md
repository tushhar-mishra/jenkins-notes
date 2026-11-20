# 40 · Per-Stage Agents, Docker Agents and Stash

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** how to give each stage its own machine or container (`agent none` + per-stage agents), how to run steps **inside a container image** (`agent { docker }`, `agent { dockerfile }`, `docker.image().inside`), and how to move files between stages on different nodes (`stash`/`unstash`).
>
> **You need:** topics 19 (tools on nodes), 26–27 (Docker), 31.
>
> **From your original notes:** Day 06 › *What each block means* (`agent { label }`, `agent none` → "define agents per-stage (advanced)").

---

## What it is

- **`agent none`** at the top + an `agent` in each stage: different stages run on different nodes (e.g. build on Linux, sign on a locked-down signing node).
- **Docker agents:** Jenkins starts a container from an image on a Docker-capable node, **mounts the workspace into it**, and runs the stage's `sh` steps **inside** the container. The image provides the toolchain, so nothing needs installing on the node (option C in topic 19).
- **`stash`/`unstash`:** save a set of files from one stage's workspace to the controller, and restore them in another stage, even on another node.

---

## Why it exists

Toolchains conflict (Java 17 vs 21, Node 18 vs 22). Installing everything on every agent leads to drift. Containers give each stage the exact tools it needs, freshly, every build.

---

## Analogy

Instead of one workshop stocked with every tool, each job gets a **pre-packed toolbox** (the image) delivered to the bench. `stash` is a **courier** that moves your half-built part to the next workshop.

---

## How it works inside

`agent { docker { image 'maven:3.9-eclipse-temurin-21' } }` (Docker Pipeline plugin):
1. The stage gets an executor on a node with Docker (any node, or one matching `label`).
2. Jenkins runs `docker pull` (if needed) and then `docker run -d -t -u <uid>:<gid> -w <workspace> -v <workspace>:<workspace> … <image> cat`: the container just waits (`cat`).
3. Each `sh` step becomes `docker exec <container> sh -c '…'`, running **as the agent's UID**, in the same workspace path.
4. At the end of the stage, the container is stopped and removed.

Consequences:
- Files written in the container appear in the node's workspace (same mount), owned by the agent user.
- The image needs a shell, and must tolerate running as an arbitrary UID (some images write to `/root` and fail; set `HOME` or use `args`).
- With DooD on the controller (our lab), this only works if workspace paths are the same on the host and in the Jenkins container (topic 26). It works naturally on a **real agent** with Docker (topic 51).

`stash` copies files over Remoting to the controller (`builds/<n>/stashes/`); `unstash` copies them back. Fine for MBs; don't stash GBs.

---

## Config / Jenkinsfile / commands

### Per-stage agents + stash

```groovy
pipeline {
  agent none
  stages {
    stage('Build jar') {
      agent { docker { image 'maven:3.9-eclipse-temurin-21'; args '-v maven-cache:/cache/m2' } }
      steps {
        sh 'mvn -B -q -Dmaven.repo.local=/cache/m2 clean package -DskipTests'
        stash name: 'jar', includes: 'target/*.jar'
      }
    }
    stage('Test') {
      agent { docker { image 'maven:3.9-eclipse-temurin-21' } }
      steps { sh 'mvn -B test' }
      post  { always { junit 'target/surefire-reports/*.xml' } }
    }
    stage('Image') {
      agent { label 'docker' }
      steps {
        unstash 'jar'
        sh 'docker build -t app:$BUILD_NUMBER .'
      }
    }
  }
}
```
- `args '-v maven-cache:/cache/m2'` = extra `docker run` flags: here a named volume to cache Maven downloads between builds, used through `-Dmaven.repo.local=/cache/m2`.
- ⚠️ *Corrected:* the original mounted the cache at `/root/.m2`. But Jenkins runs the container as the **agent's UID** (`-u 1000:1000`, see above), not root, so that user can't write to `/root` and Maven ignored or failed on the cache. Named volumes are created **owned by root**, so give the agent's UID the volume once: `docker run --rm -v maven-cache:/cache alpine sh -c 'mkdir -p /cache/m2 && chown -R 1000:1000 /cache'`.
- `stash name: 'jar', includes: 'target/*.jar'` then `unstash 'jar'` on a different node.

Console (shape):
```
$ docker run -t -d -u 1000:1000 -w /home/jenkins/workspace/app -v /home/jenkins/workspace/app:/home/jenkins/workspace/app:rw,z ... maven:3.9-eclipse-temurin-21 cat
$ docker top 7f3a… -eo pid,comm
+ mvn -B -q clean package -DskipTests
[Pipeline] stash
Stashed 1 file(s)
...
$ docker stop --time=1 7f3a…
$ docker rm -f --volumes 7f3a…
```

### `reuseNode` and `dockerfile`

```groovy
pipeline {
  agent { label 'docker' }
  stages {
    stage('Lint in container, same workspace') {
      agent { docker { image 'node:22-alpine'; reuseNode true } }   // same node + workspace as the top-level agent
      steps { sh 'npm ci && npm run lint' }
    }
    stage('Custom toolchain') {
      agent { dockerfile { filename 'ci/Dockerfile.build'; dir '.'; additionalBuildArgs '--pull' } }
      steps { sh 'make all' }
    }
  }
}
```
- `reuseNode true`: run the container on the **same** node and workspace as the outer agent: no new executor, no stash needed.
- `agent { dockerfile }`: build an image from a Dockerfile **in the repo** and use it as the agent, so the toolchain is versioned with the code.

### Scripted equivalent

```groovy
node('docker') {
  checkout scm
  docker.image('python:3.12-slim').inside('-e PIP_CACHE_DIR=/tmp/pip') {
    sh 'pip install -r requirements.txt && pytest -q'
  }
}
```

---

## Deeper dive

### All the `docker` agent options

```groovy
agent {
  docker {
    image 'registry.example.com/ci/python:3.12'
    label 'docker'                              // which nodes may run it
    registryUrl 'https://registry.example.com'  // pull from a private registry…
    registryCredentialsId 'registry-pull'       // …with this credential
    alwaysPull true                             // re-pull even if cached (gets patched base images)
    args '-v pip-cache:/root/.cache/pip -e HOME=/tmp --entrypoint='
    reuseNode false
    customWorkspace 'ws/python'                 // optional fixed workspace path
  }
}
```
- **`--entrypoint=`**: Jenkins starts the container with the command `cat` to keep it alive. If the image has an `ENTRYPOINT` (e.g. `trivy`, `kubectl` or `aws-cli` images), the entrypoint receives `cat` as an argument and the container exits immediately, giving errors like `The container started but didn't run the expected command`. Clear the entrypoint with `args '--entrypoint='`.
- **User:** Jenkins passes `-u <agent uid>:<gid>` so files in the workspace stay owned by the agent user. Images that expect root (writing to `/root`, `apt-get install` at run time) fail: set `HOME`, use writable paths, or build a proper CI image.
- **`newContainerPerStage()`** (option) with a top-level docker agent: each stage gets a fresh container from the same image, sharing the workspace.

### `agent { dockerfile }` details

- Builds the image on the agent from a Dockerfile in the repo (`filename`, `dir`, `additionalBuildArgs '--build-arg PY=3.12'`), tags it with a hash of the Dockerfile, and reuses it until the Dockerfile changes.
- The toolchain is versioned with the code: a change to the build environment goes through PR review like everything else.

### Scripted Docker Pipeline API (you'll see it in older Jenkinsfiles and libraries)

```groovy
node('docker') {
  checkout scm
  def img
  docker.withRegistry('https://registry.example.com', 'registry-push') {     // login for the block
    img = docker.build("acme/app:${env.BUILD_NUMBER}", '--pull .')           // docker build
    img.inside('-e HOME=/tmp') { sh 'make test' }                            // run steps inside it
    img.push()                                                               // push :BUILD_NUMBER
    img.push('latest')
  }
}
```
- `docker.withRegistry(url, credentialsId)` does a temporary `docker login`.
- `docker.build` returns an image object; `.inside` is the same mechanism as `agent { docker }`; `.push(tag)` pushes.

### `stash` / `unstash` details

```groovy
stash name: 'dist', includes: 'dist/**', excludes: '**/*.map', allowEmpty: false, useDefaultExcludes: true
unstash 'dist'
```
- Stashes belong to **one build**; they're deleted when the build ends (unless `preserveStashes` keeps them for Restart from Stage).
- `useDefaultExcludes` (true) skips `.git`, `.svn`, etc.
- They travel through the controller, so keep them small (MBs). For big outputs, push to an artifact repository or object storage and pass the URL/digest instead.

### When to use which

| Need | Use |
|---|---|
| A tool for one stage | `agent { docker { image … } }` (or `container('x')` on Kubernetes) |
| The same container for several stages, same workspace | top-level docker agent, or `reuseNode true` |
| The toolchain defined in the repo | `agent { dockerfile }` |
| Different OS / machine per stage | `agent none` + per-stage labels, `stash` between them |
| Build and push images | a Docker-capable label, or a daemonless builder (topic 26) |

---

## Hands-on lab

Do this after topic 51 (you need a real agent with Docker), or on the built-in node of a Jenkins **installed directly on a VM** (topic 49):
1. Run the three-stage pipeline above against the Java sample (`project-files/project-4-devsecops-eks/java-maven`).
2. Remove Maven from the node (or never install it) and see that the build still works: the image provides it.
3. Run it twice and compare Maven download times (the `maven-cache` volume).
4. Comment out `unstash 'jar'` and read the `COPY failed: no source files were specified` error in the image stage.

---

## Where you'll use it

- Polyglot organisations: one generic Docker agent pool, toolchains from images.
- Reproducible builds (the toolchain image is pinned like any dependency).
- Splitting build/test/sign/deploy across nodes with different trust levels.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `docker: not found` / `Cannot connect to the Docker daemon` | The node has no Docker | Use a Docker-capable label |
| `mkdir: cannot create directory '/.npm': Permission denied` | Container runs as the agent UID with no writable `HOME` | `args '-e HOME=/tmp'` or cache paths under the workspace |
| Files from a container can't be deleted by cleanup | The step ran as root (`args '-u root'`) | Don't run as root, or fix ownership at the end |
| `No such saved stash 'jar'` | Wrong name, or the stash stage was skipped | Match names; ensure the producer stage ran |
| Workspace empty inside the container (DooD lab) | Host and container paths differ | Use a real agent, or same-path volume mounts |

---

## Quick recap

- `agent none` + per-stage agents → each stage on the right node.
- `agent { docker { image … } }` runs the stage's steps inside a container with the workspace mounted; `dockerfile` builds the image from your repo.
- `reuseNode true` keeps the same node/workspace.
- `stash`/`unstash` move small files between stages and nodes.

**Interview questions**

1. **Q: How do you avoid installing build tools on every agent?**
   A: Run stages in container images with `agent { docker { image … } }` (or Kubernetes pod templates), so the image carries the pinned toolchain.

2. **Q: How do files get from one stage to another on a different node?**
   A: `stash` them in the first stage and `unstash` them in the second; for large artifacts use a repository or object storage.

3. **Q: What does the Docker agent actually do under the hood?**
   A: It starts the image with the workspace bind-mounted at the same path, running as the agent's UID, then runs each `sh` step through `docker exec`, and removes the container at the end of the stage.
