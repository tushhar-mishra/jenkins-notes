# 69 · Monitoring, Performance and High Availability

> **Level:** ★★★ advanced · **Status:** 🆕 new topic
>
> **You will learn:** what to monitor on a Jenkins controller (JVM heap and GC, queue length, executors, agents, disk, build durations), how to expose metrics to **Prometheus/Grafana**, where the logs are, the usual performance fixes, and the honest truth about **high availability and disaster recovery** in open-source Jenkins.
>
> **You need:** topics 11, 12, 16, 22, 68.
>
> **From your original notes:** Day 03 › admins own "backups/DR, HA"; Day 02 › Continuous Monitoring concepts; Project 01 › observability improvement.

---

## What it is

Jenkins is a production service like any other: it needs **metrics, logs, alerts and capacity planning**. When it's slow or down, every team's delivery stops.

---

## Why it exists

Common Jenkins incidents: the UI freezes (heap exhausted), builds wait for hours (no executors / agents offline), disk full, a plugin update leaves the controller down. Monitoring catches these before developers do.

---

## Analogy

An air-traffic control tower monitors itself too: radar health, staff on shift, runway queue. If the tower fails, every flight stops.

---

## How it works inside

### Key signals

| Signal | Why | Alert when |
|---|---|---|
| JVM heap used after GC, GC pause time | Memory pressure freezes the UI | heap > 85% after GC; long GC pauses |
| Build queue length & time in queue | Not enough capacity / labels missing | queue > N for > 10 min |
| Executors busy / total | Capacity | > 90% busy for long periods |
| Agents online/offline | Lost capacity | any critical agent offline |
| Disk free in `JENKINS_HOME` and on agents | Disk-full outages | < 15% free |
| Build duration & failure rate per job | Slow/flaky pipelines | regressions |
| HTTP response time / 5xx | User experience | p95 > 2 s |
| Plugin/core security warnings | Risk | any |

### Exposing metrics

- **Prometheus metrics** plugin: serves `/prometheus` with JVM, queue, executor, node and job metrics; scrape it with Prometheus, chart it in Grafana (community dashboards exist).
- **OpenTelemetry** plugin: sends pipeline **traces** (each stage as a span) and metrics to an OTel backend, so slow stages are visible; also links builds to logs.
- **Metrics** plugin: JVM/health checks at `/metrics/<key>/healthcheck`.
- Built-in **Manage Jenkins → Load Statistics** (queue vs executors over time) and **System Information**.

### Logs

| Install | Controller log |
|---|---|
| Docker | `docker logs jenkins` |
| Linux package | `journalctl -u jenkins` |
| Kubernetes | `kubectl logs sts/jenkins -c jenkins` |
| All | **Manage Jenkins → System Log** (add a custom log recorder for e.g. `hudson.plugins.git` at FINE level while debugging) |

Agent logs: node page → **Log**; on the agent, `<remote root>/remoting/logs/`. Build logs: `jobs/<job>/builds/<n>/log`.

### Performance: the usual fixes

