# 14 · Lab: Jenkins in Docker

> **Level:** ★ foundation · **Status:** ✅➕ rewritten and expanded
>
> **You will learn:** how to run your lab Jenkins in Docker (on the WSL2 Docker Engine from your Docker notes), what every flag does, how the setup wizard works, how `/var/jenkins_home` keeps your state, and how to do the same with Docker Compose.
>
> **You need:** topics 12–13, plus a working Docker Engine ([Docker notes topic 04](../../Docker/notes/04-installing-docker.md)).
>
> **From your original notes:** Day 03 › *Lab setup: Jenkins in Docker* (Run Jenkins, Flag breakdown, First-time setup, Handy commands), *Understanding `/var/jenkins_home`* (tips + note).

---

## What it is

We learn the **basics on a single-node Jenkins running in Docker**: fast to start, easy to reset. When we move to **projects and production patterns**, we'll add agents (Part 8), a VM install (topic 49) and Kubernetes (topics 53–54).

---

## Why it exists

A container gives you a clean, disposable Jenkins in one command, identical on every laptop. Keeping its state on a **volume** means you can delete and recreate the container (to change flags, upgrade, or add the Docker socket in topic 27) without losing jobs, plugins or credentials.

---

## Analogy

A **rented office with your own filing cabinet**. The office (container) can be swapped for a new one any time; your filing cabinet (the `jenkins_home` volume) is wheeled into whichever office you use, so all your paperwork is always there.

---

## How it works inside

### Docker recap (the parts this lab uses)

