# 21 · Build Triggers

> **Level:** ★★ intermediate · **Status:** 🔀➕ merged and expanded
>
> **You will learn:** every way a build can start: manually, **Poll SCM**, **Build periodically** (cron), **webhooks**, and other jobs (upstream/downstream). Also Jenkins' cron syntax and the `H` token, the Jenkins URL, how to get GitHub webhooks into a laptop Jenkins, and the security tips for webhooks.
>
> **You need:** topics 05 (webhooks), 19, 20.
>
> **From your original notes:** Day 04 › *Mini Demo 3 — Poll SCM Trigger*, *Mini Demo 4 — Webhook Trigger (GitHub/GitLab)*, the Jenkins URL note · Project 01 › *Trigger pipeline on Git push* (recommended approach, alternative Poll SCM, security/production tips).

---

## What it is

A **trigger** is what makes Jenkins put a build in the queue. Main kinds:

| Trigger | Who starts it | Latency | Load |
|---|---|---|---|
| **Manual** (Build Now / API) | a person or script | n/a | n/a |
| **Webhook** (e.g. "GitHub hook trigger for GITScm polling") | the Git host pushes an HTTP event | seconds | very low |
| **Poll SCM** | Jenkins asks Git "anything new?" on a schedule | up to the poll interval | grows with jobs × frequency |
| **Build periodically** (cron) | the clock, whether or not code changed | n/a | one build per tick |
| **Upstream job** ("Build after other projects are built", `build` step) | another job finishing | seconds | n/a |
| **Remote trigger** with a token / REST API | any HTTP client | seconds | n/a |

---

## Why it exists

CI only works if builds start **automatically and quickly** after a change. Webhooks are the ideal; polling is the fallback when the Git host can't reach Jenkins; cron is for work that should happen on a schedule regardless of code changes (nightly scans, reports, cleanups).

---

## Analogy

Getting your post:
- **Webhook** = the postman rings your doorbell the moment a letter arrives.
- **Poll SCM** = you walk to the mailbox every 2 minutes to check.
- **Build periodically** = you do your filing every night at 1:30, letters or not.

---

## How it works inside

### Jenkins cron syntax

Five fields separated by spaces (like Linux cron, Linux notes topic 039):
```
MINUTE  HOUR  DAY-OF-MONTH  MONTH  DAY-OF-WEEK
0-59    0-23  1-31          1-12   0-7 (0 and 7 = Sunday)
```
- `*` = every value; `*/15` = every 15; `1-5` = a range; `1,15` = a list.
- **`H`** = a **hash-spread** placeholder: Jenkins picks a **stable value per job**, derived from a hash of the job name, so jobs don't all fire at the same minute. `H/15 * * * *` = every 15 minutes at a job-specific offset; `H H(1-3) * * *` = once a day, sometime between 01:00 and 03:59.
- Aliases: `@hourly`, `@daily`/`@midnight`, `@weekly`, `@monthly`, `@yearly`, all hash-spread.
- A timezone can be set on the first line: `TZ=Asia/Kolkata`.
- Lines starting with `#` are comments; several lines = several schedules.

Why `H` matters: 200 jobs all on `*/5 * * * *` hit the Git server at exactly the same second. That's a **thundering herd**: many clients waking up at once and overloading a server. `H/5` spreads them across the 5 minutes.

### Poll SCM: what happens each tick

