#!/usr/bin/env bash
#
# One-time Azure bootstrap for the angular-dotnet stack. Run it in **Azure Cloud
# Shell** (https://shell.azure.com) — the Azure CLI is already installed and
# signed in there, so there's nothing to set up locally.
#
#   bash provision.sh
#
# It creates (all in the Always-Free / free-tier friendly SKUs):
#   • a resource group
#   • Azure Database for PostgreSQL Flexible Server (Burstable B1ms) + a database
#   • an Azure Container Apps environment + the API app (scale-to-zero)
#   • two Azure Static Web Apps (Free) — admin + client
#   • a GitHub-deploy service principal
#
# At the end it prints the GitHub Actions secrets/variables to add. The API app
# starts on a placeholder image; the first run of .github/workflows/deploy-azure.yml
# replaces it with the real image and applies EF migrations against Postgres.
set -euo pipefail

# ---------------------------------------------------------------------------
# Settings — tweak names/region if you like. Both regions are overridable via
# env vars so you can retry without editing the file, e.g.:
#   LOCATION=northeurope bash infra/azure/provision.sh
#
# LOCATION      → Postgres + Container Apps. New/trial subscriptions are often
#                 "restricted" from popular regions (westeurope especially); if
#                 you hit "The location is restricted from performing this
#                 operation", try another: swedencentral, northeurope,
#                 francecentral, uksouth, germanywestcentral, eastus2, centralus.
# SWA_LOCATION  → Static Web Apps only exist in: westeurope, eastus2, centralus,
#                 westus2, eastasia. Change only if westeurope is restricted too.
# ---------------------------------------------------------------------------
LOCATION="${LOCATION:-swedencentral}"
SWA_LOCATION="${SWA_LOCATION:-westeurope}"
RESOURCE_GROUP="angular-dotnet-rg"
PG_SERVER="pg-angular-dotnet-$RANDOM"      # must be globally unique
PG_ADMIN="appadmin"
PG_DB="angular_dotnet"
ACA_ENV="angular-dotnet-env"
ACA_APP="ada1-api"
SWA_ADMIN="admin-angular-dotnet"
SWA_CLIENT="client-angular-dotnet"
PLACEHOLDER_IMAGE="mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"

PG_PASSWORD="$(openssl rand -base64 24)"   # generated; surfaced only in the CI secret

echo "▶ Registering resource providers (first run only)…"
az provider register --namespace Microsoft.App --wait --only-show-errors || true
az provider register --namespace Microsoft.DBforPostgreSQL --wait --only-show-errors || true

echo "▶ Resource group…"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --only-show-errors >/dev/null

echo "▶ PostgreSQL Flexible Server ($PG_SERVER) — this takes a few minutes…"
az postgres flexible-server create \
  --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" --location "$LOCATION" \
  --admin-user "$PG_ADMIN" --admin-password "$PG_PASSWORD" \
  --tier Burstable --sku-name Standard_B1ms --storage-size 32 --version 16 \
  --public-access None --yes --only-show-errors >/dev/null
az postgres flexible-server db create \
  --resource-group "$RESOURCE_GROUP" --server-name "$PG_SERVER" --database-name "$PG_DB" \
  --only-show-errors >/dev/null
# Allow other Azure services (Container Apps) to reach the server (0.0.0.0/0.0.0.0
# is the special "Azure services" rule, not the public internet).
az postgres flexible-server firewall-rule create \
  --resource-group "$RESOURCE_GROUP" --name "$PG_SERVER" --rule-name AllowAzure \
  --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0 --only-show-errors >/dev/null

CONN="Host=${PG_SERVER}.postgres.database.azure.com;Port=5432;Database=${PG_DB};Username=${PG_ADMIN};Password=${PG_PASSWORD};Ssl Mode=Require;Trust Server Certificate=true"

echo "▶ Container Apps environment + API app…"
az containerapp env create \
  --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --location "$LOCATION" \
  --only-show-errors >/dev/null
