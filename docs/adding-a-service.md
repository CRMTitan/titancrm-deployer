# Adding a New CRM Service

When adding a new TitanCRM microservice to the deployer, update the following locations in `deploy.sh` and `crm.yaml`.

## 1. crm.yaml — add the service definition

Add a new service block following the existing pattern:

```yaml
<service-name>:
  image: ihorcrm/<service-name>:${CRM_IMAGE_TAG}
  container_name: <service-name>
  <<: *common-restart
  environment:
    COMMIT_SHORT_SHA: "n/a"
    # ... service-specific env vars
  networks: *common-network
  logging: *common-logging
  labels: *common-labels-crm
```

Use `*common-restart`, `*common-network`, `*common-logging`, and `*common-labels-crm` anchors consistently.

## 2. deploy.sh — wait_crm_containers()

Add the container name to the `CONTAINERS` array so the deploy script waits for it to reach `running` state before proceeding:

```bash
CONTAINERS=(
  ...
  "<service-name>"
)
```

## 3. deploy.sh — create_volumes() (if the service has a database)

If the service requires a dedicated PostgreSQL volume, add it to the `VOLUMES` array in `create_volumes()`:

```bash
VOLUMES=(
  ...
  infra-<service-name>-db
)
```

And add the corresponding volume to the `uninstall` cleanup section as well.

## 4. infra.yaml (if the service has a database)

Add the PostgreSQL container and its volume definition to `infra.yaml`.

## 5. deploy.sh — configure_rabbitmq() (if the service uses RabbitMQ)

Add the service name to `USERS` and `PERMISSION_USERS` arrays in `configure_rabbitmq()` so RabbitMQ credentials are provisioned at deploy time.

## 6. pgadmin/servers.json — configure_pgadmin() (if the service has a database)

Add a server entry to the `configure_pgadmin()` heredoc so the database appears in pgAdmin automatically.
