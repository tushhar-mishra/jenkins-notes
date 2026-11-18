# 27 · Lab: Docker-outside-of-Docker Setup

> **Level:** ★★ intermediate · **Status:** ✅ rewritten from your notes (two corrections)
>
> **You will learn:** how to give your lab Jenkins container access to the host's Docker daemon: mount the socket, grant permission the **safe** way (group ID, not `chmod 666`), install **only** the Docker CLI (in a custom image, so it survives recreation), and verify.
>
> **You need:** topics 14, 25, 26.
>
> **From your original notes:** Day 05 › *Introduction*, *Step 1: Recreate Jenkins with the Docker socket mounted* (what this does, what is docker.sock, note), *Step 2: Allow the Jenkins user to talk to the socket*, *Step 3: Install the Docker CLI inside the Jenkins container*, *Step 4: Verify from inside Jenkins*, *Quick FAQ*.
>
> 🎥 Original video: [Build, Push & Run a Flask App with Jenkins (DooD)](https://www.youtube.com/watch?v=UYlVTs_yK8U&ab_channel=CloudWithVarJosh)

---

## What it is

Today we make Jenkins actually *ship* something. We set up **Docker-outside-of-Docker (DooD)** so the Jenkins container can use the host's Docker Engine. Topic 28 then builds a small **Flask** app, **containerizes** it, **pushes** the image to a **private Docker Hub repository**, and **deploys** it on the host for a smoke test: **code → image → private registry → running container**, with secrets kept in Jenkins Credentials.

⚠️ This setup gives Jenkins (and every build) root-level control of your Docker host (topic 25). It's for a **personal lab only**.

---

## Why it exists

Our lab Jenkins has no agents yet, and the controller container has no Docker. DooD is the quickest way to let builds run `docker build/push/run` while we learn pipelines. Part 8 replaces it with proper agents.

---

## Analogy

Running an extension cable (the socket mount) from the main building's power (host daemon) into your shed (Jenkins container), and fitting only a plug (the CLI) on your side. No generator in the shed.

---

## How it works inside

```
WSL2 host                                     Jenkins container
──────────                                    ─────────────────
dockerd (root)                                docker CLI  (installed in the image)
  ▲ listens on /var/run/docker.sock  ◀──bind──  /var/run/docker.sock (same file)
  │                                           user jenkins (uid 1000), extra group = socket's GID
  └─ builds images, runs "sibling" containers
```

---

## Config / Jenkinsfile / commands

### Step 1: install the Docker CLI in a custom Jenkins image

We already persist Jenkins state in the **named volume** `jenkins_home`, so recreating the container won't lose plugins, jobs or config. Instead of installing the CLI inside a running container (lost on every recreate), bake it into an image:

`~/jenkins-dood/Dockerfile`:
```dockerfile
FROM jenkins/jenkins:lts-jdk21
USER root
# Install ONLY the Docker CLI (+ buildx plugin), not the engine
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && chmod a+r /etc/apt/keyrings/docker.asc \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*
USER jenkins
```
```bash
cd ~/jenkins-dood && docker build -t jenkins-dood:lts-jdk21 .
```
- The Jenkins image is Debian-based, so we use Docker's **Debian** apt repository.
- `docker-ce-cli` = the client only; `docker-buildx-plugin` = the `docker buildx`/BuildKit client plugin.
- `USER jenkins` at the end: the image still runs Jenkins as non-root.

> ⚠️ **Corrected:** the original Step 3 says "We're installing **only the client**, not a daemon" but runs `curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh` inside the running container. Now: install `docker-ce-cli` only, in a Dockerfile, because the convenience script installs the **whole Docker Engine** (`docker-ce`, `containerd.io`, plugins), which you don't want or need inside the Jenkins container, and anything installed with `docker exec` disappears the next time the container is recreated. (Docker also says the convenience script isn't meant for production.)

### Step 2: recreate Jenkins with the Docker socket mounted, with the right group

Find the group ID (**GID**) that owns the socket on the host:
```bash
stat -c '%G %g' /var/run/docker.sock
```
```
docker 989
```

```bash
docker rm -f jenkins 2>/dev/null || true

docker run -d --name jenkins --restart unless-stopped \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  -e TZ=Asia/Kolkata \
  jenkins-dood:lts-jdk21
```
**What this does:**
- `-v /var/run/docker.sock:/var/run/docker.sock` shares the **host's Docker daemon** with the Jenkins container. By mounting the socket, the **docker CLI inside the container** sends its commands to the **Docker daemon on the host** (your WSL2 Ubuntu here; a Mac in the original lecture). The container controls the host's Docker engine: fast for labs, powerful, use with care.
- `--group-add 989` makes the container's `jenkins` user a member of **GID 989** as well, the group that owns the socket, so it can connect **without** changing the socket's permissions.

### Step 3: allow the Jenkins user to talk to the socket (understanding the permissions)

Check what the container sees:
```bash
docker exec -it jenkins ls -l /var/run/docker.sock
docker exec -it jenkins id
```
```
srw-rw---- 1 root 989 0 Nov 18 09:12 /var/run/docker.sock
uid=1000(jenkins) gid=1000(jenkins) groups=1000(jenkins),989
```
The group shows as a bare number (`989`) because that GID has no name inside the container's `/etc/group`. That doesn't matter: permission checks use the number.

