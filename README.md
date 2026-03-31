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

Make the script executable:

```bash
chmod +x deploy.sh
```

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

### Domain

Point domains to your server:

- Frontend
- API
- RabbitMQ
- pgAdmin
- Dozzle

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
RABBITMQ_DOMAIN=rabbit.yourdomain.ltd
PGADMIN_DOMAIN=pgadmin.yourdomain.ltd
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

- PostgreSQL databases
- RabbitMQ
- pgAdmin
- Dozzle (logs)
- TitanCRM services (API, frontend, workers)
- Nginx reverse proxy with HTTPS

---

## Deployment Flow

1. System validation
2. Docker setup
3. Infrastructure deployment
4. CRM services deployment
5. Reverse proxy + HTTPS

The process is fully automated.

---

## Access

After deployment:

- Frontend: https://FRONTEND_DOMAIN
- API: https://BACKEND_DOMAIN
- RabbitMQ: https://RABBITMQ_DOMAIN
- pgAdmin: https://PGADMIN_DOMAIN
- Logs: https://DOZZLE_DOMAIN

Credentials are generated automatically and saved in `credentials.txt`.

> Some services may take a few minutes to become available.

---

## Commands

```bash
./deploy.sh <command>
```

| Command      | Description                      |
| ------------ | -------------------------------- |
| help         | Show available commands          |
| crm-upgrade  | Update CRM services              |
| crm-redeploy | Recreate CRM services            |
| crm-stop     | Stop CRM services                |
| crm-start    | Start CRM services               |
| uninstall    | Remove everything (⚠️ data loss) |

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
