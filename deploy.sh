#!/usr/bin/env bash

set -e

# =====[ INIT: Clear screen ]=====
if [[ -t 1 ]]; then
  printf "\033c"
  echo -e "\e[92m🚀 TitanCRM Deployment Tool\e[0m"
  echo -e "\e[90m----------------------------------\e[0m"
  echo
fi

# =====[ COLORS ]=====
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BRIGHT_RED="\e[91m"
BRIGHT_BLUE="\e[94m"
BRIGHT_GREEN="\e[92m"
RESET="\e[0m"

# =====[ DEPLOY: Marker ] =====
MARKER_FILE="/opt/titancrm/.installing"
FINAL_MARKER="/opt/titancrm/.installed"

# =====[ OUTPUT: Credentials file ]=====
CREDENTIALS_FILE="credentials.txt"

# =====[ HELPERS ]=====
info() {
  echo -e "${GREEN}[INFO]${RESET} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${RESET} $1"
}

error() {
  echo -e "${RED}[ERROR]${RESET} $1"
  exit 1
}

# =====[ CONFIRMATION: Deployment ]=====
confirm_deploy() {

  echo
  warn "This action will deploy TitanCRM on this server."
  warn "Existing containers, networks and volumes may be modified."
  echo

  read -p "Type 'deploy' to continue: " CONFIRM

  if [[ "$CONFIRM" != "deploy" ]]; then
    error "Deployment cancelled"
  fi

  echo
  info "Confirmation accepted. Continuing deployment..."
  echo
}

# =====[ CHECK: Initial deploy ]=====
deploy_start() {
  info "Checking deployment status..."
  echo
  if [[ -f "$FINAL_MARKER" ]]; then
    error "TitanCRM has already been deployed on this server.

A previous installation was completed successfully.

Run './deploy.sh uninstall' before deploying again.

This will remove existing containers, volumes and data.
Proceed only if you understand the implications.
"
  fi

  if [[ -f "$MARKER_FILE" ]]; then
    error "Detected an incomplete TitanCRM deployment.

A previous installation was interrupted (manually or due to an error).
The system may be in an inconsistent state.

Run './deploy.sh uninstall' before deploying again.

This will remove existing containers, volumes and data.
Proceed only if you understand the implications.
"
  fi

  info "Starting deployment..."
  echo
  mkdir -p "$(dirname "$MARKER_FILE")"
  touch "$MARKER_FILE"
  echo
}

# =====[ DEPLOY: Done ]=====
deploy_done() {
  info "Completing deployment process..."
  mkdir -p "$(dirname "$FINAL_MARKER")"
  rm -f "$MARKER_FILE"
  touch "$FINAL_MARKER"
}

