# 60 · Lab: Install SonarQube

> **Level:** ★★ intermediate · **Status:** ✅ rewritten from your notes (+ a Docker alternative)
>
> **You will learn:** how to install SonarQube on a VM the production way (EC2 instance, Java 21, PostgreSQL database and user, kernel limits Elasticsearch needs, a dedicated `sonar` user, the SonarQube zip, the JDBC configuration, a systemd service), plus troubleshooting, production notes, and a quick Docker Compose version for local labs.
>
> **You need:** topics 48, 59.
>
> **From your original notes:** Project 01 › *Lab: Install SonarQube on EC2*, steps 1–11 (incl. the database explanation, H2 note, DCE note, unit-file directive explanations, operational tips, troubleshooting, production notes).

---

## What it is

**SonarQube** is a server (a Java web app + an embedded **Elasticsearch** search engine + a background **Compute Engine**) that receives analysis reports from scanners and stores results in a **database**. For the lab we keep SonarQube and PostgreSQL on the **same VM**: fine for training, and close to a small VM-based production setup.

---

## Why it exists

The Project 4 pipeline's Build & Sonar stage needs a reachable SonarQube server with a project, a token and a quality gate.

---

## Analogy

A **records office with a search room**: the clerks (web + Compute Engine) process submitted forms (reports), file them in the archive (PostgreSQL), and keep a fast index (Elasticsearch). The index needs a big desk (kernel limits) to work.

---

## How it works inside

```
Jenkins agent: mvn sonar:sonar ──HTTP 9000──▶ SonarQube web ──▶ Compute Engine ──▶ PostgreSQL (5432, localhost)
                                                   └── Elasticsearch (embedded) for search/indexing
```

---

## Config / Jenkinsfile / commands

### 1) Create the EC2 instance

- **AMI:** Ubuntu 22.04 LTS (24.04 works the same; your other VMs use 24.04)
- **Instance type:** `c7i-flex.large` (SonarQube likes RAM). It's eligible under the AWS **credits-based free tier**, so no charges while within your credit balance.
- **Root volume:** 20 GB or more
- **Security group (SonarQube VM):** allow **SSH (22)** from your IP; allow **TCP 9000** from your IP **and from the Jenkins agent** (the agent runs the scanner; the original says "from the Jenkins VM").

### 2) Connect to the instance

```bash
ssh -i <your-key>.pem ubuntu@<sonarqube-ec2-public-ip>
```
Ensure your SSH private key is readable only by you:
```bash
chmod 600 ~/.ssh/<your-private-key>
chown $(whoami):$(whoami) ~/.ssh/<your-private-key>
```
**Suggested hostname:** `sonarqube` (easy to identify in SSH sessions, monitoring dashboards and DNS-based discovery):
```bash
sudo hostnamectl set-hostname sonarqube
exec bash
```
**Timezone** (consistent logs and timestamps; use your own zone):
```bash
sudo timedatectl set-timezone Asia/Kolkata
timedatectl status
# or
date
```

### 3) Install Java 21

SonarQube currently requires Java 21 (17 is also accepted by some versions; 21 is the safe choice):
```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jre
java -version
```

### 4) Install PostgreSQL and create the database

In SonarQube, the **database is critical**. It stores:
- all **projects, analyses and measures** (issues, coverage, duplications, ratings, technical debt);
- **rules, quality profiles, quality gates**, user accounts, tokens and general configuration.

Because this data matters, production setups often run the database on a **separate, self-managed PostgreSQL VM** or a **managed service such as Amazon RDS for PostgreSQL**, so performance, backups and HA are handled independently of the SonarQube VM.

For **dev and small test setups** you'll sometimes see **H2**: an **embedded**, in-memory or file-based relational database. It's easy to start but not designed for heavy multi-user production use. Fine for quick local trials; for any team environment SonarQube recommends **PostgreSQL**.

