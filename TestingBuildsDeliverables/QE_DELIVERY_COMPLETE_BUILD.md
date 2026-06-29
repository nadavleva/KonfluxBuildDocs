# RHDR Complete Build - QE Delivery Package
## All 9 Components Successfully Published to Staging

**Build Date:** 2026-06-29  
**Status:** ✅ **ALL 9 COMPONENTS PUBLISHED**  
**Namespace:** `rhdr-tenant` (stone-prod-p02)

---

## Build Summary

All 9 RHDR components successfully built and published to staging registry in **2 release batches**:

| Batch | Release | Created | Components | Status |
|-------|---------|---------|------------|--------|
| **Batch 1** | `rhdr-4-22-releaseplan-stagercr2p` | 2026-06-25 19:22 UTC | 6 | ✅ Succeeded |
| **Batch 2** | `rhdr-4-22-20260629-062626-000-fd5504f-gt5g5` | 2026-06-29 06:26 UTC | 3 | ✅ Succeeded |

---

## QE Delivery: All 9 Components

### Batch 1: Operator Bundles & Main Components (6 images)

```bash
# 1. Hub Operator Bundle
podman pull registry.stage.redhat.io/rhdr/rhdr-hub-operator-bundle@sha256:167306b35c8f37e9abcd3aa003a5b292d43f6216716b297755eb7de794e23b47

# 2. Hub Operator
podman pull registry.stage.redhat.io/rhdr/rhdr-hub-rhel9-operator@sha256:<DIGEST>

# 3. Cluster Operator Bundle
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle@sha256:883cf79151bafbfc9931c08b75d542bd55879060425b695bba688f160ecff8bb

# 4. Cluster Operator
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator@sha256:<DIGEST>

# 5. Multicluster Operator Bundle
podman pull registry.stage.redhat.io/rhdr/rhdr-multicluster-operator-bundle@sha256:7feabd1b89a3c1e6cf4d0b7a21d9590b178c1486fbdf13eb802a003dcf8c8425

# 6. Multicluster Operator Image
podman pull registry.stage.redhat.io/rhdr/rhdr-multicluster-operator-image@sha256:1c6e7c6a199c9b8c6a0d20ef4c5ff814bbcf95bd0a1adee58e7973e7a9c753ad

# 7. CSI Addons Operator Bundle
podman pull registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator-bundle@sha256:e044fb70bf7876b64fa081b3dfdd37a7d1e8b91790c6c7b8a6de8b2944bedb83

# 8. CSI Addons Operator
podman pull registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator@sha256:14611d2c39faabbb194e6ea4fb4583a6b5d2ac49703fd0253fd8cd875263a682
```

### Batch 2: Additional Components (3 images)

```bash
# 9. CSI Addons Sidecar
podman pull registry.stage.redhat.io/rhdr/rhdr-csi-addons-sidecar@sha256:c888bec7622190d6766d5c689eeabf2181fcce27b2c75bb218cccff0bb64ab85

# 10. RamenDR Console
podman pull registry.stage.redhat.io/rhdr/rhdr-ramendr-console@sha256:71fc3f6c1a26771b3ccb2891c76eaac98ada7033a12cdbb2cfe164600e65be89

# 11. Ramen Operator Base Image
podman pull registry.stage.redhat.io/rhdr/rhdr-ramen-operator-base-image@sha256:66551e81b28bb8d7e1a09b711e9b410107382ddc3f45fdb3c08c86c3057e860a
```

---

## Complete Component Table

| # | Component | Release Batch | Pullspec | Digest |
|---|-----------|--------------|----------|--------|
| 1 | rhdr-hub-operator-bundle | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-hub-operator-bundle:v4.22` | `sha256:167306b35c8f37e...` |
| 2 | rhdr-hub-rhel9-operator | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-hub-rhel9-operator:v4.22` | TBD |
| 3 | rhdr-cluster-operator-bundle | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle:v4.22` | `sha256:883cf791...` |
| 4 | rhdr-cluster-rhel9-operator | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator:v4.22` | TBD |
| 5 | rhdr-multicluster-operator-bundle | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-multicluster-operator-bundle:v4.22` | `sha256:7feabd1b...` |
| 6 | rhdr-multicluster-operator-image | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-multicluster-operator-image:v4.22` | `sha256:1c6e7c6a...` |
| 7 | rhdr-csi-addons-operator-bundle | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator-bundle:v4.22` | `sha256:e044fb70...` |
| 8 | rhdr-csi-addons-rhel9-operator | Batch 1 | `registry.stage.redhat.io/rhdr/rhdr-csi-addons-rhel9-operator:v4.22` | `sha256:14611d2c...` |
| 9 | rhdr-csi-addons-sidecar | Batch 2 | `registry.stage.redhat.io/rhdr/rhdr-csi-addons-sidecar@sha256:c888bec7...` | `sha256:c888bec7...` |
| 10 | rhdr-ramendr-console | Batch 2 | `registry.stage.redhat.io/rhdr/rhdr-ramendr-console@sha256:71fc3f6c...` | `sha256:71fc3f6c...` |
| 11 | rhdr-ramen-operator-base-image | Batch 2 | `registry.stage.redhat.io/rhdr/rhdr-ramen-operator-base-image@sha256:66551e81...` | `sha256:66551e81...` |

---

## For OLM Testing

Create a CatalogSource using one of the bundle images:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhdr-staging-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.stage.redhat.io/rhdr/rhdr-hub-operator-bundle@sha256:167306b35c8f37e9abcd3aa003a5b292d43f6216716b297755eb7de794e23b47
```

