# TitanCRM Deployer — Claude Context

## General

- **Purpose:** Single-command self-hosted installer for TitanCRM — clients run `./deploy.sh` on a clean Ubuntu 24.04 server
- **Runtime:** Docker Compose; three stacks deployed in order: `infra.yaml` → `crm.yaml` → `proxy.yaml`
- **Infra stack:** PostgreSQL (4 databases), RabbitMQ, pgAdmin, Dozzle
- **CRM stack:** all TitanCRM microservices + frontend; images `ihorcrm/<service>:<tag>`; tag controlled by `CRM_IMAGE_TAG` in `crm.yaml`
- **Proxy stack:** nginx-proxy + letsencrypt-companion — routes by `VIRTUAL_HOST` env var, issues SSL automatically
- **Network:** all containers share `titan-crm-network` Docker bridge
- **Secrets:** generated at deploy time by `deploy.sh` via `openssl rand` / `/dev/urandom`, injected into yaml files via `sed`, saved to `credentials.txt`
- **README.md is client-facing** — keep it clean and installation-focused; internal dev notes belong in `docs/` and here
- **Adding a service:** requires changes in `crm.yaml`, `wait_crm_containers()`, and potentially `create_volumes()`, `configure_rabbitmq()`, `configure_pgadmin()` in `deploy.sh`

---

## Documentation Map

Before starting any task — read the relevant file from `docs/` first.

| File                         | When to read                                                               |
| ---------------------------- | -------------------------------------------------------------------------- |
| `docs/stack-architecture.md` | Understand infra/crm/proxy stack layout, volumes, networking, deploy order |
| `docs/adding-a-service.md`   | Add a new service to the self-hosted deployer                              |
