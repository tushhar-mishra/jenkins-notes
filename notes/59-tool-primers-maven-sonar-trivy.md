# 59 · Tool Primers: Maven, SonarQube, Trivy

> **Level:** ★★ intermediate · **Status:** 🔀➕ merged and expanded
>
> **You will learn:** enough about the three tools in the DevSecOps project to understand every flag: **Maven** (lifecycle, Surefire, JaCoCo coverage, the Sonar goal), **SonarQube** (projects, tokens, quality profiles, **quality gates**, how analysis reaches the server), and **Trivy** (`fs` vs `image` scans, severities, exit codes, the vulnerability database), plus why you need both SonarQube *and* Trivy.
>
> **You need:** topics 06 (SAST/SCA), 19 (Maven basics).
>
> **From your original notes:** Project 01 › *Introduction*, *Pre-requisites for this lecture* (1–4 with "why this helps"), *Stage 2 → Why run Trivy FS scan when we already run SonarQube SAST?*, *Stage 6 → Why Trivy Image Scan is Important*, *How Trivy Image Scan differs from previous scans* (1–3, in short), *Stage 3 → mvn clean verify sonar:sonar breakdown*, the Java demo app with intentional issues.
>
> 🎥 Original prerequisite videos: [Modern SDLC](https://youtu.be/imEHsgvJbYo) · [CI/CD & Branching](https://www.youtube.com/watch?v=szPE1NKc614&ab_channel=CloudWithVarJosh) · [Maven for DevOps](https://www.youtube.com/watch?v=3OKc5y_3wMM&ab_channel=CloudWithVarJosh) ([notes](https://github.com/CloudWithVarJosh/YouTube-Standalone-Lectures/tree/main/Lectures/08-maven)) · [SonarQube for DevOps](https://www.youtube.com/watch?v=qyYsLVZDieU) ([notes](https://github.com/CloudWithVarJosh/SonarQube-For-DevOps/blob/main/README.md))

---

## What it is

Part 10 builds an end-to-end **production-grade DevSecOps pipeline** that integrates secure coding, vulnerability scanning, container image hardening, artifact management and automated Kubernetes deployment, the way real companies implement **secure CI/CD**:
- **Jenkins** (orchestration)
- **SonarQube** (SAST + coverage)
- **Trivy** (SCA + image scanning)
- **AWS ECR** (private image registry)
- **Amazon EKS** (managed Kubernetes)
- **Kubernetes YAML manifests**
- **IAM + RBAC** for least-privilege deployments

By the end you'll understand how each stage hardens delivery, from scanning code on commit to deploying a validated image on a topology-aware Kubernetes cluster. **DevSecOps** = DevOps with security built into every stage instead of bolted on at the end.

This flow reflects **actual production implementations** used in modern enterprises.

**Prerequisites (from your notes).** To follow the DevSecOps and SonarQube flow end to end, these sessions help a lot. The lecture ends with a pipeline that uses both Maven and SonarQube, so understanding those foundations makes the final pipeline much easier to follow. In this course they're covered by earlier topics:
1. **Modern SDLC** (topics 01–04). *Why this helps:* it gives the big picture of how modern SDLC, build pipelines and environment promotion work. You'll understand where DevSecOps controls fit in the lifecycle and why we gate builds and deployments.
2. **CI/CD & branching strategies** (topics 05–09). *Why this helps:* it explains pipeline stages, promotions and branching strategies, so you know at which stage to plug in SAST, SCA and quality gates. That makes the multibranch/PR mechanics and promotion rules in the demo easier to grasp.
3. **Maven for DevOps** (topic 19 + below). *Why this helps:* SonarQube is wired into the **Maven build lifecycle**. Knowing how Maven builds, runs tests and produces coverage reports helps you understand exactly when the Sonar analysis runs.
4. **SonarQube** (below + topic 60). *Why this helps:* familiarity with SonarQube concepts (projects, tokens, quality gates and analysis) makes it easier to configure the CI integration and interpret SAST results during the pipeline.

---

## Why it exists

You can't debug a failing quality gate or scan stage if you don't know what the tool is checking.

---

## Analogy

Airport security has **different scanners for different threats**: the passport check (SonarQube: is *your* document correct and well-formed?), the bag X-ray (Trivy fs: what did you pack, any known-dangerous items?), and the full-body scan just before boarding (Trivy image: is the *final* thing getting on the plane safe?).

---

## How it works inside

### Maven, for this project

The demo app (`project-files/project-4-devsecops-eks/java-maven/`) is a tiny Java 21 HTTP server (`App.java`) with two JUnit tests. It contains **intentional problems** for SonarQube to find: a hard-coded secret (`API_KEY`, a security hotspot), `System.out` instead of a logger (maintainability), a `Scanner` resource leak, and `username == "admin"` (comparing strings by reference: a bug).

`pom.xml` plugins:
- **maven-compiler-plugin**: compiles for Java 21.
- **maven-surefire-plugin**: runs unit tests (JUnit 5) in the `test` phase, writing reports to `target/surefire-reports/*.xml`.
- **jacoco-maven-plugin**: `prepare-agent` attaches the JaCoCo Java agent during tests to record which lines ran; `report` (in `prepare-package`) writes `target/site/jacoco/jacoco.xml`: the **coverage** report.
- **maven-shade-plugin**: in `package`, builds a single runnable "fat" jar `target/cwvj-devsecops-demo-1.0.0-SNAPSHOT.jar`.

`mvn clean verify sonar:sonar` breakdown:
- `clean` → removes old build artifacts (`target/`).
- `verify` → runs compile, test (Surefire), the JaCoCo report, package and verify.
- `sonar:sonar` → runs the **SonarScanner for Maven**: analyses the code, uploads it with the coverage report to SonarQube, and (with `sonar.qualitygate.wait=true`) waits for the quality-gate verdict.

### SonarQube concepts

- **Project:** one analysed codebase, identified by a **project key** (`cwvj-devsecops-demo`).
- **Rules → Quality Profiles:** which rules apply per language (default: "Sonar way").
- **Issues:** **bugs**, **vulnerabilities**, **code smells** (maintainability problems) and **security hotspots** (code that needs a security review, like a hard-coded secret).
- **Measures:** coverage, duplications, ratings, technical debt.
- **Quality Gate:** a set of **failure conditions** (e.g. "Coverage on New Code is less than 80%"). If any condition is met, the gate **fails**, and with `qualitygate.wait=true` the Maven command, and therefore the pipeline stage, fails.
- **Token:** how CI authenticates (`-Dsonar.token=…`). Use a dedicated machine user with minimal permissions.
- **Flow:** the scanner runs **on the Jenkins agent**, sends a report to the server; the server's **Compute Engine** processes it in the background; the scanner polls the result (that's the "waiting for quality gate" in the log).
- **Database:** SonarQube stores everything in PostgreSQL (topic 60).

