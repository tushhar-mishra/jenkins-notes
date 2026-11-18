# 19 · Git Checkout and Tools

> **Level:** ★★ intermediate · **Status:** ✅➕ rewritten and expanded
>
> **You will learn:** how a job checks out code from Git, the golden rule "Jenkins can only run tools that exist on the node", two ways to provide tools like Maven (Manage Jenkins → Tools vs an OS install), and enough Maven to read the commands in this course.
>
> **You need:** topics 05, 17, 18.
>
> **From your original notes:** Day 03 › *Step 3 — SCM checkout (Git) + tool requirements*, *Fix options for Git*, *Using Maven (two beginner-friendly approaches)* A and B, *Which to pick*, *Tip*, *Key points to remember*, *Conclusion*.

---

## What it is

- **SCM checkout:** the **Source Code Management** section of a job tells Jenkins which Git repo and branch to fetch into the workspace before the build steps run.
- **Tools:** any program a build step calls: `git`, `mvn`, `java`, `node`, `helm`, `docker`, `kubectl`, `trivy`. They must be available **on the node that runs the build**.
- **Jenkins Tool installations** (**Manage Jenkins → Tools**): Jenkins downloads and caches a chosen version of a tool on the node the first time a build asks for it, then puts it on that build's `PATH`.

---

## Why it exists

Builds fail constantly with `command not found` because people assume "Jenkins has Maven". It doesn't. Each node has only what's installed on it. Knowing your options (install on the node, let Jenkins install it, or use a container that has it) is the difference between reproducible builds and snowflake servers.

---

## Analogy

Hiring a **contractor** (the node): they only have the tools in their van. You can (a) give them a permanent toolbox (OS install), (b) have a tool library deliver the exact drill you specify for each job (Jenkins Tools), or (c) send a fully equipped van for each job (a container agent, topic 40).

---

## How it works inside

### What happens during Git checkout

1. Jenkins (on the build node) runs `git init` in the workspace if needed, then `git fetch` from the repo URL using the selected **credential** (for private repos).
2. It resolves the branch spec (e.g. `*/main`) to a commit SHA.
3. It runs `git checkout -f <sha>` (a **detached HEAD**, meaning the exact commit, not a branch).
4. It sets `GIT_COMMIT`, `GIT_BRANCH`, `GIT_URL` and computes the **changelog** (commits since the last build).
5. The credential is passed to Git only for that command (via a temporary askpass helper), not saved in `.git/config`.

### "Tools live on nodes"

Jenkins itself doesn't run `mvn`; it asks the node's OS to run it. If the binary isn't on the node's `PATH`, the shell says `not found`. Options:

| Option | How | Pros | Cons |
|---|---|---|---|
| **A) Manage Jenkins → Tools** | Define e.g. Maven `M3`, "install automatically", version X | Versioned per job, no root needed, works on clean nodes | Needs internet (or an internal mirror); in Freestyle only certain steps see it |
| **B) OS install on the node** | `apt-get install maven` on the agent/controller | Works with any shell step instantly | Manual versions, drift between nodes, less reproducible |
| **C) Container agent** (topic 40) | `agent { docker { image 'maven:3.9-eclipse-temurin-21' } }` | Exact version, nothing installed on the node | Needs Docker on the agent |

Production teams usually use **C** (or Kubernetes pod agents, topic 53), or **pre-baked agent images/VMs** with the toolchain installed.

---

## Config / Jenkinsfile / commands

### Step 3: SCM checkout (Git) + tool requirements

- **Edit job → Source Code Management → Git**
  - **Repository URL:** `<your repo>` (HTTPS works).
  - **Credentials:** add if private (topic 23).
  - **Branches to build:** `*/main`.
- **Build Steps → Execute shell** (replace the commands):
  ```bash
  echo "Repo status:"
  git --version
  git log --oneline -n 1 || true
  ```
- **Build Now → Console Output:**
  ```
  The recommended git tool is: NONE
  Cloning the remote Git repository
  Cloning repository https://github.com/you/jenkins-lab.git
   > git init /var/jenkins_home/workspace/intro-freestyle
   > git fetch --tags --force --progress -- https://github.com/you/jenkins-lab.git +refs/heads/*:refs/remotes/origin/*
  Checking out Revision 4b1a0d2… (refs/remotes/origin/main)
   > git checkout -f 4b1a0d2…
  Commit message: "docs: readme"
  + git --version
  git version 2.39.5
  + git log --oneline -n 1
  4b1a0d2 docs: readme
  ```

