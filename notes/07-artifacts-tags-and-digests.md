# 07 · Artifacts, Tags and Digests

> **Level:** ★★ intermediate · **Status:** 🔀➕ merged and expanded
>
> **You will learn:** the most important rule in CD, **build once, promote the same artifact**; the difference between an image **tag** and an image **digest**; the `manifest.json` promotion record; where artifacts are stored; and what SBOMs and signing add.
>
> **You need:** topics 03–06. Docker images (topic 04 recap).
>
> **From your original notes:** Day 02 › *What happened earlier on `dev` (input to promotion)* (build once, record digest, manifest, deploy by digest, example `manifest.json`, why multiple tags, TL;DR), *What is CI/CD?* note on release metadata, *Conclusion* · Day 01 › Build phase production notes (reproducibility, artifact storage, immutability, supply-chain security).

---

## What it is

- **Artifact:** the file a build produces and you deploy (`.jar`, binary, container image). Topic 03.
- **Immutable artifact:** once built, it is **never changed**. If you need a change, you build a new one with a new version.
- **Promotion:** moving the *same* artifact from one environment to the next (dev → staging → prod), changing only the **configuration** (URLs, passwords, replica counts) per environment.

For container images there are two ways to name "which image":

- **Tag:** a human-friendly label after the colon: `ghcr.io/acme/loans:v1.4.3`. **Tags can be moved.** Someone can push a different image with the same tag (`latest` is moved on every push).
- **Digest:** the image's content fingerprint: `ghcr.io/acme/loans@sha256:abc123…`. It's a **SHA-256 hash** of the image manifest (the JSON file listing the image's layers). **Digests cannot change**: different content means a different digest.

---

## Why it exists

If you **rebuild** for each environment, the thing you tested isn't the thing you ship. A rebuild can pick up a newer base image, a different library version or a different compiler flag. Then "it passed staging" means nothing.

And if you deploy **by tag**, someone (or a pipeline) can overwrite `v1.4.3` or `latest`, and prod silently runs something nobody tested.

**Build once, tag for humans, deploy by digest** removes both risks.

---

## Analogy

A **sealed, numbered evidence bag** in a court case.
- The evidence (artifact) is sealed once, at the crime scene (build).
- It moves from the lab to the courtroom (dev → stage → prod) **without being reopened** (no rebuild).
- The sticker "Exhibit A" (tag) is for humans, and a sticker can be peeled off and moved.
- The **serial number printed into the seal** (digest) proves it's the very same bag. If it doesn't match, the evidence is rejected.

---

## How it works inside

### Step 1: build once and push (a single image)

CI builds **one image** and may attach several **human-friendly tags**, all pointing to the same image:

- `:v1.4.3` (the release version)
- `:9f3c2e7` (the Git commit SHA it was built from)
- `:9f3c2e7-v1.4.3` (both)

*All of these tags point to the **same immutable digest**.*

### Step 2: record the immutable digest (the source of truth)

When you push, the registry replies with the content address, e.g. `sha256:abc123…`. This **never changes**, and it's what you **deploy**.

```
$ docker push ghcr.io/acme/banking-loans:v1.4.3
v1.4.3: digest: sha256:abc123def456... size: 1784
```

### Step 3: publish a promotion manifest

CI writes a small `manifest.json` with the repo, **digest**, commit, version, build time and tags, to a **read-only location** that the Stage/Prod pipelines can read (a GitHub Release, a Jenkins archived artifact, an S3 bucket).

```json
{
  "image": "ghcr.io/acme/banking-loans",
  "digest": "sha256:abc123...",
  "version": "v1.4.3",
  "commit_sha": "9f3c2e7",
  "tags": ["v1.4.3", "9f3c2e7", "9f3c2e7-v1.4.3"],
  "built_at": "2025-09-15T10:22:00Z"
}
```

### Step 4: deploy by digest, not by tag

Dev/Stage/Prod jobs read the manifest, **check the digest exists and can be pulled**, and **deploy that digest** with environment-specific config. **No rebuilds.** Prefer the digest even if your registry makes tags immutable.

```
image: ghcr.io/acme/banking-loans@sha256:abc123...
```

### Why keep several tags if you deploy by digest?

- **`:v1.4.3` (release):** easy for Product/QA/Support to map incidents and read changelogs/dashboards.
- **`:9f3c2e7` (commit):** engineers/SREs can jump straight to the exact source for **bisects** (finding which commit introduced a bug) and hotfixes.
- **`:9f3c2e7-v1.4.3` (combined):** both at a glance in registry UIs.

> **TL;DR:** **Build once**, **tag for humans**, **deploy by digest** everywhere.

Release metadata added later (a release tag, a signature, an attached SBOM) **doesn't rebuild** anything; the digest stays the same.

### Where artifacts are stored

| Kind of artifact | Typical store |
|---|---|
| Container images | **Registries**: Docker Hub, GHCR (GitHub Container Registry), Amazon ECR, Google Artifact Registry, Azure ACR, Harbor |
| `.jar`/`.war`, npm, PyPI packages | **Artifact repositories**: Sonatype **Nexus**, JFrog **Artifactory**, GitHub Packages |
| Small build records (reports, `manifest.json`, deploy-info) | Jenkins **archived artifacts** (topic 18), S3, GitHub Releases |

Jenkins can archive files with a build, but it is **not** an artifact repository: archived files live in `JENKINS_HOME` on the controller and are deleted with old builds. Ship real artifacts to a registry/repository.

### Production practices (from the Build phase)

- **Reproducibility:** lockfiles, pinned versions, deterministic build scripts.
- **Artifact storage:** publish to registries for traceability and rollbacks.
- **Immutability:** never modify a built artifact; the same one goes to every environment. Many registries can enforce **immutable tags** (ECR does; topic 62).
- **Supply-chain security:**
  - **SBOM (Software Bill of Materials):** a machine-readable list of every component and version inside the artifact (formats: SPDX, CycloneDX). Generated by tools like **Syft** or **Trivy**. When a new CVE is announced, you search SBOMs to find which images are affected.
  - **Signing:** a cryptographic signature proving *who* built the artifact and that it hasn't been altered. **Cosign** (from the Sigstore project) is the common tool for images; Kubernetes admission policies can refuse unsigned images (topic 64).
  - **Provenance / attestations:** signed records of *how* it was built (which commit, which pipeline). The **SLSA** framework (Supply-chain Levels for Software Artifacts) defines levels of this.
  - **Image scanning** before push (topic 06).

---

## Config / Jenkinsfile / commands

Get the digest after a push, and write the manifest, in a pipeline step:

```bash
IMAGE=ghcr.io/acme/banking-loans
docker build -t "$IMAGE:$GIT_SHA" -t "$IMAGE:v1.4.3" .
docker push "$IMAGE:$GIT_SHA"
docker push "$IMAGE:v1.4.3"
DIGEST=$(docker buildx imagetools inspect "$IMAGE:$GIT_SHA" --format '{{json .Manifest}}' | jq -r .digest)
echo "$DIGEST"
```
```
sha256:abc123def4567890...
```
- `docker buildx imagetools inspect` asks the **registry** for the manifest, so you get the digest the registry actually stores (the reliable source).
- An alternative is `docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE:$GIT_SHA"`, which prints `ghcr.io/acme/banking-loans@sha256:…` from the local cache after a push.

```bash
jq -n --arg image "$IMAGE" --arg digest "$DIGEST" --arg sha "$GIT_SHA" \
      --arg version v1.4.3 --arg at "$(date -u +%FT%TZ)" \
      '{image:$image, digest:$digest, commit_sha:$sha, version:$version, built_at:$at}' > manifest.json
```
Then in Jenkins: `archiveArtifacts artifacts: 'manifest.json', fingerprint: true` (topic 18).

Deploying by digest with Helm (topic 09 introduces Helm):
```bash
helm upgrade --install loans ./charts/loans \
  --set image.repository="$IMAGE" --set image.digest="$DIGEST" \
  -f charts/loans/values-stage.yaml
```

---

## Hands-on lab

Prove that tags move and digests don't:

```bash
docker pull alpine:3.19
docker tag alpine:3.19 localhost:5000/demo:latest
docker run -d --name reg -p 5000:5000 registry:2       # a local registry
docker push localhost:5000/demo:latest                  # note the digest printed
docker pull alpine:3.20 && docker tag alpine:3.20 localhost:5000/demo:latest
docker push localhost:5000/demo:latest                  # same tag, NEW digest
docker pull localhost:5000/demo@sha256:<first-digest>   # the old one is still pullable by digest
docker rm -f reg
```
The tag `latest` now means something different; the first digest still means exactly what it meant before.

---

## Where you'll use it

- Every promotion pipeline (topics 09, 63, 72).
- Rollbacks: redeploy the previous **digest**, which is guaranteed to be the old bits.
- Incident response: "which commit is in prod?" Read the digest → manifest → `commit_sha`.
- Security: answering "are we affected by CVE-X?" from SBOMs.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| Prod behaves differently from staging with the "same version" | Rebuilt per environment, or deployed a moved tag | Build once; deploy by digest |
| `manifest unknown` when deploying | Digest typo or image deleted by a cleanup policy | Verify with `imagetools inspect`; protect released images from cleanup |
| Rollback to `:latest` deploys something new | `latest` moved | Never deploy `latest`; keep a history of deployed digests |
| ECR: `tag invalid: The image tag 'v1' already exists … cannot be overwritten because the repository is immutable` | Immutable tags enabled (good) | Use a new version/commit tag |

---

## Quick recap

- **Build once, promote many**: never rebuild per environment.
- **Tags** are movable labels for humans; **digests** (`sha256:…`) are immutable content IDs, so deploy by digest.
- Record each build in a `manifest.json` (image, digest, commit, version, time).
- Jenkins archives are for small records; real artifacts belong in registries/repositories.
- SBOMs list what's inside; signatures prove who built it.

**Interview questions**

1. **Q: Why deploy by digest instead of tag?**
   A: Tags can be overwritten, so the same tag may point to different images over time. A digest is the hash of the image content, so it always means exactly the image that was tested.

2. **Q: What does "build once, promote many" mean?**
   A: CI builds one artifact. Every environment deploys that same artifact with only its config changed, so what passed staging is byte-for-byte what reaches production.

3. **Q: What is an SBOM and why do you need it?**
   A: A list of every component and version in an artifact. When a new CVE is published, it lets you find affected images immediately instead of rescanning everything.
