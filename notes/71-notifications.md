# 71 · Notifications

> **Level:** ★ foundation · **Status:** 🆕 new topic (implements the "notifications" uses in your `post` notes)
>
> **You will learn:** how to tell people what happened: **Email Extension** (`emailext`), **Slack** (`slackSend`), Microsoft Teams/webhooks, Git commit statuses, and which `post` conditions to use so notifications are useful instead of noisy.
>
> **You need:** topics 23–24, 35, 46.
>
> **From your original notes:** Project 01 › *Post Actions*: success → "notifications: Slack, Teams, Email"; failure → "alert developers or on-call immediately"; Day 02 › "post status back to Git/Slack".

---

## What it is

Notification steps you call from `post`:
| Channel | Plugin / step |
|---|---|
| Email | **Email Extension** → `emailext(...)` (the built-in `mail` step is simpler) |
| Slack | **Slack Notification** → `slackSend(...)` |
| Teams, Google Chat, Discord, anything | an **incoming webhook** + `httpRequest` (HTTP Request plugin) or `curl` |
| Git host | commit statuses/Checks (automatic with branch sources, topic 46) |

---

## Why it exists

A failure nobody sees is a failure that ships. But a channel full of "build succeeded" messages gets muted. Good notifications are **targeted** (the person who broke it), **actionable** (a link to the failing stage) and **rare** (only state changes).

---

## Analogy

A smoke alarm that only beeps when there's smoke (failure), and once when it clears (fixed), not one that beeps every hour to say "still no fire".

---

## How it works inside

- Notification steps run on the controller (or the agent) at the end of the build, in `post`.
- Credentials (an SMTP password, a Slack token, a webhook URL) come from Jenkins Credentials, configured once in **Manage Jenkins → System** (Extended E-mail Notification, Slack) or bound with `withCredentials` (topic 24).
- Recommended conditions: `failure`/`unstable` → notify; `fixed` → "back to green"; `success` only for **deploys/releases**.

---

## Config / Jenkinsfile / commands

```groovy
post {
  failure {
    slackSend channel: '#ci-alerts', color: 'danger',
      message: ":red_circle: ${env.JOB_NAME} #${env.BUILD_NUMBER} FAILED (${env.BRANCH_NAME ?: ''}) <${env.BUILD_URL}|open>"
    emailext subject: "FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
      body: '''${SCRIPT, template="groovy-html.template"}''',
      recipientProviders: [culprits(), requestor(), developers()],
      attachLog: true, compressLog: true
  }
  fixed {
    slackSend channel: '#ci-alerts', color: 'good', message: ":large_green_circle: ${env.JOB_NAME} is back to green"
  }
  success {
    script {
      if (env.BRANCH_NAME == 'main') {
        slackSend channel: '#deploys', color: 'good', message: "Deployed ${env.IMAGE ?: ''} from ${env.JOB_NAME} #${env.BUILD_NUMBER}"
      }
    }
  }
}
```
- `recipientProviders: [culprits(), requestor(), developers()]`: email whoever committed since the last good build (culprits), whoever started it, and the commit authors: targeted, not a mailing list.
- `attachLog: true`: attaches the console log.
- Slack setup: create a Slack app/bot token, store it as **Secret text**, configure **Manage Jenkins → System → Slack** (workspace, credential, default channel), **Test Connection**.

Generic webhook (e.g. Microsoft Teams Workflows / any chat):
```groovy
withCredentials([string(credentialsId: 'teams-webhook-url', variable: 'HOOK')]) {
  sh '''
    curl -fsS -X POST -H 'Content-Type: application/json' \
      -d "{\\"text\\": \\"$JOB_NAME #$BUILD_NUMBER failed: $BUILD_URL\\"}" "$HOOK"
  '''
}
```
(The webhook URL is itself a secret: anyone with it can post to your channel.)

SMTP for `emailext`: **Manage Jenkins → System → Extended E-mail Notification**: SMTP server (e.g. `smtp.office365.com`/`email-smtp.<region>.amazonaws.com` for SES), port 587, TLS, a credential, the default sender. Test with **Test configuration by sending test e-mail**.

---

## Deeper dive

### What a good failure message contains

1. **What:** job + build number + result ("loans #142 FAILED").
2. **Where:** branch/PR, and the **stage** that failed.
3. **Who:** the commit author(s) or whoever triggered it.
4. **Why (a hint):** the first error line, if you can extract it.
5. **Link:** straight to the failing stage or console.

