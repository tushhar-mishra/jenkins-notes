# 12 · Jenkins is a Java Web App

> **Level:** ★★ intermediate · **Status:** ➕ expanded from a short note
>
> **You will learn:** what actually runs when "Jenkins is running": a JVM, a WAR file, an embedded web server; which ports it uses; what `JENKINS_HOME` is; which Java versions current Jenkins needs; and how the LTS and weekly release lines work.
>
> **You need:** topics 03 (JVM, `.war`) and 11.
>
> **From your original notes:** Day 04 › *Jenkins is a Java web app (WAR)* · Day 03 › install notes on Java and JVM memory flags.

---

## What it is

Jenkins is a **Java program** that serves a **website**.

- It ships as **`jenkins.war`**, a **Web Application Archive** (topic 03).
- It runs on the **JVM** (Java Virtual Machine).
- It contains its own embedded web server, **Winstone**, a small wrapper around **Jetty** (a Java HTTP server), so `java -jar jenkins.war` is all you need. No Tomcat required. It *can* also be deployed inside an external **servlet container** like Tomcat, but that's rare now.
- By default it listens for HTTP on port **8080**, so you use it through a **URL**.
- All its state lives in one folder: **`JENKINS_HOME`** (topic 16). The WAR is unpacked into `$JENKINS_HOME/war/`; plugins live separately as `.jpi`/`.hpi` files in `$JENKINS_HOME/plugins/`. (**HPI** = Hudson Plug-In; **JPI** = Jenkins Plug-In. Same format: a zip of Java classes and resources.)

---

## Why it exists

Knowing this tells you how to **operate** Jenkins:
- If the UI is slow, you look at **JVM memory and garbage collection** (topic 69).
- To change settings at startup, you pass **JVM options** (`-Xmx`, `-Duser.timezone`) and **Jenkins options** (`--httpPort`).
- Upgrading Jenkins = replacing one WAR file (or image tag, or package) + compatible plugins.
- If the wrong Java version is installed, Jenkins **won't start at all**.

---

## Analogy

A **food truck**: the truck (JVM) is the engine that moves everything; the kitchen inside (`jenkins.war`) is fixed equipment you swap when you upgrade; the serving window (Jetty on port 8080) is how customers reach you; the pantry (`JENKINS_HOME`) holds everything you've stocked and cooked, and it survives swapping the kitchen.

---

## How it works inside

### What starts when Jenkins starts

```
java [JVM options] -jar jenkins.war [Jenkins options]
 │
 ├─ JVM starts (heap memory, GC, timezone, system properties)
 ├─ Winstone/Jetty opens port 8080 (HTTP) and serves /login, /api, /github-webhook/, …
 ├─ jenkins.war is exploded into $JENKINS_HOME/war/
 ├─ Plugins are loaded from $JENKINS_HOME/plugins/*.jpi (dependency order)
 ├─ config.xml + *.xml read; jobs/ loaded into memory
 ├─ (if configured) JCasC applies YAML config (topic 67)
 └─ "Jenkins is fully up and running"
```

### Ports

| Port | Purpose | Needed when |
|---|---|---|
| **8080** (default HTTP) | Web UI, REST API, webhooks, **WebSocket** inbound agents | Always (usually behind a reverse proxy on 443 in production, topic 65) |
| **50000** (default) | **Inbound agent TCP port**: agents that dial in (topic 52) | Only for TCP inbound agents. Not needed for SSH agents or WebSocket agents. Can be set to "disabled" or "random" in **Manage Jenkins → Security → Agents** |

> ⚠️ **Corrected:** the original notes call port 50000 the "**JNLP**" port. **JNLP** = Java Network Launch Protocol, the old Java Web Start mechanism used to launch agents from a browser. Java Web Start was removed from Java, and Jenkins removed that launch method. The current name is the **inbound agent (TCP) port**, and many setups now use **WebSocket** over the normal HTTP(S) port instead. You'll still see `jnlp` in old docs, in the `JNLP4-connect` protocol name, and as the default container name in Kubernetes agent pods (topic 53).

