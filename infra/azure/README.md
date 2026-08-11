# Azure deployment

Fully free-tier-friendly hosting for the stack:

| Component    | Azure service                               | Notes                                    |
| ------------ | ------------------------------------------- | ---------------------------------------- |
| `admin` SPA  | Static Web Apps (Free)                      | global CDN + free HTTPS                  |
| `client` SPA | Static Web Apps (Free)                      | global CDN + free HTTPS                  |
| `api`        | Container Apps                              | scale-to-zero, pulls the image from GHCR |
| database     | PostgreSQL Flexible Server (Burstable B1ms) | free for 12 months on a new account      |

The SPAs are served from a different origin than the API, so the API enables
**CORS** (`Cors:Origins`, set to the Static Web App URLs) and each SPA learns the
API URL at **runtime** from `config.json` (empty locally → relative `/api`; stamped
with the Container Apps URL at deploy time). One build artifact works everywhere.

## First-time setup

1. **Push the repo to GitHub** (public or private — see below for how Container Apps
   pulls the image in each case).
2. **Provision Azure** — open [Azure Cloud Shell](https://shell.azure.com) and run:
   ```bash
   bash infra/azure/provision.sh
   ```
   It prints the GitHub **secrets** and **variable** to add.
3. **Add to GitHub** (Settings → Secrets and variables → Actions):
   - Secrets: `AZURE_CREDENTIALS`, `AZURE_SWA_ADMIN_TOKEN`, `AZURE_SWA_CLIENT_TOKEN`
   - Variable: `API_BASE_URL`
4. **Let Container Apps pull the API image** (see the two options below).
5. **Push to `main`** → [`deploy-azure.yml`](../../.github/workflows/deploy-azure.yml)
   builds + pushes the API image, rolls it out to Container Apps (EF migrations apply
   on startup), and deploys both SPAs to Static Web Apps.

## Public vs private repository

The Static Web Apps deploy uses a token and the image _push_ uses `GITHUB_TOKEN`, so
both work with a **private** repo unchanged. The only difference is how Container Apps
_pulls_ the image:

- **Public package (simplest, free):** after the first image push, set the GHCR
  package to Public (GitHub → Packages → `angular-dotnet-api` → Package settings →
  Change visibility). The repo source can still be **private** — package visibility is
  independent. Container Apps then pulls anonymously; nothing else to configure.
- **Private package:** before running `provision.sh`, export a GitHub PAT with the
  `read:packages` scope so the Container App gets pull credentials:
  ```bash
  export GHCR_USERNAME=<your-github-username>
  export GHCR_PAT=<classic PAT with read:packages>
  bash infra/azure/provision.sh
  ```

### Free-tier notes for private repos

- **GitHub Actions minutes:** public repos are unlimited; **private** repos get 2,000
  min/month free. CI + deploy should fit, but heavy runs draw down that quota.
- **GHCR storage:** public packages are free/unlimited; **private** packages get 500 MB
  free. The API image (~250 MB) × several `:sha` tags can exceed that — prune old tags,
  or keep the package public.

## Deploys after that

Every push to `main` re-runs the deploy. `CI` validates the same commit
(`lint/test/build/e2e`); `Deploy (Azure)` ships it.

## Teardown

```bash
az group delete -n angular-dotnet-rg --yes --no-wait
az ad sp delete --id "$(az ad sp list --display-name angular-dotnet-gh --query '[0].appId' -o tsv)"
```
