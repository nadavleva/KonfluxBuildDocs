# Creating RHDR FBC Application in rhdr-tenant

**Status:** ⏳ PENDING  
**Related JIRA:** [VIRTDR-141](https://redhat.atlassian.net/browse/VIRTDR-141) - RamenDR Standalone Konflux Tenant Setup  
**Dependencies:** 
- [VIRTDR-155](https://redhat.atlassian.net/browse/VIRTDR-155) - Create rhdr-tenant with Application and Components
- All component builds and repository forks completed

---

## Overview

The **FBC (Filesystem-based OLM Catalog)** is the final aggregation layer that combines all operator bundles into a single OLM catalog image. It enables users to install RHDR operators through standard Kubernetes OLM/OperatorHub mechanisms.

### What is FBC?

- **Purpose:** Aggregates multiple operator bundles into a single queryable OLM catalog
- **Components Included:**
  - `rhdr-hub-operator-bundle`
  - `rhdr-cluster-operator-bundle`
  - `rhdr-multicluster-operator-bundle`
  - `rhdr-csi-addons-operator-bundle` (if applicable)
- **Output:** Single catalog image: `quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:TAG`
- **Build Type:** Single-platform (Linux/AMD64)

### Why FBC for RHDR?

| Benefit | Why It Matters |
|---------|----------------|
| **Single Installation Source** | Users get all RHDR operators from one catalog |
| **Dependency Resolution** | OLM automatically handles operator dependencies |
| **Version Management** | Different operator versions tracked in catalog index |
| **Clean Separation** | Standalone FBC (not tied to ODF catalog) |
| **Future-proof** | Supports incremental operator additions |

---

## Prerequisites

Before creating the FBC application, ensure the following are complete:

### 1. **All Operator Components Built** ✅
- [ ] `rhdr-hub-operator` component building successfully
- [ ] `rhdr-cluster-operator` component building successfully
- [ ] `rhdr-multicluster-operator` component building successfully
- [ ] `rhdr-csi-addons-operator` component building (if included in release)

**Verification:**
```bash
# Check Konflux Dashboard for component build status
# All operators should show "✅ Build Succeeded"
```

### 2. **All Bundle Components Built** ✅
- [ ] `rhdr-hub-operator-bundle` component building successfully
- [ ] `rhdr-cluster-operator-bundle` component building successfully
- [ ] `rhdr-multicluster-operator-bundle` component building successfully
- [ ] `rhdr-csi-addons-operator-bundle` building (if applicable)

**Verification:**
```bash
# Check bundle image availability in registry
podman pull quay.io/rh-ocp-dr/rhdr/rhdr-hub-operator-bundle:latest
podman pull quay.io/rh-ocp-dr/rhdr/rhdr-cluster-operator-bundle:latest
podman pull quay.io/rh-ocp-dr/rhdr/rhdr-multicluster-operator-bundle:latest
```

### 3. **Repository Forks Complete** ✅
- [ ] `rh-ocp-dr/rhdr-fbc-catalog` repository created
  - Contains `Dockerfile` for building FBC image
  - Contains `.tekton/` directory with pipeline definitions
  - Contains `catalog/` directory structure (to be populated)
  - Contains `remote_source/` directory with `cachito.env`

**Verification:**
```bash
git clone https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc-catalog.git
cd rhdr-fbc-catalog
ls -la  # Should show: Dockerfile, catalog/, .tekton/, remote_source/
```

### 4. **Tenant RPA Complete** ✅
- [ ] Release Plan Admission (RPA) files created in konflux-release-data:
  - `config/constraints/product/rhdr-tenant.yaml`
  - `config/stone-prod-p02.hjvn.p1/product/EnterpriseContractPolicy/registry-rhdr-stage.yaml`
  - `config/stone-prod-p02.hjvn.p1/product/EnterpriseContractPolicy/registry-rhdr-prod.yaml`
  - RPA files for each version: `rhdr-4-22-stage.yaml`, `rhdr-4-22-prod.yaml`

**Verification:**
```bash
# Check MR status in konflux-release-data
# Should be merged to main branch
```

### 5. **VIRTDR-141 Dependency** ✅
- [ ] Epic VIRTDR-141 shows all sub-tasks complete
- [ ] All component builds linked to VIRTDR-141

---

## Step-by-Step: Creating RHDR FBC Application

### Step 1: Verify FBC Repository Structure

```bash
cd /tmp/rhdr-fbc-catalog-setup
git clone https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc-catalog.git
cd rhdr-fbc-catalog

# Expected structure
tree -L 2
# Expected output:
# .
# ├── Dockerfile
# ├── .tekton/
# │   ├── rhdr-fbc-catalog-on-push.yaml
# │   └── rhdr-fbc-catalog-on-pull-request.yaml
# ├── catalog/
# │   ├── rhdr-hub-operator/
# │   ├── rhdr-cluster-operator/
# │   ├── rhdr-multicluster-operator/
# │   └── rhdr-csi-addons-operator/ (if applicable)
# └── remote_source/
#     ├── cachito.env
#     └── app/ -> (symlink to repo root)
```

### Step 2: Create FBC Component in Konflux UI

**Navigate to Konflux Dashboard:**

1. Go to: [Konflux Dashboard](https://console.redhat.com/hac)
2. Select tenant: `rh-ocp-dr-tenant`
3. Select application: `rhdr-4-22` (or applicable version)
4. Click **"Create component"** button

**Fill in Component Details:**

| Field | Value | Notes |
|-------|-------|-------|
| Component Name | `rhdr-fbc-catalog` | Matches repository name |
| Git Repository | `https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc-catalog.git` | Public URL to FBC repo |
| Git Reference | `main` | Default branch |
| Dockerfile | `Dockerfile` | At repo root |
| Container Image | `quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog` | Registry path for output |

**Screenshot Example:**
```
┌─────────────────────────────────────────────────┐
│ Create Component: RHDR FBC Catalog              │
├─────────────────────────────────────────────────┤
│ Component Name: [rhdr-fbc-catalog]              │
│                                                 │
│ Git Repository:                                 │
│ [https://gitlab.cee.redhat.com/rh-ocp-dr/      │
│  rhdr-fbc-catalog.git]                          │
│                                                 │
│ Git Reference: [main]                           │
│                                                 │
│ Dockerfile: [Dockerfile]                        │
│                                                 │
│ Container Image:                                │
│ [quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog]      │
│                                                 │
│ Platform:  ☑ Linux  ☐ Windows                  │
│                                                 │
│ [Create] [Cancel]                              │
└─────────────────────────────────────────────────┘
```

### Step 3: Configure Build Dependencies (Build Nudges)

**Set build nudges to depend on bundle components:**

1. In component details, click **"Edit"**
2. Find **"Build nudges from"** section (or **"depends on"**)
3. Add dependencies on bundle components:
   - `rhdr-hub-operator-bundle`
   - `rhdr-cluster-operator-bundle`
   - `rhdr-multicluster-operator-bundle`
   - `rhdr-csi-addons-operator-bundle` (if included)

**Purpose:** Ensures FBC builds only after all bundles are available.

**Example Patch Command** (if using YAML):
```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: rhdr-fbc-catalog
  namespace: rh-ocp-dr-tenant
spec:
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc-catalog.git
      revision: main
  containerImage: quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog
  dockerfile: Dockerfile
  buildNudges:
    - rhdr-hub-operator-bundle
    - rhdr-cluster-operator-bundle
    - rhdr-multicluster-operator-bundle
    # - rhdr-csi-addons-operator-bundle (if applicable)
```

### Step 4: Trigger Initial Build

**Via Konflux UI:**

1. Go to component: `rhdr-fbc-catalog`
2. Click **"Trigger build"** button
3. Select trigger type: **"Push"** (or **"Manual"** for initial test)
4. Monitor build progress in dashboard

**Expected Timeline:**
- Build preparation: ~2 minutes
- Base image pull: ~1-2 minutes
- FBC catalog generation: ~3-5 minutes
- Image push to registry: ~2-3 minutes
- **Total:** ~10-15 minutes

**Verification After Build:**
```bash
# Check if FBC image was pushed
podman pull quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest

# List catalog contents
podman run --rm quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest \
  opm render quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest
```

### Step 5: Validate FBC Content

**Verify bundles are included in catalog:**

```bash
# Export catalog index
podman run --rm quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest \
  opm render quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest > catalog-index.json

# Check for expected operators
grep -c "rhdr-hub-operator" catalog-index.json
grep -c "rhdr-cluster-operator" catalog-index.json
grep -c "rhdr-multicluster-operator" catalog-index.json

# Expected output: each should find at least 1 match
```

**Inspect Specific Operator:**
```bash
podman run --rm quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest \
  opm render quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest | \
  jq '.[] | select(.name == "rhdr-hub-operator")'
```

---

## Dockerfile Reference

**Expected Dockerfile structure in `rhdr-fbc-catalog/Dockerfile`:**

```dockerfile
# Build FBC image from opm
FROM quay.io/operator-framework/opm:latest as builder

# Copy catalog directory structure
COPY catalog /catalog

# Generate OLM catalog from directory
RUN opm render /catalog > /catalog.json && \
    opm validate /catalog

# Final image
FROM quay.io/operator-framework/opm:latest

COPY --from=builder /catalog.json /
EXPOSE 50051

ENTRYPOINT ["/opm", "serve", "/catalog.json"]
```

---

## Troubleshooting

### Issue 1: Build Fails - "Bundle not found"

**Symptom:** Build log shows `Error: cannot find bundle quay.io/.../rhdr-hub-operator-bundle:TAG`

**Root Cause:** Bundle images not yet pushed to registry

**Solution:**
1. Verify bundle components completed successfully: `rhdr-hub-operator-bundle`, etc.
2. Check registry push logs in each bundle component build
3. Ensure bundle image path matches in `catalog/` directory
4. Wait for bundle image to be available in registry (may take several minutes after build completion)

### Issue 2: FBC Doesn't Include All Operators

**Symptom:** Only 2-3 operators show in catalog, not all 4

**Root Cause:** `catalog/` directory missing subdirectories for some bundles

**Solution:**
1. Check `rhdr-fbc-catalog` repo has correct structure:
   ```bash
   ls -la catalog/
   # Should show: rhdr-hub-operator/, rhdr-cluster-operator/, 
   #              rhdr-multicluster-operator/, rhdr-csi-addons-operator/
   ```
2. Add missing subdirectories with bundle references
3. Push changes and rebuild

### Issue 3: Build Nudge Not Triggering

**Symptom:** FBC component not rebuilding when bundle components complete

**Root Cause:** Build nudges not configured correctly

**Solution:**
1. Verify build nudges are set correctly on component
2. Check component names exactly match (case-sensitive)
3. Try manual trigger first: Komponente → "Trigger build"

### Issue 4: Image Push Fails - Permission Denied

**Symptom:** Build succeeds but fails at push: `Error: unauthorized: authentication required`

**Root Cause:** Registry credentials not configured for component

**Solution:**
1. Check component has correct `quay.io` credentials
2. Verify tenant `rh-ocp-dr-tenant` has `image-pull-secret`
3. Contact tenant admin to grant push access to `quay.io/rh-ocp-dr/rhdr/`

---

## Integration Testing

### Test 1: OLM Installation from FBC

**Objective:** Verify FBC catalog works with OLM

```bash
# Create catalog source
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhdr-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:latest
  displayName: "Red Hat Disaster Recovery"
  publisher: "Red Hat"
EOF

# Wait for catalog source to be ready
kubectl wait --for=condition=Ready \
  -n openshift-marketplace \
  catalogsource/rhdr-catalog \
  --timeout=5m

# Verify operators appear in marketplace
kubectl get packagemanifests -n openshift-marketplace | grep rhdr
```

### Test 2: Install Operator from Catalog

```bash
# Create namespace for operator
kubectl create namespace ramen-system

# Create subscription to rhdr-hub-operator
cat <<EOF | kubectl apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhdr-hub-operator
  namespace: ramen-system
spec:
  channel: alpha
  name: rhdr-hub-operator
  source: rhdr-catalog
  sourceNamespace: openshift-marketplace
EOF

# Wait for operator installation
kubectl wait --for=condition=Succeeded \
  -n ramen-system \
  installplan \
  --timeout=5m \
  --all

# Verify operator pod is running
kubectl get pods -n ramen-system | grep rhdr-hub-operator
```

---

## Checklist Before Production

- [ ] FBC component created in Konflux UI
- [ ] Build nudges configured correctly
- [ ] First build completed successfully
- [ ] FBC image pushed to registry
- [ ] All expected operators present in catalog
- [ ] OLM installation test successful
- [ ] Operator pod starts and runs successfully
- [ ] No errors in operator logs
- [ ] Integration with hub/cluster operators verified

---

## Related Documentation

- [ConstraintFileStages.md](./ConstraintFileStages.md) - Three stages of release configuration
- [MULTI_COMPONENT_STRATEGY.md](../MULTI_COMPONENT_STRATEGY.md) - Component architecture details
- [TENANT_NAMING_AND_FORK_STRATEGY.md](../TENANT_NAMING_AND_FORK_STRATEGY.md) - Repository naming and forking
- [OLM/FBC Documentation](https://olm.operatorframework.io/docs/getting-started/) - Official OLM docs
- [OPM Documentation](https://github.com/operator-framework/operator-registry) - OPM (Operator Package Manager) reference

---

## Sign-Off

| Role | Status |
|------|--------|
| **Author** | Nadav Levanon |
| **Related JIRA** | [VIRTDR-141](https://redhat.atlassian.net/browse/VIRTDR-141) |
| **Expected Completion** | Post component build completion |
| **Last Updated** | 2026-05-31 |
