# 62 · Project 4, Part 1: Scan, Build, Push

> **Level:** ★★★ advanced · **Status:** ✅ rewritten from your notes (credential-ID and quality-gate corrections; BuildKit)
>
> **You will learn:** stages 1–7 of the production DevSecOps pipeline: Git checkout and job setup, Trivy filesystem scan, Maven build + SonarQube analysis with an enforced quality gate, ECR login through an IAM role, image build, Trivy image scan, and push to ECR.
>
> **You need:** topics 23–24, 49, 51, 59–61. AWS account; controller (topic 49) + SSH agent labelled `docker-maven-trivy` (topic 51) + SonarQube (topic 60).
>
> **From your original notes:** Project 01 › *Demo: End-to-End Production DevSecOps Pipeline* (What are we going to do), *Stage 1* (0–6), *Stage 2* (objective, add stage, explanation, install Trivy, commit, run, example report, simulate a problem), *Stage 3* (1–6, pipeline, explanations, run, demo note), *Stage 4* (prerequisites: AWS CLI + Docker, IAM role, ECR repository, pipeline, explanation, run), *Stage 5* (Dockerfile + explanation, pipeline, explanation, run), *Stage 6* (pipeline snippet, explanation, outcome), *Stage 7* (snippet, why, explanation, verify).
>
> 📁 Files: [`project-files/project-4-devsecops-eks/`](../project-files/project-4-devsecops-eks/) (`project_files/Jenkinsfile` = original, `project_files/Jenkinsfile.corrected` = fixed)

---

## What it is

![DevSecOps pipeline](../images/me1.png)

A **production-grade DevSecOps pipeline** using **Jenkins**, **Trivy**, **SonarQube**, **AWS ECR** and **Amazon EKS**. It enforces **several security gates**: **scanning source code**, **running unit tests**, **static analysis**, **scanning the container image**, and **deploying only when every stage passes**. It follows **least-privilege access**, uses **immutable image tags**, and **validates rollout health** before completing the deployment. This topic covers stages 1–7; topic 63 covers deployment.

---

## Why it exists

Each gate catches a different class of problem before it reaches production; the order (cheap and early first) keeps feedback fast.

---

## Analogy

A **factory with inspection stations**: incoming parts (Trivy FS), workmanship and measurement (Sonar), final product X-ray (Trivy image), sealed and shelved in the warehouse (ECR push).

---

## How it works inside

```
checkout → Trivy FS (deps/secrets) → mvn verify + Sonar (tests, coverage, SAST, quality gate)
        → ECR login (IAM role) → docker build (:BUILD_NUMBER, :latest) → Trivy image → docker push
```
Every stage runs on the agent `docker-maven-trivy`; any non-zero exit code stops the pipeline.

---

## Config / Jenkinsfile / commands

## Stage 1: Git checkout & Jenkins pipeline job setup

*(Reference: "Checkout private Git repo" box in the diagram.)*
**Objective:** prepare source control and a Jenkins pipeline job that can securely check out the private repo. No build tools yet, only **Git** (already on Ubuntu 24.04, used via the Jenkins Git plugin).

**0. Create a private GitHub repo** (GitHub → New repository → `cwvj-private-repo`, **Private**). It holds the application code, the `pom.xml`, and later the Kubernetes manifests, Dockerfile and Jenkinsfile. Jenkins pulls from it (and could push build-related updates to it).

**1. Create a GitHub PAT** (GitHub → Settings → Developer settings → Personal access tokens → **Classic**, scope `repo`, because the same token is used for **push**; in production restrict it to minimal permissions). Copy it now.

**2. Add the PAT to Jenkins credentials** (**Manage Jenkins → Credentials → System → Global → Add**): Kind **Username with password**, username = GitHub user, password = PAT, **ID `github-pat`** (keep this exact ID). Purpose: authenticated Git checkouts with the Git plugin.