### Trivy concepts

**Trivy** (by Aqua Security) is an open-source scanner for vulnerabilities, misconfigurations and secrets.
- `trivy fs <dir>`: scans a **folder** (your source checkout): dependency manifests (`pom.xml`, lockfiles), config files, Dockerfiles, and known secret patterns. This is **SCA**.
- `trivy image <image>`: scans a **built image**: OS packages from the base image, language packages inside it, and secrets in layers.
- `--severity HIGH,CRITICAL`: only report (and fail on) these levels.
- `--exit-code 1`: return exit code 1 if anything at those severities is found, which turns the scan into a **gate**.
- `--ignore-unfixed`: skip vulnerabilities with no fixed version yet (common in practice).
- Trivy downloads its **vulnerability database** (from a registry, e.g. `ghcr.io/aquasecurity/trivy-db`) on first run and caches it (`~/.cache/trivy`). Keep it updated; CI agents behind firewalls need a mirror.

### Why run Trivy FS when we already run SonarQube SAST?

- **SonarQube (SAST):** scans **your source code** for insecure patterns, code smells, bad practices, injection risks and security hotspots.
- **Trivy FS (SCA + more):** scans **third-party and runtime-related artifacts**: OS packages, JVM/dependency manifests, vendor libraries, Dockerfiles and config files. It does **SCA** to find CVE-linked library vulnerabilities, plus misconfigurations and known secret patterns that SAST can't find.
- **Outcome:** using both gives **defence in depth**: SAST improves code quality and logic safety; Trivy secures third-party libraries and runtime components.

