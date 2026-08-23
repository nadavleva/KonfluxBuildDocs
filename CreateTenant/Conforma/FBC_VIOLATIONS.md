# RHDR 4.22 File-Based Catalog (FBC) Violations Analysis

## Latest Status: FBC Fragment Validation Failures (2026-07-12)

**Latest Update:** 2026-07-12 (16:45 UTC)  
**Last Source:** rhdr-fbc-4-22-on-push-gkflz-validate-fbc.log  
**Current Status:** ❌ **FBC FRAGMENT VALIDATION FAILED**
**Issue Type:** OLM Bundle Structure Incompatibility with OCP 4.22  
**Impact:** FBC cannot be built - fragment structure is incompatible

### New Issue: OLM Bundle Structure Migration Required

**Problem:** The FBC fragment uses `olm.bundle.object` bundle properties, which are not permitted in FBC fragments for OCP version 4.22.

**Error Details (rhdr-fbc-4-22-on-push-gkflz-validate-fbc.log):**
```
Step: extract-and-validate
!FAILURE! - olm.bundle.object bundle properties are not permitted in a FBC 
           fragment for OCP version 4.22. Fragments must move to 
           olm.csv.metadata bundle metadata.

!FAILURE! - every olm.bundle object in the fragment must have a corresponding 
           olm.csv.metadata bundle property

Result: FAILURE
Failures: 2
Warnings: 0
Successes: 8
```

**Root Cause:**
- FBC fragment format changed for OCP 4.22
- `olm.bundle.object` structure is deprecated in favor of `olm.csv.metadata`
- Current fragments use old format that is incompatible with OCP 4.22

**What Needs to Be Fixed:**

1. **Migrate Bundle Properties:** Convert all `olm.bundle.object` entries to `olm.csv.metadata` format
2. **Update Fragment Structure:** Ensure every bundle has corresponding CSV metadata
3. **Validate After Changes:** Re-run validation to confirm structure is correct

**Timeline:**
- 2026-07-09 09:52 (rhdr-fbc-4-22-enterprise-contract-nqbfg-verify): Enterprise contract violations
- 2026-07-12 16:44 (rhdr-fbc-4-22-on-push-gkflz-validate-fbc): Fragment structure validation failed

**Required Actions:**
1. **Update FBC Fragment Files:**
   - Replace `olm.bundle.object` with `olm.csv.metadata`
   - Location: Likely in `rhodf/rhdr-fbc/v4.22/` or similar
   - Ensure every bundle object has a matching CSV metadata entry

2. **Example Migration Pattern:**
   ```yaml
   # OLD (Not permitted in 4.22):
   olm.bundle.object:
     - <bundle content>
   
   # NEW (Required in 4.22):
   olm.csv.metadata:
     - <csv metadata content>
   ```

3. **Validation Steps:**
   ```bash
   # After making changes, run validation
   ./validate-fbc.sh
   # Should see 0 failures after migration
   ```

---

## Previous Status: Enterprise Contract Violations (2026-07-09)

**Update:** 2026-07-09 (09:52 UTC)  
**Source:** rhdr-fbc-4-22-enterprise-contract-nqbfg-verify.log  
**Status:** ⚠️ **ENTERPRISE CONTRACT VALIDATION FAILED - Multiple Issues**
**Violations:** 20 (10 per component)  
**Warnings:** 6  
**Successes:** 260  
**Total Notifications:** 26 issues blocking merge

### Issue 1: OLM Allowed Registries Violations (7 violations)

**Problem:** Related image references are from registries not in the allowed list.

**Affected Images:**
- `registry.redhat.io/openshift4/ose-kube-rbac-proxy-rhel9`
- `registry.redhat.io/rh-ocp-dr/rhdr/rhdr-csi-addons-rhel9-operator`
- `registry.redhat.io/rh-ocp-dr/rhdr/rhdr-csi-addons-sidecar-rhel9`
- `registry.redhat.io/rhdr/rhdr-cluster-rhel9-operator`
- `registry.redhat.io/rhdr/rhdr-hub-rhel9-operator`
- `registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator`
- Additional registry.stage.redhat.io images

