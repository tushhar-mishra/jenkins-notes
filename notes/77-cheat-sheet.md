# 77 · Cheat Sheet

> **Level:** ★ reference · **Status:** 🆕 new topic
>
> One-page reminders of everything in the course. Each line points to the topic with the full explanation.

---

## Run Jenkins

```bash
# Docker lab (14)
docker run -d --name jenkins --restart unless-stopped -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home -e TZ=Asia/Kolkata jenkins/jenkins:lts-jdk21
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# + DooD (27): custom image with docker-ce-cli, -v /var/run/docker.sock:/var/run/docker.sock --group-add $(stat -c %g /var/run/docker.sock)

# Ubuntu VM (49): Java 21 + 2026 key + debian-stable
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list
sudo apt update && sudo apt install -y openjdk-21-jre-headless jenkins
sudo systemctl edit jenkins     # Environment="JAVA_OPTS=-Djava.awt.headless=true -Duser.timezone=Asia/Kolkata"
```

## Paths (16)

| What | Where |
|---|---|
| Controller state | `/var/jenkins_home` (Docker) · `/var/lib/jenkins` (package) |
| Build log | `jobs/<job>/builds/<n>/log` |
| Artifacts | `jobs/<job>/builds/<n>/archive/` |
| Credential keys | `secrets/master.key`, `secrets/hudson.util.Secret` |
| Agent work dir | `<remote root>/workspace/<job>`, `@tmp`, `@libs` |

## Declarative skeleton (31–41)

```groovy
@Library('platform-lib@v2') _
pipeline {
  agent { label 'docker' }                        // any | none | { docker { image '…' } } | { kubernetes { yaml '…' } }
  options {
    timeout(time: 30, unit: 'MINUTES'); timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
    disableConcurrentBuilds(abortPrevious: true)
  }
  parameters { choice(name: 'ENV', choices: ['dev','stage','prod']) }
  triggers   { cron('H 2 * * *') }
  environment {
    IMAGE = "registry.example.com/app"
    TOKEN = credentials('sonarqube-token')        // secret text → $TOKEN
  }
  stages {
    stage('Test')  { steps { sh 'make test' } post { always { junit 'reports/*.xml' } } }
    stage('Checks') { parallel {
      stage('Lint') { steps { sh 'make lint' } }
      stage('SCA')  { steps { sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL .' } } } }
    stage('Build') { steps { script { env.TAG = env.GIT_COMMIT.take(7) }
                             sh 'docker build -t "$IMAGE:$TAG" .' } }
    stage('Push')  { when { branch 'main' }
      steps { withCredentials([usernamePassword(credentialsId: 'registry', usernameVariable: 'U', passwordVariable: 'P')]) {
        sh 'echo "$P" | docker login -u "$U" --password-stdin registry.example.com && docker push "$IMAGE:$TAG"' } } }
    stage('Prod')  { when { branch 'main' }
      input { message 'Deploy to prod?'; submitter 'release-managers' }
      steps { lock('env-prod') { sh './deploy.sh prod' } } }
  }
  post {
    failure { echo "FAILED ${env.BUILD_URL}" }   // slackSend / emailext (71)
    fixed   { echo 'back to green' }
    cleanup { cleanWs() }
  }
}
```

## Quoting (30)

| Write | Meaning |
|---|---|
| `sh 'echo $X'` | **shell** expands `$X` ✅ (use with secrets) |
| `sh "echo ${X}"` | **Groovy** interpolates first ⚠️ |
| `sh "echo \$HOME"` | literal `$` for the shell |
| `'''…'''` / `"""…"""` | multi-line, without / with Groovy interpolation |
| `sh(script: 'cmd', returnStdout: true).trim()` | capture output |
| `sh(script: 'cmd', returnStatus: true)` | capture exit code |

## `when` (38)

`branch 'main'` · `buildingTag()` · `tag pattern: 'v*', comparator: 'GLOB'` · `changeRequest()` · `changeset 'src/**'` · `expression { params.X }` · `environment name: 'A', value: 'b'` · `allOf/anyOf/not` · `beforeAgent true`

## `post` order (35)

`always → changed → fixed → regression → aborted → failure → success → unstable → unsuccessful → cleanup`

## Results (41)

SUCCESS · UNSTABLE (`junit` failures, `unstable()`) · FAILURE (`sh` non-zero, `error()`) · ABORTED (timeout/user) · NOT_BUILT · `catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') { … }`

## Built-in env vars (17, 34, 43)

