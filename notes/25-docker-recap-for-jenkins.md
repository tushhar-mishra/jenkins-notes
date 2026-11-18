# 25 · Docker and Linux Recap for Jenkins

> **Level:** ★★ intermediate · **Status:** 🆕 new topic (built from the Day 05 socket explanation)
>
> **You will learn:** exactly how the `docker` command talks to the Docker daemon (through a **Unix domain socket**), how Linux file permissions and groups decide who may use that socket, and why access to the socket is **the same as root** on the host. Jenkins' Docker builds depend on all three.
>
> **You need:** topic 04 (images/Dockerfiles). Background: [Docker notes 03 · architecture](../../Docker/notes/03-docker-architecture.md), [Linux notes 024 · groups](../../linux-mastery-rhel/notes/024-groups.md), [026 · file permissions](../../linux-mastery-rhel/notes/026-file-permissions-and-umask.md).
>
> **From your original notes:** Day 05 › *Why we're doing this*, *What is `docker.sock`?*, the note on the socket being owned by `root:root`.

---

## What it is

Up to now we ran Jenkins in a container and built simple projects. As we move to **containerized apps**, builds must **build images and push them to a container registry**. So Jenkins needs a tool that can create **OCI-compliant images** (**OCI** = Open Container Initiative, the open standard for image and runtime formats, so any compliant runtime can run them). We'll use **Docker**.

Docker has two halves:
- **`docker` CLI (client):** the command you type. It does no real work; it sends **API requests**.
- **`dockerd` (daemon):** a background service running **as root** that builds images, pulls/pushes, and creates containers (via containerd and runc).

They talk through a **Unix domain socket** at `/var/run/docker.sock`.

---

## Why it exists

Every "Jenkins + Docker" setup (topics 26–28) is really a question of **which daemon the Jenkins user's `docker` CLI talks to, and through which socket**. If you understand the socket, you understand both the setup *and* its security risk.

---

## Analogy

The Docker daemon is a powerful **robot in a locked room** (running as root). The socket is the **intercom on the door**. Whoever can press the intercom button can tell the robot to do anything, including "open the building's master safe". File permissions decide who can reach the intercom.

---

## How it works inside

### Unix domain sockets

On Linux, processes on the **same machine** can talk using **Unix domain sockets**: special files (often ending in `.sock`) that act as communication endpoints. They're a form of **IPC** (Inter-Process Communication) and **don't use TCP/IP networking**: no port, no IP address, just a path on the filesystem.

`/var/run/docker.sock` is the Unix socket where the **Docker daemon** listens for API requests. The `docker` CLI sends commands (build, run, push…) through it as HTTP requests:

```
docker ps  ──HTTP GET /v1.47/containers/json──▶  /var/run/docker.sock  ──▶  dockerd (root)
```
You can see this yourself:
```bash
curl --unix-socket /var/run/docker.sock http://localhost/version
```
```json
{"Platform":{"Name":"Docker Engine - Community"},"Version":"29.0.1","ApiVersion":"1.52",...}
```

If you **mount this file into a container**, commands inside that container control the **host's** Docker daemon. That's powerful, so handle it with care. Topic 27 does exactly this.

### Who may use the socket: permissions and groups

```bash
ls -l /var/run/docker.sock
```
```
srw-rw---- 1 root docker 0 Nov 18 09:12 /var/run/docker.sock
```
Reading `srw-rw----` (Linux notes topic 026):
- `s` = it's a **socket** (not a regular file `-` or directory `d`).
- `rw-` (owner **root**) = root can read/write (= connect).
- `rw-` (group **docker**) = members of the `docker` group can connect.
- `---` (others) = nobody else can.

So a user can run `docker` without `sudo` **only if they're in the `docker` group**:
```bash
sudo usermod -aG docker jenkins     # add the jenkins user to the docker group
id jenkins
```
```
uid=999(jenkins) gid=999(jenkins) groups=999(jenkins),989(docker)
```
Group changes apply only to **new** login sessions/processes: restart the Jenkins service or reconnect the agent afterwards.

> In the original Day 05 notes the socket showed `srw-rw---- root root`. On Docker Desktop and some VMs, the socket inside a mounted container shows group `root` (or a numeric GID) rather than `docker`, because the group belongs to the *host* and the container has its own `/etc/group`. That's the "GID mismatch" topic 27 solves.

### Why socket access = root on the host

