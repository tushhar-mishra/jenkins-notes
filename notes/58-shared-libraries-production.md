# 58 · Shared Libraries in Production

> **Level:** ★★★ advanced · **Status:** ➕ expanded from "Why centralising config matters"
>
> **You will learn:** how real platform teams write libraries: steps with **Map parameters and defaults**, centralised config, `src/` classes, `libraryResource` templates, whole-pipeline templates, **semantic versioning with tags**, trusted vs untrusted (folder) libraries, and **testing** libraries before they break 200 pipelines.
>
> **You need:** topics 55–57.
>
> **From your original notes:** shared-library › *Why centralising config matters*, *Conclusion*.

---

## What it is

The Demo 2 library is deliberately simple: `repo`, `tag` and `port` live in each Jenkinsfile so nothing feels overwhelming. That helps beginners, but hides how powerful a library can be. Production libraries:
- take **parameters** with sensible **defaults** (no hidden dependence on env var names),
- **own shared config** (registry, scanner URLs, credential IDs) so one edit changes the fleet,
- are **versioned** and **tested** like any other software.

---

## Why it exists

From your notes: if you move values like the registry, tagging strategy or port mappings into the library, **a single edit** changes how **every pipeline** behaves: no searching through Jenkinsfiles, no forgotten service. This really shines when many apps rely on common tools: **SAST scanners (SonarQube, Semgrep)**, **DAST tools (OWASP ZAP, Burp Suite)**, **image scanners (Trivy, Grype)**, **code-quality platforms (SonarQube, CodeClimate)**. They're shared across many microservices, not one-to-one. When an endpoint changes, a new policy is introduced, or a credential rotates, you update **one place** and **every pipeline stays consistent**: less maintenance, more reliability, no subtle drift between teams.

---

## Analogy

Moving from a shared **recipe card** to a **central kitchen** that also controls the suppliers, the oven settings and the hygiene rules, and publishes versioned recipe books so a restaurant can stay on edition 3 until it's ready for edition 4.

---

## How it works inside

- **Trusted libraries** (Global Pipeline Libraries, configured by admins) run **outside the sandbox**: full API access. Protect their repo with branch protection, reviews and CODEOWNERS; anyone who can merge there can run code as Jenkins.
- **Folder libraries** (Folder → Configure → Pipeline Libraries) are **untrusted**: sandboxed like Jenkinsfiles. Good for team-owned helpers.
- **Versions:** pipelines choose `@Library('lib@v2.3.1')`. The default version should be a stable **tag** or a protected release branch, not a busy `main`.
- **Caching:** with "Cache fetched versions on controller" on, tagged versions are fetched once; branches refresh after the configured interval.

---

## Config / Jenkinsfile / commands

### A parameterised step with defaults

`vars/buildImage.groovy`:
```groovy
def call(Map cfg = [:]) {
  def registry  = cfg.registry  ?: 'registry.example.com/acme'        // central default
  def name      = cfg.name      ?: error('buildImage: "name" is required')
  def tag       = cfg.tag       ?: env.GIT_COMMIT?.take(7) ?: env.BUILD_NUMBER
  def context   = cfg.context   ?: '.'
  def image     = "${registry}/${name}:${tag}"

  withEnv(["IMAGE=${image}", "CTX=${context}"]) {
    sh 'docker build --label "org.opencontainers.image.revision=$GIT_COMMIT" -t "$IMAGE" "$CTX"'
  }
  return image                                                        // caller gets the full name
}
```
Jenkinsfile:
```groovy
@Library('platform-lib@v2.3.1') _
pipeline {
  agent { label 'docker' }
  stages {
    stage('Build') {
      steps { script { env.IMAGE = buildImage(name: 'loans', context: 'service/') } }
    }
    stage('Scan & push') { steps { scanImage(image: env.IMAGE); pushImage(image: env.IMAGE) } }
  }
}
```
- `Map cfg = [:]` = named arguments with an empty default; `?:` gives defaults.
- `error(...)` fails fast with a clear message when a required argument is missing.
- Values reach the shell via `withEnv` + single-quoted `sh`: no Groovy interpolation into the command (topic 24).

### Central config with `resources/` and `libraryResource`

`resources/org/acme/config.yaml`:
```yaml
registry: registry.example.com/acme
sonarUrl: https://sonar.internal.example.com
dockerCredentialsId: registry-push
```
`vars/platformConfig.groovy`:
```groovy
def call() { readYaml(text: libraryResource('org/acme/config.yaml')) }   // readYaml = Pipeline Utility Steps plugin
```
Use: `def cfg = platformConfig(); echo cfg.sonarUrl`. Rotate a credential ID or move SonarQube: edit one YAML, tag a release.

### A class in `src/`

`src/org/acme/Semver.groovy`:
```groovy
package org.acme
class Semver implements Serializable {        // Serializable: survives CPS state saves (topic 32)
  static String bumpPatch(String v) {
    def (maj, min, pat) = v.tokenize('.')*.toInteger()
    return "${maj}.${min}.${pat + 1}"
  }
}
```
Use in a step or Jenkinsfile: `import org.acme.Semver` then `Semver.bumpPatch('1.4.2')`. Classes that call steps need the pipeline script passed in (`new Deployer(this).run()`, then `script.sh(...)` inside).

### Whole-pipeline templates

