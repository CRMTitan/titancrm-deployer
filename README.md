# TitanCRM Deployment Guide

## Overview

TitanCRM Deployer is a one-command script that installs a full production-ready TitanCRM stack on a clean server.

It automatically:

- prepares the server environment
- generates secure credentials
- deploys infrastructure and services
- configures HTTPS and routing

---

## Quick Start

> ⚠️ **Compatibility:** The deployer is designed for **Ubuntu Server 24.04 LTS**.  
> Full support and stable operation are guaranteed only on this version.

Connect to your server via SSH, then clone the TitanCRM deployer repository:

```bash
cd ~
git clone https://github.com/CRMTitan/titancrm-deployer.git
```

Copy the example `.env` to create your own configuration:

> ⚠️ **Important:** You must configure the `.env` file before running the deployer.  
> The deployment will not work correctly without proper configuration.

```bash
cd titancrm-deployer
cp .env.example .env
```

Then, visit the [**Configuration (.env) guide**](https://github.com/CRMTitan/titancrm-deployer#configuration-env) to start setting up your environment.

You can view all supported deployer commands by running:

```bash
./deploy.sh help
```

Run the deploy:

```bash
./deploy.sh
```

Confirm deployment when prompted:

```bash
Type 'deploy' to continue
```

After completion, all service URLs and credentials will be displayed.

---

## Requirements

### System

- Ubuntu 24.04
- Root access

### Hardware

- Minimum: 120 GB disk
- Recommended: 4 CPU / 8 GB RAM

> ⚠️ **Disk space notice:** We recommend keeping sufficient free disk space beyond the minimum. Updates of microservices and general CRM operation require extra space to ensure smooth deployment and proper functioning of all services.

### Network

- Public IP address
- Open ports: 80, 443

### Domain Configuration Requirements

⚠️ The deployment relies on DNS-based routing for all exposed services.
You are responsible for provisioning and maintaining all required DNS records prior to installation.

**DNS Prerequisite**

All services are exposed via dedicated subdomains under your primary domain.
Each service endpoint must be resolvable to the server’s public IP address before deployment begins.

**Required DNS Records**

You must configure DNS A (or AAAA) records for the following services:

| Domain             | Description          |
|--------------------|----------------------|
| yourdomain.ltd     | frontend             |
| api.yourdomain.ltd | backend API          |
| mq.yourdomain.ltd  | message broker UI    |
| db.yourdomain.ltd  | database UI          |
| logs.yourdomain.ltd| logs UI              |

**Operational Requirements**

- DNS propagation must be completed prior to running the deployment
- Partial or missing DNS configuration will result in service unavailability
- The deployment process does not perform DNS provisioning or validation
- You are responsible for ensuring consistency between configured domains and enabled services

**Important Notice**

⚠️ Failure to configure all required subdomains will lead to incomplete system functionality and may prevent successful deployment or service access.

> ⚠️ **Note:** Missing DNS records can be added after deployment — SSL certificates will be issued automatically.

---

## Configuration (.env)

Set yout valid email for CRM login:

```bash
SEED_ADMIN_EMAIL=email@yourdomain.ltd
```

Set your domains:

```bash
FRONTEND_DOMAIN=yourdomain.ltd
BACKEND_DOMAIN=api.yourdomain.ltd
RABBITMQ_DOMAIN=mq.yourdomain.ltd
PGADMIN_DOMAIN=db.yourdomain.ltd
DOZZLE_DOMAIN=logs.yourdomain.ltd
```

### Facebook Auth Proxy

> ⚠️ You must provide your frontend domain (e.g. `yourdomain.ltd`) to the TitanCRM team to enable Facebook authentication. Please note that configuration may take some time. Without this, Facebook authentication will not work correctly.

### External services required

- Brevo (SMTP)
- Telegram Bot
- S3 storage

> ⚠️ **Detailed setup:** [Google Docs](https://docs.google.com/document/d/1npkPQs9O_Bshj4giDei89BFjfmimeCCjBLWwhh76zYg)

---

## What Gets Deployed

The deployment provisions a full TitanCRM stack, including:

- **Core services**
  - PostgreSQL databases
  - RabbitMQ message broker

- **Application layer**
  - TitanCRM microservices

- **Management & observability**
  - pgAdmin (database management UI)
  - Dozzle (logs viewer)

- **Edge layer**
  - Reverse proxy with automatic SSL certificate provisioning

---

## Deployment Flow

1. Validate system prerequisites
2. Prepare Docker environment
3. Deploy infrastructure (DB, RabbitMQ, etc.)
4. Deploy TitanCRM microservices
5. Configure edge layer

The entire process is fully automated.

---

## Access

After deployment, services are available at:

- Frontend → https://FRONTEND_DOMAIN
- API → https://BACKEND_DOMAIN
- RabbitMQ UI → https://RABBITMQ_DOMAIN
- Databases UI → https://PGADMIN_DOMAIN
- Logs UI → https://DOZZLE_DOMAIN

Credentials are generated automatically and stored in `credentials.txt`.

> Note: some services may take a few minutes to become available after deployment.

---

## Commands

```bash
./deploy.sh <command>
```

| Command                     | Description                                                                      |
| --------------------------- | -------------------------------------------------------------------------------- |
| help                        | Show available commands                                                          |
| crm-upgrade                 | Update CRM services                                                              |
| crm-redeploy                | Recreate CRM services                                                            |
| crm-stop                    | Stop CRM services                                                                |
| crm-start                   | Start CRM services                                                               |
| crm-tag-get                 | Show current CRM image tag                                                       |
| crm-tag-set `tag` [--force] | Set new CRM image tag (requires upgrade). Use --force to bypass version checks.  |
| uninstall                   | Remove everything (⚠️ data loss)                                                 |

---

## CRM Update

TitanCRM uses versioned Docker image tags to manage CRM updates.

### Step 1: Set a new image tag

Use the `crm-tag-set` command to update the image tag:

```bash
./deploy.sh crm-tag-set stable-1.2.3
```

- Recommended tag format: ```stable-x.x.x``` (e.g. ```stable-1.2.3```)
- The deployer extracts the semantic version (```x.y.z```) and prevents downgrades by default
- If a lower version is provided, the operation will be blocked to avoid potential data inconsistency and unpredictable behavior

Non-version tags (e.g. ```latest```, ```beta```) are allowed, but version checks will be skipped with a warning.

### Force downgrade (not recommended)

You can override version checks using the ```--force``` flag:

```bash
./deploy.sh crm-tag-set stable-1.0.3 --force
```

⚠️ Warning:

- Downgrading may break database compatibility
- Existing data may become inconsistent or unusable
- System behavior is not guaranteed after downgrade

### Step 2: Apply the update

After setting the tag, apply changes by upgrading the CRM stack:

```bash
./deploy.sh crm-upgrade
```

This will:

- Pull updated Docker images
- Restart CRM containers
- Remove unused CRM images

---

## Troubleshooting

Check logs:

Open your log service:

```bash
https://DOZZLE_DOMAIN
```

or

Use docker:

```bash
docker logs <container_name>
```

Check running containers:

```bash
docker ps
```

Common issues:

- Incorrect or incomplete [.env](https://github.com/CRMTitan/titancrm-deployer#configuration-env) configuration — make sure all required variables are set and valid
- Domains not pointing to server
- Ports 80/443 closed
- Services still starting
- Cloudflare proxy enabled — temporarily disable proxy (set DNS to "DNS only") to allow Let's Encrypt to issue certificates

---

## Architecture

- **Proxy**: Nginx + Let's Encrypt
- **Application**: TitanCRM microservices
- **Infrastructure**: PostgreSQL, RabbitMQ, pgAdmin, Dozzle

All services run in Docker and communicate via a private network.

---

## Backup & Security

- Backup databases and Docker volumes regularly
- Store `.env` securely
- Restrict admin access (VPN/firewall recommended)

HTTPS and credentials are configured automatically.
