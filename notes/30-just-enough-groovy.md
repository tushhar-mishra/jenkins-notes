# 30 · Just Enough Groovy

> **Level:** ★ foundation · **Status:** 🆕 new topic (expands Day 06's "Groovy: how much do you need?")
>
> **You will learn:** the small slice of Groovy that Jenkinsfiles use: strings and quoting (the most important part), variables, lists and maps, closures, calling methods with named arguments and without parentheses, `if`/loops, and how Groovy `$` differs from shell `$`.
>
> **You need:** topic 29. Basic shell variables ([Linux notes 012](../../linux-mastery-rhel/notes/012-variables-and-environment.md), [011 quoting](../../linux-mastery-rhel/notes/011-quoting-and-control-operators.md)).
>
> **From your original notes:** Day 06 › *Groovy: how much do you need?*.

---

## What it is

**Groovy** is a programming language that runs on the JVM, with syntax close to Java but much lighter. Jenkinsfiles are written in a Groovy-based **DSL** (Domain-Specific Language: a mini-language for one job, here describing pipelines).

> From Day 06: pipelines use Groovy syntax, but you don't need "deep Groovy". You'll mostly write **Declarative Pipeline**, which is structured and opinionated, and we learn the Groovy we need as we go.

---

## Why it exists

Most Jenkinsfile bugs aren't pipeline bugs; they're **quoting bugs**: a variable that didn't expand, a `$` that Groovy ate before the shell saw it, a secret leaked by interpolation (topic 24). Ten minutes of Groovy basics prevents hours of confusion.

---

## Analogy

Writing a letter **through an interpreter**: you (Groovy) write a note that the interpreter (the shell) will read aloud. If you write "tell them the price is $PRICE" in your own handwriting, *you* fill in the price before handing it over. If you write it in quotes that say "read this literally", the interpreter fills it in. Which one you want depends on who knows the price.

---

## How it works inside

### Two layers, two kinds of `$`

```groovy
sh "echo ${env.BUILD_NUMBER} \$HOME"
```
1. **Groovy** processes the string first: `${env.BUILD_NUMBER}` becomes `7`; `\$HOME` becomes a literal `$HOME`.
2. The **shell** then runs `echo 7 $HOME` and expands `$HOME` itself.

### Strings: the one table to memorise

| Syntax | Groovy interpolation? | Multi-line? | Use it for |
|---|---|---|---|
| `'single'` | ❌ no, text is literal | no | `sh '…'` with shell variables and **secrets** |
| `"double ${x}"` | ✅ yes (`$x` or `${expr}`) | no | Messages using Groovy values: `echo "Build ${env.BUILD_NUMBER}"` |
| `'''triple single'''` | ❌ no | ✅ yes | Multi-line shell scripts |
| `"""triple double ${x}"""` | ✅ yes | ✅ yes | Multi-line scripts that need Groovy values (escape shell `$` as `\$`) |

Escapes: inside double-quoted strings, write `\$` for a literal `$` and `\"` for a quote. Inside single quotes, write `\'` for a single quote.

Examples:
```groovy
sh 'echo "$BUILD_NUMBER"'          // shell expands; BUILD_NUMBER is an env var → 7
sh "echo ${BUILD_NUMBER}"          // Groovy expands → script text: echo 7
sh "echo \$HOME"                   // literal $HOME for the shell
sh '''
  set -eu
  echo "multi-line, shell expands $WORKSPACE"
'''
sh """
  docker build -t ${params.IMAGE}:${env.BUILD_NUMBER} .
  echo "built in \$PWD"
"""
```

All Jenkins environment variables (built-in ones, `environment {}` ones, `withCredentials` ones) are **also shell environment variables** in `sh` steps. So the shell can expand them, and single quotes are usually the safest choice.

### Variables

```groovy
def name = 'loans'                 // def = a local variable (type decided at run time)
String tag = env.BUILD_NUMBER      // typed variable (also fine)
env.IMAGE = "acme/${name}"         // set an environment variable for later sh steps
```
In declarative pipelines, `def` variables only work inside a `script { }` block or in code outside the `pipeline { }` block (topic 31).

### Lists and maps

```groovy
def envs = ['dev', 'stage', 'prod']           // list
echo envs[0]                                  // dev
def cfg = [image: 'acme/loans', port: 8080]   // map (key: value)
echo cfg.image                                // acme/loans
echo cfg['port'].toString()
```

### Calling methods: Jenkins steps are method calls

Jenkins steps (`sh`, `echo`, `git`, `archiveArtifacts`) are just methods:
```groovy
sh('make test')                        // with parentheses
sh 'make test'                         // parentheses optional for a single argument
git(url: 'https://…', branch: 'main')  // named arguments = one map
git url: 'https://…', branch: 'main'   // same, without parentheses
def out = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()   // get output back
def code = sh(script: 'test -f app.jar', returnStatus: true)                    // get exit code, don't fail
```
- `returnStdout: true` returns what the command printed (`.trim()` removes the trailing newline).
- `returnStatus: true` returns the exit code instead of failing the build on non-zero.

### Closures: the `{ … }` blocks

A **closure** is a block of code you can pass around. Every `{ }` in a Jenkinsfile is one: `stages { … }`, `steps { … }`, `withCredentials([...]) { … }`. Writing `withCredentials([...]) { sh '…' }` means "call `withCredentials`, passing it this block to run".

```groovy
envs.each { e -> echo "deploying to ${e}" }   // a closure with a parameter e
```

### Conditions and loops (inside `script {}`)

```groovy
script {
  if (env.BRANCH_NAME == 'main') {
    echo 'release build'
  } else {
    echo "branch ${env.BRANCH_NAME}"
  }
  for (e in ['dev', 'stage']) { echo e }
}
```
- `==` compares values (strings too). Unlike Java, you don't need `.equals()`.
- `env.X` is `null` if unset; `env.X ?: 'default'` gives a default (the **Elvis operator**).

### The sandbox

Jenkinsfiles run in the **Groovy sandbox**: only approved methods are allowed. Calling something unapproved (e.g. `new File(…)`, `System.getenv()`) fails with `Scripts not permitted to use method …` until an admin approves it (topic 65). Usually that means you should use a Jenkins step instead (`readFile`, `env.X`).

### Two pipeline styles (preview)

- **Declarative Pipeline** (newer, simpler): `pipeline { agent any; stages { … } }`. Structured blocks; Groovy only where you need it.
- **Scripted Pipeline** (flexible, Groovy-first): `node { stage('…') { … } }`. Plain Groovy code.

This course teaches **Declarative** first (topic 31). You can always drop into `script { }` or Scripted for advanced logic (topic 42).

---

## Config / Jenkinsfile / commands

A small pipeline that uses every idea above:

```groovy
def services = ['api', 'worker']          // Groovy outside the pipeline block

pipeline {
  agent any
  environment { REGISTRY = 'docker.io/you' }
  stages {
    stage('Info') {
      steps {
        echo "Build ${env.BUILD_NUMBER} on ${env.NODE_NAME}"     // Groovy interpolation
        sh 'echo "shell sees $REGISTRY and $BUILD_NUMBER"'       // shell expansion
        script {
          def sha = sh(script: 'echo abc1234', returnStdout: true).trim()
          env.SHORT_SHA = sha
          services.each { s -> echo "would build ${env.REGISTRY}/${s}:${sha}" }
        }
        sh 'echo "later step sees SHORT_SHA=$SHORT_SHA"'
      }
    }
  }
}
```
Console (shape):
```
Build 3 on built-in
+ echo shell sees docker.io/you and 3
shell sees docker.io/you and 3
+ echo abc1234
would build docker.io/you/api:abc1234
would build docker.io/you/worker:abc1234
+ echo later step sees SHORT_SHA=abc1234
```

---

## Hands-on lab

Create a Pipeline job (inline script) and predict each line's output before running:
```groovy
pipeline {
  agent any
  environment { GREETING = 'hello' }
  stages { stage('q') { steps {
    sh 'echo 1: $GREETING'
    sh "echo 2: ${GREETING}"
    sh "echo 3: \$GREETING"
    sh 'echo "4: ${GREETING}"'
    echo '5: ${GREETING}'
    echo "6: ${GREETING}"
  } } }
}
```
Answers: 1, 2, 3, 4 and 6 print `hello`; 5 prints the literal `${GREETING}` (single quotes, and `echo` is a Groovy step, not a shell). For 4: Groovy leaves the single-quoted text alone, and then the **shell** expands `${GREETING}` (shell syntax looks the same!).

---

## Where you'll use it

- Every `sh` step (quoting).
- `script {}` blocks for logic declarative can't express.
- Shared libraries (Part 9), which are Groovy files.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `groovy.lang.MissingPropertyException: No such property: HOME` | `"…$HOME…"` in double quotes: Groovy looked for a Groovy variable `HOME` | Single quotes, or `\$HOME` |
| Variable prints literally as `${VAR}` | Single-quoted `echo` (a Groovy step) | Double quotes for Groovy steps |
| `Warning: A secret was passed to "sh" using Groovy String interpolation` | Secret in a double-quoted `sh` | Single quotes (topic 24) |
| `Scripts not permitted to use method …` | Sandbox blocked an unapproved method | Use a Jenkins step, or have an admin approve it |
| `WorkflowScript: … expecting '}', found …` | Unbalanced braces/quotes | Check bracket pairs; use the linter (topic 33) |

---

## Quick recap

- **Single quotes:** no Groovy interpolation, so the shell expands `$VAR`. Use with `sh` and secrets.
- **Double quotes:** Groovy expands `${…}` first; escape shell `$` as `\$`.
- Triple quotes for multi-line scripts.
- Steps are methods: named arguments, optional parentheses, `returnStdout`/`returnStatus`.
- `{ }` blocks are closures; logic goes in `script {}` in declarative pipelines.

**Interview questions**

1. **Q: `sh 'echo $X'` vs `sh "echo ${X}"`?**
   A: With single quotes, the shell expands `$X` from the environment. With double quotes, Groovy substitutes the value into the script text before the shell runs, which can leak secrets and breaks shell-only variables.

2. **Q: How do you capture a command's output in a pipeline?**
   A: `def out = sh(script: 'cmd', returnStdout: true).trim()`.

3. **Q: What's the Groovy sandbox?**
   A: A security layer that only allows approved methods in pipeline code. Unapproved calls fail until an administrator approves them through script approval.