az containerapp create \
  --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --environment "$ACA_ENV" \
  --image "$PLACEHOLDER_IMAGE" \
  --ingress external --target-port 8080 \
  --min-replicas 0 --max-replicas 1 \
  --secrets "connection-string=$CONN" \
  --env-vars \
    "ConnectionStrings__Default=secretref:connection-string" \
    "ASPNETCORE_ENVIRONMENT=Production" \
    "ApplyMigrations=true" \
  --only-show-errors >/dev/null

# Private GHCR package? Give the Container App pull credentials. Set these before
# running (skip entirely if the package is public):
#   export GHCR_USERNAME=<your-github-username>
#   export GHCR_PAT=<a classic PAT with the read:packages scope>
if [[ -n "${GHCR_PAT:-}" ]]; then
  echo "▶ Configuring private GHCR pull credentials…"
  az containerapp registry set \
    --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --server ghcr.io --username "${GHCR_USERNAME:?set GHCR_USERNAME too}" \
    --password "$GHCR_PAT" --only-show-errors >/dev/null
fi

API_FQDN="$(az containerapp show -n "$ACA_APP" -g "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)"
API_URL="https://${API_FQDN}"

echo "▶ Static Web Apps (Free) — admin + client…"
az staticwebapp create -n "$SWA_ADMIN"  -g "$RESOURCE_GROUP" -l "$SWA_LOCATION" --sku Free --only-show-errors >/dev/null
az staticwebapp create -n "$SWA_CLIENT" -g "$RESOURCE_GROUP" -l "$SWA_LOCATION" --sku Free --only-show-errors >/dev/null
ADMIN_HOST="$(az staticwebapp show -n "$SWA_ADMIN"  -g "$RESOURCE_GROUP" --query defaultHostname -o tsv)"
CLIENT_HOST="$(az staticwebapp show -n "$SWA_CLIENT" -g "$RESOURCE_GROUP" --query defaultHostname -o tsv)"
ADMIN_TOKEN="$(az staticwebapp secrets list -n "$SWA_ADMIN"  -g "$RESOURCE_GROUP" --query properties.apiKey -o tsv)"
CLIENT_TOKEN="$(az staticwebapp secrets list -n "$SWA_CLIENT" -g "$RESOURCE_GROUP" --query properties.apiKey -o tsv)"

echo "▶ Wiring API CORS to the Static Web App origins…"
az containerapp update -n "$ACA_APP" -g "$RESOURCE_GROUP" \
  --set-env-vars \
    "Cors__Origins__0=https://${ADMIN_HOST}" \
    "Cors__Origins__1=https://${CLIENT_HOST}" \
  --only-show-errors >/dev/null

echo "▶ GitHub-deploy service principal…"
SUB="$(az account show --query id -o tsv)"
AZURE_CREDENTIALS="$(az ad sp create-for-rbac \
  --name "angular-dotnet-gh" --role contributor \
  --scopes "/subscriptions/${SUB}/resourceGroups/${RESOURCE_GROUP}" \
  --json-auth --only-show-errors)"

cat <<EOF

============================================================================
✅  Azure resources created.

Add these to your GitHub repo (Settings → Secrets and variables → Actions):

── Secrets ────────────────────────────────────────────────────────────────
AZURE_CREDENTIALS       (paste the JSON below)
AZURE_SWA_ADMIN_TOKEN   = ${ADMIN_TOKEN}
AZURE_SWA_CLIENT_TOKEN  = ${CLIENT_TOKEN}

── Variables ──────────────────────────────────────────────────────────────
API_BASE_URL            = ${API_URL}

── AZURE_CREDENTIALS JSON ─────────────────────────────────────────────────
${AZURE_CREDENTIALS}
============================================================================

URLs:
  API     ${API_URL}
  admin   https://${ADMIN_HOST}
  client  https://${CLIENT_HOST}

Next: push to main so .github/workflows/deploy-azure.yml runs. If the API
revision can't pull the image, make the GHCR package public (GitHub → your
profile → Packages → ada1 → Package settings → Change visibility).
============================================================================
EOF