Getting the failing stage: record it in each stage's `post { failure { } }`, where `STAGE_NAME` is set:
```groovy
pipeline {
  agent any
  stages {
    stage('Unit tests') {
      steps { sh 'make test' }
      post { failure { script { env.FAILED_STAGE = env.STAGE_NAME } } }
    }
    stage('Image') {
      steps { sh 'make image' }
      post { failure { script { env.FAILED_STAGE = env.STAGE_NAME } } }
    }
  }
  post {
    failure {
      slackSend channel: '#team-loans', color: 'danger',
        message: "❌ ${env.JOB_NAME} #${env.BUILD_NUMBER} failed in *${env.FAILED_STAGE ?: 'unknown stage'}* " +
                 "(${env.CHANGE_ID ? 'PR-' + env.CHANGE_ID : env.BRANCH_NAME}) <${env.BUILD_URL}console|logs>"
    }
  }
}
```
(A shared-library step can wrap this so every pipeline gets it for free, topic 58.)

### Threads instead of channel spam (Slack)

```groovy
def start = slackSend(channel: '#deploys', message: "🚀 Deploying ${env.IMAGE} to prod…")
// … later stages …
slackSend(channel: start.threadId, message: "✅ prod healthy")       // reply in the same thread
```
`slackSend` returns a response object whose `threadId` lets later messages reply in a thread, so each deploy is one tidy conversation.

### Email that people read

- Use `recipientProviders` (`culprits()`, `developers()`, `requestor()`) rather than a big team list.
- Use the HTML templates shipped with Email Extension (`groovy-html.template`) for test failures and changes; attach only compressed logs.
- For long-running release pipelines, send to a release mailing list on `success` and `failure` only.

### Avoiding noise

| Pattern | Do instead |
|---|---|
| Message on every successful CI build | Only `failure`, `unstable`, `fixed` |
| Same failure re-notified on every commit while red | Only `regression` (green → red) + `fixed` (red → green) |
| Notifications from every PR build to the team channel | Let the PR's status check do the talking; notify only main/release |
| Bots posting full logs | One line + link |

### Statuses and PR comments

- The commit status/Check (topic 46) is the best notification for PR builds: it appears exactly where the developer is looking.
- Some teams also post a PR comment with a summary (test counts, coverage diff, preview URL), via the GitHub API with `curl` (using a GitHub App token) or a plugin. Keep it to one comment that gets updated, not one per build.

---

## Hands-on lab

1. Create a free Slack workspace (or use an existing test one), add the Jenkins CI app/bot, configure the plugin, and send a test message.
2. Add the `failure`/`fixed` blocks to `flask-pipeline`; break and fix the build; see exactly two messages.
3. (Optional) Run MailHog/Mailpit locally (`docker run -d -p 8025:8025 -p 1025:1025 axllent/mailpit` on `jenkins-net`), point SMTP at it, and view the `emailext` HTML in its web UI.

---

## Where you'll use it

Every team's pipelines (failures to the team channel; deploys to a deploy channel); on-call alerting for release pipelines.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `No such DSL method 'slackSend'` | Slack plugin missing | Install it |
| Slack: `invalid_auth` / `channel_not_found` | Wrong token, or the bot isn't in the channel | Fix the credential; invite the bot |
| Emails never arrive | SMTP/TLS/port wrong, or blocked | Test configuration; check the System Log |
| Everyone mutes the channel | Notifying on every success | Only failure/unstable/fixed + deploys |
| `post` notification fails and hides the real error | The notification step itself throws | Wrap in `catchError` or `try` so it can't fail the build |

---

## Quick recap

- Notify from `post`: `failure`/`unstable` → team, `fixed` → back to green, `success` → only deploys/releases.
- `emailext` with `culprits()`/`requestor()` for targeted email; `slackSend` for chat; webhooks for everything else.
- Tokens and webhook URLs are credentials.

**Interview questions**

1. **Q: How do you avoid notification fatigue in CI?**
   A: Notify only on failures, unstable builds and fixes (state changes), target the people responsible (culprits/requestor), and announce successes only for deployments.

2. **Q: Where in a pipeline do notifications belong?**
   A: In the `post` section, under conditions like `failure`, `fixed` and (for deploys) `success`, so they run whatever happened in the stages.

3. **Q: How do you send a notification to a tool without a Jenkins plugin?**
   A: Through its incoming webhook with `httpRequest` or `curl`, with the webhook URL stored as a secret credential.