If a node doesn't have Git, you'd see `git: command not found`. That means the **node** running this job lacks Git.

> ⚠️ **Corrected:** the notes suggest you'll hit `git: command not found` in the Docker lab. Now: the official `jenkins/jenkins` image **already includes Git**, because the Git plugin needs it for checkout, so you won't see that error in your lab. The lesson is still exactly right for other tools. Try `mvn -v` or `helm version` in the same step and you'll get `not found`. Agents you create yourself (Part 8) also need Git installed.

**Fix options for Git (the same pattern applies to any CLI):**
- **Simple (lab):** install on the node:
  ```bash
  # inside the Jenkins container (controller) for our lab
  docker exec -u root jenkins bash -c 'apt-get update && apt-get install -y git'
  ```
  (Changes made inside a container are lost when it's recreated. For lasting changes, build a custom image, topic 67.)
- **Proper (admin):** define Git versions in **Manage Jenkins → Tools**, or run the job on an **agent** image/VM that already has Git.

> **Takeaway:** Jenkins can only run CLIs that exist **on the node** (or are provided by Tools for that build). No Maven → no `mvn`; no Helm → no `helm`.

### Using Maven: two beginner-friendly approaches

#### A) Manage Jenkins → Tools (preferred for Freestyle/Pipeline; no OS install)

- **Configure the Maven tool once:** **Manage Jenkins → Tools → Maven installations → Add Maven**
  - **Name:** `M3`
  - **Install automatically:** ✅ pick a version (e.g. 3.9.x)
- **Freestyle job:** **Add build step → Invoke top-level Maven targets**
  - **Maven Version:** `M3`
  - **Goals:** `-B clean test package` *(or `-v` to just print the version)*
  - → Jenkins downloads Maven into `tools/` on the node the first time and puts it on the `PATH` **for this build**, even though the node doesn't have `mvn` installed.
- **Pipeline (for later, topic 31):**
  ```groovy
  pipeline {
    agent any
    tools { maven 'M3' }
    stages { stage('Check') { steps { sh 'mvn -v' } } }
  }
  ```
  `tools { maven 'M3' }` installs/locates the tool named `M3` and adds it to the `PATH` for every `sh` step.

**Pros:** versioned/reproducible, no root access needed, works on clean nodes.
**Gotcha:** in Freestyle, a plain **Execute shell** step won't see `mvn` unless you either (1) use the **Invoke top-level Maven targets** step as above, or (2) add a small bridge like the **Tool Environment** plugin to expose tools on the `PATH`. (Pipelines don't have this problem: `tools {}` applies to all steps.)

#### B) OS-level install on the node (quick lab hack)

- Install Maven directly where the job runs (controller or agent):
  ```bash
  # inside the Jenkins container (controller) for our lab
  docker exec -u root jenkins bash -c 'apt-get update && apt-get install -y maven && mvn -v'
  ```
- Then your Freestyle **Execute shell** can run:
  ```bash
  mvn -B clean test package
  ```

**Pros:** works with any plain shell step immediately.
**Cons:** you manage versions by hand; they drift across nodes; less reproducible.

#### Which to pick (simple rule)

- **Learning/labs, or teams that want reproducibility:** **use Tools (A).** Pick versions per job; no OS tinkering.
- **Quick local demo or a one-off node:** **OS install (B)** is fine. Just know it doesn't scale cleanly.
- **Production:** container/pod agents with the toolchain baked in (topics 40, 53).

> **Tip:** to only *print* Maven's version:
> - Tools way (Freestyle): "Invoke top-level Maven targets" with **Goals:** `-v`
> - OS way: an **Execute shell** step `mvn -v` after installing Maven on the node.

### Maven in five minutes (what you need for this course)

**Apache Maven** is the standard build tool for Java. A project is described by **`pom.xml`** (Project Object Model): its name, version, dependencies and plugins.

- **Coordinates:** `groupId:artifactId:version`, e.g. `com.cloudwithvarjosh:cwvj-devsecops-demo:1.0.0-SNAPSHOT`. **SNAPSHOT** = a development (not yet released) version.
- **Dependencies** are downloaded from **Maven Central** (or your Nexus/Artifactory) into the local cache `~/.m2/repository`.
- **Lifecycle phases** run in order; asking for one runs all the earlier ones:
  `validate → compile → test → package → verify → install → deploy`
  - `test` runs unit tests (the **Surefire** plugin).
  - `package` makes `target/<artifactId>-<version>.jar`.
  - `verify` runs checks after packaging (coverage reports, integration tests).
  - `install` copies the jar to your local `~/.m2`; `deploy` uploads it to a remote repository.
