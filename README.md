# TitanCRM Deployment Guide

## Overview

**TitanCRM Installer** is an automated deployment script designed to quickly and reliably set up a full TitanCRM environment on a clean server.

It provisions all required infrastructure, backend services, and supporting tools needed to run TitanCRM in production — with minimal manual configuration.

The installer is built to be:

- **Simple** — can be executed with a single command
- **Automated** — handles infrastructure, services, and configuration
- **Production-ready** — includes HTTPS, service isolation, and monitoring tools
- **Accessible** — suitable for both technical and non-technical users

---

## What This Installer Does

When executed, the installer performs a full deployment of TitanCRM, including:

- Preparing the server environment
- Installing and configuring Docker (if not already installed)
- Creating required networks and persistent storage
- Deploying infrastructure services (databases, message broker, admin tools)
- Deploying all TitanCRM microservices
- Configuring a reverse proxy with HTTPS support
- Generating secure credentials for internal services
- Providing access to web interfaces for management and monitoring

At the end of the installation, you will receive direct access to:

- TitanCRM Frontend
- Backend API
- Database management (pgAdmin)
- Message broker dashboard (RabbitMQ)
- Centralized logs (Dozzle)

---

## Who This Guide Is For

This documentation is designed for:

- **End users / clients** — who want to deploy TitanCRM without deep technical knowledge
- **System administrators** — who need to manage and maintain the deployment
- **Developers** — who want to understand the system architecture and services

No advanced DevOps experience is required to complete the installation, but basic familiarity with Linux is recommended.

## Quick Start

Follow these steps to deploy TitanCRM on your server:

```bash
chmod +x install.sh
sudo ./install.sh
```

During the installation, you will be asked to confirm the deployment:

```bash
Type 'deploy' to continue
```

Once completed, the installer will output all service URLs and access credentials.

> ⚠️ Note: The full installation may take several minutes depending on your server performance and network speed.

## System Requirements

Before running the installer, ensure your server meets the following requirements:

### Operating System

- Ubuntu 24.04 (required)

### Access

- Root privileges (required to run the installer)

### Hardware

- Minimum **120 GB** of free disk space
- Recommended: 4+ CPU cores, 8+ GB RAM for stable performance

### Network

- Public IP address
- Open ports:
  - 80 (HTTP)
  - 443 (HTTPS)

### Domain Configuration

- Domain names must be pointed to your server IP address for:
  - Frontend
  - Backend API
  - RabbitMQ
  - pgAdmin
  - Dozzle

### Internet Access

