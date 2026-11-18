# 29 · Why Pipelines

> **Level:** ★ foundation · **Status:** ✅ rewritten from your notes
>
> **You will learn:** what a Jenkins Pipeline is, why it replaced chains of Freestyle jobs, the top five differences, and when Freestyle is still the right tool.
>
> **You need:** topics 17–28 (Freestyle and Project 1).
>
> **From your original notes:** Day 06 › *Introduction*, *Prerequisites*, *Why Pipelines? (the big wins)*, *Pipeline Job vs Chained Freestyle / Pipeline vs Freestyle — Top 5*, *Bottom line*.
>
> 🎥 Original video: [From Freestyle to Jenkins Pipeline: Build, Push, Deploy](https://www.youtube.com/watch?v=545qDzphdu8)

---

## What it is

A **Pipeline** is a Jenkins job whose whole process is written as **code**, in a file called a **`Jenkinsfile`**, usually committed to the app's Git repo. Instead of clicking through forms, you describe stages (checkout → build → push → deploy → test) in a small Groovy-based language.

In the next topics we convert the Project 1 Freestyle flow into a Jenkinsfile: the **same steps**, but **as code**, so it's versioned, reviewable and easy to evolve. We keep the core simple (build number as the image tag), then add practical upgrades: **post actions**, a **deploy-info.txt** artifact for traceability, and a final **workspace cleanup**.

**Prerequisite:** be comfortable with the Project 1 flow (DooD, credentials, build → push → deploy → test): topics 27–28. (Original Day 05 notes and video: [GitHub](https://github.com/CloudWithVarJosh/Jenkins-Basics-To-Production/tree/main/Day%2005) · [YouTube](https://www.youtube.com/watch?v=UYlVTs_yK8U&ab_channel=CloudWithVarJosh).)

---

## Why it exists

Freestyle jobs keep their logic in the **web UI**, stored as XML on the controller. Real delivery needs many steps, branches, approvals and parallel work. Doing that with Freestyle means **chains** of jobs glued together with plugins, with no history of who changed what and no code review.

**The big wins of pipelines:**
- **Code as config:** one **Jenkinsfile** in Git: reviewed, versioned, rollbackable.
- **Reliable & visible:** stages with clear failure points; `post {}` for cleanup; easy **timeouts/retries**.
- **Parallel + conditional:** `parallel {}` for fast feedback; `when {}` for branch/tag/file-based logic.
- **Secure & audited:** **credentials by ID** (masked), sandboxed execution, every change is a commit.
- **Less plugin sprawl:** most orchestration is built into Pipeline.
- **Durable:** a running pipeline survives a controller restart (topic 32).

---

## Analogy

Freestyle is a **recipe written on sticky notes** spread over several cupboards: it works until someone moves a note. A Pipeline is the **recipe book** kept with the ingredients: one place, versioned, and anyone can read and suggest edits.

---

## How it works inside

### Pipeline vs chained Freestyle: top 5

| Area | **Pipeline job (Jenkinsfile)** | **Chained Freestyle jobs** |
|---|---|---|
| **Code as config & audit** | One **Jenkinsfile in Git**; PR-reviewed, versioned, rollbackable | Logic scattered across jobs in the UI; weak history/traceability |
| **Parallelism** | Native `parallel {}` for fast, concurrent stages | Needs extra jobs/plugins; clunky to coordinate |
| **Conditionals** | `when {}` cleanly gates by branch/tag/files | Imitated with duplicated jobs/params; gets messy |
| **Approvals / input** | Built-in `input` step with timeouts and allowed approvers | No native gate; relies on plugins or manual steps |
| **Maintenance & plugins** | Minimal plugin sprawl; one file per project; reusable via shared libraries | Many jobs to maintain; heavy plugin reliance and drift |

### Bottom line

Pipelines keep CI/CD **in code**, so changes are reviewable and rollbackable, with **parallelism**, **conditionals** and **approvals** built in.
Yes, you *can* approximate this with Freestyle (a chain of jobs plus **Parameterized Trigger**, **Copy Artifact**, and cron/webhook plugins), but it's brittle and high-maintenance. Every new branch, gate or fan-out means **more jobs to wire and keep in sync**, which becomes real toil for DevOps teams.

Use **Pipelines** for anything beyond a tiny flow; Freestyle chains are best left for quick, one-off tasks.

### When Freestyle is still used (2026)

- Tiny admin/maintenance jobs owned by the platform team (though many teams write even these as pipelines).
- **Legacy** jobs nobody has migrated yet; you'll inherit some.
- Plugins that only offer a Freestyle build step (fewer every year).
- Teaching, exactly as we did in Part 3.

New work should be a **Pipeline** (and usually a **Multibranch Pipeline**, Part 7).

---

## Config / Jenkinsfile / commands

The Project 1 Freestyle job vs the same thing as a Jenkinsfile (full version in topic 36):

```groovy
pipeline {
  agent any
  environment { IMAGE = 'docker.io/you/cwvj-flask'; TAG = "${env.BUILD_NUMBER}" }
  stages {
    stage('build')  { steps { sh 'docker build -t "$IMAGE:$TAG" .' } }
    stage('push')   { steps { withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                usernameVariable: 'U', passwordVariable: 'P')]) {
                                sh 'echo "$P" | docker login -u "$U" --password-stdin && docker push "$IMAGE:$TAG"' } } }
    stage('deploy') { steps { sh 'docker rm -f cwvj-flask || true; docker run -d --name cwvj-flask -p 5000:5000 "$IMAGE:$TAG"' } }
  }
  post { always { echo "Build ${env.BUILD_NUMBER} finished" } }
}
```
Same steps, but: each stage shows up separately in the UI, failures point to a stage, and the whole file is reviewed in a PR.

---

## Hands-on lab

Count the cost of Freestyle:
1. Imagine adding to Project 1: (a) run unit tests and a scan **in parallel**, (b) deploy to stage only from `main`, (c) wait for a manager's approval before prod.
2. For each, write how you'd do it in Freestyle (how many extra jobs/plugins?) and the one-line pipeline equivalent (`parallel`, `when { branch 'main' }`, `input`). You'll implement them in topics 38–39.

---

## Where you'll use it

- Every new CI/CD job.
- Migrating legacy Freestyle chains to Jenkinsfiles (a common platform-team project).
- Interviews: "why pipelines over Freestyle?"

---

## When it breaks

| Situation | Why it's a problem | Better |
|---|---|---|
| Jenkinsfile pasted into the job UI ("Pipeline script") in production | No review/versioning, which defeats the point | "Pipeline script from SCM" (topic 31) |
| Pipelines copied between 20 repos | Duplication and drift | Shared libraries (Part 9) |
| Freestyle job chain with Copy Artifact for build → deploy | Fragile ordering, hard to trace | One pipeline with stages, or `build` with parameters |

---

## Quick recap

- A Pipeline = the job's process as code in a **Jenkinsfile** in Git.
- Wins: review/versioning, stages, `post`, `parallel`, `when`, `input`, credentials by ID, durability, fewer plugins.
- Freestyle chains are brittle; keep Freestyle for tiny one-offs and legacy.

**Interview questions**

1. **Q: Why use pipelines instead of Freestyle jobs?**
   A: The process is code in Git (reviewed, versioned, rollbackable), with built-in stages, parallelism, conditions, approvals, post actions and durability, instead of fragile job chains configured in the UI.

2. **Q: Is Freestyle deprecated?**
   A: Not formally, but new work should use Pipelines. Freestyle remains for simple one-off tasks and legacy jobs.

3. **Q: How would you migrate a chain of 5 Freestyle jobs?**
   A: Map each job to a stage in one Jenkinsfile, replace parameter/artifact passing with environment variables and stash/archive, add `post` for cleanup/notifications, commit it to the repo, and run it as a (multibranch) pipeline before retiring the old jobs.
