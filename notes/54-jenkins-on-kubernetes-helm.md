# 54 · Jenkins on Kubernetes with Helm

> **Level:** ★★★ advanced · **Status:** ✅➕ rewritten and expanded from the Day 03 example
>
> **You will learn:** how to run the **controller itself** in Kubernetes with the official Helm chart: values that matter (persistence, resources, admin secret, plugins, JCasC, agents, ingress), what the chart creates, how to upgrade and back it up, and when this is worth it.
>
> **You need:** topics 13, 53; Helm basics ([Kubernetes notes 65 Helm](../../CKA-Certification-Course-2025/notes/65-helm.md)).
>
> **From your original notes:** Day 03 › *3) Kubernetes (Jenkins on K8s)*: cloud-native, scalable, enterprise-ready, con, the "not every organisation runs Kubernetes" note, the Helm example and its notes.

---

## What it is

The **jenkins/jenkins Helm chart** (from `https://charts.jenkins.io`) deploys:
- a **StatefulSet** with one controller pod (containers: `jenkins` + a `config-reload` sidecar that applies JCasC changes from ConfigMaps),
- a **PVC** for `/var/jenkins_home`,
- **Services** for the UI (8080) and the inbound agent port (50000),
- a **ServiceAccount + RBAC** so the controller can create agent pods,
- the **Kubernetes cloud** preconfigured (topic 53),
- an optional **Ingress**.

---

## Why it exists

From Day 03: *cloud-native* (ingress, storage and config are standard Kubernetes resources, so ops are uniform with other apps), *scalable* (ephemeral agent pods per build; scale idle agents to zero), *enterprise-ready* where clusters already exist (secrets managers, NetworkPolicies, cloud StorageClasses). **Con:** operationally complex: needs Kubernetes skills (storage, ingress, RBAC, autoscaling) and careful chart/values management.

> Not every organisation runs Kubernetes. If your apps deploy to **VMs or serverless** (not to Kubernetes), running Jenkins **on Kubernetes adds no value**. Prefer a **VM controller** with VM-based agents (or cloud agents), and keep CD/CDp targeting the platforms you deploy to.

---

## Analogy

Moving the head chef's office into the **commercial kitchen complex** (the cluster): the complex provides power, security and storage, and the chef can summon pop-up cooks (pods) instantly. But you now depend on the complex's management.

---

## How it works inside

```
helm upgrade --install jenkins jenkins/jenkins -n ci -f values.yaml
   → StatefulSet jenkins (pod jenkins-0) ← PVC jenkins (RWO disk)
   → initContainer installs plugins listed in controller.installPlugins
   → JCasC YAML from ConfigMaps (controller.JCasC.configScripts) applied at start, reloaded by the sidecar
   → Service jenkins:8080, jenkins-agent:50000 ; Ingress (optional)
   → agents: Kubernetes cloud pointing at http://jenkins.ci.svc.cluster.local:8080
```
Only **one** controller replica: open-source Jenkins can't run active-active (topic 69). The StatefulSet restarts it if it dies; the PVC keeps the state.

---

## Config / Jenkinsfile / commands

### The Day 03 example, corrected

```bash
helm repo add jenkins https://charts.jenkins.io && helm repo update
kubectl create namespace ci
kubectl -n ci create secret generic jenkins-admin \
  --from-literal=jenkins-admin-user=admin \
  --from-literal=jenkins-admin-password="$(openssl rand -base64 24)"

helm upgrade --install jenkins jenkins/jenkins \
  --namespace ci \
  --set controller.serviceType=ClusterIP \
  --set controller.jenkinsUriPrefix="/" \
  --set controller.resources.requests.cpu=500m \
  --set controller.resources.requests.memory=1Gi \
  --set controller.admin.existingSecret=jenkins-admin \
  --set persistence.size=20Gi
```
> ⚠️ **Corrected:** was `--set controller.jenkinsAdminPassword=admin123`. Now the admin user/password come from a **Secret** via `controller.admin.existingSecret` (the chart keeps admin settings under `controller.admin.*`), because a password in `--set` lands in shell history and in the Helm release (readable with `helm get values` by anyone with namespace access), and `admin123` is trivially guessable. (Also see topic 13.)