**3. Prepare the project on your laptop/thin client** (a production-style flow: prepare locally, push to a private repo). In your folder (e.g. `java-maven`, from `project-files/project-4-devsecops-eks/java-maven`):
```bash
git init
git add .
git commit -m "Initial commit with project code"
git branch -M main
```
**First push using a temporary token (one-time only).** Use a descriptive remote name so you know it's the private repo (or use `origin`):
```bash
# add a remote that points to your private repo
git remote add private-repo https://github.com/CloudWithVarJosh/cwvj-private-repo.git

# temporarily set the remote URL with the token so we can push
git remote set-url private-repo https://<TOKEN>@github.com/CloudWithVarJosh/cwvj-private-repo.git

# push the main branch
git push private-repo main
```
**Immediately remove the token from the remote URL**, so it isn't stored in your local Git config or shell history:
```bash
git remote set-url private-repo https://github.com/CloudWithVarJosh/cwvj-private-repo.git
```
(Even better: `gh auth login` or a credential helper, topic 47.)

**4. Verify the repository contents:** `pom.xml`, `src/` (Java code); later you'll add `Dockerfile`, `deploy-svc.yaml` and `Jenkinsfile`.

**5. Create the Jenkins Pipeline job:** **New Item → Pipeline** → name `cwvj-devsecops-demo` → **Pipeline** section:
- Definition: **Pipeline script from SCM** · SCM: **Git**
- Repository URL: `https://github.com/<your-username>/<your-private-repo>.git`
- Credentials: **github-pat** · Branch: `*/main` · Script Path: `Jenkinsfile` (default)
- **Save**.

**6. Run the first build** (**Build Now**). Expected behaviour:
- Jenkins uses the Git plugin and authenticates with **github-pat**.
- It looks for a `Jenkinsfile` on the specified branch.
- If found, it checks out the workspace and continues.
- If missing, the job fails immediately with `ERROR: Unable to find Jenkinsfile`. **Expected for now.**

## Stage 2: Trivy FS scan (filesystem vulnerability scan)

*(Reference: "Trivy FS Scan" box.)*
**Objective:** run a **filesystem-level vulnerability scan** on the source with **Trivy**, catching **dependency CVEs, OS package issues, misconfigurations and secrets** early, before building the image. Trivy is installed on the **agent VM**, not the controller. (Why both Trivy and SonarQube: topic 59.)

**Add stage 2 to the Jenkinsfile** (create `Jenkinsfile` in the project folder; the original text says `jenkins-maven`, the folder is `java-maven`):
```groovy
pipeline {
  agent { label 'docker-maven-trivy' }
  stages {
    stage('Trivy FS Scan') {
      steps {
        sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL .'
      }
    }
  }
}
```
**Explanation:**
- `pipeline {}`: the whole pipeline-as-code block.
- `agent { label 'docker-maven-trivy' }`: selects the agent that has **Docker, Maven and Trivy** installed.
- `stage('Trivy FS Scan')`: a dedicated security gate for filesystem scanning.
- `sh 'trivy fs ...'`: runs Trivy against the **current workspace directory**.
  > Jobs are created on the Jenkins controller but run in a **workspace on the agent**.
- `--exit-code 1`: the security gate: **fails the whole pipeline** when vulnerabilities at the threshold are found.
- `--severity HIGH,CRITICAL`: only blocks on **high-impact issues**, keeping the pipeline practical and reducing noise.

**Install Trivy on the agent VM** (the agent can't run Trivy unless it's installed):
```bash
ssh -i <your-key>.pem ubuntu@<jenkins-agent-public-ip>

# install wget
sudo apt-get install -y wget

# download a specific Trivy release
wget https://github.com/aquasecurity/trivy/releases/download/v0.67.2/trivy_0.67.2_Linux-64bit.deb

# install the package
sudo dpkg -i trivy_0.67.2_Linux-64bit.deb

# verify the installation
trivy --version
```
Notes: keep Trivy (and its DB) updated for the latest CVE data; the agent label already routes jobs here. Pin the version you tested and verify downloads against the release's published checksums (`trivy_0.67.2_checksums.txt`), because scanners are supply-chain targets themselves. (Alternative: Aqua's official apt repository.)

