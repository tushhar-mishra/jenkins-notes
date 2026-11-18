# 46 · GitHub Integration

> **Level:** ★★ intermediate · **Status:** 🔀➕ merged and expanded
>
> **You will learn:** the right way to connect Jenkins and GitHub: a **GitHub App** credential (vs a PAT), how Jenkins posts **commit statuses / Checks**, webhooks with secrets (managed automatically or by hand), and protecting `main` with **branch protection rules or rulesets** that require Jenkins checks.
>
> **You need:** topics 05, 21, 23, 43–44.
>
> **From your original notes:** Day 07 › *Prerequisites* (PAT or GitHub App; webhook optional but recommended), *Note — Protecting `main` in GitHub (quick setup)*, *(Optional) Auto-delete branch on merge* · Day 04 › *Mini Demo 4* (webhook setup) · Project 01 › *Trigger pipeline on Git push* security tips.

---

## What it is

Three connections between Jenkins and GitHub:
1. **Jenkins → GitHub (API + checkout):** authenticated with a **GitHub App** (preferred) or a PAT.
2. **GitHub → Jenkins (events):** webhooks to `/github-webhook/`.
3. **Jenkins → GitHub (results):** commit **statuses** or **Checks** on each commit/PR, which **branch protection** requires before merging.

---

## Why it exists

This loop is what makes CI a **gate**: GitHub tells Jenkins what changed, Jenkins tells GitHub whether it's safe, and GitHub refuses unsafe merges.

---

## Analogy

A **building's security desk and a contractor**: the desk calls the contractor when a delivery arrives (webhook), the contractor inspects it and stamps "approved" or "rejected" on the form (status check), and the desk only lets approved deliveries in (branch protection). The contractor carries a company ID badge (GitHub App), not a personal key (PAT).

---

## How it works inside

### GitHub App vs PAT

| | Personal Access Token | GitHub App |
|---|---|---|
| Belongs to | a person (leaves with them) | the organisation |
| Token lifetime | long (until expiry/revoke) | **1-hour installation tokens**, minted automatically from the App's private key |
| API rate limit | 5,000/hour per user | higher (scales with the org; 5,000–12,500/hour per installation, more on Enterprise Cloud) |
| Permissions | broad scopes (classic) or per-repo (fine-grained) | per-permission, per-installation |
| Checks API (rich PR checks) | statuses only | ✅ |

### Statuses vs Checks

- **Commit status** (classic): a context name + state + link, e.g. `continuous-integration/jenkins/pr-merge: success`. GitHub Branch Source posts these by default.
- **GitHub Checks** (Checks API; needs a GitHub App and the *GitHub Checks* plugin): a richer "Checks" tab with per-stage results, test summaries and annotations.

Either can be a **required check** in branch protection.

### Webhooks: automatic or manual

With the GitHub Branch Source and a credential that has admin rights on the repo/org, Jenkins can **manage hooks automatically** (**Manage Jenkins → System → GitHub → GitHub Server → Manage hooks**). Otherwise, add the webhook manually (topic 21):
- Payload URL `https://<jenkins>/github-webhook/`, content type `application/json`
- Events: **Pushes**, **Pull requests** (a GitHub App subscribes to these itself)
- **Secret**: a long random string, also stored in Jenkins (**GitHub → Advanced → Shared secrets**) so Jenkins rejects forged payloads.

---

## Config / Jenkinsfile / commands

### Create a GitHub App for Jenkins

1. GitHub → **your org → Settings → Developer settings → GitHub Apps → New GitHub App**.
   - Name: `jenkins-ci-<org>`; Homepage URL: your Jenkins URL.
   - Webhook URL: `https://<jenkins>/github-webhook/`, plus a secret.
   - **Repository permissions:** Contents *Read*, Metadata *Read*, Pull requests *Read*, Commit statuses *Read & write*, Checks *Read & write* (add Administration *Read & write* only if Jenkins should manage hooks; Contents *Write* only if it must push).
   - **Subscribe to events:** Check run, Check suite, Pull request, Push, Repository.
2. **Generate a private key** (downloads a `.pem`). Convert it to the format the plugin expects:
   ```bash
   openssl pkcs8 -topk8 -inform PEM -outform PEM -in jenkins-ci.private-key.pem -out converted-github-app.pem -nocrypt
   ```
   (`pkcs8` = the standard private-key container format the Java plugin reads; `-nocrypt` = no passphrase.)