> ⚠️ **Corrected:** the original Step 2 used the "lab-simple option" `docker exec -u root -it jenkins chmod 666 /var/run/docker.sock` (world read/write). Now use `--group-add <socket GID>`, because `666` lets **every process and every container user** on the host control a root daemon (instant root for anything that can reach the file), and as your notes say, Docker recreates the socket on every daemon restart or reboot, so the `chmod` silently disappears and builds start failing. The group approach is both safer and persistent. (Your notes already pointed at it: "map the socket's group and add `jenkins` to it"; on a plain Linux host, that's `usermod -aG docker jenkins`, topic 51.)

### Step 4: verify from inside Jenkins

```bash
docker exec -it jenkins bash -lc 'docker version && docker ps'
```
You should see:
```
Client: Docker Engine - Community
 Version:           29.0.1
...
Server: Docker Engine - Community
 Engine:
  Version:          29.0.1
...
CONTAINER ID   IMAGE                    ...   NAMES
a1b2c3d4e5f6   jenkins-dood:lts-jdk21   ...   jenkins
```
- `Client: Docker Engine - Community`: the CLI is present.
- `Server: Docker Engine - Community`: it's talking to the host daemon.
- `docker ps` lists your **jenkins** container itself, proof that the CLI uses the **host's** daemon.

Now verify **from a build** (what really matters). Freestyle job, Execute shell:
```bash
id
docker info --format 'daemon: {{.Name}} ({{.ServerVersion}})'
```
```
uid=1000(jenkins) gid=1000(jenkins) groups=1000(jenkins),989
daemon: wsl-ubuntu (29.0.1)
```

### Quick FAQ

- **Are we "installing Docker in Jenkins"?** We install **the Docker CLI** in the Jenkins image. The **daemon** is the host's; we reach it through the mounted socket.
- **Why not run a daemon inside Jenkins (DinD)?** It needs `--privileged`, more moving parts and has slower caches. Fine for labs, but DooD is simpler here (topic 26).
- **Is the socket mount safe?** It grants broad control over the host daemon. OK for a personal lab; in real setups prefer Docker-enabled **agents** or **daemonless** builders.
- **Will my Jenkins data persist across container recreates?** Yes, because `-v jenkins_home:/var/jenkins_home` stores state in a named volume.
- **Will the group survive a reboot?** Yes. `--group-add` is part of the container's config, and the host socket keeps its group across daemon restarts.

---

## Hands-on lab

1. Build `jenkins-dood:lts-jdk21` and recreate the container as above. Log in: your jobs are still there.
2. Run the verification build. Then remove `--group-add` (recreate without it) and run it again to read the `permission denied … docker.sock` error. Put `--group-add` back.
3. From a build: `docker run --rm hello-world`. On the host, `docker ps -a` shows it ran as a sibling.
4. Save the run command as a script `~/jenkins-dood/run.sh` so you can recreate Jenkins any time.

---

## Where you'll use it

- Topics 28, 36 and 47 (Flask projects) and the shared-library labs (57).
- Quick local CI experiments.
- Understanding (and spotting) socket mounts in real environments.

---

## When it breaks

| Error | Cause | Fix |
|---|---|---|
| `permission denied while trying to connect to the Docker daemon socket` | Missing `--group-add`, or the wrong GID | Re-check `stat -c %g` on the host; recreate |
| `docker: not found` in builds | Running the plain `jenkins/jenkins` image | Use your `jenkins-dood` image |
| `Cannot connect to the Docker daemon … Is the docker daemon running?` | Socket not mounted, or Docker on the host is stopped | Add the `-v …docker.sock…` mount; `sudo systemctl start docker` |
| Works until Docker restarts, then permission denied | You used `chmod 666` | Use the group method |
| Docker Desktop (Mac/Windows): socket GID is `0`/root | Desktop exposes the socket differently | `--group-add 0` in the lab, or use a Docker agent instead |

---

## Quick recap

- DooD = mount `/var/run/docker.sock` + **CLI only** in the Jenkins image.
- Grant access with **`--group-add <socket GID>`**, not `chmod 666`.
- Bake the CLI into a custom image so it survives recreation; don't use `get.docker.com` inside it.
- Verify with `docker version` (client + server) and `docker ps` showing the jenkins container itself.
- Lab only: it's root on the host.

**Interview questions**

1. **Q: How do you let a containerised Jenkins run Docker commands?**
   A: Either mount the host Docker socket and install the Docker CLI (DooD), granting the container user the socket's group, or, better in production, run builds on Docker-enabled agents or with daemonless builders.

2. **Q: Why is `chmod 666 /var/run/docker.sock` a bad idea?**
   A: It lets any local user or container control a root daemon, which is root on the host. It's also reset whenever Docker restarts. Match the socket's group instead.

3. **Q: Why doesn't installing tools with `docker exec` last?**
   A: Changes in a container's writable layer are lost when it's recreated. Bake tools into a custom image.