1. **No builds on the controller** (executors 0) and no heavy Groovy in pipelines (topic 32).
2. **Build discarders everywhere** (topic 18): thousands of old builds slow the UI and startup.
3. **Heap sizing:** `-XX:MaxRAMPercentage=75` in containers / `-Xmx` on VMs, with G1GC (Java's default). Big controllers: 4–16 GB.
4. **Fast disk** for `JENKINS_HOME` (SSD/gp3), because everything is small files.
5. **Fewer plugins** (topic 66).
6. **Webhooks instead of polling** (topic 21); `H` in cron specs.
7. **Durability `PERFORMANCE_OPTIMIZED`** for chatty pipelines (topic 32).
8. **Avoid huge console logs** (verbose `set -x` loops), and huge `archiveArtifacts`/`stash`.
9. **Split** one giant controller into several (per org/team); CloudBees Operations Center manages many.

### High availability and disaster recovery (the honest version)

- Open-source Jenkins **does not support active-active controllers**. Only one controller process may use a given `JENKINS_HOME`.
- Practical HA = **fast recovery**: the controller runs under systemd (`Restart=always`) or a Kubernetes StatefulSet, `JENKINS_HOME` on durable storage (EBS/PVC with snapshots), config as code to rebuild quickly, and running pipelines resume after a restart (durability, topic 32). Realistic recovery: minutes.
- **DR:** backups/snapshots copied to another region + JCasC/`plugins.txt` in Git; a documented, tested restore (topic 68). Define **RPO/RTO** (topic 02) for Jenkins like any service.
- **CloudBees CI** offers a high-availability (active-active) mode for enterprise needs (topic 13).
- Reduce the blast radius by **splitting controllers** per team/business unit.

---

## Config / Jenkinsfile / commands

```bash
curl -s http://localhost:8080/prometheus/ | grep -E '^(jenkins_queue_size_value|jenkins_executor_in_use_value|jenkins_node_offline_value|vm_memory_heap_usage)'
```
```
jenkins_queue_size_value 3.0
jenkins_executor_in_use_value 4.0
jenkins_node_offline_value 1.0
vm_memory_heap_usage 0.62
```
Prometheus scrape config:
```yaml
scrape_configs:
  - job_name: jenkins
    metrics_path: /prometheus/
    static_configs: [{ targets: ['jenkins:8080'] }]
```
Example alert (PromQL):
```yaml
- alert: JenkinsQueueBacklog
  expr: jenkins_queue_size_value > 10
  for: 15m
  labels: { severity: warning }
  annotations: { summary: "Jenkins queue has >10 waiting builds for 15m" }
```
Thread dump when the UI hangs: **Manage Jenkins → System Information → Thread Dumps**, or `jcmd <pid> Thread.print` on the host, and look for many threads blocked on the same lock.

---

## Deeper dive

### Capacity planning with simple maths

```
executors needed ≈ (builds per hour at peak × average build minutes) ÷ 60   (+ 20–30% headroom)
```
Example: at 9–10 AM, 120 builds/hour × 8 min average = 960 executor-minutes per hour ÷ 60 = **16 executors** busy all hour → plan ~20. If builds use parallel branches on separate agents, count each branch. Queue time (time waiting for an executor) is the user-visible symptom when you're under capacity.

### SLOs for your CI platform

Developers experience Jenkins as a service, so give it SLOs (topic 06):
- **Queue time:** p95 time-to-start < 2 minutes during working hours.
- **Infrastructure success rate:** > 99% of builds don't fail for *platform* reasons (agent lost, disk full, plugin error); test failures don't count.
- **Availability:** UI/API/webhooks reachable 99.9% of working hours.
Track "infrastructure failure" separately, e.g. by matching log lines like `Agent went offline` or `No space left on device`.

### JVM and GC visibility

```bash
JAVA_OPTS="-XX:MaxRAMPercentage=75 -Xlog:gc*:file=/var/jenkins_home/logs/gc.log:time,uptime:filecount=5,filesize=20m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/jenkins_home/logs"
```
- `-Xlog:gc*` writes rotating GC logs; long or frequent full-GC pauses explain UI freezes.
- `HeapDumpOnOutOfMemoryError` saves a heap dump for analysis (Eclipse MAT shows which objects filled the heap: often build records or a leaky plugin).
- Thread dumps: `/threadDump` (admins) or `jcmd <pid> Thread.print`. Many threads `BLOCKED` on the same lock = a contention bug, usually in a plugin.

### Support bundles

The *Support Core* plugin generates a **support bundle** (**Manage Jenkins → Support**): system info, plugin list, logs, thread dumps, node info, with secrets removed. It's the first thing to collect for any serious incident or bug report.

### Useful built-in pages

| Page | URL |
|---|---|
| System information (Java, properties, env) | `/manage/systemInfo` |
| System log and custom recorders | `/manage/log` |
| Load statistics (queue vs executors) | `/manage/load-statistics` |
| Nodes and their monitors | `/manage/computer/` |
| About (versions, licences) | `/manage/about` |

### HA patterns people try (and their trade-offs)

| Pattern | Reality |
|---|---|
| Two controllers on shared NFS `JENKINS_HOME` | ❌ Not supported: two processes corrupt state |
| Active/passive with shared storage + failover | ⚠️ Possible if strictly one is running at a time (fencing!); recovery = start the standby (minutes) |
| StatefulSet/systemd auto-restart + durable disk | ✅ Simplest effective HA; restart in minutes, pipelines resume |
| Many smaller controllers (per team/business unit) | ✅ Limits blast radius; operational cost per controller |
| CloudBees CI high availability | ✅ Active-active (commercial) |

---

## Hands-on lab

1. Install the **Prometheus metrics** plugin; `curl /prometheus/` and find queue, executor and heap metrics.
2. Run Prometheus + Grafana with Docker Compose on `jenkins-net`, scrape Jenkins, and import a community Jenkins dashboard.
3. Start 5 builds with 1 executor available; watch `jenkins_queue_size_value` rise and fall.
4. Open **Load Statistics** and **System Log**; add a log recorder for `hudson.plugins.git` (FINE), run a checkout, read it.

---

## Where you'll use it

Running Jenkins as a platform team; on-call for CI; capacity planning; "Jenkins is slow" tickets.

---

## When it breaks

| Symptom | Likely cause | Action |
|---|---|---|
| UI unresponsive, log shows `OutOfMemoryError` | Heap too small / too many builds kept / memory-heavy plugin | Raise heap, discard builds, heap dump analysis, review plugins |
| Long queue, executors idle | Label mismatch / agents offline | Check queue reasons (`why`), node status |
| Long queue, all executors busy | Capacity | Add agents / cloud capacity; parallelism |
| Controller restarts take 20+ minutes | Huge `jobs/` with old builds | Discarders; split controllers |
| Pipelines slow, controller CPU high | Groovy-heavy pipelines | Move logic into `sh`; `@NonCPS` helpers; durability hint |

---

## Quick recap

- Monitor heap/GC, queue, executors, agents, disk, build durations; expose them with the Prometheus (and OpenTelemetry) plugins.
- Performance: no controller builds, discarders, right-sized heap, fast disk, fewer plugins, webhooks.
- OSS Jenkins has **no active-active HA**: aim for fast restart, durable storage, config as code, tested restores, and split controllers.

**Interview questions**

1. **Q: How do you monitor Jenkins?**
   A: The Prometheus metrics plugin (JVM, queue, executors, nodes, jobs) scraped into Prometheus/Grafana with alerts on queue backlog, offline agents, heap and disk; plus controller and agent logs, and OpenTelemetry for pipeline traces.

2. **Q: Can you run Jenkins in high availability?**
   A: Open-source Jenkins can't run active-active. You get resilience from automatic restarts, durable storage, resumable pipelines, configuration as code and tested backups; CloudBees CI offers active-active HA.

3. **Q: Jenkins is slow. Your first three checks?**
   A: JVM heap/GC (memory pressure), whether builds or heavy Groovy run on the controller, and the number of retained builds/jobs (build discarders) and disk performance.