3. **Install** the App on the org (all repos, or selected ones).
4. Jenkins → **Credentials → Add → Kind: GitHub App**: App ID (from the App's page), the converted key; **ID** `github-app`. Click **Test Connection** (shows the rate limit).
5. Use `github-app` as the credential in multibranch/organization-folder sources.

### Protecting `main` in GitHub (from Day 07)

- **Where:** repo → **Settings → Branches → Add rule** (classic) **or** **Settings → Rules → Rulesets → New ruleset** (newer model).
- **Pattern:** **Branch name pattern** `main` (rulesets: target `Default branch`).
- **Common protections for `main`:**
  - **Require a pull request before merging** (blocks direct pushes; you'll often see "you can't push directly to this branch").
  - **Require status checks to pass** (e.g. the Jenkins `continuous-integration/jenkins/pr-merge` check). The check must have **run at least once** before GitHub lets you pick it.
  - **Require branches to be up to date** (forces a rebase/merge with the latest `main` first).
  - **Require approvals** (e.g. at least 1 reviewer; dismiss stale reviews on new commits).
  - Optional hardening: **restrict who can push**, **require signed commits**, **require linear history**, **lock branch**.
- **Ruleset vs classic rule:** rulesets add richer targeting and org-level control; classic rules are simpler. Either is fine for the lab.
- **Heads-up (plans):** some options may be limited or "not enforced" on personal private repos without GitHub Team/Enterprise.

### (Optional) Auto-delete branches on merge

Repo → **Settings → General → Pull Requests →** enable **Automatically delete head branches**. Combined with the MBP orphan strategy, retired branches disappear from Jenkins too.

### Custom status names from a pipeline

```groovy
// GitHub Checks plugin: publish a named check from the pipeline
publishChecks name: 'deploy-preview', title: 'Preview deploy', summary: "pr-${env.CHANGE_ID} is up", conclusion: 'SUCCESS'
```
Useful when branch protection requires a specific name like `deploy-preview`.

### Security tips (from Project 01)

- Use a **webhook secret** and enable validation in Jenkins.
- Use **fine-grained** tokens with least privilege, or better, a GitHub App.
- Prefer **multibranch** for clean branch/PR isolation and auto-discovery.

---

## Hands-on lab

1. Create the GitHub App and install it on your `jenkins-lab` repo; add the `github-app` credential and **Test Connection**.
2. Switch `flask-mbp`'s branch source to `github-app`. Scan.
3. Open a PR; after the build, see the Jenkins check(s) on the PR.
4. Add a ruleset on `main` requiring the `continuous-integration/jenkins/pr-merge` status. Push a failing change to the PR and watch the **Merge** button blocked.

---

## Where you'll use it

Every GitHub-hosted company running Jenkins: Apps for auth, required checks for gating.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to update commit status … 403 Resource not accessible by integration` | App lacks *Commit statuses* (or *Checks*) write | Add the permission; accept it in the installation |
| Can't select the Jenkins check in branch protection | The check has never been reported on that repo | Run one PR build first |
| `Couldn't parse private key for GitHub app` | Key not converted to PKCS#8 | Run the `openssl pkcs8` command |
| Webhook deliveries `401/403 invalid signature` | Secret mismatch | Same secret in GitHub and Jenkins |
| Statuses link to `http://localhost:8080` | Jenkins URL not set | **Manage Jenkins → System → Jenkins URL** |

---

## Quick recap

- Authenticate Jenkins to GitHub with a **GitHub App** (short-lived tokens, org-owned, higher rate limits).
- Webhooks bring events in (use a secret); statuses/Checks send results back.
- **Branch protection/rulesets** require PRs, reviews, up-to-date branches and the Jenkins check.
- Auto-delete merged branches + MBP orphan cleanup keep things tidy.

**Interview questions**

1. **Q: How does a Jenkins result block a GitHub merge?**
   A: Jenkins posts a commit status/check on the PR's commit; a branch protection rule on `main` lists that check as required, so GitHub disables merging until it's green.

2. **Q: Why prefer a GitHub App over a PAT for Jenkins?**
   A: Org-owned identity, auto-rotating 1-hour tokens, granular permissions, higher API limits, and support for the Checks API.

3. **Q: The required check never appears in the branch protection list. Why?**
   A: GitHub only offers check names it has seen recently on that repo. Run a PR build so Jenkins reports it once.
