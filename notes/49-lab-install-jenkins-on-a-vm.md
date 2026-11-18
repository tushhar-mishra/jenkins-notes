# 49 · Lab: Install Jenkins on a Linux VM

> **Level:** ★★ intermediate · **Status:** 🔀 merged (Project 01 + shared-library labs + Day 03 VM example)
>
> **You will learn:** how to install the Jenkins controller from the official Linux packages on a VM (AWS EC2 Ubuntu 24.04, or a local VM), with Java 21, the current repo key, a systemd override for JVM options and timezone, the security group, unlocking, and the "lab mode" extras (running builds on the controller, Docker Engine, the `docker` group) with their security warnings.
>
> **You need:** topics 12, 13, 48.
>
> **From your original notes:** Project 01 › *Lab: Install Jenkins Controller on EC2* (1–6, incl. the systemd timezone override) · shared-library › *Lab: Install Jenkins Controller on EC2* (Prerequisites, 1–9, *Lab notes and security reminders*) · Day 03 › *VM / Bare Metal* example and notes.
>
> 🎥 Original videos: [Jenkins Shared Library Tutorial](https://www.youtube.com/watch?v=Eql35HIXS4A&ab_channel=CloudWithVarJosh) · [Complete DevSecOps CI/CD Pipeline](https://www.youtube.com/watch?v=9LXZm0Fryfw&ab_channel=CloudWithVarJosh)

---

## What it is

The classic production-style install: Jenkins as a **systemd service** on a Linux VM, state in `/var/lib/jenkins`. Two variants from your notes:
- **Project 01:** the VM acts **only as the controller**; all pipeline work runs on SSH agents (topic 51). ✅ The production pattern.
- **Shared-library lab:** the VM acts **both as controller and runner** ("lab mode"). Fine for demos, **not** for production.

---

## Why it exists

Many companies run exactly this: a hardened VM with the Jenkins package, managed with Ansible, backed up with disk snapshots. You must be able to build one from scratch.

---

## Analogy

Moving your lab kitchen (Docker) into a **real building** (VM) with its own caretaker (systemd) who opens up every morning (boot) and restarts the ovens if they trip (Restart=on-failure).

---

## How it works inside

```
apt install jenkins → creates user "jenkins", /var/lib/jenkins (JENKINS_HOME), /usr/share/java/jenkins.war,
                      /usr/lib/systemd/system/jenkins.service (runs: java $JAVA_OPTS -jar jenkins.war --httpPort=8080)
systemctl enable --now jenkins → starts at boot; logs to journald
```

---

## Config / Jenkinsfile / commands

### Prerequisites

- An AWS account and permission to create EC2 instances (or a local VM: Multipass/Vagrant/Hyper-V; see the local note below).
- A local SSH key (`<your-key>.pem`) to connect.
- Basic familiarity with `sudo` on Ubuntu.

### 1) Create the EC2 instance

- **AMI:** Ubuntu 24.04 LTS
- **Instance type:** `c7i-flex.large` (eligible under the AWS credits-based free tier)
- **Root volume:** 20 GB or more
- **Security group (jenkins-controller):**
  - Allow **SSH (22)** from **your IP**
  - Allow **TCP 8080** from **your IP** (Jenkins UI). (The original says "HTTP (8080)": it's HTTP traffic on custom TCP port 8080, not the security group's "HTTP" preset, which is port 80.)
  - Port **50000** only if you'll use TCP inbound agents (topic 52).

> **Local alternative (no AWS bill):** create an Ubuntu 24.04 VM with Multipass (`multipass launch 24.04 --name jenkins-vm --cpus 2 --memory 4G --disk 20G` then `multipass shell jenkins-vm`), or use your WSL2 Ubuntu itself (stop the Docker Jenkins first, or run the package on port 8090 via the override below). Every step from 2 onwards is identical.

### 2) Connect and do basic setup

From your workstation, lock down the private key and SSH in:
```bash
chmod 600 ~/path/to/<your-key>.pem
ssh -i ~/path/to/<your-key>.pem ubuntu@<jenkins-controller-public-ip>
```
On the instance, set the hostname and timezone (topic 48):
```bash
sudo hostnamectl set-hostname jenkins-controller
exec bash
sudo timedatectl set-timezone Asia/Kolkata
timedatectl status
```

### 3) Install Java 21 (JDK)

Jenkins LTS **requires** Java 21 (or 25) (topic 12):
```bash
sudo apt update
sudo apt install -y openjdk-21-jdk
java -version
javac -version
```
```
openjdk version "21.0.x" … Ubuntu-…
javac 21.0.x
```
(The controller only needs the **JRE**, `openjdk-21-jre-headless`; your notes install the JDK, which also works and gives you `javac` for experiments.)

### 4) Add the Jenkins repository and install Jenkins

Reference: https://www.jenkins.io/doc/book/installing/linux/
```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | \
  sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins
```
- `signed-by=` tells apt to trust **only this key** for **this repository** (safer than a global trusted key).
- `debian-stable` = the **LTS** repository.

> ⚠️ **Corrected:** Project 01 and the shared-library lab use `https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key`. Now `jenkins.io-2026.key`, because the 2023 key **expired on 26 March 2026** and LTS packages have been signed with the new key since **2.541.1 (January 2026)**. With the old key, `apt update` fails with `NO_PUBKEY 7198F4B714ABFC68` / `The repository … is not signed`. If you have the old setup, just overwrite the keyring file with the new key and `apt update` again.

**RHEL / AlmaLinux / Rocky (dnf):**
```bash
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2026.key
sudo dnf install -y java-21-openjdk jenkins
sudo firewall-cmd --permanent --add-port=8080/tcp && sudo firewall-cmd --reload
```

### Set the Jenkins JVM timezone (systemd override)

Make the Jenkins UI timestamps match the server's timezone by setting `JAVA_OPTS`. If you skip this, the JVM may run in UTC and dashboard/console timestamps won't match your agents' local time.

**Interactive:**
```bash
sudo systemctl edit jenkins
# add:
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Duser.timezone=Asia/Kolkata"
# save and exit
```
**Non-interactive:**
```bash
sudo mkdir -p /etc/systemd/system/jenkins.service.d
cat <<'EOF' | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Duser.timezone=Asia/Kolkata"
EOF
```
> Note (added): the packaged unit already sets `JAVA_OPTS=-Djava.awt.headless=true`. An override **replaces** the whole variable, so keep `-Djava.awt.headless=true` in it (it tells Java there's no display, which servers need). The original override only set the timezone. Other useful settings here: `-Xmx2g`, `Environment="JENKINS_PORT=8090"`.

After creating the override, reload systemd and restart Jenkins.

### 5) Start and enable Jenkins

```bash
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```
```
● jenkins.service - Jenkins Continuous Integration Server
     Loaded: loaded (/usr/lib/systemd/system/jenkins.service; enabled; preset: enabled)
    Drop-In: /etc/systemd/system/jenkins.service.d
             └─override.conf
     Active: active (running) since Tue 2026-11-18 10:15:02 IST; 5s ago
```
`Drop-In: …override.conf` proves your override is applied. (The shared-library lab runs `enable` + `status` but not `start`; the package starts the service after install, so it works there, but after a `daemon-reload` you need a **restart** to apply the override: `sudo systemctl restart jenkins`.)

### 6) Access the Jenkins UI and unlock it

Open `http://<jenkins-controller-public-ip>:8080`. Get the initial admin password on the controller:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
In the UI: install the suggested plugins, create the admin user, finish the setup, and log in.

### 7) Run pipeline workloads on the controller (lab mode only: shared-library lab)

- For that lab, the controller runs build and deploy steps itself (built-in node executors > 0).
- If your pipelines run Docker, install Docker on the controller (next step).
- Running builds on the controller is fine for demos but **not recommended for production** (topic 11).

### 8) Install Docker Engine on the controller (for lab demos)

Use Docker's official steps on Ubuntu hosts that will run containers. Safe on a fresh VM:
```bash
# remove legacy packages if any (safe)
sudo apt remove docker docker-engine docker.io containerd runc -y

# refresh apt cache
sudo apt update

# install helper packages
sudo apt install -y ca-certificates curl gnupg

# prepare keyrings dir
sudo install -m 0755 -d /etc/apt/keyrings

# fetch Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

# add Docker apt repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# refresh and install Docker Engine and plugins
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
(Docker's current docs store the key as `/etc/apt/keyrings/docker.asc` without `gpg --dearmor`; both work. In the `echo` line, `\"$VERSION_CODENAME\"` escapes are inside an outer double-quoted string. They print literal quotes, but apt accepts the line. The simpler form is `$(. /etc/os-release && echo "$VERSION_CODENAME")`.)

### 9) Allow the Jenkins user to run Docker (lab convenience only)

Adding `jenkins` to the `docker` group is convenient for demos but has security implications in production (topic 25: it's root-equivalent):
```bash
sudo usermod -aG docker jenkins
# optionally add the ubuntu user for admin demos
sudo usermod -aG docker ubuntu

# restart Jenkins so the new group membership is picked up
sudo systemctl restart jenkins
```
Verify Docker as the jenkins user:
```bash
docker --version
sudo -u jenkins docker --version
sudo -u jenkins docker ps          # proves socket access, not just that the CLI exists
```

### Lab notes and security reminders

- Adding the Jenkins user to the `docker` group grants container-runtime (root-equivalent) privileges to Jenkins. Fine for learning, risky for production. Use dedicated agent hosts in production.
- Restrict port 8080 to your IP or a VPN. **Do not open it publicly.** For real use, put Jenkins behind a reverse proxy with TLS (topic 65).
- Keep the Jenkins server patched and limit SSH to trusted IPs.
- Put `/var/lib/jenkins` on resilient storage (a separate EBS volume/LVM with snapshots), and set the JVM heap in the override (Day 03 notes).

---

## Hands-on lab

1. Build the VM (EC2 or Multipass) and complete steps 1–6.
2. `sudo systemctl cat jenkins` to see the unit + your override; `journalctl -u jenkins -n 30`.
3. In the UI: **Manage Jenkins → System Information** → check `user.timezone` and `java.version`.
4. Set **Manage Jenkins → Nodes → Built-In Node → Number of executors = 0** (Project 01 style; builds will wait until you add an agent in topic 51).
5. Snapshot the VM disk now (a clean starting point).

---

## Where you'll use it

Topics 51 (agents), 57 (shared libraries on EC2), 62–63 (DevSecOps project); real company installs.

---

## When it breaks

| Symptom | Cause | Fix |
|---|---|---|
| `NO_PUBKEY 7198F4B714ABFC68` | Old 2023 key | Install the 2026 key |
| `Job for jenkins.service failed` + log says `older than the minimum required version (Java 21)` | Java 17 or missing Java | Install Java 21; `update-alternatives --config java` |
| UI unreachable from the browser | Security group / firewall; wrong IP | Allow TCP 8080 from your IP; use the **public** IP |
| Timezone still UTC | Override not reloaded, or a typo | `daemon-reload` + restart; check `systemctl cat jenkins` |
| `permission denied … docker.sock` in builds | Jenkins not restarted after `usermod` | `sudo systemctl restart jenkins` |
| `jenkins.service: start operation timed out` | Slow first start (plugins) on a small VM | More RAM/CPU; raise `TimeoutStartSec` in the override |

---

## Quick recap

- Install Java 21 → add the **2026** repo key + `debian-stable` repo → `apt install jenkins` → systemd override for `JAVA_OPTS` → enable/start → unlock with `initialAdminPassword`.
- Keep `-Djava.awt.headless=true` when you override `JAVA_OPTS`.
- Lab mode (builds + Docker on the controller) is for demos; production sets controller executors to 0 and uses agents.
- Never expose 8080 publicly.

**Interview questions**

1. **Q: How do you set JVM options for a package-installed Jenkins?**
   A: A systemd drop-in (`systemctl edit jenkins`) with `Environment="JAVA_OPTS=…"`, then `daemon-reload` and restart.

2. **Q: Where is `JENKINS_HOME` for the Debian/RPM package?**
   A: `/var/lib/jenkins`, owned by the `jenkins` system user.

3. **Q: After installing, `apt update` fails with a signature error. Why?**
   A: The repository signing key rotated (2023 → 2026 key); install the current key from pkg.jenkins.io.