Each flag: `serviceType=ClusterIP` (internal Service, exposed via Ingress); `jenkinsUriPrefix="/"` (the URL path); `resources.requests` (guaranteed CPU/memory for scheduling); `persistence.size=20Gi` (the PVC for `JENKINS_HOME`).

### A real `values.yaml`

```yaml
controller:
  image:
    tag: "2.568.2-lts-jdk21"           # pin the controller version
  admin:
    existingSecret: jenkins-admin
  resources:
    requests: { cpu: "1", memory: "2Gi" }
    limits:   { memory: "4Gi" }
  javaOpts: "-XX:MaxRAMPercentage=75 -Duser.timezone=Asia/Kolkata"
  numExecutors: 0                      # no builds on the controller
  installPlugins:                      # pinned plugin list (topic 66)
    - kubernetes:4560.vc25b_83890c34      # these four are the chart's own defaults (Nov 2026)
    - workflow-aggregator:608.v67378e9d3db_1
    - git:5.11.0
    - configuration-as-code:2147.v8a_8d38668c72
  JCasC:
    configScripts:
      welcome: |
        jenkins:
          systemMessage: "Managed by Helm + JCasC. Changes in the UI will be lost."
  ingress:
    enabled: true
    ingressClassName: nginx
    hostName: ci.example.com
    tls:
      - secretName: ci-example-com-tls
        hosts: [ci.example.com]
persistence:
  size: 50Gi
  storageClass: gp3
agent:
  enabled: true
  namespace: jenkins-agents
  websocket: true
```
(The four plugin versions are what the chart itself installs by default as of November 2026; add your own plugins in the same `name:version` format.)