```bash
# Install PostgreSQL and common extensions
sudo apt install -y postgresql postgresql-contrib

# Enable PostgreSQL to start automatically on boot
sudo systemctl enable postgresql

# Start the PostgreSQL service now
sudo systemctl start postgresql
```

**Create the SonarQube database and user** (run SQL as the `postgres` superuser):
```bash
sudo -u postgres psql
```
Inside `psql`:
```sql
-- create a login role for SonarQube with a password
CREATE ROLE sonar WITH LOGIN ENCRYPTED PASSWORD 'StrongPasswordHere';
-- Example: CREATE ROLE sonar WITH LOGIN ENCRYPTED PASSWORD 'sonar';

-- create the SonarQube database owned by that role
CREATE DATABASE sonarqube OWNER sonar;

-- grant privileges on the database to the sonar role
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;

-- exit psql
\q
```
Quick verification (VM shell):
```bash
# list roles to confirm the 'sonar' role exists
sudo -u postgres psql -c "\du"

# list databases and owners to confirm the 'sonarqube' DB exists
sudo -u postgres psql -c "\l"

# test connecting exactly as SonarQube will (replace the password if needed)
PGPASSWORD='StrongPasswordHere' psql -U sonar -h localhost -d sonarqube -c "\dt"
```
If the last command shows an empty relation list (`Did not find any relations.`) and no authentication error, the database and user are set up correctly. Then set `sonar.jdbc.username`, `sonar.jdbc.password` and `sonar.jdbc.url` in `/opt/sonarqube-current/conf/sonar.properties` (step 8) and restart SonarQube.

### 5) Tune kernel settings required by SonarQube

SonarQube uses **Elasticsearch** internally, which needs some kernel tweaks:
```bash
# Increase the maximum number of memory map areas (required by Elasticsearch)
echo 'vm.max_map_count=524288' | sudo tee -a /etc/sysctl.d/99-sonarqube.conf

# Increase the maximum number of file handles
echo 'fs.file-max=131072' | sudo tee -a /etc/sysctl.d/99-sonarqube.conf

# Apply the new sysctl settings
sudo sysctl --system
```
Set ulimits for the `sonar` user in `/etc/security/limits.d/99-sonarqube.conf`:
```bash
# Allow many open files for the sonar user
echo 'sonar   -   nofile   131072' | sudo tee /etc/security/limits.d/99-sonarqube.conf

# Allow many processes for the sonar user
echo 'sonar   -   nproc    8192'   | sudo tee -a /etc/security/limits.d/99-sonarqube.conf
```
> **Note:** these kernel and ulimit tweaks give Elasticsearch enough **memory-map areas** (`vm.max_map_count`: how many memory-mapped regions a process may have) and **file descriptors** to index code reliably. Apply them before starting SonarQube to avoid startup, indexing or resource-limit failures. (`limits.d` applies to login sessions; for the systemd service, the `LimitNOFILE`/`LimitNPROC` lines in step 9 are what actually count.)

### 6) Create a dedicated sonar user

```bash
# Create a dedicated 'sonar' user with its home directory at /opt/sonarqube
sudo useradd -m -d /opt/sonarqube -s /bin/bash sonar
```

### 7) Download and install SonarQube

Reference: https://www.sonarsource.com/products/sonarqube/downloads/ (check the current LTA/community download URL there; the version below is the one from the lecture):
```bash
# switch to a temporary folder for downloads
cd /tmp

# download the SonarQube community zip, follow redirects (-L) and write the output to sonarqube.zip (-o)
curl -L -o sonarqube.zip "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.11.0.114957.zip"

# install unzip non-interactively (-y auto-accepts prompts)
sudo apt-get update
sudo apt-get install -y unzip

# extract the archive
unzip sonarqube.zip

# move the extracted folder to a stable location
sudo mv sonarqube-25.11.0.114957 /opt/sonarqube-current

# change ownership recursively (-R) so the sonar user owns all files and directories
sudo chown -R sonar:sonar /opt/sonarqube-current
```
You can make `/opt/sonarqube-current` a **symlink** to a versioned folder later, which makes upgrades and rollbacks easy.