`BUILD_NUMBER BUILD_URL JOB_NAME WORKSPACE NODE_NAME JENKINS_URL BUILD_TAG GIT_COMMIT GIT_BRANCH BRANCH_NAME CHANGE_ID CHANGE_TARGET` · full list: `<JENKINS_URL>/env-vars.html`

## Cron (21)

`MIN HOUR DOM MON DOW` · `H` = hash-spread · `H/15 * * * *` every ~15 min · `H 2 * * 1-5` weekday nights · `TZ=Asia/Kolkata` first line · `@daily`

## Credentials (23–24)

Kinds: username/password · secret text · SSH key · secret file · certificate · GitHub App. Scopes: Global (jobs+Jenkins) · System (Jenkins only) · folder.
```groovy
withCredentials([string(credentialsId: 'tok', variable: 'T')]) { sh 'cmd --token "$T"' }
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) { sh 'kubectl get ns' }
sshagent(credentials: ['deploy-key']) { sh 'ssh deploy@host uptime' }
```

## Shared library (55)

```
vars/buildImage.groovy   → buildImage()     (def call(Map cfg = [:]) { … })
src/org/acme/X.groovy    → import org.acme.X  (implements Serializable)
resources/x.yaml         → libraryResource 'x.yaml'
```

## Agents (50–53)

```bash
# SSH agent (51): key as controller's jenkins user → agent ~/.ssh/authorized_keys (700/600), Known hosts strategy
ssh-keyscan <agent> | sudo -u jenkins tee -a /var/lib/jenkins/.ssh/known_hosts
# Inbound (52)
java -jar agent.jar -url https://ci.example.com/ -name n1 -secret <s> -webSocket -workDir /home/jenkins/agent
```

## API / CLI (70)

```bash
curl -u user:TOKEN "$J/api/json?tree=jobs[name,color]"
curl -u user:TOKEN -X POST "$J/job/X/buildWithParameters?ENV=dev"
curl -u user:TOKEN "$J/job/X/lastBuild/consoleText"
curl -u user:TOKEN -X POST -F "jenkinsfile=<Jenkinsfile" "$J/pipeline-model-converter/validate"
java -jar jenkins-cli.jar -s $J -auth user:TOKEN build X -p ENV=dev -s -v
curl -u user:TOKEN -X POST "$J/safeRestart"      # also /quietDown, /cancelQuietDown
```

## Docker in CI (25–28)

`docker login --password-stdin` · tag by commit/digest, not only `latest` · `docker buildx imagetools inspect IMG --format '{{json .Manifest}}' | jq -r .digest` · smoke test: `docker run --rm --network container:APP curlimages/curl -fsS http://localhost:PORT` · prune: `docker image prune -af --filter until=168h`

## DevSecOps (59–63)

```bash
trivy fs --exit-code 1 --severity HIGH,CRITICAL .
mvn -B clean verify sonar:sonar -Dsonar.projectKey=K -Dsonar.host.url=$URL -Dsonar.token=$TOKEN -Dsonar.qualitygate.wait=true
aws ecr get-login-password --region R | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.R.amazonaws.com
docker build --platform linux/amd64 -t "$IMAGE_REPO:$BUILD_NUMBER" .
trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMAGE_REPO:$BUILD_NUMBER"
aws eks create-access-entry --cluster-name C --principal-arn ROLE_ARN --username jenkins-agent-role
kubectl create ns N --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout status deploy/D -n N --timeout=120s || { kubectl rollout undo deploy/D -n N; exit 1; }
```
Quality gate condition: **Coverage is *less than* 80%**.

## Ops (65–69)

Security: SSO · role/folder authorization · 0 controller executors · sandbox + careful approvals · HTTPS proxy (WebSocket headers) · patch from advisories.
Plugins: pinned `plugins.txt` → `jenkins-plugin-cli` in an image → staging → safe restart.
JCasC: `CASC_JENKINS_CONFIG`, `${SECRET}` placeholders, export from Manage Jenkins.
Backup: `jobs/ plugins/ secrets/ users/ nodes/ *.xml`; exclude `workspace/ caches/ war/ updates/`; drill restores.
Upgrade: Java → core LTS → plugins. Monitor: `/prometheus/` (queue, executors, nodes, heap).

## Current facts (Nov 2026)

Java 21/25 (17 unsupported) · LTS line 2.568.x · repo key `jenkins.io-2026.key` · Blue Ocean deprecated → Pipeline Graph View · "JNLP" → inbound agents (TCP/WebSocket) · Global Tool Configuration → **Tools** · legacy Docker builder deprecated (BuildKit) · Kaniko upstream archived · EKS `aws-auth` deprecated → access entries · `openjdk` images deprecated → `eclipse-temurin`.
