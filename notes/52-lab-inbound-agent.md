# 52 · Lab: Inbound Agent

> **Level:** ★★ intermediate · **Status:** 🆕 new topic
>
> **You will learn:** how to connect an agent that **dials in** to the controller (instead of the controller SSHing out), using the official `jenkins/inbound-agent` container, both over **WebSocket** (no extra port) and over **TCP 50000**, plus how to run it as a service on a VM.
>
> **You need:** topics 12 (ports), 50.
>
> **From your original notes:** Day 03 › `-p 50000:50000` ("inbound agent port"); Docker scaling note (external agents).

---

## What it is

An **inbound agent** (formerly "JNLP agent") is started on the worker machine with the controller's URL, the node name and a **secret**. It opens the connection itself, which is perfect when the controller can't reach the agent (NAT, home networks, Windows machines, Kubernetes pods).

---

## Why it exists

SSH agents need the controller to reach port 22 on each agent and need sshd on the agent. Inbound agents only need **outbound** access from the agent to the controller's URL.

---

## Analogy

Instead of the manager phoning each worker (SSH), each worker phones the office when they arrive and gives their badge number (secret).

---

## How it works inside

1. You create a node with **Launch agent by connecting it to the controller**. Jenkins generates a per-node **secret** (an HMAC derived from the node name and the controller's secret key).
2. The agent runs `java -jar agent.jar -url <JENKINS_URL> -secret <secret> -name <node> [-webSocket] -workDir <dir>`.
3. **WebSocket mode:** an HTTP(S) upgrade on the normal Jenkins URL (`/wsagents/`), so it passes through proxies and ingress controllers. **TCP mode:** the agent first asks `<JENKINS_URL>/tcpSlaveAgentListener/` for the port, then connects to 50000 using the `JNLP4-connect` protocol (TLS).
4. The agent checks the controller's identity, the controller checks the secret, and the Remoting channel starts.

---

## Config / Jenkinsfile / commands

### 1) Create the node

**Manage Jenkins → Nodes → New Node** → `inbound1`, *Permanent Agent*: executors `1`, remote root `/home/jenkins/agent`, label `inbound`, **Launch method: Launch agent by connecting it to the controller**, and tick **Use WebSocket**. Save. The node page now shows the exact command, including the secret:
```
echo 3f9a…c2 > secret-file
java -jar agent.jar -url http://jenkins:8080/ -secretFile secret-file -name "inbound1" -webSocket -workDir "/home/jenkins/agent"
```

### 2a) Run it as a container (WebSocket)

```bash
docker run -d --name inbound1 --network jenkins-net --restart unless-stopped \
  jenkins/inbound-agent:latest-jdk21 \
  -url http://jenkins:8080/ -webSocket -name inbound1 -secret <secret-from-node-page> -workDir /home/jenkins/agent
```
(The `jenkins-net` network from topic 51 lets it reach `http://jenkins:8080`. For a real setup, use the public Jenkins URL.)

Container log:
```
INFO: Using Remoting version: 3301.v4363ddcca_4e7
INFO: Connecting to http://jenkins:8080/ using WebSocket
INFO: WebSocket connection open
INFO: Connected
```
The node shows **online** in the UI.

### 2b) TCP instead of WebSocket

Untick **Use WebSocket** on the node; in **Manage Jenkins → Security → Agents → TCP port for inbound agents** choose **Fixed: 50000**; drop the `-webSocket` flag:
```
INFO: Locating server among [http://jenkins:8080/]
INFO: Agent discovery successful
  Agent address: jenkins
  Agent port:    50000
INFO: Handshaking
INFO: Connecting to jenkins:50000
INFO: Trying protocol: JNLP4-connect
INFO: Connected
```
This is why the lab container publishes `-p 50000:50000`.

### 3) On a VM, as a systemd service

```ini
# /etc/systemd/system/jenkins-agent.service
[Unit]
Description=Jenkins inbound agent
After=network-online.target
[Service]
User=jenkins
WorkingDirectory=/home/jenkins
ExecStartPre=/usr/bin/curl -fsSLo /home/jenkins/agent.jar https://ci.example.com/jnlpJars/agent.jar
ExecStart=/usr/bin/java -jar /home/jenkins/agent.jar -url https://ci.example.com/ -name vm-inbound-1 -secretFile /home/jenkins/secret -webSocket -workDir /home/jenkins/agent
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
```
`sudo systemctl enable --now jenkins-agent`. Keep `secret` readable only by `jenkins` (`chmod 600`).

### Use it

```groovy
pipeline { agent { label 'inbound' }; stages { stage('x') { steps { sh 'hostname' } } } }
```

---

## Hands-on lab

1. Do steps 1 and 2a. Run a job on label `inbound`.
2. Switch to TCP (2b) and confirm the handshake log.
3. Set the TCP port to *Disable*, restart the agent without `-webSocket`, read the failure, then go back to WebSocket.
4. Delete the node, recreate it: the secret changes, and the old container fails with `Authorization failure`. Update the secret.

---

## Where you'll use it

Windows build machines, agents in other networks/clouds, and every Kubernetes agent pod (topic 53; the `jnlp` container is an inbound agent).

---

## When it breaks

| Message | Meaning | Fix |
|---|---|---|
| `…/tcpSlaveAgentListener/ is invalid: 404 Not Found` | TCP port disabled | Enable a fixed port, or use `-webSocket` |
| `Connection refused` to `:50000` | Port not published/allowed | Firewall/`-p 50000:50000`, or WebSocket |
| `The server rejected the connection: None of the protocols were accepted` / `Authorization failure` | Wrong secret or node name | Copy the current secret from the node page |
| WebSocket `404` / handshake fails behind a proxy | Proxy doesn't forward WebSocket upgrades | Configure the proxy (`Upgrade`/`Connection` headers, topic 65) |
| Agent keeps reconnecting | Wrong Jenkins URL in the agent's command | Use the URL configured in Manage Jenkins → System |

---

## Quick recap

- Inbound agents dial the controller with URL + name + secret.
- **WebSocket** uses the normal HTTP(S) port; **TCP** uses 50000 (`JNLP4-connect`).
- Official image: `jenkins/inbound-agent`; on VMs, run it as a systemd service.

**Interview questions**

1. **Q: When would you use an inbound agent instead of SSH?**
   A: When the controller can't reach the agent (NAT, firewalls, other networks), on Windows, or for Kubernetes pods. The agent only needs outbound access to the Jenkins URL.

2. **Q: What does WebSocket mode change?**
   A: The agent connects over the normal HTTP(S) Jenkins URL instead of the separate TCP port 50000, so it works through proxies and ingress without opening extra ports.

3. **Q: How does the controller know an inbound agent is legitimate?**
   A: The agent presents a per-node secret generated by the controller; the agent in turn verifies the controller's instance identity.
