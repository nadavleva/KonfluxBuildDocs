# Testing and Validating RHDR Builds in Staging

This guide covers how to access staging repositories, verify built images, and prepare deliverables for QE testing of RHDR (Red Hat Disaster Recovery) components.

---

## Table of Contents

1. [Network & VPN Setup](#network--vpn-setup)
2. [Accessing the Staging Registry](#accessing-the-staging-registry)
3. [Verifying Built Images](#verifying-built-images)
4. [Delivering to QE](#delivering-to-qe)
5. [Checking Build Status](#checking-build-status)
6. [Troubleshooting](#troubleshooting)

---

## Network & VPN Setup

### For Fedora CSB (Corporate Standard Build) with Chrome

#### Step 1: Connect to Red Hat VPN

Ensure you are connected to the Red Hat internal network via VPN or from a corporate network location.

#### Step 2: Configure the Proxy (Fedora GNOME)

The proxy autoconfig script allows your browser and CLI tools to route traffic through Red Hat's internal proxy for stage access.

**Via GNOME Settings UI:**

1. Press the **Super (Windows) key**
2. Type **"Network"** and open **Network settings**
3. Scroll down and click the gear icon next to **Network Proxy**
4. Select **Automatic** and paste the proxy autoconfig URL:
   ```
   https://nexus.corp.redhat.com/repository/endpointsystems-raw-releases/proxy.pac/proxy.pac
   ```
5. Close the settings

**Via Command Line (Alternative):**

```bash
gsettings set org.gnome.system.proxy mode auto
gsettings set org.gnome.system.proxy autoconfig-url https://nexus.corp.redhat.com/repository/endpointsystems-raw-releases/proxy.pac/proxy.pac
```

#### Step 3: Configure CLI Tools (Required for Command-Line Access)

Command-line tools like `podman`, `skopeo`, `curl`, and `kubectl` do **not** use the GNOME proxy settings automatically. You **must** set environment variables in your shell.

**Add proxy variables to your shell configuration:**

Choose your shell:

**For bash** (`~/.bashrc`):
```bash
cat >> ~/.bashrc <<'EOF'

# Red Hat proxy configuration
export HTTP_PROXY=http://squid.corp.redhat.com:3128
export HTTPS_PROXY=http://squid.corp.redhat.com:3128
export NO_PROXY=localhost,127.0.0.1
EOF

source ~/.bashrc
```

**For zsh** (`~/.zshrc`):
```bash
cat >> ~/.zshrc <<'EOF'

# Red Hat proxy configuration
export HTTP_PROXY=http://squid.corp.redhat.com:3128
export HTTPS_PROXY=http://squid.corp.redhat.com:3128
export NO_PROXY=localhost,127.0.0.1
EOF

source ~/.zshrc
```

**Verify the variables are set:**
```bash
echo $HTTP_PROXY
echo $HTTPS_PROXY
# Should both display: http://squid.corp.redhat.com:3128
```

#### Step 4: Configure Chrome

Chrome on Linux uses the system proxy settings configured in Step 2, so it should automatically pick up the GNOME proxy settings. No additional Chrome configuration needed.

**To verify browser proxy is working:**

1. Open Chrome
2. Visit `https://www.dev.redhat.com/`
3. If it loads, your proxy is configured correctly

#### Step 5: Validate Full Proxy Setup

**For command-line tools (already configured in Step 3):**

The proxy environment variables are now active. Verify by running:

```bash
curl -I https://www.dev.redhat.com/
# Should get HTTP 200

podman login registry.stage.redhat.io
# Should prompt for credentials (indicating connection works)
```

**Test all proxies are working:**

Use the validation script provided below in the [Verifying Built Images](#verifying-built-images) section.

---

## Accessing the Staging Registry

Your staging images live in `registry.stage.redhat.io` after the Konflux release pipeline publishes them. This is backed by `quay.io/redhat-pending` (private by default).

### Getting Staging Registry Credentials

You need a **terms-based registry service account** (different from your personal Red Hat account).

#### Step 1: Access the Terms-Based Registry Portal

1. Ensure your **proxy is configured** (see above)
2. Open Chrome and navigate to:
   ```
   https://access.stage.redhat.com/terms-based-registry/#/
   ```
3. Log in with your **Red Hat account**

#### Step 2: Create a Service Account

1. Click **Create Service Account** (or similar button)
2. Give it a descriptive name, e.g., `rhdr-staging-testing`
3. Copy the **username** and **token** that are generated

#### Step 3: Log In to the Staging Registry

Now you can authenticate with the credentials you just created:

**Using `podman`:**

```bash
podman login registry.stage.redhat.io
# Username: <paste the username from service account>
# Password: <paste the token from service account>
```

**Using `skopeo`:**

Note: `skopeo login` is interactive and will always prompt for credentials to update the auth file, even if credentials already exist. This is normal behavior.

```bash
skopeo login --authfile=~/.rhdr-staging-auth.json registry.stage.redhat.io
# Username: <paste the username from service account>
# Password: <paste the token from service account>
# Login Succeeded!
```

**Or create an auth file:**

```bash
# Create a minimal auth file for skopeo/podman
cat > ~/.rhdr-staging-auth.json <<EOF
{
  "auths": {
    "registry.stage.redhat.io": {
      "username": "<your-service-account-username>",
      "password": "<your-service-account-token>"
    }
  }
}
EOF

chmod 600 ~/.rhdr-staging-auth.json

# Use with skopeo
skopeo inspect --authfile=~/.rhdr-staging-auth.json \
  docker://registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator:latest
```

---

## Verifying Built Images

### Finding Your Built Images

After Konflux builds complete, images end up in two possible places:

**1. Build Output (Before Release Pipeline)** - `quay.io/redhat-user-workloads/`
- Available immediately after component build completes
- Used by the release pipeline as input
- Access: Extract credentials from your build pipeline ServiceAccount secrets

**2. Staging Registry (After Release Pipeline)** - `registry.stage.redhat.io/rhdr/`
- Published AFTER the staging release pipeline runs
- This is the final location QE should pull from
- Access: Use your terms-based registry service account

### Where to Find Your Images

**Start here - Check Konflux console first:**

1. Log into your Konflux cluster
2. Navigate: **Applications** → **Your Application** → **Releases**
3. Click on your release (the one from Thursday)
4. Look for **Artifacts** or **Image pull** section
5. Copy the exact **pullspecs** shown there

This is the authoritative source for where your images actually are and exactly how to pull them.

### Check Individual Image

**Inspect by tag (if available):**

```bash
skopeo inspect docker://registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator:latest
```

**Inspect by digest:**

```bash
# Get the digest from your release artifacts page, then:
skopeo inspect docker://registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator@sha256:abc123def456...
```

### Quick Batch Check

Use the provided validation script to check all RHDR images in staging:

**After logging in with your credentials:**

```bash
# Make the script executable
chmod +x validate_images.sh

# Run the validation (uses your current podman login)
./validate_images.sh
```

**Output includes:**
- ✅/❌ Status for each component
- Image size (GB/MB/KB)
- Full pullspec and digest
- Next steps for QE testing

**Example output:**

```
=== RHDR Staging Image Validation ===

Registry: registry.stage.redhat.io
Auth file: .docker/config.json

Checking RHDR components...

  rhdr-hub-rhel9-operator:                   ✅ found (650.5MB)
     Pullspec: registry.stage.redhat.io/rhdr/rhdr-hub-rhel9-operator:latest
     Digest:   sha256:abc123def456789...
...

=== Summary ===
Found:     8 / 8 images
Not found: 0 / 8 images

✅ All RHDR components are present in staging!
```

**If you need to use a specific auth file:**

```bash
./validate_images.sh ~/.rhdr-staging-auth.json
```

**Or with the docker config from podman login:**

```bash
./validate_images.sh ~/.docker/config.json
```

### Pull an Image

Once you've verified an image exists, pull it:

```bash
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator:latest

# Or by digest:
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator@sha256:abc123def456...
```

---

## Image Publishing Workflow

Understanding where images go at each stage helps troubleshoot issues:

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: Component Builds (Konflux)                             │
│ Output: quay.io/redhat-user-workloads/rhdr-tenant/rhdr/...     │
│ Access: Extract from build pipeline ServiceAccount secrets      │
│ Timeline: Completes in 5-10 minutes                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: Staging Release Pipeline (Konflux)                     │
│ Input: Pulls from redhat-user-workloads                         │
│ Output: registry.stage.redhat.io/rhdr/... (final location)      │
│ Access: Use terms-based registry service account                │
│ Timeline: 10-20 minutes after Stage 1                           │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: Ready for QE Testing                                   │
│ Images: registry.stage.redhat.io/rhdr/...                       │
│ Deliver: Pullspecs from Konflux Artifacts page                  │
└─────────────────────────────────────────────────────────────────┘
```

**What to do at each stage:**

| Stage | How to Access | Command |
|-------|---------------|---------|
| **Build Output** (redhat-user-workloads) | Extract ServiceAccount secrets | `kubectl get secret <pull-secret> -o jsonpath='{.data.\.dockerconfigjson}'` |
| **Staging (registry.stage.redhat.io)** | Terms-based registry SA | `podman login registry.stage.redhat.io` |
| **Release Artifacts** | `extract-release-artifacts.sh` script | `./extract-release-artifacts.sh rhdr-tenant` |
| **Verify Published** | Konflux Artifacts page | Navigate to Releases → Artifacts |

### Quick Start: Extract and Share Images

```bash
# 1. Extract all published images from your releases
./extract-release-artifacts.sh rhdr-tenant

# Output shows:
#   - Backing store URLs: quay.io/redhat-pending/rhdr----* (private, for reference only)
#   - Pullable URLs: registry.stage.redhat.io/rhdr/* (use these!)
#     Example: podman pull registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator-bundle:v4.22

# 2. Test pulling one (use registry.stage.redhat.io, not quay.io/redhat-pending)
podman pull registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator-bundle:v4.22

# 3. Share the registry.stage.redhat.io URLs with QE
```

---

## Delivering to QE

You have several options for delivering built images to QE without needing a full FBC (File-Based Catalog).

### Option 1: Direct Image Pull (Simplest)

Share the **image pullspecs** from your Release artifacts (use `extract-release-artifacts.sh`). QE can pull directly using **`registry.stage.redhat.io` (NOT `quay.io/redhat-pending`)**:

```bash
# The Release shows quay.io/redhat-pending URLs, but pull via the proxy:
podman pull registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator-bundle:v4.22
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle@sha256:<digest>
```

**What to give QE:**
- Component name (e.g., `rhdr-cluster-operator`)
- Pullspec with registry.stage.redhat.io registry (e.g., `registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle:v4.22`)
- Digest for reproducibility (e.g., `@sha256:abc123...`)
- Bundle image pullspec (for OLM testing)

**Important:** 
- DO NOT share `quay.io/redhat-pending/` URLs - those are private backing store, not directly accessible
- Always convert to `registry.stage.redhat.io/rhdr/` for pulling

---

### Option 2: CatalogSource from Bundle (Operator Testing)

For testing operator install/upgrade via OLM without a full FBC, QE creates a `CatalogSource` pointing at your staged bundle image:

**Example CatalogSource YAML for QE to apply:**

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhdr-staging-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle@sha256:<digest>
```

**What to give QE:**
- Bundle image pullspec with digest
- YAML template they can customize
- Instructions to apply it with `kubectl apply -f`

Once applied, OLM will discover and allow installation of the operator from the bundle.

---

### Option 3: ImageDigestMirrorSet (Cluster-Wide Redirection)

If your manifests/CSVs reference production `registry.redhat.io` paths, QE can apply an `ImageDigestMirrorSet` to redirect all image pulls to staging transparently:

**Example IDMS YAML for QE to apply:**

```yaml
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: rhdr-staging-mirror
spec:
  imageDigestMirrors:
    - source: registry.redhat.io/rhdr
      mirrors:
        - registry.stage.redhat.io/rhdr
```

**Benefits:**
- No manifest edits needed
- Redirects all pulls cluster-wide
- Remove after testing

**What to give QE:**
- The IDMS YAML above
- Instructions to apply with `kubectl apply -f`
- Note: Changes take effect immediately on apply

---

### Recommended Delivery Format

Prepare a **delivery document** for QE with the following structure:

```markdown
# RHDR Staging Build Delivery - [DATE]

## Build Information

- **Release:** [name from Release object]
- **Konflux Workspace:** rhdr-tenant
- **Build Date:** 2026-06-25
- **Status:** Successfully published ✅

## Component Images

| Component | Pullspec | Digest |
|-----------|----------|--------|
| rhdr-hub-operator | registry.stage.redhat.io/rhdr/rhdr-hub-rhel9-operator | sha256:abc123... |
| rhdr-hub-bundle | registry.stage.redhat.io/rhdr/rhdr-hub-operator-bundle | sha256:def456... |
| rhdr-cluster-operator | registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator | sha256:ghi789... |
| rhdr-cluster-bundle | registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle | sha256:jkl012... |
| [... others ...] | | |

*Extract this table using: `./extract-release-artifacts.sh rhdr-tenant`*
*Note: Release YAML shows `quay.io/redhat-pending/` URLs, but convert to `registry.stage.redhat.io/rhdr/` for pulling*

## Testing Options

### Option A: Direct Pull (Use registry.stage.redhat.io)
\`\`\`bash
podman pull registry.stage.redhat.io/rhdr/rhdr-hub-rhel9-operator:v4.22
\`\`\`

### Option B: OLM Testing with CatalogSource
Apply this manifest:
\`\`\`yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhdr-staging-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle:v4.22
\`\`\`

### Option C: Cluster-Wide Image Redirection
Apply this manifest to transparently redirect all `registry.redhat.io/rhdr` pulls to staging:
\`\`\`yaml
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: rhdr-staging-mirror
spec:
  imageDigestMirrors:
    - source: registry.redhat.io/rhdr
      mirrors:
        - registry.stage.redhat.io/rhdr
\`\`\`

## Registry Access

Images are stored in: \`quay.io/redhat-pending/rhdr----*\` (private backing store)
But access them via: \`registry.stage.redhat.io/rhdr/*\` (public proxy)

To access:
1. Visit: https://access.stage.redhat.com/terms-based-registry/#/
2. Create a service account or use existing credentials
3. Log in:
   \`\`\`bash
   podman login registry.stage.redhat.io
   \`\`\`
```

---

## Checking Build Status and Published Images

### Extract Images from Your Releases (Easiest Method)

Your Konflux Releases contain the exact image URLs and digests. Use the provided script:

```bash
# Make it executable
chmod +x extract-release-artifacts.sh

# Extract all published images from releases
./extract-release-artifacts.sh rhdr-tenant
```

**Output shows:**
- Component name
- Image digest (sha256)
- All available pullspecs
- SBOM URLs for compliance

This is the source-of-truth data from your Thursday release that QE needs!

### Manually Check Release Artifacts

1. Log into your Konflux cluster
2. Navigate to **Applications** → **Your Application**
3. Click **Components**
4. For each component, check the **Build** tab:
   - **Latest pipeline run** shows build status
   - **Logs** tab shows build output
   - **Artifacts** tab lists published images and digests

### From CLI (kubectl)

```bash
# Set your namespace
kubectl config set-context --current --namespace=rhdr-tenant

# List components
kubectl get components

# Watch a specific component's builds
kubectl get pipelinerun -n rhdr-tenant --watch

# Get details of a pipeline run
kubectl describe pipelinerun <name> -n rhdr-tenant

# Stream logs from a pipeline run
kubectl logs -f pipelinerun/<name> -n rhdr-tenant
```

### From Release Pipeline Status

After your staging release pipeline completes:

1. Navigate to **Releases** in Konflux console
2. Find your release (e.g., `rhdr-staging-release-4.22`)
3. View the **Artifacts** page — lists all published images with:
   - Full pullspecs
   - Image digests
   - Bundle image references
   - Publish timestamp

---

## Troubleshooting

### "Preprod Lockdown: Access Denied" When Accessing Terms-Based Registry

**Cause:** Your browser isn't routing through the Red Hat internal proxy.

**Fix:**

1. Verify **VPN is connected**
2. Verify **proxy is configured** (see Network & VPN Setup section)
3. Verify proxy is active:
   ```bash
   gsettings get org.gnome.system.proxy mode
   # Should return: 'auto'
   ```
4. Try accessing again: `https://access.stage.redhat.com/terms-based-registry/#/`

If still failing, check ServiceNow KB0006375 for detailed proxy setup.

### "403 Forbidden" When Pulling from Staging Registry

**Cause:** Invalid or expired service account credentials.

**Fix:**

1. Visit terms-based registry portal again: `https://access.stage.redhat.com/terms-based-registry/#/`
2. Create a **new** service account
3. Re-authenticate:
   ```bash
   podman logout registry.stage.redhat.io
   podman login registry.stage.redhat.io
   # Use new credentials
   ```

### "Cannot list RHDR repositories" Error

**This is a permissions issue, not a build problem.**

**What it means:**
- Your service account has **WRITE-only** (push/upload) permissions
- It does NOT have **READ** permissions on the RHDR namespace
- The images likely exist (built on Thursday), but you can't view them

**Solution - Option 1: Create a New Service Account with Read Access**

1. Visit: `https://access.stage.redhat.com/terms-based-registry/#/`
2. Create a **new service account** specifically for reading/pulling images
   - Note the name clearly, e.g., `rhdr-staging-pull-access`
3. Use the new credentials:
   ```bash
   podman logout registry.stage.redhat.io
   podman login registry.stage.redhat.io
   # Use new credentials
   
   # Update auth file
   cat > ~/.rhdr-staging-auth-pull.json <<EOF
   {
     "auths": {
       "registry.stage.redhat.io": {
         "username": "<new-read-service-account>",
         "password": "<new-token>"
       }
     }
   }
   EOF
   
   ./validate-images.sh ~/.rhdr-staging-auth-pull.json
   ```

**Solution - Option 2: Request Read Access for Current Account**

- Contact your Platform Engineer or registry admin to grant read access to your existing service account

**Solution - Option 3: Check Konflux Console Directly**

Even without registry read access, you can see published images:
1. Log into Konflux console
2. Navigate: **Applications** → **Your Application** → **Releases** → **Artifacts**
3. Look for your Thursday release
4. View the published image digests and pullspecs

---

### "unauthorized: access to the requested resource is not authorized"

**This happens when:**
- The images haven't been published to staging yet (builds/release pipeline still running)
- Your service account doesn't have read access to RHDR repositories
- The RHDR repositories haven't been created yet

**What to do:**

1. **Check if builds completed:**
   ```bash
   kubectl get components -n rhdr-tenant
   kubectl get pipelinerun -n rhdr-tenant --watch
   ```

2. **Check if release pipeline ran:**
   Visit your Konflux console:
   - Navigate to **Applications** → **Your Application** → **Releases** → **Artifacts**
   - Look for published images in `registry.stage.redhat.io/rhdr/`

3. **If builds are complete but images still not accessible:**
   - The service account may not have read permissions
   - Contact your Platform Engineer for access to RHDR staging repositories

**Typical timeline:**
- Component build: 5-10 minutes
- Release pipeline publish: 10-20 minutes
- Images appear in staging registry: 5-10 minutes after release

If you're still seeing "not found" after 30 minutes, check the build logs in Konflux.

### "manifest unknown" When Checking Image

**Cause:** Image hasn't been published yet, or the tag/digest is incorrect.

**Fix:**

1. Verify the build completed in Konflux console
2. Check the **Artifacts** page for the correct pullspec and digest
3. Verify you're using the correct registry: `registry.stage.redhat.io` (not `quay.io/redhat-pending`)
4. Run the batch check script to see which images are actually present

### "Cannot connect to API" or "Network is unreachable"

**Cause:** Not connected to Red Hat network/VPN.

**Fix:**

```bash
# Verify VPN connection (depends on your VPN client)
# Check if you can reach an internal resource
ping corp.redhat.com  # May be blocked by firewall, that's OK

# Test proxy connectivity
curl -x http://squid.corp.redhat.com:3128 https://www.dev.redhat.com/

# Reconnect to VPN if needed
# (instructions depend on your VPN client)
```

---

## Quick Reference

### Commands for Staging Access

```bash
# 1. Extract all published images from your releases (START HERE)
./extract-release-artifacts.sh rhdr-tenant

# 2. Login to registry
podman login registry.stage.redhat.io

# 3. Pull an image by tag (use registry.stage.redhat.io, NOT quay.io/redhat-pending)
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator:v4.22

# 4. Pull an image by digest (best for reproducibility)
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-operator-bundle@sha256:abc123...
```

### Proxy Configuration (One-Time Setup)

```bash
# Step 1: Via GNOME settings
gsettings set org.gnome.system.proxy mode auto
gsettings set org.gnome.system.proxy autoconfig-url \
  https://nexus.corp.redhat.com/repository/endpointsystems-raw-releases/proxy.pac/proxy.pac

# Step 2: For CLI tools, add to ~/.bashrc or ~/.zshrc
export HTTP_PROXY=http://squid.corp.redhat.com:3128
export HTTPS_PROXY=http://squid.corp.redhat.com:3128
export NO_PROXY=localhost,127.0.0.1

# Apply immediately
source ~/.bashrc  # or source ~/.zshrc
```

### Verify Everything Works

```bash
# 1. Proxy is working (should load)
curl -I https://www.dev.redhat.com/

# 2. Registry login is working
podman login registry.stage.redhat.io
# Use your terms-based registry service account credentials

# 3. Validate all staging images were published
./validate_images.sh

# 4. Pull a specific image
podman pull registry.stage.redhat.io/rhdr/rhdr-cluster-rhel9-operator:latest
```

---

## Additional Resources

- **Konflux Documentation:** https://konflux-ci.dev/docs/
- **Red Hat KB0006375:** Proxy configuration in ServiceNow
- **Terms-Based Registry:** https://access.stage.redhat.com/terms-based-registry/#/
- **Staging Registry:** https://registry.stage.redhat.io
- **RHDR Product Definitions:** See `rhdr_product.yaml` in your repository

---

## Need Help?

If you encounter issues:

1. Check the **Troubleshooting** section above
2. Verify **proxy configuration** (most issues are proxy-related)
3. Check **Konflux console** for build status
4. Contact your **Platform Engineer** for cluster or credential issues
5. File an issue in your RHDR GitLab repository if it's a tool/pipeline problem

