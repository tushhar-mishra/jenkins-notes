# 17 · Your First Freestyle Job

> **Level:** ★ foundation · **Status:** ✅ rewritten from your notes
>
> **You will learn:** how to create a Freestyle job, where its shell commands actually run, the built-in environment variables Jenkins gives every build, and why you print build details.
>
> **You need:** topics 11, 14, 15.
>
> **From your original notes:** Day 03 › *First steps with Jenkins jobs (start with Freestyle)*, *Step 0 — Create the job*, *Step 1 — Where do commands run? (Execute Shell)*, built-in variables, *See all built-in env vars*, *Dump all env vars*, *Why print build details?*.

---

## What it is

A **Freestyle project** is the original Jenkins job type: you configure it in web forms (source code, triggers, build steps, post-build actions) instead of writing code. It's the simplest way to see the core ideas (node, workspace, environment, artifacts) before we move to pipelines as code (Part 6).

In this part we create **one Freestyle job** and progressively edit it to learn the essentials: where commands run, how workspaces and environment variables behave, saving **artifacts**, connecting **Git**, **tool requirements** (Git/Maven/Helm), and **parameters**.

---

## Why it exists

Freestyle came first in Jenkins' history and is still used for simple one-off tasks (a nightly cleanup, a quick script). Learning it shows you clearly what Jenkins does for you on every build, things pipelines also do but hide behind syntax.

---

## Analogy

A **printed form** you fill in for a task: "Get the code from here. Run these commands. Keep these output files." Easy for one task; painful when you have fifty forms to keep in sync. That's the reason for pipelines.

---

## How it works inside

When you click **Build Now** on a Freestyle job:
1. A build (`#1`) is queued and assigned an executor on a node (here: the **built-in node**, i.e. the controller container, because we have no agents yet).
2. Jenkins creates/uses the **workspace** `/var/jenkins_home/workspace/<job-name>` on that node.
3. It sets **environment variables** describing the build.
4. Each **Execute shell** step is written to a temporary script and run with `/bin/sh -xe` (`-x` prints each command before running it, shown with a `+` prefix; `-e` stops at the first failing command).
5. If any command returns a **non-zero exit code**, the build is marked **FAILURE**.

---

## Config / Jenkinsfile / commands

### Step 0: create the job

- **New Item → Freestyle project → Name:** `intro-freestyle` → **OK**.
- Leave **Source Code Management** = *None* for now.

### Step 1: where do commands run? (Execute shell)

**Build Steps → Add build step → Execute shell:**

```bash
echo "Node info:"
uname -a

echo "Workspace: $WORKSPACE"

echo "Build: $JOB_NAME #$BUILD_NUMBER"

echo "Node: $NODE_NAME"
```

**Save → Build Now → open build #1 → Console Output:**

```
Started by user admin
Running as SYSTEM
Building in workspace /var/jenkins_home/workspace/intro-freestyle
[intro-freestyle] $ /bin/sh -xe /tmp/jenkins1234567890.sh
+ echo Node info:
Node info:
+ uname -a
Linux 3f2c1a9b8d7e 6.6.87.2-microsoft-standard-WSL2 #1 SMP x86_64 GNU/Linux
+ echo Workspace: /var/jenkins_home/workspace/intro-freestyle
Workspace: /var/jenkins_home/workspace/intro-freestyle
+ echo Build: intro-freestyle #1
Build: intro-freestyle #1
+ echo Node: built-in
Node: built-in
Finished: SUCCESS
```

What it tells you:
- `Started by user admin`: the **cause** of the build.
- `Building in workspace …`: the workspace path **on the node**.
- `$ /bin/sh -xe /tmp/jenkins….sh`: your step became a temporary shell script, run with `-x` (echo commands as `+ …`) and `-e` (stop on the first error).
- `uname -a` shows the **container's** hostname and the WSL2 kernel: commands ran inside the Jenkins controller container.
- `Node: built-in`: the controller's own node.

> **Takeaway:** Freestyle steps run **on the node** assigned to the job. Today that's the controller; later we use **agents** (Part 8). In production the controller should run **no** builds (topic 50).

### Built-in variables (quick peek)

Jenkins sets these on every build:

