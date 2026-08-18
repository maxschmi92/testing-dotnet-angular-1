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
   - Variables: `API_BASE_URL`, `RESOURCE_GROUP` (`angular-dotnet-rg`),
     `CONTAINERAPP_NAME` (`ada1-api`) — the last two used to live hard-coded in the
     workflow; they are variables now so each environment can point somewhere different.
4. **Create the deploy environments** — see [Environments & promotion](#environments--promotion).
5. **Let Container Apps pull the API image** (see the two options below).
6. **Push to `main`** → [`deploy-azure.yml`](../../.github/workflows/deploy-azure.yml)
   builds the artifacts once, promotes them to `staging` automatically, then waits for a
   human to approve `production` (EF migrations apply on API startup).

## Public vs private repository

The Static Web Apps deploy uses a token and the image _push_ uses `GITHUB_TOKEN`, so
both work with a **private** repo unchanged. The only difference is how Container Apps
_pulls_ the image:

- **Public package (simplest, free):** after the first image push, set the GHCR
  package to Public (GitHub → Packages → `ada1` → Package settings →
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

## Environments & promotion

`Deploy (Azure)` is a **promotion pipeline**, not a single deploy. On every push to
`main` it builds the API image + both SPA bundles **once**, then promotes those exact
artifacts through GitHub Environments:

```
build ──▶ staging (auto) ──▶ production (manual approval gate)
```

The reusable [`deploy-env.yml`](../../.github/workflows/deploy-env.yml) does the actual
rollout for one environment; [`deploy-azure.yml`](../../.github/workflows/deploy-azure.yml)
calls it twice. Nothing is rebuilt per environment — only `config.json` (SPA API URL)
and the Container App target change.

### One-time GitHub setup

**Settings → Environments → New environment**, create two:

| Environment  | Protection rule              | Effect                                           |
| ------------ | ---------------------------- | ------------------------------------------------ |
| `staging`    | _none_                       | deploys automatically after the build            |
| `production` | **Required reviewers** = you | pipeline pauses here until you click **Approve** |

The `production` "Required reviewers" rule **is** the promotion gate — that pause in the
Actions run is where a real team does its final go/no-go.

**Per-environment config.** Each environment can carry its own **variables** and
**secrets** (Environment → Add variable / secret), which override repo-level ones for
jobs targeting that environment. The workflow reads:

- Variables: `RESOURCE_GROUP`, `CONTAINERAPP_NAME`, `API_BASE_URL`
- Secrets: `AZURE_CREDENTIALS`, `AZURE_SWA_ADMIN_TOKEN`, `AZURE_SWA_CLIENT_TOKEN`

> **Single-env caveat (free tier).** With one Azure environment, set the **same** values
> on both `staging` and `production` (or just leave them repo-level) — both stages deploy
> to the same resources, and the point of the exercise is the **gate**, not isolation.
> When you later stand up real stage infra (e.g. a shared Postgres server with separate
> `stage`/`prod` databases + separate SWA apps), change only the `staging` environment's
> variables — the workflow doesn't change.

### Branch protection (recommended companion)

So `main` only ever moves through reviewed PRs, set **Settings → Branches → Add rule**
for `main`: require a pull request, require the `CI` status check to pass, require ≥1
approval, and include administrators. See the
[git & delivery handbook](https://claude.ai/code/artifact/11120a13-5c4f-4b96-b5a6-981c87b70f45)
for the reasoning.

## Teardown

```bash
az group delete -n angular-dotnet-rg --yes --no-wait
az ad sp delete --id "$(az ad sp list --display-name angular-dotnet-gh --query '[0].appId' -o tsv)"
```
