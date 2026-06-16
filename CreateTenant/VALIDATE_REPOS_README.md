# RHDR Repository Validation Script

This directory contains `validate-rhdr-repos.sh`, a bash script to validate RHDR container repositories in both production and staging Pyxis environments.

## ⚠️ Current Status: Repositories Not Yet Created

**If you're seeing 404 errors, this is EXPECTED and CORRECT.**

The validation script currently shows all repositories as "MISSING" (404 Not Found) because:
1. ✗ `pyxis-repo-configs` MR with `products/rhdr/rhdr.yaml` hasn't been created yet, OR
2. ✗ MR has been created but not merged to `main` branch, OR
3. ✗ MR merged but Cicada pipeline still completing

**Next Steps:**
1. **Create** `products/rhdr/rhdr.yaml` in `releng/pyxis-repo-configs` ([see guide](./CreateContainerRepositories.md#step-1-create-delivery-repositories-in-pyxis))
2. **Submit** MR to `main` branch (don't use a fork - push directly)
3. **Merge** MR after review approval
4. **Wait** ~5 minutes for Cicada pipeline to create repositories
5. **Run validation** script again: `./validate-rhdr-repos.sh --prod-only`

Expected after MR merge: All 8 repositories appear in production within 5 minutes ✓

---

The script checks whether container repositories created in `pyxis-repo-configs` have been successfully registered and are ready to receive releases. This validation should be done:

1. **After pyxis-repo-configs MR is merged** - to verify production repos exist
2. **After ~24 hours** - to verify staging repos have synced from production
3. **Before creating RPA** - to ensure repositories are ready for the release service

## Quick Start

### Prerequisites

```bash
# Ensure you have required tools
command -v curl || echo "curl not installed"
command -v jq   || echo "jq not installed"

# Ensure valid Kerberos ticket
kinit USERNAME@REDHAT.COM
```

### Basic Usage

```bash
# Check all repositories in both environments (production & staging)
./validate-rhdr-repos.sh

# Check production only (immediately after MR merge)
./validate-rhdr-repos.sh --prod-only

# Check staging only (after ~24 hours for sync)
./validate-rhdr-repos.sh --stage-only

# Show detailed JSON responses
./validate-rhdr-repos.sh --detailed

# Show help
./validate-rhdr-repos.sh --help
```

## Expected Output Stages

### Stage 0: Before MR Merge (Right Now - You Are Here ✓)

**Current Status:**
```
✗ MISSING rhdr/rhdr-hub-operator
✗ MISSING rhdr/rhdr-hub-operator-bundle
... (all 8 repos showing 404 Not Found)

✗ Production: No repositories found
✗ FAILED: Not all production repositories found
```

**Error Details:**
```json
{
  "status": 404,
  "title": "Not Found",
  "detail": "Document in containerRepository not found."
}
```

**This is CORRECT and EXPECTED** ✓

**Why:** Repositories don't exist in Pyxis yet because the `pyxis-repo-configs` MR containing `products/rhdr/rhdr.yaml` hasn't been created or merged.

**Next Step:** 
1. Create `products/rhdr/rhdr.yaml` following [CreateContainerRepositories.md](./CreateContainerRepositories.md#step-1-create-delivery-repositories-in-pyxis)
2. Update `CODEOWNERS` with RHDR entries
3. Submit MR to `releng/pyxis-repo-configs` main branch
4. Once merged and Cicada pipeline completes, run validation again

**Timeline:** 30 minutes to submit MR, then wait for merge and pipeline completion

### Stage 1: After MR Merge, Before Staging Sync

**Expected Status (T+5min after merge):**
```
✓ Production: All 8 repositories ready
✗ Staging: 0/8 repositories found (8 missing)

✗ FAILED: Not all staging repositories found
```

**Why:** Production repositories are created immediately upon MR merge. Staging repositories sync with a ~24-hour delay from production.

**Next Step:** Wait for staging repositories to sync from production

**Timeline:** ~24 hours from MR merge

### Stage 3: Staging Synced (Ready for Release)

```
✓ Production: All 8 repositories ready
✓ Staging: All 8 repositories ready

✓ SUCCESS: All repositories ready in both environments
Proceed with RPA creation
```

**Status:** Ready to create RPA

## Repository List

The script validates these 8 repositories from MR 1:

**Layer 1 (Core Operators):**
- `rhdr/rhdr-hub-operator`
- `rhdr/rhdr-hub-operator-bundle`
- `rhdr/rhdr-cluster-operator`
- `rhdr/rhdr-cluster-operator-bundle`

**Layer 2 (Multicluster Operators):**
- `rhdr/rhdr-multicluster-operator`
- `rhdr/rhdr-multicluster-operator-bundle`

**Layer 3 (CSI Addons Operators):**
- `rhdr/rhdr-csi-addons-operator`
- `rhdr/rhdr-csi-addons-operator-bundle`

## Understanding Results

### Symbol Meanings

| Symbol | Meaning | Next Step |
|--------|---------|-----------|
| ✓ | Repository exists and ready | Continue to next layer |
| ✗ | Repository not found | Check MR status or wait for sync |
| ? | Error querying repository | Check network/Kerberos authentication |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | ✓ SUCCESS - All checked repositories exist |
| 1 | ⚠ WARNING/FAILURE - Some repositories missing or not ready |
| 2 | ✗ ERROR - Script error or authentication issue |

## Troubleshooting

### "404 Not Found" on All Repositories

**Status:** This is EXPECTED before MR merge ✓

**Error Output:**
```json
{
  "status": 404,
  "title": "Not Found",
  "detail": "Document in containerRepository not found."
}
```

**Cause:** Repositories haven't been created in Pyxis yet

**Solution:**
1. Follow [Step 1 of CreateContainerRepositories.md](./CreateContainerRepositories.md#step-1-create-delivery-repositories-in-pyxis) to create `products/rhdr/rhdr.yaml`
2. Submit MR to `git@gitlab.cee.redhat.com:releng/pyxis-repo-configs` (main branch)
3. After MR merge and Cicada pipeline completes (~5 minutes), run validation again
4. Expected result: `✓ Production: All 8 repositories ready`

### "Kerberos ticket not found"

```bash
kinit USERNAME@REDHAT.COM
# Then run validation script again
```

### "Repository not found" on all repos after MR merge

**Causes:**
1. MR not merged yet
2. Cicada pipeline failed
3. YAML syntax error in rhdr.yaml

**Debug:**
```bash
# Check MR merge status
git log --oneline origin/main | grep -i rhdr

# View Cicada pipeline
# https://gitlab.cee.redhat.com/releng/pyxis-repo-configs/-/pipelines
```

### "Production exists, staging missing" after 48+ hours

**Cause:** Sync delay (should be ~24 hours, but can take longer)

**Action:**
- Contact Release Engineering: [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ)
- Include your MR URL and this script output

### Manual API Validation

If you want to check repositories manually:

```bash
# Production
curl --negotiate -u: \
  "https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq .

# Staging
curl --negotiate -u: \
  "https://pyxis.stage.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq .
```

Success response:
```json
{
  "repository_id": "5f8d3c9e7b2a1c4d",
  "repository": "rhdr/rhdr-hub-operator",
  "enabled": true,
  "release_categories": ["Tech Preview"]
}
```

Error response (404):
```json
{
  "status": 404,
  "detail": "Document in containerRepository not found."
}
```

## Validation Workflow

### Immediate After MR Merge

```bash
# 1. Verify production repositories exist
./validate-rhdr-repos.sh --prod-only

# Expected: ✓ Production: All 8 repositories ready

# 2. Record time for staging sync check
date
```

### After 24-48 Hours

```bash
# 1. Check if staging has synced
./validate-rhdr-repos.sh --stage-only

# Expected: ✓ Staging: All 8 repositories ready

# 2. Full validation
./validate-rhdr-repos.sh

# Expected: ✓ SUCCESS: All repositories ready in both environments
```

### Proceed with RPA Creation

Once both production and staging show all 8 repositories:

1. Create staging RPA pointing to `registry.stage.redhat.io/rhdr/...`
2. Create production RPA pointing to `registry.redhat.io/rhdr/...`
3. Run `tox` to validate RPA YAML
4. Submit RPA MRs to `konflux-release-data`

## Viewing Detailed Responses

To see full JSON responses from Pyxis API:

```bash
# Show detailed JSON for each repository
./validate-rhdr-repos.sh --detailed

# Or use curl directly
curl --negotiate -u: \
  "https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq .
```

Useful jq filters:
```bash
# Show only repository name
curl --negotiate -u: ... | jq '.repository'

# Show only status fields
curl --negotiate -u: ... | jq '{enabled, release_categories, vendor_label}'

# Check if enabled
curl --negotiate -u: ... | jq '.enabled'
```

## Related Documentation

- [Creating Container Repositories for RHDR Release](./CreateContainerRepositories.md) - Full process guide
- [Pyxis Repo Configs](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs) - Repository definitions
- [Cicada Support](https://redhat.enterprise.slack.com/archives/C095V063YLQ) - For on-boarding and support

## License and Attribution

Script: `validate-rhdr-repos.sh`
Created for: RHDR product repository validation
Status: Tech-preview validation tool