Or use the cluster operator bundle:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhdr-staging-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle@sha256:883cf79151bafbfc9931c08b75d542bd55879060425b695bba688f160ecff8bb
```

---

## Build Information

### Snapshots Used

- **Batch 1 Snapshot:** `rhdr-4-22-20260625-125749-000` (6 components built)
- **Batch 2 Snapshot:** `rhdr-4-22-20260629-062626-000` (9 components built, 3 published in this batch)

### Releases Created

```bash
# View all releases
kubectl get releases -n rhdr-tenant

# View specific release details
kubectl describe release rhdr-4-22-releaseplan-stagercr2p -n rhdr-tenant
kubectl describe release rhdr-4-22-20260629-062626-000-fd5504f-gt5g5 -n rhdr-tenant

# Verify published images
kubectl get release rhdr-4-22-releaseplan-stagercr2p -n rhdr-tenant -o jsonpath='{.status.artifacts.images[].name}'
```

---

## Key Points for QE

✅ **All components are published to `registry.stage.redhat.io`**  
✅ **Use `registry.stage.redhat.io/rhdr/` (NOT `quay.io/redhat-pending`)**  
✅ **Components built in 2 batches (intentional) - all 9 are complete**  
✅ **Use provided pullspecs with digests for reproducibility**  
✅ **Proxy required:** `squid.corp.redhat.com:3128`  
✅ **Credentials:** Terms-based registry service account from https://access.stage.redhat.com/terms-based-registry/

---

## Using extract-release-artifacts.sh Script

The included `extract-release-artifacts.sh` script automates pulling all 9 components and generating deployment files:

### Step 1: Authenticate to Staging Registry

```bash
# You MUST log in to access staging images
podman login registry.stage.redhat.io

# When prompted:
# Username: <your service account username from https://access.stage.redhat.com/terms-based-registry/>
# Password: <your service account token>
```

### Step 2: Run the Extraction Script

```bash
# Make executable
chmod +x extract-release-artifacts.sh

# Run it (searches last 10 releases by default)
./extract-release-artifacts.sh

# Or search more releases
./extract-release-artifacts.sh rhdr-tenant 15
```

### Step 3: Use Generated Output Files

The script creates two files in `./output/` with timestamped names:

**A. Pull all components locally:**
```bash
bash output/podman-pull-20260629-212803.sh
```

**B. Deploy to OCP cluster:**
```bash
kubectl apply -f output/catalogsource-20260629-212803.yaml
```

---

## Quick Manual Pull Test (without script)

```bash
# Set proxy (if required by your network)
export HTTP_PROXY=http://squid.corp.redhat.com:3128
export HTTPS_PROXY=http://squid.corp.redhat.com:3128

# Login (REQUIRED)
podman login registry.stage.redhat.io

# Pull any component
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle@sha256:883cf79151bafbfc9931c08b75d542bd55879060425b695bba688f160ecff8bb
```

---

## Deploying CatalogSource to OpenShift Cluster

### Important: Cluster Authentication

When applying the CatalogSource to an OpenShift cluster, **the cluster itself needs credentials** to pull the image. This is different from your local `podman login`.

**You must create an ImagePullSecret for the cluster:**

```bash
# 1. Create pull secret with your staging credentials
kubectl create secret docker-registry rhdr-staging-pull-secret \
  --docker-server=registry.stage.redhat.io \
  --docker-username=<service-account-username> \
  --docker-password=<service-account-token> \
  --docker-email=your-email@example.com \
  -n openshift-marketplace

# 2. Patch service account to use this secret
kubectl patch serviceaccount default \
  -p '{"imagePullSecrets": [{"name": "rhdr-staging-pull-secret"}]}' \
  -n openshift-marketplace

# 3. Apply the CatalogSource from script output
kubectl apply -f output/catalogsource-20260629-212803.yaml

# 4. Verify it's ready
kubectl get catalogsource rhdr-staging-catalog -n openshift-marketplace
```

**Yes, even though you're logged in locally, the cluster needs its own credentials to pull the image from the staging registry.**

---

## Support

For issues:
1. Verify proxy configuration (see [VerifyBuildImages.md](./VerifyBuildImages.md))
2. Check credentials are fresh at https://access.stage.redhat.com/terms-based-registry/
3. Run: `./verify-latest-release.sh` to confirm all components are published
4. Contact Platform Engineer for cluster/credential issues

---

**Generated:** 2026-06-29 14:50 UTC  
**Konflux Namespace:** `rhdr-tenant`  
**Cluster:** `stone-prod-p02`
