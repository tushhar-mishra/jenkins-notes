# 48 · Linux Recap: Users, SSH and Services

> **Level:** ★★ intermediate · **Status:** 🆕 new topic (gathers the Linux explanations from Project 01 and the shared-library lab)
>
> **You will learn:** the Linux pieces every Jenkins server and agent depends on: service users and home directories, `sudo`/`su` (and a common misunderstanding), file permissions on keys, SSH key pairs, `authorized_keys`, `known_hosts`, systemd services and their logs, hostname and time settings. Each one is shown with exactly how Jenkins uses it.
>
> **You need:** basic Linux ([Linux notes](../../linux-mastery-rhel/INDEX.md): [022 users](../../linux-mastery-rhel/notes/022-users-and-accounts.md), [028 sudo/su](../../linux-mastery-rhel/notes/028-sudo-and-su.md), [065 SSH](../../linux-mastery-rhel/notes/065-ssh.md), [037 systemd](../../linux-mastery-rhel/notes/037-systemd-services-and-targets.md), [098 unit files](../../linux-mastery-rhel/notes/098-systemd-unit-files.md), [038 logging](../../linux-mastery-rhel/notes/038-logging-journald-rsyslog-logrotate.md), [069 time](../../linux-mastery-rhel/notes/069-time-sync-chrony.md)).
>
> **From your original notes:** Project 01 › *Connect to the instance* (key permissions, hostname, timezone), *Create a dedicated jenkins user*, *Generate SSH key…*, *Copy the public key to the agent* (incl. the password note, permissions, test, "Why this matters"), *Host key verification strategies*, SonarQube *systemd unit explanations* · shared-library › *Connect to the instance and basic setup*.

---

## What it is

| Linux concept | How Jenkins uses it |
|---|---|
| **Service user** (`jenkins`) | The controller runs as `jenkins` (home `/var/lib/jenkins` for packages); agents run builds as a `jenkins` user (home `/home/jenkins`) |
| **Permissions** | Who can read `JENKINS_HOME`, SSH keys, the Docker socket |
| **SSH keys** | The controller logs in to SSH agents with a private key; the agent trusts the public key in `authorized_keys` |
| **known_hosts** | The controller verifies it's talking to the real agent |
| **systemd** | Starts Jenkins (`jenkins.service`), Docker, SonarQube; restarts on failure; holds JVM options |
| **journald** | Where the Jenkins service log goes (`journalctl -u jenkins`) |
| **hostname / timezone** | Readable node names; correct timestamps |

---

## Why it exists

Most "Jenkins" agent problems are really Linux problems: wrong key permissions, the wrong user's home directory, an untrusted host key, a service that didn't pick up a new group.

---

## Analogy

Jenkins is the manager; Linux is the building. The manager can only enter rooms their key card (user + permissions) opens, must recognise the right building by its sign (host key), and relies on the building's caretaker (systemd) to keep the lights on.

---

## How it works inside

### Users and switching users

- `sudo useradd -m -s /bin/bash jenkins`: create a user with a **home directory** (`-m` → `/home/jenkins`) and the **bash** login shell (`-s`). Used on agents (Project 01).
- The Jenkins **package** on the controller creates a **system user** `jenkins` with home `/var/lib/jenkins` (= `JENKINS_HOME`).
- `sudo su - jenkins` or `sudo -i -u jenkins`: become `jenkins` with **its** environment and home. `-`/`-i` = a login shell, so `~` means `/var/lib/jenkins` (controller) or `/home/jenkins` (agent).
- `sudo -u jenkins <cmd>`: run one command as jenkins.

> ⚠️ **Corrected:** Project 01 says "`sudo su - jenkins` … will prompt you to set the password for the `jenkins` user. Ubuntu service accounts are often created without a local password, so an interactive `sudo su - jenkins` may ask you to create one." Now: **`sudo su - jenkins` never sets or asks for the jenkins user's password.** `sudo` asks for **your own** password (on EC2 the `ubuntu` user has passwordless sudo, so nothing is asked), and because `su` is then run by root, root doesn't need the target's password. A service account should have **no** password at all (log in with keys or `sudo` only). If you saw a prompt, it was `sudo` asking for *your* password, or you ran `su - jenkins` without `sudo` (that asks for jenkins' password, which doesn't exist, so it fails). The note's last sentence is right: `sudo -i -u jenkins` works without setting any password.

