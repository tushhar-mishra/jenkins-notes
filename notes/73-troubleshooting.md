# 73 · Troubleshooting Method and Catalog

> **Level:** ★★ intermediate · **Status:** 🆕 new topic (collects every "When it breaks" table into one method)
>
> **You will learn:** a repeatable way to debug any Jenkins problem (read the console from the top, identify the layer, reproduce on the node), where every log lives, and a catalog of the most common errors: agent offline, permission denied, credentials not found, `No such DSL method`, script approval, serialisation, workspace/disk, plugin conflicts, webhooks, Docker, Kubernetes, SonarQube.
>
> **You need:** most of the course; this is a reference.
>
> **From your original notes:** the troubleshooting hints in Project 01 ("If login fails, verify…", "If it fails, check…"), shared-library Step 10 ("If something fails, check…"), Day 03 (`git: command not found`).

---

## What it is

A method + a lookup table. Most Jenkins failures fall into one of a few **layers**:

```
1. Trigger      (did the build even start? webhook, polling, branch indexing)
2. Queue        (waiting for an executor? label? agent offline?)
3. Agent/node   (connection, Java, disk, permissions, tools on PATH)
4. SCM          (checkout, credentials, branch spec, Jenkinsfile path)
5. Pipeline     (syntax, sandbox, plugin steps, Groovy/CPS)
6. Step/tool    (your shell command, Docker, Maven, kubectl, scanners)
7. Post/report  (archive, junit, notifications)
8. Controller   (plugins, memory, disk, security, proxy)
```

---

## Why it exists

Randomly retrying wastes hours. Locating the **layer** first turns most problems into a two-minute fix.

---

## Analogy

A doctor's triage: check breathing (did it start?), pulse (is it queued?), then the specific organ, before prescribing anything.

---

## How it works inside: the method

1. **Read the console output from the top**, not just the last line. The first lines tell you: cause, `Obtained Jenkinsfile from <sha>`, `Running on <node> in <workspace>`, library loads, checkout. The **first error** is usually the real one; later ones are consequences.
2. **Find the failing stage** in the Stages view, and that step's log.
3. **Name the layer** (list above).
4. **Reproduce on the node, as the agent user**: `sudo -i -u jenkins` on the agent, `cd` to the workspace, run the same command. If it fails there, it's not "Jenkins".
5. **Check what changed**: the build's *Changes*, recent plugin updates (Manage Jenkins → Plugins → Updates history), agent images, credentials rotation.
6. **Use Replay** to try a fix without commits (topic 32).
7. **Look at the controller/agent logs** if the build log isn't enough.

### Where the logs are

| What | Where |
|---|---|
| Build log | Build → Console Output (`/consoleText`), `$JENKINS_HOME/jobs/<job>/builds/<n>/log` |
| Branch indexing | Multibranch job → *Scan Repository Log* / *Multibranch Events* |
| Polling | Job → *Git Polling Log* |
| Agent connection | Node page → *Log*; on the agent `<remote root>/remoting/logs` |
| Controller | `docker logs jenkins` / `journalctl -u jenkins` / `kubectl logs`; Manage Jenkins → *System Log* (+ custom recorders) |
| Webhook deliveries | GitHub repo → Settings → Webhooks → Recent Deliveries |
| Script approvals | Manage Jenkins → *In-process Script Approval* |

---

## Config / Jenkinsfile / commands

Debugging helpers to drop into a failing pipeline temporarily:
```groovy
sh '''
  set -x
  id; hostname; pwd; ls -la
  echo "PATH=$PATH"
  which git docker mvn kubectl trivy || true
  df -h . /tmp
'''
```

## The catalog

### Trigger / queue / agents

| Symptom / message | Cause | Fix | Topic |
|---|---|---|---|
| Nothing happens after `git push` | Webhook not delivered, trigger not enabled, URL mismatch | Recent Deliveries; enable trigger; correct Jenkins URL; tunnel | 21, 46 |
| `Waiting for next available executor on 'x'` | All matching executors busy | More executors/agents | 11 |
| `There are no nodes with the label 'x'` | Typo or no agent with label | Fix label / add label | 11, 50 |
| `‘agent1’ is offline` / `Agent went offline during the build` | Channel lost: network, agent JVM OOM, host reboot | Node log; agent host memory; `Keep online`; ephemeral agents + `retry(conditions: [agent()])` | 50, 37 |
| `[SSH] Authentication failed` | Key/user/permissions | `authorized_keys`, 700/600, `ssh -v` as jenkins | 48, 51 |
| `Host key verification failed` | known_hosts not populated or changed | `ssh-keyscan`; verify the change | 51 |
| Inbound: `tcpSlaveAgentListener … 404` / `Connection refused :50000` | TCP port disabled/blocked | `-webSocket` or open/enable the port | 52 |
| `Disk space is too low. Only 0.8GiB left` (node offline) | Disk full | Clean workspaces/Docker; bigger disk | 22 |

### SCM / credentials