**Verified against the chart's `values.yaml`/`VALUES.md` (November 2026):**
- `controller.admin.*`: `username` (default `admin`), `password` (random if empty), `createSecret` (true), `existingSecret` (empty), and the keys **inside** that Secret, `userKey: jenkins-admin-user` and `passwordKey: jenkins-admin-password` (which is why the Secret above uses those names).
- `controller.image.{registry, repository, tag, tagLabel}`: `tag` is empty by default (the chart picks its own pinned version), and `tagLabel` defaults to `jdk25`. Set `tag` to pin the version yourself.
- `controller.numExecutors` defaults to **0**: the chart already follows the "no builds on the controller" rule.
- `controller.javaOpts`, `controller.installPlugins`, `controller.JCasC.configScripts`, `controller.jenkinsUriPrefix`, `controller.serviceType` (default `ClusterIP`), `controller.resources` (default requests 50m CPU / 256Mi, limits 2 CPU / 4Gi), `controller.ingress.{enabled, ingressClassName, hostName, tls}`.
- `controller.sidecars.configAutoReload.enabled` (default **true**: the `k8s-sidecar` reload container that makes the pod `2/2`).
- `agent.enabled` (true), `agent.namespace` (unset = the controller's namespace), `agent.websocket` (**false** by default, so set it to `true` as above).
- `persistence.enabled` (true), `persistence.size` (8Gi), `persistence.storageClass` (unset = the cluster default). These three were confirmed only from summaries of the chart docs, so re-check them with the command below.
- The controller is a **StatefulSet** (`controller.statefulSetAnnotations`, `controller.updateStrategy`). The chart also supports Gateway API `controller.httpRoute` as an alternative to Ingress.

> **Check the keys against your chart version.** Chart keys can move between major chart versions. Before installing, print the real defaults and compare:
> ```bash
> helm show values jenkins/jenkins > chart-values.yaml
> grep -n -A6 '^  admin:' chart-values.yaml          # admin.username / password / existingSecret / userKey / passwordKey
> grep -n -E 'installPlugins|configScripts|numExecutors|javaOpts|websocket|hostName|ingressClassName' chart-values.yaml
> ```
> If a key here differs from `chart-values.yaml`, the chart file wins. Also check the key names the chart expects **inside** the admin Secret (`userKey`/`passwordKey`; commonly `jenkins-admin-user` / `jenkins-admin-password`, as used above).

```bash
helm upgrade --install jenkins jenkins/jenkins -n ci -f values.yaml
kubectl -n ci rollout status statefulset/jenkins
kubectl -n ci get pods,svc,pvc
```
```
NAME            READY   STATUS    RESTARTS   AGE
pod/jenkins-0   2/2     Running   0          3m
NAME                    TYPE        CLUSTER-IP     PORT(S)
service/jenkins         ClusterIP   10.96.41.12    8080/TCP
service/jenkins-agent   ClusterIP   10.96.200.7    50000/TCP
NAME                                   STATUS   CAPACITY   STORAGECLASS
persistentvolumeclaim/jenkins          Bound    50Gi       gp3
```
`2/2` = the `jenkins` container + the `config-reload` sidecar.

**Notes (from Day 03, expanded):**
- Use a **StorageClass with snapshots**; back up the **PVC** (e.g. VolumeSnapshots or Velero) *and* keep configuration as code (**JCasC**, topic 67), so you can rebuild from Git.
- Prefer **Ingress + TLS**; lock down with **NetworkPolicies** (only the ingress controller and agent pods may reach the controller); run agents as non-root.
- **Upgrades:** bump `controller.image.tag` and plugin pins in `values.yaml`, `helm upgrade`, watch the rollout; roll back with `helm rollback jenkins <rev>` (but plugins may have migrated data, so snapshot the PVC first, topic 68).
- In-cluster agents: the chart configures the Kubernetes cloud for you.

---

## Hands-on lab (kind)

1. `kind create cluster --name jk`; create the namespace and admin Secret; install with the Day 03 command (use `persistence.size=5Gi` for kind).
2. `kubectl -n ci port-forward svc/jenkins 8080:8080` → log in with the Secret's password (`kubectl -n ci get secret jenkins-admin -o jsonpath='{.data.jenkins-admin-password}' | base64 -d`).
3. Run a pipeline with `agent { kubernetes { yaml '…' } }` (topic 53): an agent pod appears in the namespace.
4. Delete the controller pod (`kubectl -n ci delete pod jenkins-0`): it comes back with all its jobs (the PVC).
5. Change `systemMessage` in values, `helm upgrade`, and see it update without a restart (config-reload sidecar).

---

## Where you'll use it

Kubernetes-first platform teams; companies standardising everything (including CI) on EKS/GKE/AKS.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `jenkins-0` stuck `Pending` | PVC can't bind (no StorageClass) | Set `persistence.storageClass` |
| `Init:CrashLoopBackOff` | A plugin in `installPlugins` failed to download/resolve | Check the init container log; fix versions/dependencies |
| UI changes disappear after restart | JCasC re-applies values | Change values.yaml, not the UI |
| Agents can't connect | Wrong agent Jenkins URL / NetworkPolicy | Use the Service DNS name; allow agent → controller traffic |
| OOMKilled controller | Memory limit too low for the heap | Raise the limit; `MaxRAMPercentage` |

---

## Quick recap

- The chart deploys a single-replica StatefulSet + PVC + Services + RBAC + Kubernetes cloud (+ Ingress).
- Admin credentials from a **Secret** (`controller.admin.existingSecret`), never `--set` passwords.
- Pin the image tag and plugins; configure with JCasC in values; 0 controller executors.
- Back up the PVC *and* keep config as code; only worth it if you already run Kubernetes.

**Interview questions**

1. **Q: How does the Jenkins Helm chart persist data?**
   A: A PVC mounted at `/var/jenkins_home` in a single-replica StatefulSet; the pod can be rescheduled and reattaches the same volume.

2. **Q: How do you configure a Helm-deployed Jenkins without clicking in the UI?**
   A: JCasC YAML in `controller.JCasC.configScripts` and pinned plugins in `controller.installPlugins`, applied via `helm upgrade`; a sidecar reloads JCasC changes.

3. **Q: Can you run several Jenkins controller replicas for HA?**
   A: No, open-source Jenkins doesn't support active-active controllers. Rely on fast restart (StatefulSet + PVC), backups, and splitting load across multiple controllers.
