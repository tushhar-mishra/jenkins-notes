# 56 · Lab: Your First Shared Library

> **Level:** ★★ intermediate · **Status:** ✅ rewritten from your notes
>
> **You will learn:** to wire the smallest possible shared library into Jenkins and call one step that just echoes a message, proving the mechanism without secrets, tools or agents.
>
> **You need:** topic 55; a Jenkins (the Docker lab is fine; the original runs on the EC2 controller from topic 49).
>
> **From your original notes:** shared-library › *Demo 1: Configure a very simple Shared Library*: Step 1 (repo + layout, `.groovy` note, `simpleEcho.groovy`, explanations), Step 2 (create the library), Step 3 (pipeline script + explanation + note), Step 4 (run & verify).

---

## What it is

**Goal:** show how to wire a shared library into a job and call one trivial step that only echoes a message. This proves the concept without introducing complexity.

---

## Why it exists

Separating "does the wiring work?" from "does my logic work?" makes debugging libraries much easier.

---

## Analogy

Plugging a new lamp into a socket before wiring it into the house: just check the light turns on.

---

## How it works inside

Jenkins reads `@Library` → fetches the repo at `main` → registers `vars/simpleEcho.groovy` as `simpleEcho` → the stage calls it → its `call()` runs `echo`.

---

## Config / Jenkinsfile / commands

### Step 1: create the repo and minimal layout

Create a **public** repository for the demo (mine is `shared-library-demo`):
```
shared-library-demo/
├─ vars/
│  └─ simpleEcho.groovy
└─ README.md
```
- Only `vars/` is used, so you can see how a single global step maps into the `Jenkinsfile`.
- `simpleEcho.groovy` is intentionally tiny and safe.

> **Note:** create your own public repo, because the author deletes the demo repo.

**About the `.groovy` extension and file contents:** files in `vars/` must use the `.groovy` extension. Jenkins treats `vars/*.groovy` as executable pipeline steps and loads them as Groovy code. The contents must be valid Groovy (commonly a `call(...)` method, or a top-level closure) so the step can be invoked like a function from the `Jenkinsfile`. For static templates or other text files, use `resources/` and `libraryResource`.

**`vars/simpleEcho.groovy`**
```groovy
// vars/simpleEcho.groovy
def call() {
  echo "Jenkins Shared Library Project with CWVJ"
}
```
- **What is `def call()` and why put it in `vars/*.groovy`?** When you create a file in `vars`, Jenkins expects one main function it can run when the step is called from a `Jenkinsfile`. That function must be named `call`.
- **Filename → step mapping:** `simpleEcho.groovy` becomes a global step named `simpleEcho()`.
- **Why so simple:** it only echoes a message, deliberately: it proves the wiring from library to job without secrets, external tools or agent differences.

(An optional extension: `def call(String msg = 'Jenkins Shared Library Project with CWVJ') { echo msg }`, then `simpleEcho('hi')`. The original Step 4 mentions "or your custom message if you passed one".)

### Step 2: create the Jenkins shared library

**Manage Jenkins → System → Global Pipeline Libraries → Add** (each option is explained in topic 55):
- **Name:** `my-first-shared-library`: what you reference in `@Library('…')`.
- **Default version:** `main`.
- **Load implicitly:** leave unchecked.
- **Allow default version to be overridden:** keep checked.
- **Include @Library changes in job recent changes:** keep checked.
- **Cache fetched versions on controller:** leave unchecked for the demo.
- **Retrieval method:** **Modern SCM → Git**, repository URL e.g. `https://github.com/CloudWithVarJosh/shared-library-demo.git` (use yours).
- **Save and verify:** confirm Jenkins can reach the repo (no red error under the URL field) and that the name matches what you'll use in `@Library`. Connectivity is checked **from the controller**.

### Step 3: write the pipeline script

Use this as the job's **Pipeline script** (not Pipeline script from SCM).

**Create the job:** **New Item** → `shared-library-job` → **Pipeline** → **OK**; **Pipeline → Definition → Pipeline script**; paste; **Save**.