- `clean` is a separate lifecycle that deletes `target/`.
- Common CI command: `mvn -B clean verify` (`-B` = batch mode: no prompts, cleaner logs).

Topic 59 adds JUnit, JaCoCo coverage and the SonarQube plugin.

### Key points to remember

- **Node of execution:** Freestyle steps run on the assigned node (today: the controller). For real projects, attach **agents** (VMs/containers/K8s pods) with the required toolchain.
- **Tools live on nodes:** if the node lacks **Git/Maven/Helm**, commands fail. Use **Manage Jenkins → Tools** or provide an agent image/VM that has them.
- **Artifacts:** archive outputs you need to keep (reports, binaries); they're attached to the build record (topic 18).
- **Parameters:** make jobs reusable; values show up as env vars (topic 20).
- **Security & scaling:** avoid piling every tool into the controller. Prefer **agents** and keep the controller lean and stable.

This single job, edited in stages, gives a clean tour of **execution context**, **workspaces/env vars**, **artifacts**, **SCM**, **tooling** and **parameters**, without overwhelming you.

---

## Hands-on lab

1. Point `intro-freestyle` at your `jenkins-lab` repo (public for now, or add a credential first, topic 23).
2. Add `mvn -v` to the Execute shell step and build: read the `not found` error.
3. Configure **Tools → Maven `M3`** (install automatically). Add a build step **Invoke top-level Maven targets**, version `M3`, goals `-v`. Build again: Jenkins downloads Maven (`Unpacking https://repo.maven.apache.org/… to /var/jenkins_home/tools/hudson.tasks.Maven_MavenInstallation/M3`) and prints its version.
4. Check where it went: `docker exec jenkins ls /var/jenkins_home/tools`.
5. Add the Day 1 Java sample (`project-files/project-4-devsecops-eks/java-maven`) to your repo and run goals `-B clean package`. Archive `target/*.jar`.

---

## Where you'll use it

- Every job that compiles code.
- Diagnosing `not found` / wrong-version errors on agents.
- Designing agent images (what toolchain each label provides).

---

## When it breaks

| Error | Meaning | Fix |
|---|---|---|
| `mvn: not found` / `helm: command not found` | Tool missing on that node | Tools config, OS install, or a container agent |
| `stderr: remote: Repository not found` / `Authentication failed` | Private repo without (valid) credentials | Add a PAT/GitHub App credential (topic 23) |
| `Couldn't find any revision to build. Verify the repository and branch configuration` | Branch spec doesn't match (`*/master` vs `main`) | Fix **Branches to build** |
| `Unable to find Jenkinsfile` / Maven `Could not resolve dependencies` | Wrong path or no network to Maven Central | Check paths; proxy/mirror settings (`settings.xml`) |
| Tools auto-install fails: `UnknownHostException` | No internet on the node | Point Tools at a local path or internal mirror |

---

## Quick recap

- The SCM section fetches an exact commit into the workspace and sets `GIT_*` variables.
- **Tools must exist on the node.** Provide them via Manage Jenkins → Tools, an OS install, or container agents.
- In Freestyle, Tools-installed Maven is visible to the Maven build step; Pipelines use `tools {}`.
- Maven lifecycle: `compile → test → package → verify → install → deploy`; CI usually runs `mvn -B clean verify`.

**Interview questions**

1. **Q: A build fails with `mvn: not found`, but Maven is installed on the controller. Why?**
   A: The build ran on a different node (an agent) that doesn't have Maven, or Maven isn't on that process's `PATH`. Tools must exist on the node that runs the build.

2. **Q: How do you give builds a specific Maven version without installing it on every agent?**
   A: Define it in Manage Jenkins → Tools with automatic installation and reference it (`tools { maven 'M3' }`), or run the stage in a container image that has that version.

3. **Q: What does `mvn clean verify` do?**
   A: Deletes `target/`, then runs the lifecycle up to `verify`: compile, test, package and post-package checks (like coverage reports).

---

*Day 03 conclusion (kept):* you now have a **running Jenkins** (the Docker lab), understand **when to choose** each install method, and have created a **Freestyle job** that prints environment details, archives artifacts and checks out code. You also know the difference between **OS-level tools** and **Tools-managed** integrations. Next: parameters, triggers and scheduled jobs (topics 20–22), then pipelines (Part 6) and promoting artifacts/images by **immutable digest**.
