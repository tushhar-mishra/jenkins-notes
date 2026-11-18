# 44 · Multibranch Build Strategies

> **Level:** ★★ intermediate · **Status:** ✅ rewritten from your notes
>
> **You will learn:** the three **branch discovery strategies** (exclude PR branches / only PR branches / all branches), the three **PR strategies** (Head / Merge / Both) for same-repo PRs and for forks, fork **trust policies** and why they protect your secrets, plus a cheat sheet of good defaults.
>
> **You need:** topic 43.
>
> **From your original notes:** Day 07 › *Build strategies (what to build)*: *Branch build strategy*, *Discover pull requests from origin*, *Discover pull requests from forks*, *Trust policy*, *Example trust flow*, *Quick cheat-sheet*, the quick example of the three branch strategies.

---

## What it is

Settings on the GitHub branch source (**Behaviours**) that decide **which refs get jobs and builds**:
- **Discover branches → Strategy** (affects **branch jobs**, not PR jobs).
- **Discover pull requests from origin → Strategy** (PRs from branches in the same repo).
- **Discover pull requests from forks → Strategy + Trust** (PRs from other people's copies of the repo).

---

## Why it exists

Without the right strategy you either **double-build** every change (branch job + PR job), **miss integration bugs** (only testing your branch, not branch + current `main`), or **leak secrets** to untrusted fork code.

---

## Analogy

Exam rules: do you mark a student's draft (branch), their final answer (PR head), or how their answer fits with the rest of the class's work (merge)? And do you let outside students (forks) use the school's lab equipment (credentials)?

---

## How it works inside

### Branch build strategy (affects branch jobs, not PR jobs)

1. **Exclude branches that are also filed as PRs** *(recommended)*
   - **Behaviour:** build a branch on every push **until** a PR is opened from it; then **stop** the branch job and let the **PR job** run. If the PR closes and the branch remains, the **branch job resumes** on the next push.
   - **Example:** push to `feature/x` → branch job builds. Open PR `feature/x → main` → the PR job builds; the branch job pauses. Close the PR, push again → the branch job builds.
2. **Only branches that are also filed as PRs**
   - **Behaviour:** build a **branch job only if that branch has an open PR**. Long-lived branches like `main`/`release/*` won't build unless included elsewhere.
   - **Example:** push to `feature/y` (no PR) → **no build**. Open PR `feature/y → main` → the branch job builds (and the PR job, depending on PR settings). `main` after merging → **won't build** unless separately included.
3. **All branches**
   - **Behaviour:** build **every** branch on push, even if a PR exists, so you'll likely build both the branch job **and** the PR job (duplicates).
   - **Example:** open a PR from `feature/z` → push again → the **branch job builds** and the **PR job builds** for the same change.

> Quick example of the three: you push `feature/x` (no PR yet): **Exclude** = builds; **Only** = doesn't build; **All** = builds. You open a PR from `feature/x`: **Exclude** = builds the PR job only; **Only** = builds (because a PR exists); **All** = builds both (duplication).

### Discover pull requests from origin (same-repo PRs)

Pick **one** strategy (or **Both**):

1. **The current pull request revision (Head)**: *"your code only"*
   - **Builds:** the PR tip **as-is** (no merge with `main`).
   - **Rebuilds when:** the **PR updates** (not when `main` moves).
   - **What it tells you:** does **your change alone** build/test/deploy?
   - **Limit:** can miss failures that appear **after** merging with a newer `main`.
   - **Example:** `main` added a breaking API change; Head passes, but the merge would fail.
2. **Merging the pull request with the current target branch revision (Merge)**: *"your code + current main"*
   - **Builds:** a **synthetic merge** = `main@tip` + `PR@head` (what would land **right now**). Jenkins creates this merge commit locally, in the workspace only.
   - **Rebuilds when:** the **PR updates** **or** **`main` moves** (via webhook/scan).
   - **What it tells you:** would the **post-merge** build succeed? It catches integration drift and conflicts.
   - **Relation to the `main` build:** if you merged **immediately**, the `main` build should look like **this** result.
   - **Example:** `main` bumped a library; the Merge build fails until the PR adapts.
3. **Both (Head + Merge)**: *verify both views*
   - **Builds:** **two** jobs per PR event: **Head** and **Merge** (`PR-1-head`, `PR-1-merge`).
   - **What it tells you:** both signals: PR-only regressions **and** the after-merge outcome.
   - **Production tip:** make the **Merge** status a **required check**, since it reflects what `main` will be **after** the merge.

> **Rule of thumb:** if you must choose one, pick **Merge**, to know what `main` will look like after merging. If you have capacity, choose **Both**, to verify **your code alone** *and* **your code + current main**.

### Discover pull requests from forks

**What to build for forked PRs** (pick one):
1. **The current pull request revision (Head)**: **safest default**. Runs the fork's code **as-is**, often combined with **no credentials** to avoid secret leakage.
   - *Example:* an external contributor opens a PR from a fork → a Head build runs with the target repo's Jenkinsfile but without your secrets.
2. **Merging with the current target branch revision (Merge)**: builds the synthetic **merge** of target + fork PR. Use only if you're comfortable with the security posture and secret handling.
   - *Example:* an org-internal fork where secrets are allowed; you validate integration with the latest `main`.
3. **Both (Head + Merge)**: the strongest signal, but use cautiously with secrets; typically for **trusted forks** only.

**Trust policy** (who gets the "full" treatment):
- **From users with Admin or Write permission** *(common)*.
- Others (depending on plugin version): *Nobody*, *Collaborators*, *Everyone* (dangerous).

What "trust" means precisely: for an **untrusted** fork PR, Jenkins runs the pipeline using the **Jenkinsfile from the target branch** (your `main`), **not the fork's Jenkinsfile**. That stops an attacker from editing the Jenkinsfile to print your credentials. (Their *code* still runs, e.g. their tests, so don't expose powerful credentials to stages that run PR code from forks.) For **trusted** users, the PR's own Jenkinsfile is used.