**Commit and push the Jenkinsfile:**
```bash
git add .
git commit -m "Jenkinsfile with Stage: 2"
git push private-repo main
```
(The original says `git push origin main`; use whichever remote name you created: `private-repo` in Stage 1.)

**Run the pipeline** (**Build Now**). You now see Stage 1 (*Declarative: Checkout SCM*) and Stage 2 (Trivy FS Scan); both should pass.

**Example Trivy FS report (clean run):**
```
Report Summary
┌─────────┬──────┬─────────────────┬─────────┐
│ Target  │ Type │ Vulnerabilities │ Secrets │
├─────────┼──────┼─────────────────┼─────────┤
│ pom.xml │ pom  │        0        │    -    │
└─────────┴──────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)
```
> Trivy reports **no findings** because it scans dependencies, OS packages and known secret patterns, not source-code logic or bad practices. The issues in the Java file are **SAST/style/logic** problems (hard-coded string, wrong string comparison, resource leak) that **SonarQube** flags, not Trivy. Use both: **SonarQube for code issues**, **Trivy for CVEs and secret patterns**.

**Simulate a problem** (to see Trivy fail):
- **Add a vulnerable dependency** under `<dependencies>` in `pom.xml` (it's already there, commented out, in the project file):
  ```xml
  <dependency>
    <groupId>org.apache.logging.log4j</groupId>
    <artifactId>log4j-core</artifactId>
    <version>2.14.0</version>
  </dependency>
  ```
- **Add a known-secret pattern:** create `secrets.txt` with
  ```
  AWS_SECRET_ACCESS_KEY=AKIAAAAAAAAAAAAAAAAA
  ```
  > ⚠️ **Corrected (detail):** `AKIA…` is the format of an AWS **access key ID**, not a secret access key (which is 40 random base64 characters). Trivy's AWS rule flags the `AKIA…` pattern, so the demo works, but label it `AWS_ACCESS_KEY_ID=` to be accurate.
- Commit and push, run the pipeline, and watch Trivy fail and show the findings (`CVE-2021-44228 … CRITICAL`, and an `AWS Access Key ID` secret). Then remove the dependency and `secrets.txt`, commit and push again.

## Stage 3: Build and Sonar (Maven build, SAST scan, coverage enforcement)

*(Reference: "Build and Sonar" box.)*
**Objective:** compile with **Maven**, run **unit tests**, collect **coverage**, and run **SAST** with **SonarQube**, enforcing **Quality Gates** so the pipeline fails if the project doesn't meet coverage or security standards. **JUnit**, **Surefire** and **JaCoCo** produce the reports SonarQube consumes. Jenkins talks to SonarQube over the **private IP**, as is common in production.

**1. SSH into the SonarQube server** (or just use its UI) to configure the project, token and quality gate:
```bash
ssh -i <your-key>.pem ubuntu@<sonarqube-public-ip>
```

**2. Create a SonarQube project:** UI → **Projects → Create Project** (local project) → display name `cwvj-devsecops-demo`, project key `cwvj-devsecops-demo` (the unique ID used in the Maven command).

**3. Create a custom Quality Gate:** **Quality Gates → Create** → name `cwvj-devsecops-demo-qg` → **Add Condition** → Coverage, on **Overall Code**:

> ⚠️ **Corrected:** was operator **"is greater than"**, value **80**. Now **"is less than" 80**, because SonarQube quality-gate conditions describe when the gate **fails**. "Coverage is greater than 80" would fail a well-tested project and pass an untested one, the opposite of the intent. The UI shows it as *Coverage is less than 80.0%*.

Assign your project to this gate (gate page → **Projects** tab, or project → **Project Settings → Quality Gate**).
Purpose: fail the pipeline if overall coverage drops below 80%. That makes the build failure predictable for the demo.

**4. Generate a SonarQube token for Jenkins:** **Administration → Security → Users → Create User**:
- Machine account `jenkins-sonar` (or `sonar-user`) with minimal permissions (*Browse* + *Execute Analysis* on the project; avoid admin).
- **Tokens → Generate** a token named `jenkins-token`. **Why:** so the **Jenkins agent can authenticate to SonarQube** and upload analysis results. **Copy it immediately**; you'll see it only once.

**5. Add the token to Jenkins credentials:** Kind **Secret text**, Secret = the token, **ID `sonarqube-token`**. Then in **Pipeline Syntax → withCredentials → Secret text**, variable `SONAR_TOKEN`, credentials `sonarqube-token` → generates:
```groovy
withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
    // some block
}
```
You'll wrap the Maven Sonar command in this block, so the token is passed securely and **masked** in console output (topic 24).

> ⚠️ **Corrected:** the original pipelines in Stages 3–5 use `credentialsId: 'sonarqube-token-new'` while the credential created here (and the final Jenkinsfile) is `sonarqube-token`. Use **`sonarqube-token`** everywhere; a mismatch fails with `Could not find credentials entry with ID 'sonarqube-token-new'`.

**6. Add the Maven tool in Jenkins:** **Manage Jenkins → Tools → Maven installations** → Name `maven3`, ✅ **Install automatically**, pick a version.

> ⚠️ **Corrected (name):** the original says "Manage Jenkins → Global Tool Configuration". That page was renamed **Manage Jenkins → Tools** (current LTS).

You **can** install Maven on the agent manually, but Jenkins' automatic installation is convenient for demos and online agents. If your environment is **offline** or restricted, **preinstall Maven on the agent** and point the tool configuration at that local path (untick install automatically, set `MAVEN_HOME`).

**Pipeline with Stage 3:**
```groovy
pipeline {
  agent { label 'docker-maven-trivy' }
  tools {
    maven 'maven3'
  }
  environment {
    SONAR_IP = '172.31.21.44'
  }
  stages {
    stage('Trivy FS Scan') {
      steps {
        sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL .'
      }
    }
    stage('Build & Sonar') {
      steps {
        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
          sh 'mvn clean verify sonar:sonar \
  -Dsonar.projectKey=cwvj-devsecops-demo \
  -Dsonar.host.url="http://${SONAR_IP}:9000" \
  -Dsonar.qualitygate.wait=true'
        }
      }
    }
  }
}
```
**Explanation (stage 3 blocks):**
- `tools { maven 'maven3' }`: Jenkins provisions the configured Maven version and puts `mvn` on the `PATH` for this build (topic 19).
- `environment { SONAR_IP = '172.31.21.44' }`: the SonarQube server's **private IP**; could live inside the stage, but kept global so all variables are in one place (production: use a **DNS name**, topic 34).
- `withCredentials`: injects the token as `SONAR_TOKEN`, masked; it never appears in logs or pipeline history.
- The `sh '…'` string is **single-quoted**, so `${SONAR_IP}` and `${SONAR_TOKEN}` are expanded by the **shell**, not Groovy: the safe way (topic 30). The backslash-newline continuations end up inside one long shell line.
- `mvn clean verify sonar:sonar`: `clean` removes old artifacts; `verify` compiles, tests (Surefire) and produces JaCoCo coverage; `sonar:sonar` runs the SAST analysis, uploads coverage, and triggers the quality-gate evaluation (topic 59).
- `-Dsonar.projectKey`: our project. `-Dsonar.host.url`: the server URL. The CI auth token reaches the scanner as the **`SONAR_TOKEN` environment variable** set by `withCredentials`, which the Sonar Maven plugin reads automatically. ⚠️ *Corrected:* the course passed `-Dsonar.token="${SONAR_TOKEN}"`, which puts the token in the process arguments, readable by anyone on the agent with `ps` (topic 24). (`sonar.token` replaced the deprecated `sonar.login`.) In a real setup also use **HTTPS** for SonarQube, not `http://IP:9000`, and prefer `withSonarQubeEnv` + `waitForQualityGate`. `-Dsonar.qualitygate.wait=true`: the pipeline **waits** for SonarQube to evaluate the gate, and the build **fails** if coverage or SAST rules violate it.

Sample output (gate failing, as designed):
```
[INFO] ANALYSIS SUCCESSFUL, you can find the results at: http://172.31.21.44:9000/dashboard?id=cwvj-devsecops-demo
[INFO] ------------- Check Quality Gate status
[INFO] Waiting for the analysis report to be processed (max 300s)
[ERROR] QUALITY GATE STATUS: FAILED - View details on http://172.31.21.44:9000/dashboard?id=cwvj-devsecops-demo
[ERROR] Failed to execute goal org.sonarsource.scanner.maven:sonar-maven-plugin:…:sonar … QUALITY GATE STATUS: FAILED
Finished: FAILURE
```

**Run the pipeline.** It **fails at stage 3** because the gate requires **80% coverage** and the demo project doesn't have enough unit tests. In production, this is where **developers improve test coverage** or code quality.

**For demo purposes only:** to continue, lower the threshold: change the condition's value from `80` to `1`. **Never do this in production.** Quality gates exist to protect system integrity.

(Alternative, Jenkins-native style with the *SonarQube Scanner* plugin: configure the server under **Manage Jenkins → System → SonarQube servers**, then `withSonarQubeEnv('sonar') { sh 'mvn verify sonar:sonar' }` and a later `timeout(5) { waitForQualityGate abortPipeline: true }`, which uses a SonarQube webhook back to Jenkins instead of the scanner polling.)

## Stage 4: ECR login (authenticate the agent to Amazon ECR)

*(Reference: "ECR Login" box.)*
**Objective:** authenticate the agent to your **private ECR registry** so the pipeline can push images: install the **AWS CLI**, give the agent the right **IAM permissions**, create the repository, and log in securely with `aws ecr get-login-password`.

**Prerequisite: install the AWS CLI & Docker Engine on the agent.** SSH into the agent VM.

*1) AWS CLI v2 (system-wide):*
```bash
# download aws cli v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip

# install unzip
sudo apt install unzip

# unzip the installer
unzip awscliv2.zip

# install system-wide so all users (including jenkins) can use it
sudo ./aws/install
```
Verify:
```bash
aws --version
sudo -u jenkins aws --version
```