**Root Cause:** Registry prefixes for RHDR related images are not in the `allowed_olm_image_registry_prefixes` policy configuration.

**Solution Options:**

**Option A: Add to Policy Allowed Registries (Recommended)**
```yaml
# In the Conforma policy configuration, add to allowed_olm_image_registry_prefixes:
- registry.redhat.io/openshift4/
- registry.redhat.io/rh-ocp-dr/rhdr/
- registry.redhat.io/rhdr/
- registry.stage.redhat.io/rhdr/
```

**Option B: Exclude Rule (Temporary)**
Add to policy configuration's `exclude` section:
```
olm.allowed_registries_related:registry.redhat.io/openshift4/ose-kube-rbac-proxy-rhel9
olm.allowed_registries_related:registry.redhat.io/rh-ocp-dr/rhdr/rhdr-csi-addons-rhel9-operator
olm.allowed_registries_related:registry.redhat.io/rh-ocp-dr/rhdr/rhdr-csi-addons-sidecar-rhel9
olm.allowed_registries_related:registry.redhat.io/rhdr/rhdr-cluster-rhel9-operator
olm.allowed_registries_related:registry.redhat.io/rhdr/rhdr-hub-rhel9-operator
olm.allowed_registries_related:registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator
```

### Issue 2: Test Failures (3 violations)

**Problem:** Three FBC validation tasks are reporting failures:

| Task | Issue | Impact |
|------|-------|--------|
| `fbc-fips-check-oci-ta` | Failed test | FIPS compliance check failed |
| `fbc-target-index-pruning-check` | Failed test | Index pruning validation failed |
| `validate-fbc` | Failed test | Generic FBC validation failed |

**Root Cause Analysis:**
- These are informative test failures indicating structural/compliance issues
- Need to check individual task logs for specific failure reasons
- Likely related to the OLM bundle structure issue (FBC fragment format)

**Solution:**
1. Check the actual task logs for detailed failure information
2. Fix the underlying FBC structure issues
3. Re-run validation tests

### Issue 3: Registry Access Failure (Background Issue)

**Error Observed:**
```
time="2026-07-09T09:52:48Z" level=error msg="failed to fetch image"
  error="GET https://registry.redhat.io/auth/realms/rhcc/protocol/redhat-docker-v2/auth?scope=repository%3Aopenshift4%2Fose-operator-registry-rhel9%3Apull&service=docker-registry: 
         UNAUTHORIZED: Please login to the Red Hat Registry"
```

**Impact:** Same registry access issue affecting build pipeline
- Cannot fetch base images from registry.redhat.io
- CI environment credentials may be missing or expired
- Shared with the RHDR operator component validation issue

---

## Related Images Detected

**From rhdr-fbc-4-22-on-push-gkflz-validate-fbc.log:**

| Image | Registry | Status |
|-------|----------|--------|
| ose-kube-rbac-proxy-rhel9 | registry.redhat.io/openshift4/ | ⚠️ Allowed registry issue |
| rhdr-csi-addons-rhel9-operator | registry.redhat.io/rh-ocp-dr/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-csi-addons-sidecar-rhel9 | registry.redhat.io/rh-ocp-dr/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-cluster-rhel9-operator | registry.redhat.io/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-hub-rhel9-operator | registry.redhat.io/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-multicluster-rhel9-operator | registry.redhat.io/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-cluster-operator-bundle | registry.stage.redhat.io/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-csi-addons-operator-bundle | registry.stage.redhat.io/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-hub-operator-bundle | registry.stage.redhat.io/rhdr/ | ⚠️ Allowed registry issue |
| rhdr-multicluster-operator-bundle | registry.stage.redhat.io/rhdr/ | ⚠️ Allowed registry issue |