**Example trust flow:**
- PR from a team member (write access) → full pipeline (image build/push, preview deploy).
- PR from an unknown fork → reduced pipeline (no creds; maybe Head-only checks).

In the Jenkinsfile you can detect fork PRs and skip secret-using stages:
```groovy
when { not { changeRequest fork: '.*' } }   // run only for non-fork builds
```

### Quick cheat sheet

- **Best general setup:**
  - Branch strategy: **Exclude branches that are also filed as PRs**
  - Origin PRs: **Both (Head + Merge)** → require the **Merge** status
  - Fork PRs: **Head** only + trust **"From users with Admin or Write permission"** for full runs
- **Capacity constrained:**
  - Origin PRs: **Merge** only (still catches integration drift)
  - Keep **Exclude…** to avoid duplicate branch + PR builds

---

## Config / Jenkinsfile / commands

Where they appear in the UI: **flask-mbp → Configure → Branch Sources → GitHub → Behaviours**. As JCasC/Job DSL (topic 67) they look like:
```groovy
traits: [
  gitHubBranchDiscovery(strategyId: 1),                 // 1 = exclude branches filed as PRs, 2 = only PRs, 3 = all
  gitHubPullRequestDiscovery(strategyId: 1),            // 1 = merge, 2 = head, 3 = both
  gitHubForkDiscovery(strategyId: 2, trust: gitHubTrustPermissions())
]
```

Console differences:
```
# PR-7 (merge strategy)
Merging remotes/origin/main commit 4b1a0d2… into PR head commit 9f3c2e7…
Merge succeeded, producing a1b2c3d…
```
Status check names posted to GitHub: `continuous-integration/jenkins/pr-merge`, `continuous-integration/jenkins/pr-head`, `continuous-integration/jenkins/branch`.

---

## Hands-on lab

1. Set the strategies to the "best general setup".
2. Push `feature/x` (no PR): a branch job builds. Open a PR: `PR-N` builds; push again: only the PR job builds.
3. Switch origin PRs to **Both**: you get two checks on the PR. Push a commit to `main` and see the **Merge** job rebuild without a PR change.
4. (Optional, with a second GitHub account) open a PR from a fork and check which Jenkinsfile was used (`Obtained Jenkinsfile from …` shows the target-branch commit when untrusted).

---

## Where you'll use it

Configuring any multibranch job; securing open-source or multi-team repos; deciding the required checks on `main`.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Every push builds twice | "All branches" strategy | "Exclude branches that are also filed as PRs" |
| `main` never builds | "Only branches that are also filed as PRs" | Use "Exclude…" or add `main` explicitly |
| PR green, `main` red right after the merge | Head-only strategy | Merge (or Both) + require the merge check |
| `Jenkinsfile` edits in a fork PR "ignored" | Untrusted fork: target-branch Jenkinsfile used (by design) | Expected; a maintainer can re-push to the origin repo |
| Merge build: `Merge conflict` | PR conflicts with `main` | Rebase/resolve in the PR |

---

## Quick recap

- Branch strategy: **Exclude PR branches** (default best), Only PR branches, All branches.
- PR strategy: **Head** (your code), **Merge** (your code + current main), **Both**; require **Merge**.
- Fork PRs: Head only, trust users with write access; untrusted forks run the target branch's Jenkinsfile.

**Interview questions**

1. **Q: PR Head vs Merge builds?**
   A: Head builds the PR's own commit; Merge builds a temporary merge of the PR with the current target branch, showing what `main` would be after merging. Merge also rebuilds when `main` moves.

2. **Q: How does Jenkins protect credentials from malicious fork PRs?**
   A: Trust policies: for untrusted fork PRs it uses the target branch's Jenkinsfile, not the fork's, and you typically skip secret-using stages for fork builds.

3. **Q: Why exclude branches that are also filed as PRs?**
   A: To avoid building the same change twice (branch job + PR job). Once a PR exists, the PR job is the meaningful one.
