# 75 · Interview Question Bank

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** the questions DevOps/SRE interviews actually ask about CI/CD and Jenkins, grouped by area, each with a short model answer and the topic to revise. Every topic's own "Interview questions" stay in that topic; this is the consolidated drill sheet, plus extra questions.
>
> **How to use it:** cover the answer, say yours out loud, then compare. For any you miss, re-read the linked topic.

---

## CI/CD fundamentals

1. **CI vs continuous delivery vs continuous deployment?** CI builds and tests every change and gates merges; delivery keeps a tested artifact always releasable with a human approval for prod; deployment ships to prod automatically when checks pass. (01, 06)
2. **What does "build once, promote many" mean, and why?** One artifact is built and promoted unchanged (by digest) through all environments, so what was tested is exactly what ships. (07)
3. **Tag vs digest?** Tags are movable labels; digests are immutable SHA-256 content IDs. Deploy by digest. (07)
4. **GitFlow (environment branches) vs trunk-based?** Env branches: PRs between dev/stage/prod, a strong audit trail, more merges. Trunk-based: one `main`, short branches, promotions via pipeline/GitOps, needs feature flags and good tests. (08)
5. **Why deploy before merging a promotion PR?** So the target branch only records promotions proven healthy in that environment. (09)
6. **Canary vs blue-green?** Canary ramps traffic gradually while watching metrics; blue-green switches all traffic between two full environments. (09)
7. **SAST vs SCA vs DAST?** Your code statically; your dependencies/images against CVEs; the running app from outside. (06, 59)
8. **SLI, SLO, SLA, error budget?** Measurement; target; customer promise; allowed failure within the SLO. (06)

## Jenkins architecture

9. **Explain Jenkins architecture.** A controller (UI, queue, configs, history, credentials, plugins) plus agents that run builds in workspaces with executors; labels route jobs; Remoting connects them. (11)
10. **What happens after `git push`?** Webhook → job/branch found → queue → executor on a matching agent → workspace → checkout of the exact SHA → stages → artifacts/tests → result → status to Git → notifications. (11)
11. **Node vs agent vs executor?** Any build machine; a non-controller node; one build slot. (11)
12. **Why 0 executors on the controller?** Stability and security: build code could exhaust resources or read `JENKINS_HOME` secrets. (11, 50)
13. **What is `JENKINS_HOME` and what's in it?** All controller state: config XML, `jobs/` with build history, plugins, users, nodes, credentials and the `secrets/` keys. (16)
14. **LTS vs weekly? Java version?** LTS = stable baselines with backported fixes, for production; Jenkins now needs Java 21 or 25. (12)
15. **Ports Jenkins uses?** 8080 HTTP (UI/API/webhooks/WebSocket agents); 50000 TCP for inbound agents (optional). (12)
16. **Why does Jenkins use `hudson.*` names?** It was forked from Hudson in 2011 and kept the package names for compatibility. (10)
17. **Master/slave?** The old names for controller/agent. (10)

## Jobs and pipelines

18. **Freestyle vs Pipeline?** Pipelines are code in Git with stages, `parallel`, `when`, `input`, `post`, durability; Freestyle is UI-configured and brittle when chained. (29)
19. **Declarative vs scripted?** A fixed, validated structure with built-in features vs free-form Groovy. Use declarative + `script{}` + libraries. (31, 42)
20. **Mandatory declarative sections?** `pipeline`, `agent`, `stages`, `stage`, `steps`. (31)
21. **Where does pipeline Groovy run vs `sh`?** Groovy on the controller (flyweight executor); `sh` on the agent. (32)
22. **What is CPS? Why do pipelines survive restarts?** The engine saves program state between steps and resumes; `sh` runs as a durable process on the agent. (32)
23. **`NotSerializableException`?** A non-serialisable object held across a step; use `@NonCPS` helpers. (32, 42)
24. **`sh 'echo $X'` vs `sh "echo ${X}"`?** The shell expands vs Groovy interpolates; double quotes leak secrets. (30, 24)
25. **How do you run cleanup/notifications whatever the result?** `post { always/failure/cleanup }`, outside `stages`. (35)
26. **UNSTABLE vs FAILURE?** Quality failures (e.g. tests via `junit`) vs a failed step. (41)
27. **How do you deploy only from main?** `when { branch 'main' }` (multibranch). (38)
28. **How do you add an approval gate?** The stage-level `input` directive with `submitter` and a `timeout`. (38)
29. **How do you stop old builds deploying after new ones?** `milestone`, `disableConcurrentBuilds(abortPrevious: true)`, `lock`. (37, 38)
30. **How do you speed up CI?** Parallel stages on separate agents, caching/proxies, slow suites out of the merge gate, enough executors. (39)
31. **How do you avoid installing tools on agents?** Container agents (`agent { docker }`, Kubernetes pod templates). (40, 53)
32. **How do you pass files between stages on different agents?** `stash`/`unstash`. (40)
33. **How do you stop a pipeline hanging forever?** `options { timeout(...) }`. (37)
34. **How do you validate a Jenkinsfile without running it?** The declarative linter (HTTP or CLI). (33)

## Branches, PRs and GitHub