---

## Comparison: FBC vs RHDR Operator Violations

### Similarities
- **Registry Access Issue:** Both blocked by 401 Unauthorized to registry.redhat.io
- **Registry Prefix Issue:** Both use registries not in allowed list (RHDR-specific registries)
- **CI Infrastructure Problem:** Shared credentials/access problem

### Differences
| Aspect | FBC | RHDR Operators |
|--------|-----|----------------|
| **Primary Issue** | OLM bundle structure incompatibility | Buildah task trust issues |
| **Violation Count** | 20 | ~37 |
| **Warning Count** | 6 | ~80 |
| **Root Cause** | Format change for OCP 4.22 | Task digest version mismatch |
| **Fix Complexity** | Medium - migrate bundle structure | High - requires task digest updates |
| **Blocker Status** | Blocks FBC build validation | Blocks operator component validation |

---

## Affected Components

**FBC Fragment Components:**
- `rhdr-fbc-4-22` (index)
- `rhdr-fbc-4-22` (amd64 specific)

**Related Component Dependencies:**
- `rhdr-cluster-operator-bundle-4-22`
- `rhdr-csi-addons-operator-bundle-4-22`
- `rhdr-hub-operator-bundle-4-22`
- `rhdr-multicluster-operator-bundle-4-22`

---

## Next Steps Priority

### Critical (Blocking)
1. **Fix OLM Bundle Structure**
   - Migrate from `olm.bundle.object` to `olm.csv.metadata`
   - File location: `rhodf/rhdr-fbc/v4.22/*.yaml`
   - Expected timeline: 1-2 hours

2. **Validate FBC Fragment**
   - Re-run `validate-fbc` after structure changes
   - Verify 0 failures before proceeding

### Important (Needs Investigation)
3. **Resolve Registry Access Issue**
   - Check CI environment credentials for registry.redhat.io
   - Verify pull secrets are configured
   - Coordinate with infrastructure team

4. **Address Test Failures**
   - Run individual FBC validation tasks with detailed logging
   - Understand why FIPS check and index pruning checks are failing
   - May be resolved by fixing bundle structure

### Nice-to-Have (Policy Enhancement)
5. **Update Conforma Policy**
   - Add RHDR registry prefixes to allowed list
   - Or create RHDR-specific policy exceptions
   - Better long-term solution than exclusions

---

## Violation History Timeline

| Date | Time | Log File | Status | Violations | Warnings | Issue |
|------|------|----------|--------|-----------|----------|-------|
| 2026-07-09 | 09:52 | rhdr-fbc-4-22-enterprise-contract-nqbfg-verify | FAILED | 20 | 6 | OLM registries + test failures + registry access |
| 2026-07-12 | 16:44 | rhdr-fbc-4-22-on-push-gkflz-validate-fbc | FAILED | 0 (2 errors in extract-validate) | 0 | OLM bundle structure incompatibility |

---

## Key Resources

- **Policy Documentation:** https://conforma.dev/docs/policy/
- **OLM Documentation:** https://olm.operatorframework.io/
- **FBC Format Migration:** https://olm.operatorframework.io/docs/advanced-tasks/file-based-catalogs/
- **OCP 4.22 Release Notes:** Check for OLM/FBC breaking changes

---

## Notes for Troubleshooting

### If Bundle Migration Doesn't Work
- Check OCP 4.22 OLM compatibility matrix
- Verify CSV metadata format is correct
- Look for examples in other operators' 4.22 FBC fragments

### If Registry Access Still Fails
- Verify `~/.docker/config.json` has registry.redhat.io credentials
- Check if credentials have been rotated or expired
- Test manual pull: `podman pull registry.redhat.io/openshift4/ose-operator-registry-rhel9:v4.22`

### If Allowed Registries Issue Persists
- Confirm policy bundle is using latest RHDR registry prefixes
- Check if policy override is needed for RHDR FBC specifically
- Consider creating staging vs production policies