# =====[ CHECK: Integrity ]=====
integrity_check() {

  info "Verifying integrity..."

  REQUIRED_FILES=(
    ".env"
    "infra.yaml"
    "crm.yaml"
    "proxy.yaml"
  )

  MISSING=()

  for FILE in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$FILE" ]]; then
      MISSING+=("$FILE")
    fi
  done

  if [[ ${#MISSING[@]} -ne 0 ]]; then
    error "❌ Missing required files: ${MISSING[*]}
    "
  fi

  info "Integrity check passed"
}

# =====[ CHECK: Root privileges ]=====
if [[ "$EUID" -ne 0 ]]; then
  error "This script must be run as root"
fi

# =====[ CHECK: OS version ]=====
check_os() {

  info "Checking operating system..."

  if ! grep -q "Ubuntu 24.04" /etc/os-release; then
    error "This installer supports only Ubuntu 24.04"
  fi

  info "Ubuntu 24.04 detected"
}

# =====[ CHECK: Disk space ]=====
check_disk() {

  info "Checking available disk space..."

  FREE_SPACE=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')

  if [[ "$FREE_SPACE" -lt 120 ]]; then
    error "At least 120GB of free disk space is required"
  fi

  info "Disk space OK (${FREE_SPACE}GB available)"
}

# =====[ SETUP: Docker installation ]=====
install_docker() {

  if command -v docker &> /dev/null; then
    info "Docker already installed"
    return
  fi

  warn "Docker not found. Installing Docker..."

  info "Updating package lists..."
  apt update -y >/dev/null 2>&1

  info "Installing required dependencies..."
  apt install -y ca-certificates curl gnupg openssl >/dev/null 2>&1

  info "Setting up Docker GPG key..."
  install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
  rm -f /etc/apt/keyrings/docker.gpg
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1
  chmod a+r /etc/apt/keyrings/docker.gpg >/dev/null 2>&1

  info "Adding Docker repository..."
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    noble stable" \
    > /etc/apt/sources.list.d/docker.list

  info "Updating package lists again..."
  apt update -y >/dev/null 2>&1

  info "Installing Docker packages..."
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

  info "Enabling and starting Docker service..."
  systemctl enable docker >/dev/null 2>&1
  systemctl start docker >/dev/null 2>&1

  info "Docker installed successfully"
}

# =====[ SETUP: Docker network ]=====
create_network() {

  NETWORK="titan-crm-network"

  info "Checking docker network..."

  if docker network inspect "$NETWORK" >/dev/null 2>&1; then
    info "Network $NETWORK already exists"
  else
    info "Creating docker network $NETWORK"
    if docker network create "$NETWORK" >/dev/null 2>&1; then
      info "Network $NETWORK created successfully"
    else
      error "Failed to create Docker network $NETWORK"
    fi
  fi
}

# =====[ SETUP: Docker volumes ]=====
create_volumes() {

  info "Checking required docker volumes..."

  VOLUMES=(
    infra-company-management-db
    infra-content-db
    infra-cost-management-db
    infra-finance-db
    infra-rabbitmq
    infra-pgadmin
    proxy-html
    proxy-certs
    proxy-vhost
  )

  for VOLUME in "${VOLUMES[@]}"; do

    if docker volume inspect "$VOLUME" >/dev/null 2>&1; then
      info "Volume $VOLUME already exists"
    else
      info "Creating volume $VOLUME"
      docker volume create "$VOLUME" >/dev/null
    fi

  done
}

# =====[ SECRETS: Generation ]=====
generate_secrets() {

  info "Generating secrets..."

  # Infra RabbitMQ admin password
  RABBITMQ_ADMIN_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)

  # Infra PGAdmin admin password
  PGADMIN_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)
  sed -i "s|PGADMIN_DEFAULT_PASSWORD:.*|PGADMIN_DEFAULT_PASSWORD: \"$PGADMIN_PASSWORD\"|g" infra.yaml

  # Infra Dozzle admin password
  DOZZLE_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)

  # CRM JWT tokens
  JWT_ACCESS_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 128)
  JWT_REFRESH_SECRET=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 128)
  safe_access=$(printf '%s\n' "$JWT_ACCESS_SECRET" | sed 's/[&/\\"]/\\&/g')
  safe_refresh=$(printf '%s\n' "$JWT_REFRESH_SECRET" | sed 's/[&/\\"]/\\&/g')
  sed -i "s|^\([[:space:]]*\)JWT_ACCESS_SECRET:.*|\1JWT_ACCESS_SECRET: \"$safe_access\"|" crm.yaml
  sed -i "s|^\([[:space:]]*\)JWT_REFRESH_SECRET:.*|\1JWT_REFRESH_SECRET: \"$safe_refresh\"|" crm.yaml

  # CRM encryption key
  ENCRYPTION_KEY=$(openssl rand -hex 32)
  sed -i "s|^\([[:space:]]*\)ENCRYPTION_KEY:.*|\1ENCRYPTION_KEY: \"$ENCRYPTION_KEY\"|" crm.yaml

  # CRM admin password
  upper=$(tr -dc 'A-Z' </dev/urandom | head -c 1)
  lower=$(tr -dc 'a-z' </dev/urandom | head -c 1)
  digit=$(tr -dc '0-9' </dev/urandom | head -c 1)
  special=$(tr -dc '!@#$%^&*' </dev/urandom | head -c 1)
  rest=$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 12)
  SEED_ADMIN_PASSWORD=$(echo "$upper$lower$digit$special$rest" | fold -w1 | shuf | tr -d '\n')
  safe_password=$(printf '%s\n' "$SEED_ADMIN_PASSWORD" | sed 's/[&/\\"]/\\&/g')
  sed -i "s|^\([[:space:]]*\)SEED_ADMIN_PASSWORD:.*|\1SEED_ADMIN_PASSWORD: \"$safe_password\"|" crm.yaml

  info "Secrets generated"

}