- `docker run` creates and starts a container from an image (Docker notes topic 05).
- `-p HOST:CONTAINER` **publishes a port**: traffic to the host's port is forwarded into the container (Docker notes topic 28).
- `-v NAME:/path` mounts a **named volume** (storage managed by Docker, living outside the container's own filesystem) at `/path`. Deleting the container doesn't delete the volume (Docker notes topic 24).
- The official image runs Jenkins as a non-root Linux user **`jenkins` (UID 1000)**, with `JENKINS_HOME=/var/jenkins_home`.

### What happens when you run it

1. Docker pulls `jenkins/jenkins:lts-jdk21` (a Debian-based image with Java 21 and `jenkins.war`).
2. It creates the volume `jenkins_home` if it doesn't exist and mounts it at `/var/jenkins_home`. On first use, the image's startup script copies its default reference files in (logged to `copy_reference_file.log`).
3. The entrypoint runs `java … -jar /usr/share/jenkins/jenkins.war`.
4. Jenkins generates an **initial admin password**, writes it to `/var/jenkins_home/secrets/initialAdminPassword`, prints it in the log, and serves the **setup wizard** on port 8080.

---

## Config / Jenkinsfile / commands

### Run Jenkins

```bash
docker run -d \
  --name jenkins \
  --restart unless-stopped \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -e TZ=Asia/Kolkata \
  jenkins/jenkins:lts-jdk21
```

**Flag breakdown:**

| Flag | Meaning |
|---|---|
| `-d` | Run in the background (detached). |
| `--name jenkins` | A fixed name, easy to reference (`docker logs jenkins`). |
| `--restart unless-stopped` | Start it again automatically when Docker restarts (e.g. after a reboot), unless you stopped it yourself. |
| `-p 8080:8080` | UI at `http://localhost:8080`. |
| `-p 50000:50000` | The **inbound agent TCP port** (topic 12; formerly called JNLP). Only needed for TCP inbound agents (topic 52). Harmless to keep in the lab. |
| `-v jenkins_home:/var/jenkins_home` | **Persistent data**: jobs, plugins, config, credentials, build history. |
| `-e TZ=Asia/Kolkata` | Container timezone (shell commands, log timestamps). Use your own zone. |
| `jenkins/jenkins:lts-jdk21` | The current **LTS** line on **Java 21**. |

> ⚠️ **Corrected:** was `jenkins/jenkins:lts`. Now `jenkins/jenkins:lts-jdk21`, and for anything beyond a lab, an **exact** version tag such as `jenkins/jenkins:2.568.2-lts-jdk21` (check the current one on [Docker Hub](https://hub.docker.com/r/jenkins/jenkins/tags)). That's because `lts` silently moves to a new baseline on your next `docker pull`, changing the Jenkins version (and maybe the Java version) under your plugins. Pinning makes upgrades a deliberate step (topic 68).

> Note: we **don't** set `-u root`. Jenkins runs as the default non-root `jenkins` user, as it should.

On Windows: run these commands inside your **WSL2 Ubuntu** shell, where your Docker Engine lives. `localhost:8080` works from the Windows browser too, because WSL2 forwards localhost ports.

### First-time setup

1. Get the initial password:
   ```bash
   docker logs jenkins 2>&1 | grep -A2 "following password"
   # or
   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```
   ```
   Please use the following password to proceed to installation:
   5d3c8f1a9b7e4c2d8a6f0e1b2c3d4e5f
   ```
2. Open `http://localhost:8080` → paste the password → **Install suggested plugins** (a curated set: Git, Pipeline, Credentials Binding, Pipeline Graph View, Workspace Cleanup, Timestamper, GitHub Branch Source, etc.).
3. **Create the first admin user** (don't keep using the initial password).
4. **Instance configuration:** set the Jenkins URL to `http://localhost:8080/` for now (topic 21 changes it for webhooks).
5. You're on the dashboard, ready to create jobs.

### Handy commands

```bash
docker exec -it jenkins bash                 # shell inside (as user jenkins)
docker exec -u root -it jenkins bash         # shell as root (for installing tools in the lab)
docker restart jenkins                       # restart Jenkins
docker stop jenkins && docker start jenkins  # stop/start
docker logs -f jenkins                       # follow the Jenkins log
docker volume inspect jenkins_home           # where the volume lives on the host
```

### Understanding `/var/jenkins_home` (your Jenkins *state*)

This path holds the **controller's persisted state**, not the build "data plane". Everything the controller needs is here: **jobs/pipelines, build history/logs, plugins, global config, credentials, node definitions, UI settings**. Keep it **outside the container's filesystem** so a crash or recreate doesn't lose data.

In our lab, we mount a **Docker named volume**:
```bash
-v jenkins_home:/var/jenkins_home
```
If the container dies or is replaced, reattach the same volume and Jenkins comes back exactly as it was. In production, consider **bind mounts** (a host directory) or **network/block storage** with snapshots and encryption.

**Tips:**
- Treat it as **sensitive**: it contains secrets and the keys that decrypt them. Back it up and restrict access.
- Keep it **lean** by running heavy workspaces on agents; discard old builds.
- Test **backup/restore** regularly (topic 68).

> **Note:** if `/var/jenkins_home` is on a persistent volume and you reuse it when recreating the container, **all prior state returns**: jobs, build history, credentials, configs and **plugins**. Keep the Jenkins image/version consistent (or upgrade deliberately), make sure ownership stays `jenkins:jenkins` (UID 1000), and back up before changes.

Topic 16 tours every file in it.

### The same thing with Docker Compose

`compose.yaml` (Docker notes topic 35):
```yaml
services:
  jenkins:
    image: jenkins/jenkins:lts-jdk21
    container_name: jenkins
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    environment:
      TZ: Asia/Kolkata
      JAVA_OPTS: "-XX:MaxRAMPercentage=75"
    volumes:
      - jenkins_home:/var/jenkins_home
volumes:
  jenkins_home:
    name: jenkins_home   # reuse the same volume as the docker run version
```
```bash
docker compose up -d && docker compose logs -f jenkins
```
`JAVA_OPTS: -XX:MaxRAMPercentage=75` lets the JVM heap use up to 75% of the container's memory limit (topic 12).

---

## Hands-on lab

1. Run Jenkins with the command above and complete the setup wizard.
2. Create a Freestyle job `hello` with an **Execute shell** step `echo hello` (topic 17 explains this properly). Build it once.
3. **Prove persistence:**
   ```bash
   docker rm -f jenkins
   docker run -d --name jenkins --restart unless-stopped -p 8080:8080 -p 50000:50000 \
     -v jenkins_home:/var/jenkins_home -e TZ=Asia/Kolkata jenkins/jenkins:lts-jdk21
   ```
   Log in: your user, the `hello` job and build `#1` are all still there. No setup wizard this time.
4. Look inside the volume:
   ```bash
   docker exec jenkins ls -la /var/jenkins_home
   docker exec jenkins ls /var/jenkins_home/jobs/hello/builds/1
   ```
   ```
   build.xml  changelog.xml  log
   ```
   `log` is the console output of build #1; `build.xml` is its record.
5. Check the version: `curl -sI http://localhost:8080/login | grep X-Jenkins`.

---

## Where you'll use it

- Your lab for Parts 3–7 and most of Parts 8–9.
- Quick local experiments (trying a plugin, testing a Jenkinsfile) at work.
- Small teams sometimes run exactly this in production, with agents on other machines and backups of the volume.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `Bind for 0.0.0.0:8080 failed: port is already allocated` | Something else uses 8080 | `-p 8081:8080` and browse to 8081, or stop the other thing |
| `touch: cannot touch '/var/jenkins_home/copy_reference_file.log': Permission denied` | You used a **bind mount** owned by root | `sudo chown -R 1000:1000 /path/on/host` |
| Setup wizard appears again after recreate | You forgot the `-v` flag or used a different volume name | Recreate with the same `-v jenkins_home:/var/jenkins_home` |
| Container restarts in a loop, log shows `OutOfMemoryError` | Too little memory for the JVM | Give Docker/WSL2 more memory; set `JAVA_OPTS` |
| Plugin install fails: `java.net.UnknownHostException: updates.jenkins.io` | No DNS/internet from the container (proxy, VPN) | Fix Docker DNS/proxy (Docker notes topic 34); configure **Manage Jenkins → Plugins → Advanced → HTTP proxy** |

---

## Quick recap

- `docker run … -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts-jdk21` gives a full Jenkins whose state survives the container.
- Port 8080 = UI; 50000 = inbound agents (optional).
- Unlock with `secrets/initialAdminPassword`, install suggested plugins, create an admin.
- `/var/jenkins_home` is the **controller's state**: sensitive, back it up.
- Pin exact image versions beyond the lab.

**Interview questions**

1. **Q: How do you persist Jenkins data when running it in Docker?**
   A: Mount `/var/jenkins_home` on a named volume or persistent storage; recreating the container with the same volume restores everything.

2. **Q: Why not run the Jenkins container as root?**
   A: Least privilege. Build steps on the controller would run as root inside the container, and any escape or misconfigured mount would have root power on the host.

3. **Q: Why pin the Jenkins image tag?**
   A: Floating tags like `lts` change versions on the next pull, which can break plugins or change Java. Pinning makes upgrades deliberate and reproducible.