```groovy
@Library('my-first-shared-library@main') _

pipeline {
  agent any

  stages {
    stage('Demo - call shared step') {
      steps {
        // Calls vars/simpleEcho.groovy
        simpleEcho()
      }
    }
  }
}
```
- **`@Library('my-first-shared-library@main') _`** tells Jenkins to **load** the library `my-first-shared-library` at version `main` for this script. The trailing `_` is a harmless placeholder so Groovy accepts the annotation syntax; it has no runtime effect. Put this line at the very **top** of the `Jenkinsfile`. If the library were "load implicitly" you wouldn't need it, but explicitly **importing** the library makes the pipeline easier to read and debug.
- **`pipeline { agent any … }`** runs the job on any available agent.
- **`stage('Demo - call shared step')`** groups the work so the UI shows a clear stage.
- **`steps { simpleEcho() }`** calls the global step from **`vars/simpleEcho.groovy`**, which prints the message.
- The pipeline is intentionally **minimal**: **no post actions**, **no credentials**, **no external tools**. It only proves the wiring.

> Note: **import** the library at the **top** of the `Jenkinsfile` (`@Library('my-first-shared-library@main') _`) so Jenkins loads it, then call steps by the file name **without** `.groovy` (e.g. **`simpleEcho()`**). Different stages can call different `vars/*.groovy` steps (stage A calls `foo()`, stage B calls `bar()`), and Jenkins invokes only each file's **`call(...)`** entry point.

### Step 4: run and verify

- Click **Build Now** on `shared-library-job`; wait for the build in **Build History**.
- Open it → **Console Output**. Look for the stage `Demo - call shared step` and the line `Jenkins Shared Library Project with CWVJ` (or your custom message).
- Confirm `Finished: SUCCESS` at the end.

```
Loading library my-first-shared-library@main
Attempting to resolve main from remote references...
Checking out Revision 1a2b3c4… (main)
[Pipeline] Start of Pipeline
[Pipeline] node
[Pipeline] { (Demo - call shared step)
[Pipeline] echo
Jenkins Shared Library Project with CWVJ
[Pipeline] End of Pipeline
Finished: SUCCESS
```

---

## Hands-on lab

1. Do steps 1–4 with your own repo.
2. Add the parameterised version of `simpleEcho` and call it with a message.
3. Create a tag `v1.0.0` in the library repo, change the message on `main`, and run once with `@main` and once with `@v1.0.0`: two different outputs. That's library **versioning**.
4. Break it: rename the file to `SimpleEcho.groovy`; read the `No such DSL method 'simpleEcho'` error (names are case-sensitive).

---

## Where you'll use it

As the first step whenever you set up a library on a new controller.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `Could not find any definition of libraries [my-first-shared-library@main]` | Library not configured / name typo | Check Global Pipeline Libraries |
| `No such DSL method 'simpleEcho'` | File not under `vars/`, wrong case, not on that branch | Fix the path/name; push to `main` |
| `fatal: could not read Username for 'https://github.com'` | Private repo without credentials | Add credentials to the retrieval method (topic 57) |
| `unexpected token: _` | `@Library` not at the top / missing `_` | Put `@Library('…') _` on the first line |

---

## Quick recap

- A one-file library (`vars/simpleEcho.groovy` with `call()`) + a Global Pipeline Libraries entry + `@Library('name@main') _` + `simpleEcho()` proves the wiring.
- The file name is the step name; only `call()` runs.
- Versions (branches/tags) let pipelines pin library behaviour.

**Interview questions**

1. **Q: What's the trailing `_` in `@Library('x') _`?**
   A: A placeholder: Groovy annotations must annotate something, so `_` is a dummy. It does nothing at run time.

2. **Q: How do you use a specific library version?**
   A: `@Library('name@tag-or-branch-or-commit') _`, if "Allow default version to be overridden" is enabled.

3. **Q: Why start with a trivial step?**
   A: To verify the library configuration and loading separately from the logic, so failures are easy to localise.