1. At each scheduled time, Jenkins runs `git ls-remote` (or the plugin's API equivalent) to get the latest SHA of the configured branches.
2. It compares with the last built SHA (and applies path include/exclude filters if configured).
3. **Only if something changed**, it queues a build (cause: `Started by an SCM change`).
4. The polling log is at **job → Git Polling Log**.

### Webhook: what happens on a push

1. GitHub POSTs a JSON event to `https://<jenkins>/github-webhook/`.
2. The GitHub plugin finds jobs whose Git URL matches the repo and that have **GitHub hook trigger for GITScm polling** enabled.
3. For each, it **runs an immediate poll** (that's why the option has "polling" in its name) and, if there are new commits, queues the build.
4. For **Multibranch** jobs (topic 43), the event triggers branch indexing for that branch/PR directly.

### The Jenkins URL must be right

Jenkins builds absolute links (in status checks, emails, `BUILD_URL`) from **Manage Jenkins → System → Jenkins URL**. Set it to the address **others** use to reach Jenkins (e.g. `https://ci.example.com/`), not `localhost`, or every link in GitHub will point at `localhost`.

---

## Config / Jenkinsfile / commands

### Mini demo 3: Poll SCM trigger (no webhooks)

**Goal:** auto-build when Git changes, using polling.

**Setup:**
- Keep the Git config from topic 20.
- **Build Triggers → Poll SCM:** `H/2 * * * *`
  - **What this does:** polls the repo about every **2 minutes** and triggers a build **only if** a new commit is detected.
  - **About `H`:** a **hash-spread** placeholder; Jenkins picks a stable minute offset per job so polls are spread evenly (no thundering herd).

**Build step (Execute shell):**
```bash
echo "Polling-driven build"
git log --oneline -n 3 || true
```
After you push, within ~2 minutes:
```
Started by an SCM change
...
+ git log --oneline -n 3
c41d9e2 test: poll trigger
```

**Production note:** polling is a **firewall-friendly** trigger when webhooks aren't possible.
- **Locked networks:** banks and healthcare companies often block **inbound** webhooks. Polling from Jenkins (**outbound**) still gives near-real-time CI.
- **Busy repos:** if a **monorepo** (many projects in one repo) changes often, restrict polling to specific paths (Git plugin → **Additional Behaviours → Polling ignores commits in certain paths**, includes/excludes) to avoid needless builds.
- **Coverage vs load:** use jittered `H/` schedules so many jobs don't hit the **VCS** (Version Control System) in the same minute; this prevents thundering-herd problems on self-hosted Git.

### Mini demo 4: webhook trigger (GitHub/GitLab)

**Goal:** start builds immediately on push.

**Setup (GitHub):**
- Job → **Build Triggers:** ✅ **GitHub hook trigger for GITScm polling**.
- GitHub repo → **Settings → Webhooks → Add webhook**:
  - **Payload URL:** `http://<jenkins>/github-webhook/` (note the trailing slash)
  - **Content type:** `application/json`
  - **Events:** "Just the push event" (add Pull requests for PR builds)
  - **Secret:** a long random string; add the same value in Jenkins (**Manage Jenkins → System → GitHub → Advanced → Shared secrets**, stored as a Secret text credential) so Jenkins can verify signatures.

**Build step (Execute shell):**
```bash
echo "Triggered by webhook; branch=$GIT_BRANCH"
git log -n 1 || true
```
Console:
```
Started by GitHub push by octo-dev
```

> Set **Manage Jenkins → System → Jenkins URL** to your public tunnel/domain first; then use `https://<your-domain>/github-webhook/` as the Payload URL.

For **GitLab**, the GitLab plugin's endpoint is `https://<jenkins>/project/<job-name>` with a secret token; for **Bitbucket**, `https://<jenkins>/bitbucket-scmsource-hook/notify`.

**Production note:** webhooks cut the **feedback loop** from minutes to seconds, improving quality and developer flow.
- **Fast fail:** a React app that builds in 30 s should start instantly; developers fix issues before switching context, keeping PRs small.
- **Compute savings:** no polling every 2 minutes across 30 jobs means less idle CPU and fewer API calls to GitHub/GitLab.
- **Event breadth:** extend to PR events to run PR validations (lint, unit, SAST) only when needed, not on cron.

### Getting webhooks into a laptop Jenkins

GitHub can't reach `http://localhost:8080`. For the lab, use a tunnel (no router changes):

```bash
# Option 1: smee.io (made for this; no account). Get a channel URL at https://smee.io
npx smee-client --url https://smee.io/AbC123 --target http://localhost:8080/github-webhook/
# then use https://smee.io/AbC123 as the GitHub Payload URL
```
```
Forwarding https://smee.io/AbC123 to http://localhost:8080/github-webhook/
Connected https://smee.io/AbC123
POST http://localhost:8080/github-webhook/ - 200
```
```bash
# Option 2: Cloudflare quick tunnel (gives a temporary public https URL)
cloudflared tunnel --url http://localhost:8080
```
Never expose a lab Jenkins that still has weak passwords; a tunnel makes it reachable from the internet.

### Trigger a pipeline on Git push (from the Project 01 notes)

**Recommended approach: Multibranch Pipeline + GitHub webhook** (Part 7)
1. Create a **Multibranch Pipeline** job pointing at your repo. Jenkins auto-scans branches and reads the `Jenkinsfile`.
2. Add Jenkins credentials for GitHub (username + token) in Jenkins Credentials. Use a **machine** token (or a GitHub App), not a personal password.
3. Add a GitHub webhook in **repo → Settings → Webhooks**:
   - Payload URL: `https://<JENKINS_HOST>/github-webhook/`
   - Content type: `application/json`
   - Secret: a strong secret, also stored in Jenkins (optional but recommended)
   - Events: `Push` (and `Pull request` if you want PR builds)
4. Configure branch filters and build strategies in the multibranch settings, e.g. exclude `dependabot/*` and `docs/*` branches.
5. Test from the GitHub UI (**Recent Deliveries → Redeliver**, or the ping event). Check the Jenkins job's **Multibranch Events**/indexing log and the build log for the trigger.

**Alternative (simple): Poll SCM** with a cron such as `H/5 * * * *` as a fallback when webhooks are blocked.

**Security / production tips:**
- Use a **webhook secret** and turn on secret validation in Jenkins.
- Use **fine-grained** GitHub tokens with least privilege (or a GitHub App, topic 46).
- Prefer **Multibranch** for clean branch/PR isolation and auto-discovery.

### Cron, upstream and remote triggers in a Jenkinsfile (preview of topic 37)

```groovy
pipeline {
  agent any
  triggers {
    pollSCM('H/5 * * * *')                       // fallback polling
    cron('TZ=Asia/Kolkata\nH 1 * * *')           // nightly, ~01:xx IST
    upstream(upstreamProjects: 'lib-core', threshold: hudson.model.Result.SUCCESS)
  }
  stages { stage('x') { steps { echo "cause: ${currentBuild.getBuildCauses()*.shortDescription}" } } }
}
```
And from one pipeline, start another:
```groovy
build job: 'deploy-stage', parameters: [string(name: 'DIGEST', value: env.DIGEST)], wait: false
```

---

## Hands-on lab

1. Add **Poll SCM** `H/2 * * * *` to your job, push a commit, wait, check **Git Polling Log** and the new build's cause.
2. Remove polling. Start the smee client, add the GitHub webhook (with a secret), enable **GitHub hook trigger**, set the Jenkins URL. Push: the build should start within seconds.
3. In GitHub **Settings → Webhooks → Recent Deliveries**, open the delivery and look at the request headers (`X-GitHub-Event: push`, `X-Hub-Signature-256: sha256=…`) and Jenkins' `200` response.
4. Create a second job `downstream`, and in it set **Build after other projects are built → intro-freestyle**. Build the first and watch the second start.

---

## Where you'll use it

- Webhooks for every CI job; polling only behind strict firewalls.
- Cron for nightly scans, dependency updates, cache warm-ups, reports and cleanups (topic 22).
- Upstream/downstream for library → app rebuilds, or build → deploy chains (pipelines usually do this with `build`).

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| GitHub delivery shows `timed out` / `Failed to connect` | Jenkins not reachable from the internet | Public URL, reverse proxy, or tunnel; firewall rules |
| Delivery `200`, but no build | Job doesn't have the webhook trigger enabled, or its repo URL doesn't match the event's | Enable the trigger; use the same URL form (`https://github.com/org/repo.git`) |
| Delivery `403` / `No valid crumb` | Wrong path (e.g. missing trailing `/`), so it's treated as a UI POST | Use exactly `/github-webhook/` |
| Delivery `400`/signature error | Secret mismatch | Same secret in GitHub and Jenkins |
| Polling builds every time with no change | Workspace-based polling or a changing branch spec | Use the Git plugin's fast remote polling; fix the branch spec |
| Links in GitHub point to `localhost` | Jenkins URL not set | **Manage Jenkins → System → Jenkins URL** |

---

## Quick recap

- **Webhook** = push-based and instant (preferred); **Poll SCM** = pull-based fallback; **cron** = time-based.
- Cron fields: minute hour day month weekday; **`H`** spreads load by hashing the job name.
- GitHub's endpoint is `/github-webhook/`; use a secret, and a correct Jenkins URL.
- Laptop labs need a tunnel (smee.io / cloudflared) for webhooks.

**Interview questions**

1. **Q: Webhook vs Poll SCM?**
   A: Webhooks are pushed by the Git host and start builds within seconds with no wasted load. Polling has Jenkins check on a schedule; it works when inbound connections are blocked, but adds latency and load.

2. **Q: What does `H` mean in a Jenkins cron spec?**
   A: A hash of the job name chooses a stable value for that field, so jobs scheduled "every 15 minutes" don't all run at the same minute.

3. **Q: Your webhook shows a 200 response but nothing builds. What do you check?**
   A: Whether the job has the GitHub hook trigger enabled, whether its configured repo URL matches the event's repository, whether there were actually new commits for its branch spec, and the Jenkins system log for the GitHub plugin's messages.
