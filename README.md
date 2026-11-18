![Jenkins – Basics to Production](https://img.shields.io/badge/Jenkins-Basics_to_Production-blue?style=for-the-badge&logo=jenkins&logoColor=white)

# Jenkins: From Zero to Production

> **📘 Restructured learning path:** the original *Jenkins: Basics to Production* `Day NN/`, `shared-library/` and `Project 01/` notes have been reorganised into one ordered course of **77 topics** in [`notes/`](notes/), updated to current Jenkins LTS practice (November 2026: Java 21/25, the 2026 repo key, Pipeline Graph View, EKS access entries…), with every correction marked **⚠️ Corrected** in the topic where it applies. Start at **[INDEX.md](INDEX.md)**. **[COVERAGE.md](COVERAGE.md)** shows where every original section, image and file now lives; **[ANALYSIS.md](ANALYSIS.md)** lists what was wrong or missing in the originals. The original Day folders aren't included here; they're in the original course repo: [CloudWithVarJosh/Jenkins-Basics-To-Production](https://github.com/CloudWithVarJosh/Jenkins-Basics-To-Production).

Based on the **Jenkins: Basics to Production** course by **CloudWithVarJosh**.

### Course Introduction:
[![Watch the video](https://img.youtube.com/vi/bBx6UfQP1Lo/maxresdefault.jpg)](https://www.youtube.com/watch?v=bBx6UfQP1Lo&ab_channel=CloudWithVarJosh)

### Course Playlist:
[Jenkins: Basics to Production Playlist](https://www.youtube.com/playlist?list=PLmPit9IIdzwSiYCKOtXUGNwytXXiJ8Rv8)

---

## What you'll find in this repository

* **One ordered learning path:** 77 topics in `notes/`, in dependency order, in 12 parts: CI/CD foundations → Jenkins architecture → Freestyle → credentials → Docker → pipelines as code → multibranch → agents → shared libraries → a DevSecOps project on EKS → running Jenkins in production → troubleshooting and interviews (see [INDEX.md](INDEX.md)).
* **The same shape in every topic:** What it is · Why it exists · Analogy · How it works inside · Config/Jenkinsfile/commands with sample output · Hands-on lab · Where you'll use it · When it breaks · Quick recap + interview questions.
* **Project files:** every original app, Jenkinsfile, manifest and shared-library file in [`project-files/`](project-files/), unchanged, with fixed versions alongside as `*.corrected` files.
* **Diagrams:** the original course images plus new diagrams for the build lifecycle, pipeline execution, agents, Kubernetes agents, credentials, security and GitOps.
* **Interview prep:** recap questions in every topic, a question bank (topic 75), production scenarios (74), a troubleshooting catalog (73) and a cheat sheet (77).

## Your lab

Jenkins in Docker on a WSL2 Docker Engine; agents as local containers; Kubernetes agents on kind. The AWS labs (EC2, ECR, EKS) are clearly marked and cost money. Delete the resources when you're done.

## A note on accuracy

Facts that change often were checked against official sources in November 2026 (see the verification note in [INDEX.md](INDEX.md)). The labs were **written, not executed**: sample outputs show the expected *shape*, so trust your own terminal when it differs.

## How to use this repository

```bash
git clone https://github.com/tushhar-mishra/jenkins-notes.git
cd jenkins-notes
# open INDEX.md and start at topic 01
```

## Credits

Original course and material: **Varun Joshi / CloudWithVarJosh**: [YouTube](https://www.youtube.com/@CloudWithVarJosh) · [GitHub](https://github.com/CloudWithVarJosh) · [LinkedIn](https://www.linkedin.com/in/varun-joshi-2b516752/).