### Useful JVM and Jenkins options

| Option | What it does |
|---|---|
| `-Xms1g -Xmx2g` | Initial and maximum **heap** (Java's main memory area). Too small → `OutOfMemoryError` and a frozen UI. In containers, prefer `-XX:MaxRAMPercentage=75` so the heap follows the container's memory limit. |
| `-Duser.timezone=Asia/Kolkata` | Timezone for timestamps in the UI and logs (topic 49) |
| `-Djenkins.install.runSetupWizard=false` | Skip the setup wizard (used with JCasC, topic 67) |
| `--httpPort=8080` / `--prefix=/jenkins` | Port and URL path prefix (e.g. `https://ci.example.com/jenkins`) |
| `JENKINS_HOME=/var/jenkins_home` | (environment variable) where state lives |

How you set them depends on the install (topics 14, 49, 54):
- **Docker image:** `-e JAVA_OPTS="-Xmx2g"` and `-e JENKINS_OPTS="--prefix=/jenkins"`.
- **Linux package (systemd):** `Environment="JAVA_OPTS=…"` in a systemd override file.
- **Helm chart:** `controller.javaOpts`.

### Java versions: what current Jenkins needs

Jenkins follows a **"2+2+2" Java support policy**: each new Java LTS is supported for about **two years**, then becomes the **minimum** required for about two years, then is dropped.

As of November 2026:
- **Java 21** or **Java 25** are required.
- **Java 17 is no longer supported.** Weekly releases dropped it at 2.545 (January 2026), LTS after 2.541.3 (March 2026). **Jenkins 2.555.1 and later refuse to run on Java 17.**
- **Agents** must run a Java version supported by the controller's Remoting too. Keep agents on the same major Java version as the controller.

> ⚠️ **Corrected:** the Day 03 VM example installs `openjdk-17-jre-headless`. Now: install **Java 21** (`openjdk-21-jre-headless` on Ubuntu/Debian, `java-21-openjdk` on RHEL), because current Jenkins LTS won't start on Java 17. Your shared-library and Project 01 notes already use Java 21, which is correct.

### Release lines: LTS vs weekly

| | **Weekly** | **LTS (Long-Term Support)** |
|---|---|---|
| Version format | `2.568` | `2.568.1`, `2.568.2`, `2.568.3` |
| Cadence | every week | a new **baseline** about every 12 weeks, picked from a weekly that proved stable; then point releases (`.1`, `.2`, `.3`) with backported fixes and security patches |
| Use for | trying new features | **production** |
| Docker tag | `jenkins/jenkins:latest`, `jenkins/jenkins:2.568-jdk21` | `jenkins/jenkins:lts-jdk21`, `jenkins/jenkins:2.568.2-lts-jdk21` |
| Changelog | [jenkins.io/changelog](https://www.jenkins.io/changelog/) | [jenkins.io/changelog-stable](https://www.jenkins.io/changelog-stable/) |

Rules of thumb:
- **Production runs LTS**, pinned to an exact version (`2.568.2`), not the floating `lts` tag.
- Read the **LTS upgrade guide** before each new baseline; it lists breaking changes.
- **Security advisories** (jenkins.io/security/advisories) are published for core and plugins; LTS point releases often exist just to ship those fixes (topic 65).

---

## Config / Jenkinsfile / commands

Run the WAR directly (useful for understanding; in this course you'll use Docker):

```bash
curl -fsSLO https://get.jenkins.io/war-stable/latest/jenkins.war
java -version
JENKINS_HOME=$HOME/jh java -Xmx1g -jar jenkins.war --httpPort=8080
```
```
openjdk version "21.0.5" 2024-10-15 LTS
...
Running from: /home/you/jenkins.war
Jetty (winstone) 12.0.x
Started ServerConnector@...{HTTP/1.1, (http/1.1)}{0.0.0.0:8080}
Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:
3f8c1e0f7c2d4a1b9e6f5a4b3c2d1e0f
This may also be found at: /home/you/jh/secrets/initialAdminPassword
Jenkins is fully up and running
```
- `Jetty (winstone)`: the embedded web server.
- `0.0.0.0:8080`: listening on all network interfaces, port 8080.
- The **initial admin password** unlocks the setup wizard; it's also saved in `secrets/initialAdminPassword`.

What happens on the wrong Java:
```bash
JAVA_HOME=/usr/lib/jvm/java-17 java -jar jenkins.war
```
```
Running with Java 17 from /usr/lib/jvm/java-17, which is older than the minimum required version (Java 21).
Supported Java versions are: [21, 25]
```
Jenkins exits immediately.

Check what a running Jenkins uses: **Manage Jenkins → System Information** (Java version, JVM options, system properties, environment), or **Manage Jenkins → About Jenkins**.

---

## Hands-on lab

(Needs Java 21 locally, or do it in a container.)

```bash
docker run --rm -it -p 8081:8080 eclipse-temurin:21-jre bash -c '
  apt-get update -qq && apt-get install -y -qq curl >/dev/null &&
  curl -fsSLo /tmp/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war &&
  JENKINS_HOME=/tmp/jh java -Xmx512m -jar /tmp/jenkins.war'
```
1. Wait for `Jenkins is fully up and running`, then open `http://localhost:8081`.
2. In another terminal: `docker ps` → `docker exec -it <id> ls /tmp/jh` to see the `JENKINS_HOME` it created (`war/`, `plugins/`, `secrets/`, `config.xml`…).
3. Stop it with Ctrl+C. Everything disappears with the container, because `JENKINS_HOME` wasn't on a volume. Topic 14 fixes that.

---

## Where you'll use it

- Sizing the controller (heap) and fixing a slow or crashing UI.
- Planning upgrades: Java version first, then Jenkins LTS, then plugins (topic 68).
- Setting up a reverse proxy and URL prefix (topic 65).
- Answering "what is Jenkins built on?" in interviews.

---

## When it breaks

| Error | Meaning | Fix |
|---|---|---|
| `older than the minimum required version (Java 21)` | Wrong Java | Install Java 21/25, point `JAVA_HOME`/the service at it |
| `java.lang.OutOfMemoryError: Java heap space` in the log; UI freezes | Heap too small, or a memory leak from huge logs/many builds | Raise `-Xmx` / `MaxRAMPercentage`; discard old builds; check plugins (topic 69) |
| `Address already in use` / `Failed to bind to 0.0.0.0:8080` | Something else uses port 8080 | `--httpPort=8090` or stop the other process (`ss -ltnp \| grep 8080`) |
| Agents fail with `UnsupportedClassVersionError` | Agent Java older than controller's `remoting.jar` needs | Upgrade the agent's Java |
| Timestamps are in UTC | JVM timezone not set | `-Duser.timezone=…` (topic 49) |

---

## Quick recap

- Jenkins = `jenkins.war` running on a **JVM** with embedded **Jetty** on port **8080**.
- Port **50000** is the inbound-agent TCP port (formerly "JNLP"); WebSocket agents don't need it.
- Current Jenkins needs **Java 21 or 25**; Java 17 is unsupported.
- Production = **LTS**, pinned to an exact version; weekly is for testing.
- All state is in **`JENKINS_HOME`**.

**Interview questions**

1. **Q: What's the difference between Jenkins LTS and weekly?**
   A: Weekly releases ship every week with new features. LTS takes a stable weekly as a baseline about every 12 weeks and ships point releases with backported fixes and security patches. Production should run LTS.

2. **Q: Which ports does Jenkins use?**
   A: 8080 for HTTP (UI, API, webhooks, WebSocket agents), and optionally 50000 for TCP inbound agents. SSH agents use port 22 on the agent, not on the controller.

3. **Q: Jenkins UI is freezing. Where do you look first?**
   A: JVM heap and GC (out-of-memory errors in the log), the number of builds running on the controller, and disk space in `JENKINS_HOME`.
