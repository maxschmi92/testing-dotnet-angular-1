# Oracle Always-Free A1 launch retry

Ampere A1 free capacity is frequently exhausted, so the console throws
`Out of capacity for shape VM.Standard.A1.Flex`. [`launch-retry.sh`](./launch-retry.sh)
keeps attempting the launch (cycling availability domains) until one has room,
then stops.

## 1. Install the OCI CLI

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)"
```

## 2. Configure it (one time)

```bash
oci setup config
```

This walks you through creating an API signing key. When it finishes, upload the
generated **public** key to the console: **Profile → User settings → API keys →
Add API key → paste** `~/.oci/oci_api_key_public.pem`. Then verify:

```bash
oci iam region list >/dev/null && echo "OCI CLI OK"
```

## 3. Discover your OCIDs

Fill these into `launch.env`.

```bash
# Tenancy / root compartment OCID (also printed as `tenancy=` in ~/.oci/config)
grep '^tenancy' ~/.oci/config

C=$(grep '^tenancy' ~/.oci/config | cut -d= -f2)   # reuse below

# Availability-domain names (copy the full "xxxx:REGION-AD-N" strings into ADS)
oci iam availability-domain list --query 'data[].name' --raw-output

# Public subnet OCID (the one the VCN wizard labeled "Public Subnet-...")
oci network subnet list --compartment-id "$C" \
  --query 'data[].{name:"display-name", id:id}' --output table

# Ubuntu 22.04 aarch64 image for the A1 shape
oci compute image list --compartment-id "$C" \
  --operating-system "Canonical Ubuntu" --operating-system-version "22.04" \
  --shape VM.Standard.A1.Flex \
  --query 'data[0].id' --raw-output
```

## 4. Run it

```bash
cd infra/oracle
cp launch.env.example launch.env    # then edit launch.env
chmod +x launch-retry.sh
./launch-retry.sh
```

Leave it running. On success it prints the instance's **public IP** — copy that
and report it back so the deploy workflow can be wired up. It stops immediately
on any non-capacity error so real misconfigurations surface fast.

> Tip: if capacity stays unavailable for a long time, converting the account to
> **Pay As You Go** (Always Free stays free) markedly improves A1 allocation.