(Naming note: the free edition is now called **SonarQube Community Build**, with versions like `25.11`; paid editions use "Server" LTA releases like `2025.x`.)

> In enterprise implementations you'll typically see the **Data Center Edition (DCE)** used, because it provides application-level high availability: clustered SonarQube with several app nodes behind a load balancer, dedicated Elasticsearch search nodes, and a shared external database, for resilience, scale and zero-downtime maintenance.

### 8) Configure SonarQube to use PostgreSQL

We point SonarQube at the database created earlier. **PostgreSQL's default port is `5432`**; use it in the JDBC URL unless your DB uses another port.
```bash
# edit the main SonarQube configuration file as the 'sonar' user
sudo -u sonar vim /opt/sonarqube-current/conf/sonar.properties
```
Uncomment and set (replace the password/host if needed):
```properties
# DB username for SonarQube (the DB user you created)
sonar.jdbc.username=sonar

# DB password for that user; keep this secret and match your DB setup
sonar.jdbc.password=StrongPasswordHere

# JDBC URL: jdbc:postgresql://<host>:<port>/<database>
# default PostgreSQL port is 5432; localhost because the DB is on the same VM
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
```
**JDBC** = Java Database Connectivity, the standard way Java apps connect to databases; the URL names the driver, host, port and database.
Notes and quick checks:
- If PostgreSQL runs on another host, replace `localhost` with its host/IP and make sure the DB accepts remote connections (`listen_addresses` and `pg_hba.conf`).
- Restart SonarQube after saving so it picks up the DB settings.
- If SonarQube can't connect, check PostgreSQL is running and that the `sonar` user can access the `sonarqube` database.

### 9) Create a systemd service for SonarQube

**What a systemd unit file is:** a small config that tells the OS how to start, stop and manage a service: which user runs it, what it depends on, its restart policy and resource limits (topic 48).
```bash
sudo vim /etc/systemd/system/sonarqube.service
```
Paste this exact unit file (no inline comments inside the file):
```ini
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking
User=sonar
Group=sonar
ExecStart=/opt/sonarqube-current/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube-current/bin/linux-x86-64/sonar.sh stop
Restart=on-failure
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
```
Reload systemd and start:
```bash
# reload systemd to pick up the new unit
sudo systemctl daemon-reload

# enable SonarQube to start on boot
sudo systemctl enable sonarqube

# start SonarQube now
sudo systemctl start sonarqube

# check the status; it should become active (running)
sudo systemctl status sonarqube
```
**Unit-file directive explanations (keep these out of the unit file):**
- `Description`: human-friendly name.
- `After`: start after the listed units (network and PostgreSQL).
- `Type=forking`: the start script forks into the background; systemd treats the original process as the starter.
- `User`/`Group`: the system account running the service (`sonar`), for least privilege.
- `ExecStart`: full path to the start command (must be executable).
- `ExecStop`: full path to the clean stop command.
- `Restart=on-failure`: restart automatically if it crashes or exits with an error.
- `LimitNOFILE`: raise the open-files limit (Elasticsearch needs many file descriptors).
- `LimitNPROC`: raise the process count for the service user.
- `WantedBy=multi-user.target`: start during normal boot.

**Operational tips:**
- If the status isn't `active (running)`, follow live logs: `sudo journalctl -u sonarqube -f`.
- Confirm `sonar` owns `/opt/sonarqube-current` and has the ulimits above.
- After editing the unit file, always run `sudo systemctl daemon-reload`.

**Troubleshooting:** check the SonarQube logs (look for `ERROR` / bootstrap failures):
```bash
# recent general, web and elasticsearch logs
sudo tail -n 200 /opt/sonarqube-current/logs/sonar.log
sudo tail -n 200 /opt/sonarqube-current/logs/web.log
sudo tail -n 200 /opt/sonarqube-current/logs/es.log
```
(`ce.log` holds the Compute Engine log, useful when analyses get stuck "in progress".)

### 10) Access the SonarQube UI