# =====[ SETUP: Dozzle authentication ]=====
configure_dozzle() {

  info "Setting up Dozzle authentication..."

  echo -n "[33%] Generating Dozzle password hash..."
  DOZZLE_PASSWORD_HASH=$(docker run --rm httpd:2.4-alpine \
    htpasswd -nbBC 10 "" "$DOZZLE_PASSWORD" 2>/dev/null | tr -d ':\n')
  echo " done"

  echo -n "[66%] Creating Dozzle volume..."
  docker volume create infra-dozzle >/dev/null 2>&1
  echo " done"

  echo -n "[100%] Writing users.yaml into volume..."
  docker run --rm -i -v infra-dozzle:/data alpine sh -c "cat > /data/users.yaml" <<EOF >/dev/null 2>&1
users:
  admin:
    email: admin@local
    name: admin
    password: ${DOZZLE_PASSWORD_HASH}
EOF
  echo " done"

  # Cleanup temporary images
  docker image rm httpd:2.4-alpine >/dev/null 2>&1 || true

  info "Dozzle authentication configured"

}

# =====[ SETUP: Proxy configuration ]=====
configure_proxy() {

  info "Setting up proxy configuration..."

  echo -n "[100%] Writing conf into volume..."
  docker run --rm -i -v proxy-vhost:/data alpine sh -c "cat > /data/default" <<EOF >/dev/null 2>&1
client_max_body_size 700m;
proxy_buffer_size 8k;
proxy_read_timeout 900;
proxy_send_timeout 900;
proxy_request_buffering off;
EOF
  echo " done"

  info "Proxy configuration created in volume"
}

# =====[ SETUP: pgAdmin configuration ]=====
configure_pgadmin() {

  info "Setting up pgAdmin servers configuration..."

  echo -n "[50%] Creating pgadmin directory..."
  mkdir -p ./pgadmin
  echo " done"

  echo -n "[100%] Writing servers.json..."
  cat <<EOF > ./pgadmin/servers.json
{
  "Servers": {
    "1": {
      "Group": "TitanCRM",
      "Name": "company-management",
      "Host": "company-management-db",
      "Port": 5432,
      "MaintenanceDB": "company-management",
      "Username": "company",
      "Password": "company"
    },
    "2": {
      "Group": "TitanCRM",
      "Name": "content",
      "Host": "content-db",
      "Port": 5432,
      "MaintenanceDB": "content",
      "Username": "content",
      "Password": "content"
    },
    "3": {
      "Group": "TitanCRM",
      "Name": "cost-management",
      "Host": "cost-management-db",
      "Port": 5432,
      "MaintenanceDB": "cost-management",
      "Username": "cost",
      "Password": "cost"
    },
    "4": {
      "Group": "TitanCRM",
      "Name": "finance",
      "Host": "finance-db",
      "Port": 5432,
      "MaintenanceDB": "finance",
      "Username": "finance",
      "Password": "finance"
    }
  }
}
EOF
  echo " done"

  # Cleanup temporary image
  docker image rm alpine:latest >/dev/null 2>&1 || true

  info "pgAdmin servers configuration created"

}

# =====[ DEPLOY: Infra stack ]=====
deploy_infra() {

  info "Deploying infra docker stack..."

  if [[ ! -f infra.yaml ]]; then
    error "infra.yaml not found in current directory"
  fi

  echo
  info "[1/2] Pulling Docker images..."
  docker compose -f infra.yaml -p infra pull

  echo
  info "Waiting 10 seconds before starting infra services..."
  for i in {10..1}; do
    echo -ne "Starting in $i seconds...\r"
    sleep 1
  done
  echo

  echo
  info "[2/2] Starting infra services..."
  docker compose -f infra.yaml -p infra up -d

  echo
  info "Infra stack successfully deployed"
}