### Key file permissions

SSH refuses private keys others can read:
```bash
chmod 600 ~/.ssh/<your-private-key>            # owner read/write only
chown $(whoami):$(whoami) ~/.ssh/<your-private-key>
```
Otherwise: `WARNING: UNPROTECTED PRIVATE KEY FILE! … Permissions 0644 for 'key.pem' are too open.`
On the server side: `~/.ssh` must be `700` and `authorized_keys` `600`, owned by the user, or `sshd` silently ignores the file.

### SSH key pairs, authorized_keys and known_hosts

```
Controller (user jenkins)                          Agent (user jenkins)
/var/lib/jenkins/.ssh/jenkins-agent-key   ──SSH──▶ /home/jenkins/.ssh/authorized_keys  (contains the .pub line)
/var/lib/jenkins/.ssh/known_hosts  ◀── agent's host key (proves the agent's identity)
```
- `ssh-keygen -t ed25519 -f <file> -C "<comment>"` creates a key pair: `<file>` (private, stays on the controller) and `<file>.pub` (public, goes to the agent). **ed25519** is a modern, short and fast key type (preferred over RSA). The `-C` comment is just a label inside the `.pub` line.
- `authorized_keys`: each line is a public key allowed to log in as that user.
- **Host keys:** each server has its own key pair (in `/etc/ssh/ssh_host_*`). On first connection, SSH shows the fingerprint and asks `Are you sure you want to continue connecting (yes/no)?`, then stores it in `~/.ssh/known_hosts`. Next time, a different key means **possible man-in-the-middle** and SSH refuses. **TOFU** (Trust On First Use) = accepting the key the first time you see it.
- `ssh-keyscan <host>` fetches a host's public keys without logging in (to pre-populate `known_hosts`).

**Why the user matters:** run SSH tests **as the `jenkins` user** so `~` expands to *its* home. The same `ssh -i ~/.ssh/jenkins-agent-key …` run as `ubuntu` looks for `/home/ubuntu/.ssh/jenkins-agent-key` and fails.

### systemd services

- A **unit file** tells systemd how to start/stop a service, which user runs it, dependencies, restart policy and limits. Packages install `/usr/lib/systemd/system/jenkins.service`.
- **Override (drop-in):** `sudo systemctl edit jenkins` creates `/etc/systemd/system/jenkins.service.d/override.conf`. It's merged over the original, survives package upgrades, and is where you put `Environment="JAVA_OPTS=…"`.
- After editing unit files: `sudo systemctl daemon-reload`, then restart the service.
- `systemctl enable --now X` = start now + at boot; `status` shows state and recent log lines.
- Logs: `journalctl -u jenkins -f` (follow), `-n 200`, `--since "10 min ago"`.

Unit directives you'll meet (from the SonarQube unit in Project 01):
- `Description`: human-friendly name. `After`: start after these units. `Type=forking`: the start command forks into the background. `User`/`Group`: the account that runs it (least privilege). `ExecStart`/`ExecStop`: full paths of the start/stop commands. `Restart=on-failure`: restart if it crashes. `LimitNOFILE`/`LimitNPROC`: raise open-file and process limits. `WantedBy=multi-user.target`: start during normal boot.

### Hostname and time

- `sudo hostnamectl set-hostname jenkins-controller`, then `exec bash` (re-starts your shell so the prompt shows the new name). Readable names make SSH sessions, monitoring and node names easy to tell apart.
- `sudo timedatectl set-timezone Asia/Kolkata`; `timedatectl status` (also shows whether NTP sync is active). Agents and controller clocks must be in sync: Jenkins warns `Clock difference` on the Nodes page, and TLS/AWS signatures fail when clocks drift.