| Symptom / message | Cause | Fix | Topic |
|---|---|---|---|
| `ERROR: Could not find credentials entry with ID 'x'` | ID typo, wrong folder, System scope | Match ID; scope Global or the job's folder | 23 |
| `remote: Repository not found` / `Authentication failed` | Token expired/revoked/wrong scope | New token / GitHub App | 23, 46 |
| `Couldn't find any revision to build` | Branch spec doesn't match | `*/main` vs `master` | 19 |
| `ERROR: Unable to find Jenkinsfile` | Wrong branch / Script Path | Commit it; fix the path | 31 |
| `API rate limit exceeded` | PAT limits on multibranch scans | GitHub App | 46 |

### Pipeline / Groovy

| Symptom / message | Cause | Fix | Topic |
|---|---|---|---|
| `WorkflowScript: N: Missing required section "steps"` | Declarative structure | Fix the block | 31 |
| `No such DSL method 'x' found among steps` | Typo or plugin missing (cleanWs, slackSend, lock…) | Snippet Generator; install plugin | 33 |
| `Scripts not permitted to use method …` / `RejectedAccessException` | Sandbox | Use a step; careful approval | 30, 65 |
| `groovy.lang.MissingPropertyException: No such property: X` | Groovy interpolated `$X` in double quotes | Single quotes / `\$X` | 30 |
| `Warning: A secret was passed to "sh" using Groovy String interpolation` | Secret in a double-quoted `sh` | Single quotes | 24 |
| `java.io.NotSerializableException` | Non-serialisable object across a step | `@NonCPS` helper | 32, 42 |
| `Required context class hudson.FilePath is missing` | Step outside `node`/agent (scripted, or `agent none` post) | Wrap in `node {}` | 42, 35 |
| `Could not find any definition of libraries [x]` | Library name / config | Global Pipeline Libraries | 55 |
| Build green but tests failed | `\|\| true`, no `junit` | Publish results; let failures count | 41 |

### Steps / tools

| Symptom / message | Cause | Fix | Topic |
|---|---|---|---|
| `mvn: not found` / `docker: not found` / `kubectl: command not found` | Tool missing on that node / PATH | Tools config, install, container agent | 19, 40 |
| `permission denied while trying to connect to the Docker daemon socket` | Not in the socket's group / group not applied | Group (GID) + restart/reconnect | 25, 27 |
| `Bind for 0.0.0.0:5000 failed: port is already allocated` | Old container | `docker rm -f` first | 28 |
| `denied: requested access to the resource is denied` | Registry login/namespace/permissions | Login, correct repo, token scope | 28 |
| `no basic auth credentials` (ECR) | Login missing/expired | `aws ecr get-login-password` first | 62 |
| `exec format error` in the cluster | Image built for the wrong CPU arch | `--platform linux/amd64` | 62 |
| `QUALITY GATE STATUS: FAILED` | Code doesn't meet the gate | Fix code/tests (not the gate) | 62 |
| `Unauthorized` / `Forbidden` from kubectl | No access entry / RBAC | Access entry + RBAC | 63 |
| `No space left on device` | Disk full | Prune Docker, clean workspaces | 22 |

### Controller

| Symptom / message | Cause | Fix | Topic |
|---|---|---|---|
| Won't start: `older than the minimum required version (Java 21)` | Java too old | Java 21/25 | 12 |
| Won't start after updates: `Failed Loading plugin … Update required` | Plugin dependency conflict | Roll back; fix plugin set in staging | 66 |
| UI frozen, `OutOfMemoryError` | Heap | Heap size, discarders, plugins | 69 |
| "reverse proxy set up is broken" | Proxy headers/URL | Fix proxy config | 65 |
| `403 No valid crumb` | CSRF | API token / crumb | 70 |
| `NO_PUBKEY 7198F4B714ABFC68` on apt | Expired repo key | 2026 key | 49 |

---

## Hands-on lab

Break things on purpose in your lab, one at a time, and practise the method (read from the top → layer → reproduce → fix): wrong label; wrong credential ID; a typo in `steps`; `sh "echo $HOME"` in double quotes; stop the agent mid-build; remove the Docker group; fill a test agent's disk with `fallocate -l 20G /tmp/fill`. Write down the first error line for each; that's your personal catalog.

---

## Where you'll use it

Daily, as the "Jenkins person" on a team; on-call; interviews ("a build fails with X, what do you do?").

---

## When it breaks

(This whole topic is the "when it breaks" section.) One meta-rule: if a problem appeared **without** any change to the Jenkinsfile, look first at what changed **outside** it: plugins, agents, images, credentials, the network, the Git host.

---

## Quick recap

- Read the console **from the top**; the first error is usually the real one.
- Identify the layer: trigger → queue → agent → SCM → pipeline → step → post → controller.
- Reproduce on the node as the agent user; use Replay; check what changed.
- Know where each log lives.

**Interview questions**

1. **Q: A pipeline that worked yesterday fails today with no code change. How do you approach it?**
   A: Read the console from the top to find the first error and its layer, then check what changed outside the code: plugin updates, agent images/tools, rotated credentials, Git host or registry changes, disk space. Reproduce on the agent as the jenkins user.

2. **Q: A build is stuck "waiting for next available executor". Causes?**
   A: All matching executors are busy, the label matches no online node, agents are offline (disk, connection), or the job is blocked by concurrency limits/locks. The queue's "why" message says which.

3. **Q: `No such DSL method` means what?**
   A: The step isn't available: a typo, or the plugin providing it isn't installed or enabled on this controller.