# =====[ WAIT: RabbitMQ readiness ]=====
wait_rabbitmq() {

  info "Waiting for RabbitMQ container..."

  MAX_ATTEMPTS=30
  ATTEMPT=1

  while true; do

    if docker exec rabbitmq rabbitmq-diagnostics ping >/dev/null 2>&1; then
      info "RabbitMQ is ready"
      break
    fi

    if [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then
      error "RabbitMQ did not become ready in time"
    fi

    warn "RabbitMQ not ready yet... ($ATTEMPT/$MAX_ATTEMPTS)"

    sleep 30
    ((ATTEMPT++))

  done

}

# =====[ CONFIGURE: RabbitMQ ]=====
configure_rabbitmq() {

  info "Configuring RabbitMQ users and permissions..."

  RABBIT_CONTAINER="rabbitmq"

  # -------------------------------
  # Create admin user
  # -------------------------------
  docker exec $RABBIT_CONTAINER rabbitmqctl list_users | grep -q "^admin" || \
  docker exec $RABBIT_CONTAINER rabbitmqctl add_user admin "$RABBITMQ_ADMIN_PASSWORD"

  docker exec $RABBIT_CONTAINER rabbitmqctl set_user_tags admin administrator

  # -------------------------------
  # Create service users
  # -------------------------------
  USERS=(
    cost-management
    scheduler
    content
    company-management
  )

  for USER in "${USERS[@]}"; do

    if docker exec $RABBIT_CONTAINER rabbitmqctl list_users | grep -q "^$USER"; then
      info "User $USER already exists"
    else
      info "Creating user $USER"
      docker exec $RABBIT_CONTAINER rabbitmqctl add_user "$USER" "$USER"
    fi

  done

  # -------------------------------
  # Set permissions
  # -------------------------------
  PERMISSION_USERS=(
    admin
    cost-management
    scheduler
    content
    company-management
  )

  for USER in "${PERMISSION_USERS[@]}"; do

    docker exec $RABBIT_CONTAINER rabbitmqctl set_permissions -p / "$USER" ".*" ".*" ".*"

  done

  info "RabbitMQ configuration completed"

}

# =====[ DEPLOY: CRM stack ]=====
deploy_crm() {

  info "Deploying CRM docker stack..."

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  echo
  info "[1/2] Pulling Docker images..."
  docker compose -f crm.yaml -p crm pull

  echo
  info "Waiting 10 seconds before starting services..."
  for i in {10..1}; do
    echo -ne "Starting in $i seconds...\r"
    sleep 1
  done
  echo

  echo
  info "[2/2] Starting CRM services..."
  docker compose -f crm.yaml -p crm up -d

  echo
  info "CRM stack successfully deployed"
}

# =====[ WAIT: CRM containers ]=====
wait_crm_containers() {
  CONTAINERS=(
    "analytics"
    "api-gateway"
    "app-auth"
    "binom"
    "company-management"
    "content"
    "cost-management"
    "facebook"
    "finance"
    "frontend"
    "keitaro"
    "mail"
    "scheduler"
    "telegram-bot"
  )

  MAX_ATTEMPTS=30
  ATTEMPT=1

  info "Waiting for all CRM containers to be running..."

  while true; do
    NOT_RUNNING=()
    
    for C in "${CONTAINERS[@]}"; do
      STATUS=$(docker inspect --format='{{.State.Status}}' "$C" 2>/dev/null || echo "missing")
      if [[ "$STATUS" != "running" ]]; then
        NOT_RUNNING+=("$C")
      fi
    done

    if [[ ${#NOT_RUNNING[@]} -eq 0 ]]; then
      info "All CRM containers are running"
      break
    fi

    if [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then
      error "Some CRM containers did not start in time: ${NOT_RUNNING[*]}"
    fi

    warn "Waiting for containers to start: ${NOT_RUNNING[*]} ($ATTEMPT/$MAX_ATTEMPTS)"
    sleep 30
    ((ATTEMPT++))
  done
}

# =====[ DEPLOY: Proxy stack ]=====
deploy_proxy() {

  info "Deploying proxy docker stack..."

  if [[ ! -f proxy.yaml ]]; then
    error "proxy.yaml not found in current directory"
  fi

  echo
  info "[1/2] Pulling Docker images..."
  docker compose -f proxy.yaml -p proxy pull

  echo
  info "Waiting 10 seconds before starting proxy services..."
  for i in {10..1}; do
    echo -ne "Starting in $i seconds...\r"
    sleep 1
  done
  echo

  echo
  info "[2/2] Starting proxy services..."
  docker compose -f proxy.yaml -p proxy up -d

  echo
  info "Proxy stack successfully deployed"
}

# =====[ LOAD: Environment variables ]=====
load_env() {
  ENV_FILE=".env"

  if [[ ! -f $ENV_FILE ]]; then
    warn "$ENV_FILE not found, skipping environment load"
    return
  fi

  info "Loading environment variables..."
  # shellcheck disable=SC1090
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
}

# =====[ OUTPUT: Save credentials ]=====
save_credentials() {
  cat <<EOF > "$CREDENTIALS_FILE"
Access URLs:

Frontend:         https://${FRONTEND_DOMAIN}
login: ${SEED_ADMIN_EMAIL} | password: ${SEED_ADMIN_PASSWORD}

Backend API:      https://${BACKEND_DOMAIN}

RabbitMQ Console: https://${RABBITMQ_DOMAIN}
login: admin | password: ${RABBITMQ_ADMIN_PASSWORD}

Log Console:      https://${DOZZLE_DOMAIN}
login: admin | password: ${DOZZLE_PASSWORD}

Database Console: https://${PGADMIN_DOMAIN}
login: ${SEED_ADMIN_EMAIL} | password: ${PGADMIN_PASSWORD}

Database credentials:
- company-management: company
- content: content
- cost-management: cost
- finance: finance

Encryption Key: ${ENCRYPTION_KEY}

EOF

  chmod 600 "$CREDENTIALS_FILE"
  info "Credentials saved to $CREDENTIALS_FILE"
}

# =====[ CLI: Commands ]=====

# -------------------------------
# Unknown command handler
# -------------------------------
if [[ -n "$1" ]]; then
  case "$1" in
    crm-upgrade|crm-tag-get|crm-tag-set|crm-redeploy|crm-stop|crm-start|uninstall|help)
      ;;
    *)
      error "❌ Unknown command: $1
      
      Run './deploy.sh help' to see available commands.
      "
      ;;
  esac
fi

# -------------------------------
# CRM upgrade
# -------------------------------
if [[ "$1" == "crm-upgrade" ]]; then

  info "Upgrading CRM stack..."

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  echo
  info "Pulling CRM images..."
  docker compose -f crm.yaml -p crm pull

  echo
  info "Restarting containers in 10 seconds..."
  for i in {10..1}; do
    echo -ne "Restarting in $i seconds...   \r"
    sleep 1
  done
  echo

  echo
  info "Starting updated containers..."
  docker compose -f crm.yaml -p crm up -d

  echo
  info "Cleaning up old CRM images..."

  CRM_IMAGES=$(docker compose -f crm.yaml -p crm images -q | sort -u)

  if [[ -n "$CRM_IMAGES" ]]; then
    for IMAGE_ID in $CRM_IMAGES; do
      IN_USE=$(docker ps -a --filter "ancestor=$IMAGE_ID" -q)
      if [[ -z "$IN_USE" ]]; then
        docker image rm "$IMAGE_ID" >/dev/null 2>&1 || true
      fi
    done
  fi

  echo
  info "CRM stack successfully upgraded"

  exit 0
fi

# -------------------------------
# CRM get tag
# -------------------------------
if [[ "$1" == "crm-tag-get" ]]; then

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  TAG=$(grep -m1 "image:" crm.yaml | sed -E 's|.*:([^:/[:space:]]+)$|\1|')

  if [[ -z "$TAG" ]]; then
    error "Could not detect tag in crm.yaml"
  fi

  echo
  info "Current CRM image tag: $TAG"
  echo

  exit 0
fi

# -------------------------------
# CRM set tag
# -------------------------------
if [[ "$1" == "crm-tag-set" ]]; then

  NEW_TAG="$2"

  if [[ -z "$NEW_TAG" ]]; then
    error "Please specify a tag. Usage: ./deploy.sh crm-tag-set v1.0.3"
  fi

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  echo
  info "Updating CRM image tags to: $NEW_TAG..."

  sed -i -E "s|^([[:space:]]*image: .+):[^[:space:]]+|\1:${NEW_TAG}|" crm.yaml

  echo "Updating CRM_IMAGE_TAG..."

  sed -i -E "s|^( *CRM_IMAGE_TAG:\s*)\"[^\"]*\"|\1\"${NEW_TAG}\"|g" crm.yaml

  echo
  info "Tags successfully updated."
  info "You can now upgrade the CRM stack using: ./deploy.sh crm-upgrade"
  echo

  exit 0
fi

# -------------------------------
# CRM recreate
# -------------------------------
if [[ "$1" == "crm-redeploy" ]]; then

  info "Redeploy CRM stack..."

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  echo
  info "Stopping and removing containers..."
  docker compose -f crm.yaml -p crm down

  echo
  info "Starting containers..."
  docker compose -f crm.yaml -p crm up -d

  echo
  info "CRM stack successfully redeployed"

  exit 0
fi

# -------------------------------
# CRM stop
# -------------------------------
if [[ "$1" == "crm-stop" ]]; then

  info "Stopping CRM stack..."

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  docker compose -f crm.yaml -p crm stop

  info "CRM stack stopped"

  exit 0
fi

# -------------------------------
# CRM start
# -------------------------------
if [[ "$1" == "crm-start" ]]; then

  info "Starting CRM stack..."

  if [[ ! -f crm.yaml ]]; then
    error "crm.yaml not found in current directory"
  fi

  docker compose -f crm.yaml -p crm start

  info "CRM stack started"

  exit 0
fi

# -------------------------------
# Uninstall all TitanCRM stacks
# -------------------------------
if [[ "$1" == "uninstall" ]]; then

  warn "This will remove ALL TitanCRM containers, stacks, networks and volumes!"
  read -p "Type 'uninstall' to confirm: " CONFIRM

  if [[ "$CONFIRM" != "uninstall" ]]; then
    error "Uninstallation cancelled"
  fi

  echo
  info "Stopping and removing CRM stack..."
  docker compose -f crm.yaml -p crm down --volumes --remove-orphans || true

  echo
  info "Stopping and removing Infra stack..."
  docker compose -f infra.yaml -p infra down --volumes --remove-orphans || true

  echo
  info "Stopping and removing Proxy stack..."
  docker compose -f proxy.yaml -p proxy down --volumes --remove-orphans || true

  echo
  info "Removing TitanCRM docker network..."
  docker network rm titan-crm-network >/dev/null 2>&1 || true

  echo
  info "Removing TitanCRM docker volumes..."
  VOLUMES=(
    infra-company-management-db
    infra-content-db
    infra-cost-management-db
    infra-finance-db
    infra-rabbitmq
    infra-pgadmin
    infra-dozzle
    proxy-html
    proxy-certs
    proxy-vhost
  )
  for VOLUME in "${VOLUMES[@]}"; do
    docker volume rm "$VOLUME" >/dev/null 2>&1 || true
  done

  echo
  info "Removing deployment state..."
  rm -f "$MARKER_FILE" "$FINAL_MARKER"
  rmdir "$(dirname "$MARKER_FILE")" 2>/dev/null || true

  echo
  info "All TitanCRM stacks, volumes and network removed successfully"

  exit 0
fi

# -------------------------------
# Script help section
# -------------------------------
if [[ "$1" == "help" ]]; then
  echo "Available commands:"
  echo
  echo "  crm-upgrade       - Upgrade CRM stack"
  echo "  crm-redeploy      - Redeploy CRM stack"
  echo "  crm-stop          - Stop CRM stack"
  echo "  crm-start         - Start CRM stack"
  echo "  crm-tag-get       - Show current CRM image tag"
  echo "  crm-tag-set <tag> - Set new CRM image tag (e.g. ./deploy.sh crm-tag-set stable)"
  echo "  uninstall         - Uninstall all TitanCRM stacks, volumes and network"
  echo
  exit 0
fi

# =====[ MAIN ]=====
if [[ -z "$1" ]]; then
  info "🚀 Starting TitanCRM deployment..."
  confirm_deploy
  deploy_start
fi

integrity_check
check_os
check_disk
install_docker
create_network
create_volumes
generate_secrets
configure_dozzle
configure_proxy
configure_pgadmin
deploy_infra
wait_rabbitmq
configure_rabbitmq
deploy_crm
wait_crm_containers
deploy_proxy
load_env
save_credentials
deploy_done

echo
info "TitanCRM is ready!"
echo
info "Services have started, but it may take a few minutes for:"
echo "- Let's Encrypt certificates to be issued"
echo "- Nginx proxy to configure the domains"
echo "- All services to be fully ready and reachable"
echo
info "Once the process completes, you can access your services at:"
echo
echo -e "${BRIGHT_RED}Frontend:${RESET}                 ${BRIGHT_GREEN}https://${FRONTEND_DOMAIN}${RESET}"
echo -e "login: ${BRIGHT_BLUE}${SEED_ADMIN_EMAIL}${RESET} ${BRIGHT_RED}|${RESET} password: ${BRIGHT_BLUE}${SEED_ADMIN_PASSWORD}${RESET}"
echo
echo -e "${BRIGHT_RED}Backend API:${RESET}              ${BRIGHT_GREEN}https://${BACKEND_DOMAIN}${RESET}"
echo
echo -e "${BRIGHT_RED}RabbitMQ Console:${RESET}         ${BRIGHT_GREEN}https://${RABBITMQ_DOMAIN}${RESET}"
echo -e "login: ${BRIGHT_BLUE}admin${RESET} ${BRIGHT_RED}|${RESET} password: ${BRIGHT_BLUE}${RABBITMQ_ADMIN_PASSWORD}${RESET}"
echo
echo -e "${BRIGHT_RED}Log Console:${RESET}              ${BRIGHT_GREEN}https://${DOZZLE_DOMAIN}${RESET}"
echo -e "login: ${BRIGHT_BLUE}admin${RESET} ${BRIGHT_RED}|${RESET} password: ${BRIGHT_BLUE}${DOZZLE_PASSWORD}${RESET}"
echo
echo -e "${BRIGHT_RED}Database Console:${RESET}         ${BRIGHT_GREEN}https://${PGADMIN_DOMAIN}${RESET}"
echo -e "login: ${BRIGHT_BLUE}${SEED_ADMIN_EMAIL}${RESET} ${BRIGHT_RED}|${RESET} password: ${BRIGHT_BLUE}${PGADMIN_PASSWORD}${RESET}"
echo
info "Database credentials:"
echo
echo -e "company-management:       ${BRIGHT_BLUE}company${RESET}"
echo -e "content:                  ${BRIGHT_BLUE}content${RESET}"
echo -e "cost-management:          ${BRIGHT_BLUE}cost${RESET}"
echo -e "finance:                  ${BRIGHT_BLUE}finance${RESET}"
echo
info "Encryption Key: ${ENCRYPTION_KEY}"
echo
info "Please wait a few minutes if services are not immediately reachable."
echo
echo -e "${BRIGHT_RED}⚠️  Make sure to save your credentials in a safe place! They will not be shown again. Stored in:${RESET} ${BRIGHT_BLUE}${CREDENTIALS_FILE}${RESET}"
echo