35. **What is a multibranch pipeline?** Automatically creates a job per branch/PR/tag with a Jenkinsfile, via scans/webhooks, and retires them. (43)
36. **PR Head vs Merge strategy?** The PR commit alone vs a synthetic merge with the current target; require Merge. (44)
37. **How are secrets protected from fork PRs?** Trust policies: untrusted forks use the target branch's Jenkinsfile; no credentials in stages running fork code. (44)
38. **How does Jenkins block a merge?** It posts a status/check; branch protection requires it. (46)
39. **GitHub App vs PAT?** Org-owned, short-lived tokens, granular permissions, higher rate limits, Checks API. (46)
40. **Webhook vs polling?** Push-based and instant vs scheduled checks; polling suits locked-down networks; use `H`. (21)

## Credentials and security

41. **Credential scopes?** Global (jobs + Jenkins), System (Jenkins only), folder (jobs in that folder). (23)
42. **How are credentials stored?** Encrypted in XML with keys in `secrets/`; protect the controller filesystem. (16, 23)
43. **Is masking enough?** No: it only hides exact matches in the console; control who edits pipelines. (24)
44. **How do you avoid static cloud keys?** IAM roles/instance profiles, IRSA/Pod Identity, OIDC. (24, 61)
45. **How do you secure Jenkins?** SSO, role/folder authorization, no controller builds, sandbox + careful approvals, HTTPS reverse proxy, patching, folder credentials. (65)
46. **Why is the Script Console dangerous?** Arbitrary Groovy as the controller: it can decrypt all credentials. (65, 70)
47. **What's a CSRF crumb?** An anti-CSRF token for session POSTs; API tokens don't need it. (65, 70)

## Agents and scaling

48. **SSH vs inbound agents?** The controller connects out over SSH vs the agent dials in (TCP 50000 or WebSocket). (50)
49. **Which host key verification strategy?** Known hosts file (pre-populated) or a manually provided key. (51)
50. **How do Kubernetes agents work?** A pod per build from a template; the `jnlp` inbound-agent container + tool containers sharing a workspace; deleted afterwards. (53)
51. **Downside of ephemeral agents?** Cold caches; fix with dependency proxies or cache volumes. (53)
52. **Jenkins on Kubernetes: how is data persisted? HA?** A StatefulSet + PVC; no active-active in OSS. (54, 69)

## Docker in CI

53. **DooD vs DinD?** Host socket (fast, root on the host) vs a nested privileged daemon (isolated-ish, slow caches). (26)
54. **Why is the docker group dangerous?** Socket access = root on the host. (25)
55. **Build images in Kubernetes without docker.sock?** BuildKit rootless/buildx remote, Buildah (Kaniko upstream is archived). (26)

## Shared libraries

56. **What problem do they solve?** Duplicated pipeline logic across repos; fix once, apply everywhere. (55)
57. **`vars/` vs `src/` vs `resources/`?** Global steps (`call()`); classes; static files via `libraryResource`. (55)
58. **How do you version and roll out library changes?** Semver tags, pinning, tests (JenkinsPipelineUnit), staged rollout. (58)
59. **Trusted vs untrusted libraries?** Global = trusted, not sandboxed; folder = sandboxed. (58)

## DevSecOps project

60. **Walk me through your DevSecOps pipeline.** Trivy FS → Maven verify + SonarQube gate → ECR login via IAM role → build (amd64) → Trivy image → push to an immutable ECR repo → update the manifest → deploy to EKS with least-privilege access → rollout status with automatic undo → post notifications. (62, 63)
61. **Why both SonarQube and Trivy?** Different risks: own code vs third-party/base image CVEs. (59)
62. **How did Jenkins get EKS access with least privilege?** IAM role with only DescribeCluster, an access entry (or legacy aws-auth) mapping it to a username in `system:authenticated`, and a minimal ClusterRole. Never `system:masters`. (61, 63)
63. **How does the pipeline roll back a failed rollout?** `rollout status --timeout` → `rollout undo` → `exit 1`. (63)
64. **How would you improve the pipeline?** Ingress/Gateway, multibranch, GitOps, DNS, digests, signing + admission, a secrets manager, observability, policy-as-code, Helm/Kustomize, canary, cleanup. (64)

## Operations

65. **How do you manage plugins?** A minimal pinned `plugins.txt`, a custom image, staging, security advisories. (66)
66. **How do you make a controller reproducible?** JCasC + plugins.txt + image + Job DSL/Organization Folders + Jenkinsfiles. (67)
67. **What do you back up, and what's the classic mistake?** `jobs/`, `plugins/`, `secrets/`, users, nodes, XML; forgetting `secrets/`. (68)
68. **Upgrade order?** Java → core LTS → plugins, after a backup and staging. (68)
69. **How do you monitor Jenkins?** The Prometheus plugin: queue, executors, nodes, heap; logs; alerts. (69)
70. **How do you trigger a job via API and wait for it?** `buildWithParameters` + API token → follow queue item → poll result; or CLI `build -s`. (70)
71. **Jenkins + Argo CD?** Jenkins CI commits the digest to an env-config repo; Argo CD syncs. (72)
72. **Jenkins vs GitHub Actions?** Topic 76.

## Rapid-fire

- `H` in cron? A hash-spread value per job. (21)
- Default inbound agent port? 50000. (12)
- Where's a build's log on disk? `jobs/<job>/builds/<n>/log`. (16)
- Step to clean the workspace? `cleanWs()` / `deleteDir()`. (22)
- Step to publish tests? `junit`. (41)
- Pin a library version? `@Library('lib@v1.2.0') _`. (55)
- Skip automatic checkout? `options { skipDefaultCheckout() }`. (37)
- Re-run with an edited Jenkinsfile without committing? Replay. (32)
- Successor of Blue Ocean? Pipeline Graph View. (15)
- Current Jenkins repo key file? `jenkins.io-2026.key`. (49)