*2) Docker Engine on the agent (official steps):* reference https://docs.docker.com/engine/install/ubuntu/. The commands are identical to topic 49, step 8 (remove old packages; install `ca-certificates curl gnupg`; create `/etc/apt/keyrings`; add Docker's GPG key and apt repo; install `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`). Then:
```bash
# add the 'jenkins' user to the docker group so builds can run docker without sudo
sudo usermod -aG docker jenkins

# optional: also add the ubuntu user if admins will demo from it
sudo usermod -aG docker ubuntu

# verify the Docker CLI works as the current user
docker --version

# verify as the jenkins user (non-root check)
sudo -u jenkins docker --version
```
**Notes:**
- After `usermod -aG docker jenkins`, the jenkins session must re-login, i.e. **disconnect and relaunch the agent** in Jenkins (node → Disconnect → Launch agent), for the group to apply.
- For production, secure the Docker remote API; don't expose `/var/run/docker.sock` to untrusted containers (topic 25).

**Prerequisite: grant the agent access to ECR.** Because the agent runs on **EC2**, use an **IAM role**, not long-lived access keys (topic 61).
- **Create the IAM role:** AWS Console → **IAM → Roles → Create role** → *AWS service* → use case **EC2** → attach **AmazonEC2ContainerRegistryPowerUser** → name `jenkins-agent-role`.
- **Attach it to the agent instance:** **EC2 → Instances → jenkins-agent → Actions → Security → Modify IAM role** → `jenkins-agent-role` → Save.