Open `http://<sonarqube-ec2-public-ip>:9000`. Default login: username `admin`, password `admin`; you'll be asked to change it.

From here you can:
- explore **Quality Profiles**, **Quality Gates**, **Rules**;
- later create a **project** and a **token** for Jenkins (topic 62);
- use `http://<sonarqube-ip>:9000` as the Sonar host URL in Jenkins (the pipeline uses the **private** IP or, better, a DNS name).

### 11) Production notes for SonarQube

In many production deployments:
- SonarQube runs on **one or more VMs**, with PostgreSQL on a separate DB server or managed service.
- Resources are sized by the number of projects and users, usually more CPU and RAM than the lab.
- Access is via **HTTPS**, fronted by an ALB (AWS Application Load Balancer) or Nginx.
- Authentication integrates with **LDAP, SSO or OIDC**.
- Backups cover both the **database** and the **configuration**.
- Some teams move SonarQube to **Kubernetes**, but this VM pattern is still very common.

### Local alternative: Docker Compose (lab only)

```yaml
# compose.yaml
services:
  db:
    image: postgres:17
    environment: { POSTGRES_USER: sonar, POSTGRES_PASSWORD: sonar, POSTGRES_DB: sonarqube }
    volumes: [pgdata:/var/lib/postgresql/data]
  sonarqube:
    image: sonarqube:community
    depends_on: [db]
    ports: ["9000:9000"]
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    volumes: [sqdata:/opt/sonarqube/data, sqext:/opt/sonarqube/extensions]
volumes: { pgdata: {}, sqdata: {}, sqext: {} }
```
On the WSL2 host first: `sudo sysctl -w vm.max_map_count=524288`. Then `docker compose up -d` and open `http://localhost:9000`. Connect it to your Jenkins network (`docker network connect jenkins-net <sonarqube-container>`) so pipelines can reach `http://<container-name>:9000`.

---

## Hands-on lab

Do steps 1–10 (or the Compose version). Log in, change the password, look at **Quality Gates → Sonar way**, and keep the UI open for topic 62.

---

## Where you'll use it

The Project 4 pipeline (topic 62); any company that runs SonarQube itself.

---

## When it breaks

| Log message | Cause | Fix |
|---|---|---|
| `es.log`: `max virtual memory areas vm.max_map_count [65530] is too low` | Kernel setting missing | Step 5; `sudo sysctl --system` |
| `web.log`: `Unable to connect to database` / `password authentication failed for user "sonar"` | Wrong JDBC settings / password | Fix `sonar.properties`; test with `psql` |
| `Elasticsearch: can not run elasticsearch as root` | Started as root | Run as `sonar` (the systemd unit) |
| `Permission denied` on logs/data | Files not owned by sonar | `chown -R sonar:sonar /opt/sonarqube-current` |
| UI unreachable | Security group / still starting (takes 1–3 min) | Allow 9000; watch `sonar.log` for "SonarQube is operational" |

---

## Quick recap

- Java 21 + PostgreSQL (role `sonar`, DB `sonarqube`) + kernel limits (`vm.max_map_count=524288`) + a `sonar` user + the zip in `/opt` + JDBC settings + a systemd unit.
- Logs: `sonar.log`, `web.log`, `es.log`, `ce.log`.
- Production: separate/managed DB, HTTPS behind a load balancer, SSO, backups; DCE for HA.

**Interview questions**

1. **Q: Why does SonarQube need `vm.max_map_count` raised?**
   A: Its embedded Elasticsearch memory-maps many index files; the default limit is too low and Elasticsearch refuses to start.

2. **Q: Why PostgreSQL rather than H2?**
   A: H2 is an embedded database for quick trials only; PostgreSQL is supported for production: concurrency, durability, backups and upgrades.

3. **Q: SonarQube won't start. Where do you look?**
   A: `systemctl status`/`journalctl -u sonarqube`, then `logs/sonar.log`, `es.log` (kernel limits, permissions) and `web.log` (database connection).
