# TitanCRM Deployment Guide

## Overview

TitanCRM Deployer is a one-command script that installs a full production-ready TitanCRM stack on a clean server.

It automatically:

- prepares the server environment
- deploys infrastructure and services
- configures HTTPS and routing
- generates secure credentials

---

## Quick Start

```bash
chmod +x deploy.sh
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

> ⚠️ **Important:** You must configure the `.env` file before running the deployer.  
> The deployment will not work correctly without proper configuration.

Set your domains:

```bash
FRONTEND_DOMAIN=app.example.com
BACKEND_DOMAIN=api.example.com
RABBITMQ_DOMAIN=rabbit.example.com
PGADMIN_DOMAIN=pgadmin.example.com
DOZZLE_DOMAIN=logs.example.com
```

pgAdmin login:

```bash
PGADMIN_LOGIN=admin@example.com
```

### External services required

- Brevo (SMTP)
- Telegram Bot
- S3 storage

> ⚠️ **Detailed setup:** https://docs.google.com/document/d/1npkPQs9O_Bshj4giDei89BFjfmimeCCjBLWwhh76zYg

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
| crm-redeploy | Recreate CRM containers          |
| crm-stop     | Stop CRM                         |
| crm-start    | Start CRM                        |
| uninstall    | Remove everything (⚠️ data loss) |

---

## Troubleshooting

Check logs:

```bash
docker logs <container_name>
```

Check running containers:

```bash
docker ps
```

Common issues:

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