`vars/standardPythonPipeline.groovy`:
```groovy
def call(Map cfg) {
  pipeline {
    agent { label 'docker' }
    options { timeout(time: 30, unit: 'MINUTES'); timestamps() }
    stages {
      stage('Test')  { steps { sh 'pip install -r requirements.txt && pytest -q --junitxml=r.xml' } }
      stage('Image') { steps { script { env.IMAGE = buildImage(name: cfg.name) } } }
      stage('Deploy dev') { when { branch 'main' } steps { deployApp(image: env.IMAGE, env: 'dev') } }
    }
    post { always { junit allowEmptyResults: true, testResults: 'r.xml' } }
  }
}
```
An app's whole Jenkinsfile becomes:
```groovy
@Library('platform-lib@v2') _
standardPythonPipeline(name: 'loans')
```
Great for consistency; give teams escape hatches (parameters/hooks) or they'll fork it.

### Versioning and release process

- Use **semantic versioning** tags: `v2.3.1` (patch = fixes, minor = new optional features, major = breaking changes).
- Keep a moving **major tag/branch** (`v2`) for teams who want fixes automatically; pin exact tags for critical pipelines.
- Changelog per release; announce breaking changes; deprecate before removing.

### Testing libraries

- **Unit tests** with **JenkinsPipelineUnit** (a JUnit framework that mocks pipeline steps): run `vars/*.groovy` with fake `sh`/`echo` and assert which commands were called. Run them in the library's own CI.
- **Integration test:** a test Jenkins (e.g. JCasC in Docker, topic 67) running sample Jenkinsfiles against the library's PR branch, `@Library('platform-lib@pr-branch')`.
- **Replay** (topic 32) lets you edit library files for one run while debugging.

---

## Hands-on lab

1. Convert your Demo 2 `buildImage`/`deployApp` to Map-parameter steps with defaults, and update app1/app2 (`buildImage(name: 'app1-flask')`, `deployApp(name: 'app1-flask', port: 5000)`).
2. Tag the library `v1.0.0`, pin app1 to it, then change the default restart policy on `main` and confirm only app2 (on `@main`) changes.
3. Add `resources/config.yaml` with a `maintainer` value and read it with `libraryResource` + `readYaml` (install *Pipeline Utility Steps*).

---

## Where you'll use it

Platform/DevOps teams supporting many services: the library *is* the product.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| A library merge breaks every pipeline | Everyone on `@main`, no tests | Tags + tests + staged rollout (pin, then bump) |
| `NotSerializableException` from a `src` class | Class not `Serializable` | `implements Serializable` |
| `No signature of method … sh()` inside a class | Classes can't call steps directly | Pass the script (`this`) and call `script.sh` |
| `Scripts not permitted…` in a folder library | Untrusted libraries are sandboxed | Use approved APIs, or move it to a trusted global library |
| Teams copy and fork the template | Template too rigid | Parameters, hooks, clear docs |

---

## Quick recap

- Steps take `Map` parameters with defaults and fail fast on missing ones.
- Central config in `resources/` (via `libraryResource`) makes fleet-wide changes one edit.
- `src/` classes must be `Serializable`; pass `this` to call steps.
- Version with semver tags; test with JenkinsPipelineUnit and a test controller; protect the repo (trusted code).

**Interview questions**

1. **Q: How do you roll out a breaking library change safely?**
   A: Release it as a new major version tag, keep the old major available, migrate pipelines gradually (pinning), test with JenkinsPipelineUnit and a staging controller, then deprecate the old version.

2. **Q: Trusted vs untrusted shared libraries?**
   A: Global libraries configured by admins are trusted and run outside the sandbox; folder-level libraries are untrusted and sandboxed. Trusted library repos need strict review because their code runs with Jenkins' full permissions.

3. **Q: Why centralise config like registry URLs and credential IDs in the library?**
   A: One change (new endpoint, rotated credential, new policy) applies to every pipeline consistently, without editing dozens of Jenkinsfiles or risking drift.

---

*Shared-library conclusion, kept:* a shared library becomes the **single source of truth** for your organisation's CI/CD logic. Instead of fixing twenty Jenkinsfiles, you **update one place**, and every service benefits. This improves consistency, reduces maintenance and removes subtle differences between teams. The demo made it real: a label or a restart policy needed **one change** in the library, and both app1 and app2 were updated. The advantage multiplies in real environments where microservices depend on **shared tools like SonarQube, Trivy, Semgrep, OWASP ZAP, Maven, and Slack or email notifications**. In short: **write once, reuse everywhere**, and keep pipelines clean, predictable and future-ready.

---

## References (from your original shared-library notes)

* **Jenkins Pipeline Shared Libraries Documentation:** [https://www.jenkins.io/doc/book/pipeline/shared-libraries/](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)
* **Jenkins Pipeline Syntax Reference:** [https://www.jenkins.io/doc/book/pipeline/syntax/](https://www.jenkins.io/doc/book/pipeline/syntax/)
* **`libraryResource` Function Reference (Jenkins):** [https://www.jenkins.io/doc/pipeline/steps/workflow-cps-global-lib/#libraryresource-unstable](https://www.jenkins.io/doc/pipeline/steps/workflow-cps-global-lib/#libraryresource-unstable)
* **Install Jenkins on Linux (Official Guide):** [https://www.jenkins.io/doc/book/installing/linux/](https://www.jenkins.io/doc/book/installing/linux/)
* **Groovy Language Reference:** [https://groovy-lang.org/syntax.html](https://groovy-lang.org/syntax.html)
* **Dockerfile Reference (Labels, Build Options):** [https://docs.docker.com/reference/dockerfile/](https://docs.docker.com/reference/dockerfile/)
* **Docker Container Restart Policies (Official Docker Docs):** [https://docs.docker.com/config/containers/start-containers-automatically/](https://docs.docker.com/config/containers/start-containers-automatically/)