This lets the agent authenticate to ECR, pull/push images and do registry actions. (PowerUser is broader than needed; in production, a custom policy limited to this repository's ARN for `ecr:GetAuthorizationToken`, `BatchCheckLayerAvailability`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`, `PutImage`, `BatchGetImage`.)

**Create the ECR repository:** **Amazon ECR → Private registry → Create repository**:
- Name `cwvj-devsecops-demo`
- Image tag mutability → **Immutable**. Benefits: prevents accidental overwrites, improves auditability, keeps deployment history clean (topic 07).
- Immutable tag exclusions → `latest`, so the `latest` tag can be pushed repeatedly during demos.
- Other settings default → **Create**.

The repository's **View push commands** shows the login snippet:
```bash
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <YOUR_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com
```

**Pipeline with ECR login (Stage 4):**
```groovy
pipeline {
  agent { label 'docker-maven-trivy' }
  tools {
    maven 'maven3'
  }
  environment {
    SONAR_IP = '172.31.21.44'
    ECR_REGISTRY = '<YOUR_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com'
  }
  stages {
    stage('Trivy FS Scan') {
      steps {
        sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL .'
      }
    }
    stage('Build & Sonar') {
      steps {
        withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
          sh 'mvn clean verify sonar:sonar \
  -Dsonar.projectKey=cwvj-devsecops-demo \
  -Dsonar.host.url="http://${SONAR_IP}:9000" \
  -Dsonar.qualitygate.wait=true'
        }
      }
    }
    stage('ECR Login') {
      steps {
        sh 'aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $ECR_REGISTRY'
      }
    }
  }
}
```
**Explanation:**
- `environment { ECR_REGISTRY = '…' }`: the private ECR hostname, so long URLs aren't repeated.
- `aws ecr get-login-password --region ap-south-1`: fetches a **short-lived authentication token** (valid 12 h).
- `| docker login --username AWS --password-stdin $ECR_REGISTRY`: pipes the token into Docker for a secure, non-interactive login (the username is always the literal `AWS`).
- Combined, the agent authenticates without exposing credentials and **without any AWS access keys**, because the EC2 instance uses the IAM role `jenkins-agent-role`.

**Run the pipeline.** With the AWS CLI installed, the role attached and the repo existing, **ECR Login** succeeds (`Login Succeeded`). If it fails, check that:
- the IAM role is attached,
- its policy includes `AmazonEC2ContainerRegistryPowerUser` (or equivalent),
- the AWS CLI works for both root and the jenkins user,
- `ECR_REGISTRY` matches your repository's registry (account + region).

## Stage 5: Build image

*(Reference: "Build Image" box.)*
**Objective:** with Docker on the agent and the `jenkins` user allowed to run it, build an image that later stages scan and push. An `IMAGE_REPO` variable keeps image naming consistent across stages.

**Create `Dockerfile`** in the `java-maven` project root:
```dockerfile
FROM eclipse-temurin:21
WORKDIR /app
COPY target/cwvj-devsecops-demo-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```
- `FROM eclipse-temurin:21`: the Eclipse Temurin Java 21 image as a maintained base (the full JDK image; `eclipse-temurin:21-jre` would be smaller and has fewer CVEs for the image scan).
- `WORKDIR /app`: the working directory inside the image.
- `COPY target/…-1.0.0-SNAPSHOT.jar app.jar`: copies the jar built by Maven in Stage 3 (the shaded fat jar from `target/`).
- `EXPOSE 8080`: documents that the container listens on 8080.
- `ENTRYPOINT ["java", "-jar", "app.jar"]`: runs the jar when the container starts.

Commit and push from the `java-maven` folder:
```bash
git add .
git commit -m "added Dockerfile"
git push private-repo main
```

**Build Image stage** (with `IMAGE_REPO` added to `environment`):
```groovy
  environment {
    SONAR_IP = '172.31.21.44'
    ECR_REGISTRY = '<YOUR_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com'
    IMAGE_REPO = "${ECR_REGISTRY}/cwvj-devsecops-demo"
  }
  ...
    stage('Build Image') {
      steps {
        sh 'export DOCKER_BUILDKIT=0 && docker build --platform linux/amd64 -t "$IMAGE_REPO:$BUILD_NUMBER" -t "$IMAGE_REPO:latest" .'
      }
    }
```
**Explanation:**
- `IMAGE_REPO = "${ECR_REGISTRY}/cwvj-devsecops-demo"`: the image repository used for tagging and pushing in every stage (double quotes: Groovy builds it from `ECR_REGISTRY`).
- `stage('Build Image')`: builds the image from the workspace (where Stage 3 left `target/*.jar`).
- `export DOCKER_BUILDKIT=0`: disables BuildKit so the build runs in the **classic** builder (the original reason: predictable output on agents with older or mixed Docker versions).

  > ⚠️ **Corrected:** was `export DOCKER_BUILDKIT=0 && docker build …`. Now plain `docker build …` (BuildKit), because the **legacy builder is deprecated**: BuildKit has been the default since Docker Engine 23, the legacy builder prints a deprecation warning, and it's slated for removal. Your agent installs current Docker CE plus `docker-buildx-plugin`, so BuildKit is available and gives the same image, faster, with better caching. `--platform` is a BuildKit feature too.

- `--platform linux/amd64`: builds for the **amd64** architecture. This matches the **EKS worker nodes** (x86_64; Docker treats x86_64 and amd64 as the same) and avoids accidental arm64 builds that wouldn't run on the cluster (e.g. when someone builds on an Apple-silicon Mac or a Graviton agent). It also matches the **base image** variant pulled for `eclipse-temurin:21`. **In short:** the architecture of both the **EKS nodes** and the **image** must line up, and `--platform linux/amd64` guarantees it.
- `-t "$IMAGE_REPO:$BUILD_NUMBER"`: tags with the Jenkins build number: immutable, traceable deployments.
- `-t "$IMAGE_REPO:latest"`: also tags `latest` for demo convenience (excluded from immutability in the repo settings).
- `.`: the repo root as the **build context**. Add a `.dockerignore` (e.g. `.git`, `*.md`, `src/test`) to keep the context small.

**Run the stage.** With Docker installed and jenkins in the `docker` group, the image builds and is tagged. If it fails, check:
- the Docker service is active (`sudo systemctl status docker`),
- `jenkins` is in the `docker` group **and** the agent was reconnected,
- the build context is small and has a `.dockerignore`,
- the jar exists (`ls target/*.jar`; Stage 3 must have run).

## Stage 6: Trivy image scan

*(Reference: "Trivy Image Scan" box.)*
**Objective:** scan the **built image** for vulnerabilities **before** pushing or deploying it, so the actual runtime artifact (what runs in your Kubernetes pods) has no high or critical CVEs. Image scanning is a mandatory gate in any production DevSecOps pipeline. (Why, and how it differs from the FS scan and Sonar: topic 59.)
```groovy
stage('Trivy Image Scan') {
  steps {
    sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMAGE_REPO:$BUILD_NUMBER"'
  }
}
```
**Explanation:**
- `stage('Trivy Image Scan')`: a dedicated security gate before deployment.
- `trivy image … "$IMAGE_REPO:$BUILD_NUMBER"`: scans the **exact image** just built; the immutable build-number tag avoids scanning the wrong version. (Trivy reads it from the local Docker daemon.)
- `--exit-code 1`: **fails** the pipeline on High/Critical vulnerabilities.
- `--severity HIGH,CRITICAL`: focuses on severe issues that must be fixed before any deployment.

**Outcome:** this stage validates that the image is production-safe. If vulnerabilities are found: the pipeline fails, you do **not** push the image, and you do **not** deploy it to EKS. A strong security boundary: only secure artifacts move forward. (Practical tip: base images often carry unfixable OS CVEs; `--ignore-unfixed` and a slimmer base like `eclipse-temurin:21-jre` keep the gate meaningful.)

## Stage 7: Push to ECR

*(Reference: "Push to ECR" box.)*
**Objective:** push the built, scanned and tagged image to ECR so it's available for deployment: both the immutable build tag (`$BUILD_NUMBER`) and the convenience `latest` tag.
```groovy
stage('Push to ECR') {
  steps {
    sh 'docker push "$IMAGE_REPO:$BUILD_NUMBER"'
    sh 'docker push "$IMAGE_REPO:latest"'
  }
}
```
**Why this stage matters:**
- It pushes the exact artifact that was scanned and validated in earlier stages.
- The `$BUILD_NUMBER` tag is an immutable, traceable image for rollbacks.
- `latest` is useful for iterative testing and demos (excluded from immutability).

**Explanation:**
- `docker push "$IMAGE_REPO:$BUILD_NUMBER"`: pushes the build-specific image, the **canonical** image to promote to environments.
- `docker push "$IMAGE_REPO:latest"`: pushes `latest` for convenience.
- **Preconditions:** ECR Login succeeded (in the same pipeline run, within 12 h); `IMAGE_REPO` is `<account>.dkr.ecr.<region>.amazonaws.com/<repo>`; the role has push permissions; Docker is running and the tagged image exists locally.

**Verify:**
1. AWS Console → **Amazon ECR** → repository `cwvj-devsecops-demo`.
2. **Images**: two tags: `<BUILD_NUMBER>` (e.g. `42`) and `latest`.
3. Note the image **digest** and push time for traceability (topic 07). The push log prints it too: `42: digest: sha256:… size: …`.

If a tag is missing, check the pipeline log for errors, and that the image was built and tagged locally before the push.

---

## Hands-on lab

Build the pipeline stage by stage exactly as above, committing after each stage and running it. Keep a note of each failure you hit and its fix; that list is your best interview material. (No AWS? Do stages 1–3 and 5–6 locally: Docker Jenkins + a Docker agent with Maven/Trivy + SonarQube Compose, and push to a local `registry:2` instead of ECR.)

---

## Where you'll use it

The template for secure CI on AWS; the same structure works with GHCR/Harbor and other clusters.

---

## When it breaks

| Error | Stage | Fix |
|---|---|---|
| `ERROR: Unable to find Jenkinsfile` | 1 | Commit a `Jenkinsfile` on `main` |
| `trivy: command not found` | 2 | Install Trivy on the agent (not the controller) |
| `Could not find credentials entry with ID 'sonarqube-token-new'` | 3 | Use `sonarqube-token` |
| `QUALITY GATE STATUS: FAILED` | 3 | Raise coverage (or, demo only, lower the gate) |
| `Not authorized. Please check the property sonar.token` | 3 | Regenerate the token; machine user needs Execute Analysis |
| `Unable to locate credentials` (aws) | 4 | Attach the IAM role to the agent |
| `permission denied … docker.sock` | 4/5 | Add jenkins to the docker group and reconnect the agent |
| `COPY failed: … target/…jar: no such file` | 5 | Stage 3 must run `package`/`verify` in the same workspace |
| `tag invalid: The image tag '42' already exists … immutable` | 7 | Expected protection; re-run creates a new build number |

---

## Quick recap

- Stage 1: private repo, PAT credential, Pipeline-from-SCM job.
- Stage 2: `trivy fs --exit-code 1 --severity HIGH,CRITICAL .` as an SCA gate.
- Stage 3: `mvn clean verify sonar:sonar … -Dsonar.qualitygate.wait=true` with a token from `withCredentials`; the gate condition is "coverage **less than** 80".
- Stage 4: IAM role on the agent + `aws ecr get-login-password | docker login`.
- Stages 5–7: BuildKit `docker build --platform linux/amd64`, `trivy image` gate, push the build tag (+ `latest`) to an immutable ECR repo.

**Interview questions**

1. **Q: In what order do you put security scans in a pipeline, and why?**
   A: Cheap and early first: dependency/secret scan of the source, then SAST + tests + quality gate during the build, then the image scan after building and before pushing. Each gate stops bad artifacts as early as possible.

2. **Q: How does the pipeline fail on a SonarQube quality gate?**
   A: The scanner runs with `sonar.qualitygate.wait=true`; it waits for the server's verdict and exits non-zero if the gate fails, failing the `sh` step.

3. **Q: Why use an immutable ECR repository?**
   A: A tag can't be overwritten, so `:42` always means the image that was scanned and tested, which is what makes audits and rollbacks reliable.