### Why the Trivy image scan matters

It analyses the **final container image**, including:
- OS packages inside the base image (Ubuntu, Alpine, distroless…)
- language-level dependencies bundled into the image
- system libraries and utilities present only at run time
- vulnerable binaries or layers introduced by the base image

This is critical because **developers rarely control the base image**, yet most vulnerabilities come from it.

### How the three scans differ

1. **Trivy FS scan (SCA on the source folder):** scans the *project source folder*; finds dependency vulnerabilities in `pom.xml`, configs and vendor packages; does **not** inspect the final image.
2. **SonarQube SAST + coverage:** checks your **custom code**; finds insecure patterns, code smells, bugs and quality issues; measures unit-test coverage; does **not** detect OS-level CVEs or container vulnerabilities.
3. **Trivy image scan:** scans the **fully built image** in the local Docker cache; finds vulnerabilities in base-image layers and OS packages; detects issues that **don't exist in the source** and appear only after building; ensures the production runtime artifact is safe to deploy.

**In short:** source-level scans protect your code; image scans protect your container runtime. Both are needed in a secure pipeline.

---

## Config / Jenkinsfile / commands

Try the tools locally with Docker:
```bash
cd project-files/project-4-devsecops-eks/java-maven
docker run --rm -v "$PWD":/src -w /src maven:3.9-eclipse-temurin-21 mvn -B -q clean verify
ls target/site/jacoco/jacoco.xml target/surefire-reports/
docker run --rm -v "$PWD":/src aquasec/trivy:latest fs --severity HIGH,CRITICAL /src
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity HIGH,CRITICAL eclipse-temurin:21
```
The `fs` scan of the clean project reports `pom.xml … 0` vulnerabilities; the `image` scan of the base image lists OS-package CVEs (the count changes daily as the DB updates).

---

## Hands-on lab

1. Run the three commands above.
2. Un-comment the `log4j-core 2.14.0` dependency in `pom.xml` and re-run `trivy fs`: `CVE-2021-44228` (Log4Shell) appears as CRITICAL. Comment it out again.
3. Read `App.java` and predict which lines SonarQube will flag (you'll check in topic 62).

---

## Where you'll use it

Every DevSecOps pipeline; interviews ("SAST vs SCA vs image scanning", "what's a quality gate?").

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Trivy: `FATAL … failed to download vulnerability DB` | No internet / rate limited | Mirror the DB (`--db-repository`), cache `~/.cache/trivy` |
| Sonar: `Project not found` / 403 | Wrong key, or token lacks *Execute Analysis* | Fix the key; token permissions |
| Coverage shows 0% in SonarQube | JaCoCo report missing or not found | Run `verify` (not just `compile`); check `jacoco.xml` exists |
| Scans fail on CVEs you can't fix yet | No triage policy | `--ignore-unfixed`, `.trivyignore` with expiry, update base images |

---

## Quick recap

- Maven `clean verify` = compile, test (Surefire), coverage (JaCoCo), package; `sonar:sonar` uploads to SonarQube.
- SonarQube quality gates = failure conditions on your code (coverage, bugs, vulnerabilities).
- Trivy `fs` = dependencies/config/secrets in the source; `image` = the built image; `--exit-code 1` makes it a gate.
- Use both: SAST for your code, SCA/image scanning for everything you didn't write.

**Interview questions**

1. **Q: Why do you need both SonarQube and Trivy?**
   A: SonarQube analyses your own source code (SAST, quality, coverage). Trivy finds known CVEs in dependencies, base images and configs (SCA/image scanning). They cover different risks.

2. **Q: What does `--exit-code 1` do in Trivy?**
   A: It makes Trivy return 1 when it finds issues at the selected severities, so the pipeline step fails and acts as a security gate.

3. **Q: What's a SonarQube quality gate?**
   A: A set of conditions (e.g. coverage below 80%, any new critical vulnerability) that mark the analysis as failed. CI can wait for the verdict and fail the build.