---

## Config / Jenkinsfile / commands

```bash
id jenkins
sudo -i -u jenkins bash -c 'echo $HOME; ls -la ~/.ssh'
```
```
uid=999(jenkins) gid=999(jenkins) groups=999(jenkins)
/var/lib/jenkins
drwx------ 2 jenkins jenkins 4096 Nov 18 10:01 .
-rw------- 1 jenkins jenkins  419 Nov 18 10:01 jenkins-agent-key
-rw-r--r-- 1 jenkins jenkins  106 Nov 18 10:01 jenkins-agent-key.pub
```

```bash
ssh -v -i key jenkins@agent hostname 2>&1 | grep -E 'Offering|Authenticated|denied'
```
```
debug1: Offering public key: key ED25519 SHA256:3k… explicit
Authenticated to 172.31.40.86 ([172.31.40.86]:22) using "publickey".
```
`-v` (verbose) shows which key was offered and why authentication succeeded or failed: the fastest SSH debugging tool.

```bash
systemctl cat jenkins | head -20        # the unit + overrides as systemd sees them
journalctl -u jenkins -n 50 --no-pager
```

---

## Hands-on lab

In WSL2 Ubuntu (or any VM):
1. `sudo useradd -m -s /bin/bash agentuser`; generate a key as **your** user: `ssh-keygen -t ed25519 -f ~/lab48 -C lab48 -N ''`.
2. Install it: `sudo -i -u agentuser bash -c 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' < ~/lab48.pub`.
3. `sudo apt install -y openssh-server && sudo systemctl start ssh`, then `ssh -i ~/lab48 agentuser@localhost hostname`. Answer `yes` to the host-key prompt; look at `~/.ssh/known_hosts`.
4. `chmod 644 ~/lab48` and try again: read the "UNPROTECTED PRIVATE KEY" error. Restore `600`.
5. Clean up: `sudo userdel -r agentuser`.

---

## Where you'll use it

Topics 49 (VM install), 51 (SSH agents), 60 (SonarQube), and every time an agent won't connect.

---

## When it breaks

| Error | Meaning | Fix |
|---|---|---|
| `Permission denied (publickey)` | Key not in `authorized_keys`, wrong user, or bad permissions on `~/.ssh` | Check user, perms 700/600, the right key; `ssh -v` |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!` | Private key readable by others | `chmod 600` |
| `Host key verification failed` / `REMOTE HOST IDENTIFICATION HAS CHANGED` | Host key unknown or changed (rebuilt VM, or an attack) | Verify out of band, then `ssh-keygen -R host` + re-scan |
| Service ignores your new JAVA_OPTS | Edited the unit but didn't reload | `daemon-reload` + restart |
| Group change "doesn't work" | Running service started before the change | Restart the service / reconnect the agent |

---

## Quick recap

- Controller runs as `jenkins` (home `/var/lib/jenkins`); agents use a `jenkins` user (`/home/jenkins`).
- `sudo -i -u jenkins` / `sudo su - jenkins` switch users without the target's password; service accounts have no password.
- Private keys `600`; `~/.ssh` `700`; `authorized_keys` `600`.
- `known_hosts` proves the agent's identity; `ssh-keyscan` pre-fills it.
- Configure services with systemd drop-in overrides; read logs with `journalctl -u`.

**Interview questions**

1. **Q: An SSH agent fails with "Permission denied (publickey)". What do you check?**
   A: That the public key is in the agent user's `authorized_keys`, permissions on `~/.ssh` (700) and the file (600), the username in the credential, and `ssh -v` from the controller as the jenkins user to see which key is offered.

2. **Q: Why use `systemctl edit` instead of editing the unit file?**
   A: It creates a drop-in override that's merged over the vendor unit and survives package upgrades.

3. **Q: What's in `known_hosts` and why does Jenkins care?**
   A: The trusted host keys of servers you've connected to. Jenkins verifies the agent's host key against it so it can't be tricked into sending builds and credentials to an impostor.
