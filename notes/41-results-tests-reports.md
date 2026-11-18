# 41 · Build Results, Tests and Reports

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** the five build results (SUCCESS, UNSTABLE, FAILURE, ABORTED, NOT_BUILT) and how each is produced; publishing test results with `junit`; controlling results with `catchError`, `unstable`, `error`, `warnError`; reading `currentBuild`; and publishing coverage.
>
> **You need:** topics 35, 37.
>
> **From your original notes:** Project 01 › *Build & Sonar* (JUnit/Surefire/JaCoCo reports), *Real-world usage: publish JUnit, coverage, and security summaries*.

---

## What it is

| Result | Colour | Means | Typical cause |
|---|---|---|---|
| **SUCCESS** | green | everything passed | n/a |
| **UNSTABLE** | yellow | the build ran, but quality checks failed | `junit` recorded failed tests; `unstable('…')` |
| **FAILURE** | red | a step failed | non-zero `sh` exit; `error('…')` |
| **ABORTED** | grey | stopped before finishing | a user clicked ✖, a `timeout`, superseded by a `milestone` |
| **NOT_BUILT** | grey | a stage/build didn't run | skipped by `when`, or a stage after a failure |

Results only get **worse** during a build (SUCCESS → UNSTABLE → FAILURE); a later "success" can't make a failure green.

---

## Why it exists

"Red" should mean *broken*, "yellow" *runs but has quality problems*. Branch protection, `post` conditions and dashboards all depend on correct results. Test reports turn 10,000 lines of log into "3 failed tests, here they are".

---

## Analogy

A **school report card**: pass (green), pass with poor marks (yellow), fail (red), didn't sit the exam (grey). The detailed marks sheet is the test report.

---

## How it works inside

- `sh` with a non-zero exit code throws an error → the stage fails → FAILURE, and later stages are skipped.
- `junit 'path/*.xml'` parses **JUnit XML** (a standard test-report format produced by Maven Surefire, pytest `--junitxml`, Jest reporters, Go `gotestsum`…). It stores the results on the build, and **if any test failed, it sets the build to UNSTABLE** (not FAILURE), unless the test command itself already failed.
- Trick: test commands fail with a non-zero exit when tests fail. To get **UNSTABLE + a report** rather than FAILURE, let the test command "succeed" (e.g. Maven `-Dmaven.test.failure.ignore=true`) and let `junit` set the result.
- `catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') { … }` lets a block fail **without** failing the build (only the stage turns red).

---

## Config / Jenkinsfile / commands

```groovy
pipeline {
  agent any
  stages {
    stage('Unit tests') {
      steps { sh 'mvn -B test -Dmaven.test.failure.ignore=true' }   // test failures → handled by junit
      post {
        always {
          junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: false
          recordCoverage tools: [[parser: 'JACOCO', pattern: 'target/site/jacoco/jacoco.xml']]   // Coverage plugin
        }
      }
    }
    stage('Optional lint') {
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
          sh 'ruff check .'               // stage goes yellow, build result unchanged
        }
      }
    }
    stage('Guard') {
      steps {
        script {
          if (!fileExists('Dockerfile')) { error('Dockerfile missing: cannot build image') }   // → FAILURE with a clear message
          if (currentBuild.currentResult == 'UNSTABLE') { echo 'Tests failed: not deploying' }
        }
      }
    }
  }
  post {
    unstable { echo 'Some tests failed' }
    always   { echo "Result: ${currentBuild.currentResult}, took ${currentBuild.durationString}" }
  }
}
```

Other result steps:
- `unstable('message')`: set UNSTABLE and continue.
- `warnError('message') { … }`: if the block fails, mark build and stage UNSTABLE and continue.
- `error('message')`: fail now with a message (cleaner than `sh 'exit 1'`).
- `currentBuild.result = 'UNSTABLE'` in `script {}`: older style.

Useful `currentBuild` fields: `number`, `currentResult`, `result`, `durationString`, `previousBuild?.result`, `getBuildCauses()`, `changeSets`.

Console (shape) when 2 tests fail:
```
Tests run: 42, Failures: 2, Errors: 0, Skipped: 1
[Pipeline] junit
Recording test results
[Checks API] No suitable checks publisher found.
None of the test reports contained any result  ← (only if the path is wrong)
...
Finished: UNSTABLE
```
The build page gets a **Test Result** link (failures with stack traces) and the job page a **trend graph**.

---

## Deeper dive

### `currentResult` vs `result`

- `currentBuild.currentResult`: always a string (`SUCCESS` while nothing has gone wrong yet). Use this in `script` logic.
- `currentBuild.result`: `null` until something explicitly sets it. Reading it mid-build often gives `null`, which surprises people.
- Results only get worse: setting `currentBuild.result = 'SUCCESS'` after a failure has no effect.

### Stage result vs build result

Per-step result control lets the **Stages** graph show exactly what happened:

| Step | Stage shows | Build becomes | Continues? |
|---|---|---|---|
| failing `sh` | FAILURE | FAILURE | no (later stages skipped) |
| `unstable('msg')` | UNSTABLE | UNSTABLE | yes |
| `warnError('msg') { … }` (block fails) | UNSTABLE | UNSTABLE | yes |
| `catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') { … }` | FAILURE | unchanged | yes |
| `catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') { … }` | UNSTABLE | UNSTABLE | yes |
| `error('msg')` | FAILURE | FAILURE | no |

### Results of downstream jobs

```groovy
def r = build job: 'integration-tests', parameters: [string(name: 'IMAGE', value: env.IMAGE)], propagate: false
echo "downstream #${r.number} finished ${r.result}"
if (r.result == 'FAILURE') { unstable('integration tests failed') }
```
- `propagate: true` (default): a failed downstream build fails this build.
- `propagate: false`: you get the result back and decide yourself.
- `wait: false`: fire and forget (no result).

### `junit` options worth knowing

```groovy
junit testResults: '**/surefire-reports/*.xml, **/pytest-*.xml',
      allowEmptyResults: false,     // fail if no reports (catches wrong paths)
      keepLongStdio: false,         // don't store huge stdout per test
      skipMarkingBuildUnstable: false,
      healthScaleFactor: 1.0        // how test failures affect the job's weather icon
```
- The job page gets a **test trend graph**; each build has **Test Result** with history per test ("failing since build #41"), which is great for spotting flaky tests.
- With the *GitHub Checks* plugin, `junit` also publishes a summary to the PR's Checks tab (`skipPublishingChecks: true` turns that off).

### Linters and static analysis: Warnings Next Generation

```groovy
sh 'ruff check --output-format=pylint . > ruff.txt || true'
recordIssues tools: [pyLint(pattern: 'ruff.txt')], qualityGates: [[threshold: 1, type: 'TOTAL_ERROR', unstable: true]]
```
The *Warnings Next Generation* plugin parses 100+ tool formats (ESLint, Checkstyle, SpotBugs, PMD, pylint…), shows new vs fixed issues per build, and can mark the build UNSTABLE via quality gates.

### Coverage

```groovy
recordCoverage tools: [[parser: 'JACOCO', pattern: '**/jacoco.xml']],
               qualityGates: [[threshold: 80.0, metric: 'LINE', baseline: 'PROJECT', criticality: 'UNSTABLE']]
```
(*Coverage* plugin; it replaced the older *Cobertura* and *JaCoCo* plugins.) This duplicates part of what SonarQube does (topic 59). Pick one source of truth for coverage gates.

### Flaky tests

- Symptoms: the same commit passes and fails; failures disappear on rebuild.
- Don't hide them with `retry`. Quarantine them (mark/skip with a ticket), track them with the per-test history in Test Result, and fix them. A test suite people don't trust is worse than no suite.

---

## Hands-on lab

1. Python repo: `pip install pytest`, write one passing and one failing test, run `pytest --junitxml=report.xml || true`, then `junit 'report.xml'`. Result: UNSTABLE, with the failing test visible.
2. Remove `|| true`: now FAILURE (the step failed before `junit` decided).
3. Wrap a failing lint in `catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE')`: a red stage, green build.
4. Use `error('stop here')` in a `when`-guarded stage and read the clean message.

---

## Where you'll use it

Every CI pipeline: test reports on every PR, coverage trends, optional checks that warn without blocking.

---

## When it breaks

| Message | Meaning | Fix |
|---|---|---|
| `ERROR: No test report files were found. Configuration error?` | Wrong path, or tests didn't run | Check the path; `allowEmptyResults: true` only if that's genuinely OK |
| Build red, but you wanted yellow for test failures | The test command's exit code failed the step first | Ignore test failures in the tool; let `junit` set UNSTABLE |
| Build green with failing tests | `\|\| true` and no `junit` step | Always publish with `junit` |
| Deploy ran on an UNSTABLE build | No guard | `skipStagesAfterUnstable()` or `when { expression { currentBuild.currentResult == 'SUCCESS' } }` |

---

## Quick recap

- Results: SUCCESS, UNSTABLE, FAILURE, ABORTED, NOT_BUILT; they only get worse.
- `junit` publishes reports and marks failed tests UNSTABLE.
- `catchError`/`warnError`/`unstable`/`error` control results explicitly.
- `currentBuild` tells you the current state inside the pipeline.

**Interview questions**

1. **Q: UNSTABLE vs FAILURE?**
   A: FAILURE means a step failed (the build is broken). UNSTABLE means the build completed but quality checks failed, typically failed tests recorded by `junit`.

2. **Q: How do you let a non-critical stage fail without failing the build?**
   A: Wrap it in `catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE')` (or `warnError`).

3. **Q: How do you publish test results in Jenkins?**
   A: Have the test tool write JUnit XML and call `junit 'path/*.xml'`, usually in `post { always { … } }` so results are recorded even on failure.
