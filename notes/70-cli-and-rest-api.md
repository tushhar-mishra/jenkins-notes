# 70 · Jenkins CLI and REST API

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** how to drive Jenkins from scripts: API tokens, the **REST API** (`/api/json`, triggering builds with parameters, polling results, reading logs), CSRF crumbs, the **Jenkins CLI** (`jenkins-cli.jar`), and the **Script Console** (and why it's dangerous).
>
> **You need:** topics 15, 20, 65.
>
> **From your original notes:** none directly (new); builds on Day 04 parameters ("SRE can deploy by changing parameters") and Day 03 env-vars.html.

---

## What it is

- **REST API:** almost every Jenkins page has a machine-readable version: append `/api/json` (or `/api/xml`, `/api/python`). Actions are HTTP POSTs to URLs like `/job/X/build`.
- **Jenkins CLI:** `java -jar jenkins-cli.jar -s <JENKINS_URL> -auth user:token <command>`, downloadable from `<JENKINS_URL>/jnlpJars/jenkins-cli.jar`. Commands: `build`, `console`, `list-jobs`, `install-plugin`, `safe-restart`, `declarative-linter`, `groovy`…
- **Script Console** (`/script`): run Groovy as the controller itself.

---

## Why it exists

Automation of the automation server: chat-ops bots triggering deploys, other CI systems starting Jenkins jobs, scripts collecting build stats, admins doing bulk changes.

---

## Analogy

The web UI is the shop counter; the API is the trade entrance, where suppliers with the right pass (API token) deliver and collect in bulk.

---

## How it works inside

- **Authentication:** use `user:API_TOKEN` with HTTP basic auth (create the token at user menu → **Security → API Token**). Tokens are revocable and don't expose your password/SSO.
- **CSRF:** POSTs authenticated with an API token **don't need a crumb**. Session/cookie-based POSTs do: fetch `/crumbIssuer/api/json` and send the `Jenkins-Crumb` header.
- **Triggering:** `POST /job/<name>/build` (no parameters) or `/buildWithParameters?K=V`. The response's `Location` header points to the **queue item**; poll it until it has an `executable` (the build number), then poll the build until `result` is set.
- **Tree filter:** `?tree=` limits the JSON returned, which is much faster on big controllers: `api/json?tree=jobs[name,color]`.
- Folders and multibranch: `/job/team-a/job/loans/job/main/`.

---

## Config / Jenkinsfile / commands

```bash
J=http://localhost:8080; A="admin:$TOKEN"

# list jobs with their status colour (blue = success, red = failed, *_anime = running)
curl -s -u $A "$J/api/json?tree=jobs[name,color]&pretty=true"

# trigger a parameterised build and follow it
Q=$(curl -s -u $A -X POST -D - -o /dev/null "$J/job/intro-freestyle/buildWithParameters?ENV=stage&RUN_TESTS=false" \
     | awk -F': ' '/^Location/ {print $2}' | tr -d '\r')
echo "queued: $Q"
sleep 5
B=$(curl -s -u $A "${Q}api/json" | jq -r '.executable.url')
echo "build: $B"
until [ "$(curl -s -u $A "${B}api/json" | jq -r '.result')" != "null" ]; do sleep 3; done
curl -s -u $A "${B}api/json" | jq -r '.result'
curl -s -u $A "${B}consoleText" | tail -5
```
```
queued: http://localhost:8080/queue/item/57/
build: http://localhost:8080/job/intro-freestyle/23/
SUCCESS
+ echo Skipping tests.
Skipping tests.
Finished: SUCCESS
```

Other useful endpoints:
| Endpoint | Gives |
|---|---|
| `/job/X/lastBuild/api/json?tree=result,number,duration` | last build summary |
| `/job/X/lastSuccessfulBuild/artifact/<path>` | download an artifact |
| `/computer/api/json?tree=computer[displayName,offline,numExecutors]` | agents |
| `/queue/api/json` | queue with `why` reasons |
| `/job/X/config.xml` (GET/POST) | read/replace a job's config |
| `/quietDown`, `/cancelQuietDown`, `/safeRestart` (POST) | maintenance |
| `/job/X/<n>/stop` (POST) | abort a build |

### Jenkins CLI

```bash
curl -fsSLO http://localhost:8080/jnlpJars/jenkins-cli.jar
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$TOKEN who-am-i
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$TOKEN build intro-freestyle -p ENV=dev -s -v
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$TOKEN declarative-linter < Jenkinsfile
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$TOKEN help
```
`build … -s -v` = wait for completion (`-s`) and stream the console (`-v`); the exit code reflects the build result, handy in other CI systems. The CLI connects over HTTP(S) (or SSH, if enabled).

### Script Console (admins only, carefully)

```groovy
// Manage Jenkins → Script Console: list jobs whose last build failed
Jenkins.instance.getAllItems(Job).findAll { it.lastBuild?.result == Result.FAILURE }.each { println it.fullName }
```
It runs **as the controller** with full power: it can read and decrypt every credential. Treat access as root access, log its use, prefer JCasC/API for routine changes.

---

## Deeper dive

### Managing jobs through the API

```bash
J=http://localhost:8080; A="admin:$TOKEN"

# read a job's config, edit it, write it back
curl -s -u $A "$J/job/intro-freestyle/config.xml" -o job.xml
curl -s -u $A -X POST -H 'Content-Type: application/xml' --data-binary @job.xml "$J/job/intro-freestyle/config.xml"

# create a job from an XML file
curl -s -u $A -X POST -H 'Content-Type: application/xml' --data-binary @job.xml "$J/createItem?name=new-job"

# copy a job
curl -s -u $A -X POST "$J/createItem?name=copy-of-intro&mode=copy&from=intro-freestyle"

# disable / enable / delete
curl -s -u $A -X POST "$J/job/new-job/disable"
curl -s -u $A -X POST "$J/job/new-job/enable"
curl -s -u $A -X POST "$J/job/new-job/doDelete"
```
Inside folders, prefix paths with `/job/<folder>`; `createItem` works on folders too (`$J/job/team-a/createItem?name=x`).

### Pipeline stage data: the `wfapi` endpoints

The *Pipeline: Stage View* / REST API plugin exposes stage-level timings:
```bash
curl -s -u $A "$J/job/flask-pipeline/lastBuild/wfapi/describe" | jq '.stages[] | {name, status, durationMillis}'
```
```json
{ "name": "build", "status": "SUCCESS", "durationMillis": 41200 }
{ "name": "push",  "status": "SUCCESS", "durationMillis": 12800 }
```
That's the data source for "which stage got slower this month?" dashboards.

### Useful query patterns

```bash
# failed jobs right now
curl -s -u $A "$J/api/json?tree=jobs[name,color]" | jq -r '.jobs[] | select(.color=="red") | .name'
# the last 10 build results of a job with durations
curl -s -u $A "$J/job/loans/api/json?tree=builds[number,result,duration]{0,10}"
# parameters of a specific build
curl -s -u $A "$J/job/intro-freestyle/23/api/json?tree=actions[parameters[name,value]]" | jq '.actions[].parameters? // empty'
# offline agents
curl -s -u $A "$J/computer/api/json?tree=computer[displayName,offline,offlineCauseReason]" | jq '.computer[] | select(.offline)'
```
`{0,10}` in `tree` = range (first 10 items), which keeps responses small on jobs with thousands of builds.

### Client libraries

For anything beyond a few curls, use a library: e.g. **python-jenkins** (`pip install python-jenkins`) or the Jenkins CLI from scripts. They handle auth, folders and polling for you.

### Security notes

- Create a dedicated **service account** user for automation, with only the permissions it needs (e.g. Build on one folder), and an API token per consumer, so you can revoke one integration without breaking others.
- Tokens are as powerful as the user. Store them in your secret manager, never in scripts or repos.
- The legacy unauthenticated "Trigger builds remotely (authentication token)" option on jobs is weak (a shared static token in the URL). Prefer user API tokens or webhooks.

---

## Hands-on lab

1. Create an API token; list your jobs with `?tree=`.
2. Trigger `intro-freestyle` with parameters via curl and follow it to completion with the script above.
3. Download an archived artifact by URL.
4. Download `jenkins-cli.jar`; run `who-am-i`, `list-jobs`, and lint a Jenkinsfile with `declarative-linter`.
5. In the Script Console, run the failed-jobs one-liner.

---

## Where you'll use it

Chat-ops and release tooling; integrations with other CI/CD systems; reporting; admin automation.

---

## When it breaks

| Response | Meaning | Fix |
|---|---|---|
| `401 Unauthorized` | Bad user/token | New API token; right username |
| `403 No valid crumb was included in the request` | Session/password auth without a crumb | Use an API token, or send the crumb |
| `403 … is missing the Job/Build permission` | Authorization | Grant Build on that job/folder |
| `404` on `/job/x/…` | Wrong path (folders need `/job/<folder>/job/<name>`) | Fix the URL |
| `400 … Nothing is submitted` / parameters ignored | Used `/build` for a parameterised job | `/buildWithParameters` |

---

## Quick recap

- Append `/api/json` (use `?tree=`) to read; POST to `/build` / `/buildWithParameters` to trigger; follow queue → build → `result`.
- Authenticate with user + **API token**; tokens skip CSRF crumbs.
- `jenkins-cli.jar` for scripted admin and `build -s -v`; `declarative-linter`.
- Script Console = controller-level power: admins only.

**Interview questions**

1. **Q: How do you trigger a Jenkins job from another system and wait for the result?**
   A: POST to `/job/<name>/buildWithParameters` with an API token, read the queue item from the `Location` header, poll it for the build URL, then poll the build's `/api/json` until `result` is set (or use the CLI `build -s`).

2. **Q: Why use API tokens rather than passwords?**
   A: They're per-use, revocable, don't expose the real password or SSO credentials, and don't need CSRF crumbs.

3. **Q: How can you make API calls faster on a large Jenkins?**
   A: Use the `tree` parameter to request only the fields you need, instead of the full default JSON.
