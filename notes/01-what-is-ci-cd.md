# 01 · What is CI/CD

> **Level:** ★ foundation · **Status:** 🔀➕ merged and expanded
>
> **You will learn:** what goes wrong when software is built and shipped by hand, and what CI and CD mean in plain words. This is the 10-minute overview the rest of the path fills in.
>
> **You need:** nothing. This is the starting point.
>
> **From your original notes:** Day 01 › *Introduction*, *Why Build Automation Matters*, *Conclusion* · Day 02 › *What is CI/CD?* · root `README.md` (course overview).
>
> 🎥 Original videos: [Course introduction](https://www.youtube.com/watch?v=bBx6UfQP1Lo&ab_channel=CloudWithVarJosh) · [Full playlist](https://www.youtube.com/playlist?list=PLmPit9IIdzwSiYCKOtXUGNwytXXiJ8Rv8)

---

## What it is

**CI/CD** = **Continuous Integration / Continuous Delivery** (and sometimes **Continuous Deployment**).

Three ideas, in plain words:

- **Continuous Integration (CI):** every time a developer saves a change into the shared code (Git, topic 05), a machine **automatically builds the code and tests it**, within minutes. If something broke, the team knows right away.
- **Continuous Delivery (CD):** the thing CI built (the **artifact**: a `.jar`, a container image, a binary) is **automatically moved through test environments** and is always *ready* to go to production. A human still presses "go" for production.
- **Continuous Deployment (also "CD", we write **CDp** to tell them apart):** same as delivery, but production is updated **automatically** too, with no human approval, if all checks pass.

Two words you'll see everywhere:

- **Pipeline** = an automated, repeatable list of steps that a change goes through: **checkout → build → test → package → publish → deploy**. The same steps, in the same order, every time.
- **Artifact** = the file that a build produces and that you actually ship (a `.jar`, an `.exe`, a container image). Topic 03 covers this in depth.

**Jenkins** (from topic 10 onwards) is a tool that *runs* pipelines. CI/CD is the practice; Jenkins is one way to do it.

---

## Why it exists

Writing code is only half the job. To run in production, code must be **prepared into a deployable form**: compiled, with its libraries, packaged, tested, and copied to servers.

If people do that **by hand**:

- Every developer uses slightly different commands, tool versions and settings. The build works on one laptop and fails on another: the classic **"works on my machine"** problem.
- Changes from many developers are combined (**integrated**) rarely, maybe once a month. Then hundreds of changes collide at once and nobody knows which one broke things ("integration hell").
- Bugs are found weeks after they were written, when fixing them is slow and expensive.
- Releases are big, scary, manual events done late at night with a checklist. One missed step means an outage.
- Nobody can say exactly *which* code is running in production.

**Automation fixes this.** A properly automated build is:

- **Reproducible:** the same steps run everywhere (dev, staging, prod).
- **Version-locked:** artifacts and dependencies have fixed versions.
- **Traceable:** every artifact links back to the exact code change and build that made it.
- **Predictable and safe to promote:** if it passed here, it behaves the same there.

---

## Analogy

A **car factory assembly line**.

- In the old days, each car was built by hand by one craftsman. Every car was a bit different, and you only found out the brakes were wrong at the final test drive.
- An assembly line does the **same steps in the same order every time**, with a **quality check after each station**. A bad part is caught at the station where it was fitted, not when the car is sold.
- **CI** is the check at each station ("does this part fit?").
- **Continuous Delivery** is the finished car parked at the factory gate, fully tested, waiting for the manager to sign it out.
- **Continuous Deployment** is the car driving out of the gate to the customer automatically the moment it passes the last check.

---

## How it works inside

Here is the whole journey of one change, at a high level. Every step gets its own topic later.

```
Developer laptop          Git host (GitHub)          CI/CD server (Jenkins)           Environments
─────────────────         ─────────────────          ─────────────────────           ────────────
1. edit code
2. git commit
3. git push  ───────────▶ 4. stores the commit
                          5. sends a "webhook"  ───▶ 6. starts the pipeline
                                                     7. checks out that exact commit
                                                     8. builds it (compile, package)
                                                     9. runs tests and scans
                          10. shows ✅ or ❌  ◀────── 10. reports the result
                                                     11. publishes the artifact ──────▶ registry
                                                     12. deploys the artifact  ──────▶ dev → staging → prod
                                                     13. notifies the team (chat/email)
```

1–3. The developer saves work locally (**commit**) and sends it to the shared Git server (**push**). (Topic 05 explains Git.)
4–5. The Git host stores it and immediately sends a small HTTP message called a **webhook** ("something changed in repo X") to the CI server.
6–9. The CI server runs the **pipeline**: gets the exact code, builds it, tests it. This is **CI**.
10. The result is posted back to Git as a green ✅ or red ❌ mark next to the change. Protected branches can **refuse** a merge that is red (topic 05).
11–12. If green, the artifact is stored and promoted through environments. This is **CD**.
13. People are told what happened.

The key principle that ties it together: **build once, promote the same artifact everywhere**. The thing you tested in staging is *exactly* (byte for byte) the thing that goes to production. Topic 07 explains why and how.

---

## Config / Jenkinsfile / commands

You don't run anything yet. But here is what "the pipeline" looks like when it is written down as code in Jenkins (a **Jenkinsfile**). You'll write one yourself in topic 31. For now just notice it reads like the list of steps above.

```groovy
pipeline {
  agent any                          // run on any available machine
  stages {
    stage('Checkout') { steps { checkout scm } }          // get the code
    stage('Build')    { steps { sh 'mvn -B package' } }   // compile + package
    stage('Test')     { steps { sh 'mvn -B test' } }      // run tests
    stage('Publish')  { steps { sh 'docker push myapp:42' } }  // store artifact
    stage('Deploy')   { steps { sh './deploy.sh dev' } }  // deploy to dev
  }
}
```

Sample console output (shape only):

```
[Pipeline] stage (Checkout)
Cloning repository https://github.com/acme/loans.git
 > git checkout -f 9f3c2e7
[Pipeline] stage (Build)
+ mvn -B package
[INFO] BUILD SUCCESS
[Pipeline] stage (Test)
Tests run: 42, Failures: 0, Errors: 0, Skipped: 0
...
Finished: SUCCESS
```

What each part means:
- `Cloning … 9f3c2e7`: CI always builds an **exact commit** (identified by its SHA, topic 05), not "whatever is on the branch".
- `BUILD SUCCESS` / `Tests run`: the automated checks. If any fail, the pipeline stops and the result becomes `FAILURE`.
- `Finished: SUCCESS`: the overall result, which is sent back to Git as ✅.

---

## Hands-on lab

No Jenkins yet. Do this thought-experiment on paper (5 minutes). It makes the rest of the course click.

1. Write down every step *you* would do by hand to take a small app from your laptop to a server: install tools, download libraries, compile, run tests, copy files, restart the service…
2. Next to each step, write what could go wrong if a tired person did it at 2 AM.
3. Circle the steps that could be done by a script.
4. Count them. That list of circled steps **is** your pipeline. Everything in this course is about making that list automatic, safe, fast and auditable.

---

## Where you'll use it

- **Every pull request** at a modern company runs CI before anyone is allowed to merge.
- **Microservices / SaaS** companies deploy many times a day with CD or CDp (Amazon and Netflix push hundreds of changes daily).
- **Regulated companies** (banks, healthcare) use Continuous **Delivery** with a manual production approval, so there is an audit trail of who approved what.
- **In interviews,** "explain CI vs CD vs continuous deployment" is one of the most common opening questions.

---

## When it breaks

| Symptom | What it usually means |
|---|---|
| "It passed CI but failed in production" | The artifact was **rebuilt** for production instead of promoted, or environments differ in config. Topic 07. |
| CI takes 45 minutes, so people stop waiting for it | CI is doing too much. Keep the merge-gating CI fast (~10–15 min) and move heavy tests later. Topic 06. |
| Developers merge red builds anyway | Branch protection isn't enforced. Topic 05. |
| "Which version is in prod?" nobody knows | Artifacts aren't tagged/traceable to commits. Topic 07. |

---

## Quick recap

- **CI** = every change is automatically built and tested within minutes, and the result gates the merge.
- **Continuous Delivery** = the tested artifact is always ready to release; production needs a human "go".
- **Continuous Deployment (CDp)** = production is updated automatically when all checks pass.
- A **pipeline** is the automated list of steps; an **artifact** is what it produces.
- Golden rule: **build once, promote the same artifact** everywhere.

**Interview questions**

1. **Q: What's the difference between continuous delivery and continuous deployment?**
   A: Both automatically build, test and promote the artifact. In delivery, a human approves the production release. In deployment, production is updated automatically once all checks pass.

2. **Q: Why does CI need to be fast?**
   A: CI gates every merge. If it's slow, developers batch up changes or skip it, and the feedback loop that makes CI valuable is lost. Aim for about 10–15 minutes.

3. **Q: What problem does build automation solve?**
   A: Manual builds differ between people and machines ("works on my machine"). Automation makes builds reproducible, version-locked and traceable, so what passed tests is exactly what gets shipped.