- Required for:
  - Downloading Docker images
  - Installing system dependencies
  - Issuing SSL certificates (Let's Encrypt)

---

> ⚠️ The installer will validate some of these requirements automatically (OS version, disk space), but others must be configured manually.

## Environment Configuration (.env)

Before running the installer, you must configure the `.env` file.

This file defines domain names, access credentials, and service endpoints used during deployment.

Before filling in the `.env` file, you must obtain access credentials for the following external services.
Detailed setup instructions for each service are available in the [Configuration Guide](https://docs.google.com/document/d/1npkPQs9O_Bshj4giDei89BFjfmimeCCjBLWwhh76zYg/edit?usp=sharing).

### Required Service Access

- **Facebook** — App ID and secret for OAuth / API integration
- **Brevo** — SMTP credentials and API key for transactional emails
- **Telegram Bot** — Bot token obtained via [@BotFather](https://t.me/BotFather)
- **S3** — Bucket name, region, access key, and secret key for file storage

---

### Required Variables

Set the following variables according to your environment:

```bash id="m1xq8p"
FRONTEND_ENDPOINT=app.example.com
BACKEND_ENDPOINT=api.example.com
RABBITMQ_ENDPOINT=rabbit.example.com
PGADMIN_ENDPOINT=pgadmin.example.com
DOZZLE_ENDPOINT=logs.example.com
```

These values must be valid domain names pointing to your server.

---

### pgAdmin Access

```bash id="y8c1df"
PGADMIN_LOGIN=admin@example.com
```

- `PGADMIN_LOGIN` — email used to log into pgAdmin

> ⚠️ Note: The installer may override the password with a generated secure value.

---

### Automatically Generated Variables

During installation, the script will automatically generate secure passwords for:

- RabbitMQ admin user
- Dozzle (log viewer) authentication
- pgAdmin

These credentials will be displayed after installation completes.

---

### Example .env File

```bash id="6x3c9a"
FRONTEND_ENDPOINT=app.example.com
BACKEND_ENDPOINT=api.example.com
RABBITMQ_ENDPOINT=rabbit.example.com
PGADMIN_ENDPOINT=pgadmin.example.com
DOZZLE_ENDPOINT=logs.example.com

PGADMIN_LOGIN=admin@example.com
PGADMIN_PASSWORD=strongpassword123
```

---

### Important Notes

- All domains must be properly configured in DNS before installation
- The server must be reachable from the internet
- HTTPS certificates will be issued automatically using Let's Encrypt
- Do not use `localhost` or internal IP addresses for endpoints

---

> 💡 Tip: If you're unsure, start with subdomains like:
> `app.yourdomain.com`, `api.yourdomain.com`, etc.

## How the Installation Works

The TitanCRM installer performs a fully automated deployment in several stages.

At a high level, the process looks like this:

1. **System validation**
   The script checks your operating system, disk space, and permissions.

2. **Environment preparation**
   Docker is installed (if missing), and required networks and volumes are created.

3. **Infrastructure deployment**
   Core services such as databases, message broker, and admin tools are started.

4. **Service configuration**
   Internal services like RabbitMQ are configured with users and permissions.

5. **CRM deployment**
   All TitanCRM backend and frontend services are launched.

6. **Proxy setup**
   A reverse proxy is configured with automatic HTTPS (Let's Encrypt).

7. **Finalization**
   The script outputs access URLs and generated credentials.

---

This process is fully automated and typically requires no manual intervention after start.

## Installation Process

This section describes each step of the deployment in detail.

---

### 1. System Validation

Before installation begins, the script verifies:

- The script is run as **root**
- The operating system is **Ubuntu 24.04**
- At least **120 GB of free disk space** is available

If any of these checks fail, the installation will stop.

---

### 2. Docker Installation

If Docker is not installed, the script will:

- Add the official Docker repository
- Install Docker Engine and required components
- Enable and start the Docker service

If Docker is already installed, this step is skipped.

---

### 3. Docker Environment Preparation

The installer creates:

- A shared Docker network:
  - `titan-crm-network`

- Persistent volumes for:
  - Databases
  - RabbitMQ
  - pgAdmin
  - Proxy configuration
  - Other infrastructure components

---

### 4. Secrets Generation

Secure credentials are automatically generated for:

- RabbitMQ admin user
- Dozzle (log viewer) authentication
- pgAdmin password (may override `.env` value)

These credentials are displayed at the end of installation.

---

### 5. Infrastructure Deployment

The infrastructure stack is deployed using Docker Compose (`infra.yaml`).

This includes:

- PostgreSQL databases
- RabbitMQ
- pgAdmin
- Dozzle
- Portainer

The script waits for critical services (e.g., RabbitMQ) to become ready.

---

### 6. RabbitMQ Configuration

The installer automatically:

- Creates an **admin user**
- Creates service users:
  - `cost-management`
  - `scheduler`
  - `content`
  - `company-management`

- Assigns full permissions to all users

---

### 7. CRM Services Deployment

The main TitanCRM services are deployed using `crm.yaml`.

This includes:

- API Gateway
- Frontend
- Business services (content, finance, etc.)
- Background workers and integrations

The script ensures all containers are running before proceeding.

---

### 8. Proxy Deployment

The proxy stack is deployed using `proxy.yaml`.

This includes:

- Nginx reverse proxy
- Automatic HTTPS via Let's Encrypt
- Domain-based routing to services

---

### 9. Finalization

After deployment:

- All service URLs are displayed
- Access credentials are printed
- The system continues initializing in the background

> ⚠️ Some services may take a few minutes to become fully available.

## Accessing the Services

After the installation completes, all core services become available via web interfaces.

The installer will display all URLs and credentials in the console output.

---

### TitanCRM Frontend

```bash id="k2f8za"
https://FRONTEND_ENDPOINT
```

This is the main user interface of the system.

---

### Backend API

```bash id="q91l2c"
https://BACKEND_ENDPOINT
```

Used for API access, integrations, and internal communication between services.

---

### RabbitMQ Management Console

```bash id="r7k3dp"
https://RABBITMQ_ENDPOINT
```

Used to monitor message queues and system communication.

**Credentials:**

```bash id="c6f9s2"
login: admin
password: <generated during installation>
```

---

### Logs (Dozzle)

```bash id="w8d4mx"
https://DOZZLE_ENDPOINT
```

Provides real-time logs for all containers in the system.

**Credentials:**

```bash id="n3v7qp"
login: admin
password: <generated during installation>
```

---

### Database Management (pgAdmin)

```bash id="p2x9lr"
https://PGADMIN_ENDPOINT
```

Used to manage PostgreSQL databases.

**Credentials:**

```bash id="z5h1yt"
login: <PGADMIN_LOGIN>
password: <generated during installation>
```

---

### Preconfigured Databases

The following databases are automatically created and available in pgAdmin:

- `company-management`
- `content`
- `cost-management`
- `finance`

Each database uses its own default credentials:

```bash id="v4m8dk"
company-management → company
content → content
cost-management → cost
finance → finance
```

---

### Important Notes

- Services may take a few minutes to become fully available after installation
- HTTPS certificates (Let's Encrypt) may require additional time to be issued
- If a service is not accessible immediately, wait a few minutes and try again

---

> 💡 Tip: After installation, all access credentials will be displayed in the console and saved in the file `credentials.txt` for your reference and safe storage.

## Managing TitanCRM

The installer script provides several built-in commands to manage TitanCRM services. Run any command with:

```bash
sudo ./deploy.sh <command>
```

## Help Command

The `help` command of the installer script displays a list of all available commands with a short description.  
It is a **read-only command** and does not modify the system or start any services.

```bash
sudo ./deploy.sh help
```

## Upgrading TitanCRM

To update TitanCRM services to the latest version, use the built-in upgrade command:

```bash id="u1p9zx"
sudo ./deploy.sh crm-upgrade
```

This command will:

1. Pull the latest Docker images
2. Restart the CRM containers with updated versions
3. Remove old images

Notes:

- Only CRM services are upgraded (infrastructure is not affected)
- Existing data (databases, volumes) will not be modified
- A short service interruption may occur during restart

## CRM Redeploy

The `crm-redeploy` command stops and removes all existing CRM containers, then recreates and starts them again.  
This is useful for refreshing configuration without affecting the underlying data in volumes.

```bash
sudo ./deploy.sh crm-redeploy
```

## CRM Stop

The `crm-stop` command stops all running CRM containers.  
Volumes and the Docker network remain intact, so data is preserved.

```bash
sudo ./deploy.sh crm-stop
```

## CRM Start

The `crm-start` command starts previously stopped CRM containers.  
It does not modify any volumes or network settings.

```bash
sudo ./deploy.sh crm-start
```

## Uninstall

The `uninstall` command removes **all TitanCRM stacks** including CRM, Infra, and Proxy containers,  
all Docker volumes created by TitanCRM, and the shared Docker network.  

> ⚠️ Use this command with caution — it will delete all data stored in TitanCRM volumes.

```bash
sudo ./deploy.sh uninstall
```

---

> 💡 Tip: It is recommended to perform upgrades during low-traffic periods.

## Logs & Troubleshooting

This section helps you diagnose and resolve common issues.

---

### Viewing Logs (Recommended)

The easiest way to view logs is via the Dozzle web interface:

```bash id="l8c2vm"
https://DOZZLE_ENDPOINT
```

It provides real-time logs for all running containers.

---

### Using Docker CLI

You can also inspect logs directly from the command line:

```bash id="g7d4qx"
docker logs <container_name>
```

Example:

```bash id="p9w3kt"
docker logs api-gateway
```

---

### Checking Running Containers

To verify that all services are running:

```bash id="c3x8zr"
docker ps
```

---

### Restarting Services

To restart CRM services manually:

```bash id="n5k1vh"
./deploy.sh crm-redeploy
```

To stop/start CRM Stack:

```bash id="f2m7qs"
./deploy.sh crm-stop
./deploy.sh crm-start
```

---

### Common Issues

#### Services Not Accessible

- Wait a few minutes after installation
- Check DNS configuration
- Ensure ports **80** and **443** are open
- Verify containers are running (`docker ps`)

---

#### SSL Certificates Not Issued

- Ensure domain names point to your server
- Verify port 80 is accessible from the internet
- Wait a few minutes for Let's Encrypt to complete

---

#### Containers Not Starting

Check logs for the failing container:

```bash id="h4v9lb"
docker logs <container_name>
```

---

#### RabbitMQ Not Working

- Ensure the container is running:

```bash id="k6p2dz"
docker ps | grep rabbitmq
```

- Check logs:

```bash id="x8n3fw"
docker logs rabbitmq
```

---

### Reset / Clean Start (Advanced)

If you need to fully reset the installation:

```bash id="d7q4mp"
./deploy.sh uninstall
```

> ⚠️ Tip: The `uninstall` command will remove **all TitanCRM stacks**, including CRM, Infra, and Proxy containers, all Docker volumes created by TitanCRM, and the shared network.  
> Use it with caution — all data stored in these volumes will be permanently deleted!

---

### Useful Tips

- Always check logs first — most issues are visible there
- Ensure your `.env` configuration is correct
- Do not modify Docker volumes manually unless necessary

---

> 💡 Tip: If something doesn't work, logs are your best starting point.

## System Architecture

TitanCRM is deployed as a containerized microservices-based system using Docker.

The architecture consists of three main layers:

---

### 1. Proxy Layer

- Nginx reverse proxy
- Handles incoming HTTP/HTTPS traffic
- Automatically provisions SSL certificates (Let's Encrypt)
- Routes requests to internal services based on domain names

> 💡 Tip: If you are using domain proxying via Cloudflare, temporarily disable it during deployment.  
> This ensures Let's Encrypt can issue HTTPS certificates correctly and the Nginx proxy can configure the domains without interference.

---

### 2. Application Layer (TitanCRM Services)

Core business logic is implemented as independent microservices:

- API Gateway
- Frontend
- Authentication service
- Analytics
- Company management
- Content management
- Cost management
- Finance
- Scheduler (background jobs)
- Integrations (Telegram, Facebook, Mail, etc.)

All services communicate internally via:

- HTTP APIs
- RabbitMQ (message broker)

---

### 3. Infrastructure Layer

Provides supporting services required for system operation:

- PostgreSQL databases (multiple instances)
- RabbitMQ (message broker)
- pgAdmin (database management UI)
- Dozzle (log viewer)
- Portainer (container management)

---

### Networking

- All containers are connected via a shared Docker network:
  - `titan-crm-network`

- Internal services are not exposed directly to the internet
- External access is only available through the proxy layer

---

### Data Persistence

All critical data is stored in Docker volumes:

- Databases
- Message queues
- Configuration files
- Proxy settings

This ensures data is preserved across container restarts and upgrades.

## Backup Recommendations

To prevent data loss, it is strongly recommended to implement regular backups.

---

### What Should Be Backed Up

You should regularly back up:

- PostgreSQL databases
- Docker volumes
- `.env` configuration file

---

### Backup Options

#### Option 1: Database Dumps (Recommended)

Create backups using `pg_dump`:

```bash id="b3k9xv"
docker exec -t company-management-db pg_dump -U company company-management > backup.sql
```

Repeat for other databases as needed.

---

#### Option 2: Volume Backup

You can back up Docker volumes directly:

```bash id="v6n2pd"
docker run --rm -v infra-company-management-db:/volume -v $(pwd):/backup alpine \
  tar czf /backup/company-management.tar.gz /volume
```

---

#### Option 3: Full Server Backup

Use system-level backup tools to snapshot the entire server.

---

### Backup Frequency

- Production: daily backups recommended
- Critical systems: multiple backups per day

---

### Important Notes

- Store backups on a separate server or cloud storage
- Regularly test backup restoration
- Do not rely on a single backup copy

---

> 💡 Tip: Automate backups using cron jobs for reliability.

## Security Notes

TitanCRM installer includes several built-in security practices:

---

### Automatic HTTPS

- All services are exposed via HTTPS
- SSL certificates are automatically issued using Let's Encrypt

---

### Isolated Networking

- Internal services are not exposed publicly
- All communication happens inside a private Docker network

---

### Generated Credentials

- Sensitive passwords are automatically generated during installation
- Credentials are not hardcoded in the repository

---

### Access Control

- Admin interfaces (pgAdmin, RabbitMQ, Dozzle) are protected with authentication
- Each service uses its own credentials

---

### Recommendations

For improved security:

- Restrict access to admin panels via firewall or VPN
- Regularly update the system (`crm-upgrade`)
- Monitor logs for suspicious activity

---

> ⚠️ Always store credentials securely and avoid sharing them publicly.