| Variable | Example | Meaning |
|---|---|---|
| `WORKSPACE` | `/var/jenkins_home/workspace/intro-freestyle` | Absolute path of the workspace |
| `JOB_NAME` | `intro-freestyle` (or `team-a/loans`) | Full job name, including folders |
| `BUILD_NUMBER` | `7` | This build's number |
| `BUILD_ID` | `7` | Same as the number on current Jenkins |
| `BUILD_URL` | `http://localhost:8080/job/intro-freestyle/7/` | Link to this build (needs the Jenkins URL set) |
| `NODE_NAME` | `built-in` / `linux-1` | Node running the build |
| `JENKINS_URL` | `http://localhost:8080/` | The configured Jenkins URL |
| `BUILD_TAG` | `jenkins-intro-freestyle-7` | Handy unique string for names/labels |
| `EXECUTOR_NUMBER` | `0` | Which executor slot on the node |

With **Git SCM** configured (topic 19): `GIT_COMMIT`, `GIT_BRANCH`, `GIT_URL`, `GIT_PREVIOUS_SUCCESSFUL_COMMIT`.

**See all built-in env vars (UI):** open **`<JENKINS_URL>/env-vars.html`** (e.g. `http://localhost:8080/env-vars.html`) for Jenkins' reference list of core variables.

**Dump all env vars (from a build):**
```bash
echo "---- ALL ENV VARS ----"
printenv | sort
```
```
BUILD_NUMBER=2
BUILD_TAG=jenkins-intro-freestyle-2
BUILD_URL=http://localhost:8080/job/intro-freestyle/2/
EXECUTOR_NUMBER=0
HOME=/var/jenkins_home
JENKINS_HOME=/var/jenkins_home
JOB_NAME=intro-freestyle
NODE_LABELS=built-in
NODE_NAME=built-in
WORKSPACE=/var/jenkins_home/workspace/intro-freestyle
...
```

> **Why print build details?**
> - **Traceability:** link logs/artifacts to the exact run (`JOB_NAME`, `BUILD_NUMBER`, `GIT_COMMIT`).
> - **Debugging:** show the execution context (`NODE_NAME`, `WORKSPACE`, OS) to speed up root-cause analysis.
> - **Reproducibility/audit:** capture versions, parameters and environment so you can re-run or prove what shipped.

> ⚠️ Never `printenv` in a build that has credentials bound (topic 24). Masking hides exact matches, but dumping the whole environment is still a bad habit.

---

## Hands-on lab

1. Build `intro-freestyle` as above.
2. Add a second step that fails on purpose:
   ```bash
   echo "before"
   false
   echo "after"
   ```
   Build. Console shows `+ false`, then `Build step 'Execute shell' marked build as failure`, and `after` is **never printed** (because of `-e`). Result: **FAILURE**.
3. Change `false` to `false || true` and build: now **SUCCESS**. You've learnt how exit codes decide build results.
4. Open the job's **Workspace** link in the UI and look at what's there (empty for now).

---

## Where you'll use it

- Quick admin/maintenance jobs (topic 22).
- Understanding what any build is doing: the first lines of Console Output (cause, node, workspace) are the same for every job type.
- Using `BUILD_NUMBER`, `GIT_COMMIT` and `BUILD_URL` to tag images and write deploy records (topics 28, 36).

---

## When it breaks

| Console message | Meaning | Fix |
|---|---|---|
| `Build step 'Execute shell' marked build as failure` | A command returned non-zero | Read the line just above it |
| `/tmp/jenkins….sh: 3: mvn: not found` | Tool not installed **on that node** | Topic 19 |
| `BUILD_URL` is empty | Jenkins URL not configured | **Manage Jenkins → System → Jenkins URL** |
| `Permission denied` writing a file outside the workspace | Builds run as the `jenkins` OS user | Write inside `$WORKSPACE`, or fix permissions |
| Build waits forever in the queue | Built-in node has 0 executors, or a label mismatch | Topic 11 |

---

## Quick recap

- A Freestyle job is configured in forms; **Execute shell** runs on the assigned node with `sh -xe`.
- Any non-zero exit code → **FAILURE**.
- Jenkins injects `WORKSPACE`, `JOB_NAME`, `BUILD_NUMBER`, `BUILD_URL`, `NODE_NAME`, and more; see `/env-vars.html`.
- Print build context for traceability and debugging.

**Interview questions**

1. **Q: How does Jenkins decide a shell step failed?**
   A: The step's process returned a non-zero exit code. Jenkins runs shell steps with `-e`, so the first failing command stops the script and fails the build.

2. **Q: Name some built-in Jenkins environment variables.**
   A: `WORKSPACE`, `JOB_NAME`, `BUILD_NUMBER`, `BUILD_URL`, `NODE_NAME`, `JENKINS_URL`, and with Git `GIT_COMMIT`/`GIT_BRANCH`.

3. **Q: Where does an Execute shell step run?**
   A: On whichever node the build was assigned to: the built-in node (controller) in a lab, an agent in production. Inside that node's workspace for the job.