The daemon runs as root and does what the API asks. Anyone who can talk to the socket can run:
```bash
docker run --rm -it --privileged -v /:/host alpine chroot /host sh
```
…and get a **root shell on the host**, reading every file, every key, every other container's secrets. So:
- **Being in the `docker` group is equivalent to having root.**
- **Mounting `docker.sock` into a container gives that container root on the host.**
- A Jenkins build that can use the socket can do anything to the machine: take over other builds, read other jobs' workspaces, steal credentials.

That's why production setups isolate Docker builds (topic 26).

### The Docker context: which daemon am I talking to?

The CLI decides the daemon from (in order): `DOCKER_HOST` (e.g. `unix:///var/run/docker.sock`, `tcp://10.0.0.5:2376`, `ssh://user@host`), the current **docker context**, or the default socket.
```bash
docker context ls
echo "$DOCKER_HOST"
```
Remote daemons over plain TCP (port 2375) have **no authentication**. Never expose one; use TLS (2376) or SSH.

### Images, tags and registries (one-paragraph recap)

Image names are `registry/namespace/repository:tag` (e.g. `docker.io/cloudwithvarjosh/cwvj-flask:42`). `docker build -t NAME:TAG .` builds from the Dockerfile in `.` (the **build context**). `docker push` uploads to the registry (after `docker login`). `docker pull` downloads. Every image has an immutable **digest** (topic 07). Docker notes topics 06, 14 and 22 have the details.

---

## Config / Jenkinsfile / commands

Diagnosing Docker access from a Jenkins build (put this in any shell step):

```bash
id
ls -l /var/run/docker.sock
docker version --format 'client {{.Client.Version}} / server {{.Server.Version}}'
docker info --format '{{.Name}}'
```
Healthy:
```
uid=1000(jenkins) gid=1000(jenkins) groups=1000(jenkins),989(docker)
srw-rw---- 1 root docker 0 Nov 18 09:12 /var/run/docker.sock
client 29.0.1 / server 29.0.1
wsl-ubuntu
```
Broken:
```
permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock:
Get "http://%2Fvar%2Frun%2Fdocker.sock/v1.47/version": dial unix /var/run/docker.sock: connect: permission denied
```
→ the user isn't in a group that can use the socket (or the group change hasn't taken effect yet).

---

## Hands-on lab

On your WSL2 Docker host:
1. `ls -l /var/run/docker.sock` and `id`. Are you in `docker`?
2. Talk to the daemon without the CLI:
   ```bash
   curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json | head -c 300
   ```
   It's the same data `docker ps` shows: the CLI is just an HTTP client.
3. See the risk (lab only, then exit immediately):
   ```bash
   docker run --rm -it -v /:/host alpine sh -c 'cat /host/etc/shadow | head -3'
   ```
   A container just read the host's password hashes. Whoever controls the socket controls the host.

---

## Where you'll use it

- Setting up any Jenkins that builds images (topics 26–28, 51, 62).
- Debugging `permission denied … docker.sock`.
- Security reviews: "who can reach a Docker socket in our CI?"

---

## When it breaks

| Error | Meaning | Fix |
|---|---|---|
| `permission denied while trying to connect to the Docker daemon socket` | User not in the socket's group / new group not picked up | Add to the group; restart the service or reconnect the agent |
| `Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?` | dockerd down, socket not mounted, or wrong `DOCKER_HOST` | `systemctl status docker`; check the mount and context |
| `docker: command not found` | CLI not installed on that node/container | Install the CLI only (topic 27) |
| `client version 1.52 is too new. Maximum supported API version is 1.43` | CLI newer than the daemon | Use a matching CLI or set `DOCKER_API_VERSION` |

---

## Quick recap

- `docker` CLI → HTTP over the Unix socket `/var/run/docker.sock` → `dockerd` (root).
- `srw-rw---- root docker`: only root and the `docker` group can use it.
- **`docker` group membership or a mounted socket = root on the host.**
- `DOCKER_HOST`/contexts decide which daemon you talk to.

**Interview questions**

1. **Q: What is `/var/run/docker.sock`?**
   A: The Unix domain socket where the Docker daemon listens for API requests. The `docker` CLI sends HTTP requests through it.

2. **Q: Why is adding a user to the `docker` group a security risk?**
   A: It lets them control a root daemon, so they can start a privileged container that mounts the host's filesystem. That's effectively root on the host.

3. **Q: A Jenkins job says "permission denied" on docker.sock. Steps?**
   A: Check `id` and `ls -l /var/run/docker.sock` on the node, add the Jenkins user to the socket's group (matching the GID if it's in a container), then restart Jenkins or reconnect the agent so the new group applies.
