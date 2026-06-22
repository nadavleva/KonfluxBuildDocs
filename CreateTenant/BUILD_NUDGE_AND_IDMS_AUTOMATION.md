# Manage Commit Digest Automatic Changes for Bundle and Operators

## Overview

This document describes the implementation of an automated "build nudge" delivery workflow between core operator components and the File-Based Catalog (FBC) using Tekton, Konflux pipelines, and GitOps configurations.

**Target Implementation:** RHDR (Red Hat Disaster Recovery) components in the `rh-ocp-dr` organization on GitLab within the `rhdr-tenant` Konflux namespace.

**Purpose:** When core operator images or underlying dependencies are successfully built and pushed, Tekton must trigger automated Merge Requests (MRs) to downstream bundle and catalog repositories (e.g., `rhdr-fbc`). This ensures that non-released image digests from Quay map correctly to `registry.redhat.io` formats during internal Konflux FIPS verification testing.

> **Note:** The dragonfly/fence-agents-remediation and rhwa-fbc repositories referenced in this document serve as examples. The actual implementation target is the rhdr component in https://gitlab.cee.redhat.com/rh-ocp-dr within the `rhdr-tenant` namespace.

---

## Workflow Summary: 4 Steps in Order

The implementation follows this exact sequence:

1. **Update bundle scripts** — Modify `update_bundle.sh` to handle digest replacements and CSV metadata
2. **Build nudge on the push** — Configure build-nudge-files annotations in Tekton pipeline  
3. **Configure ConfigMap in namespace** — Deploy namespace-wide-nudging-renovate-config for auto-merge
4. **Create IDMS mapping** — Set up ImageDigestMirrorSet for registry translation

Each step depends on the previous step being completed. Detailed instructions for each follow below.

---

## Implementation Workflow Order

### Step 1: Update Bundle Scripts

Configure `update_bundle.sh` to correctly handle image digest replacements and CSV metadata updates.

**Target Repository:**
- [rhdr in rh-ocp-dr](https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr)

**Reference Implementation (example only):**
- [fence-agents-remediation/bundle-hack/update_bundle.sh](https://gitlab.cee.redhat.com/dragonfly/fence-agents-remediation/-/blob/far-0-8/bundle-hack/update_bundle.sh?ref_type=heads)

**Key Operations:**

1. **CSV Metadata Replacement** (line ~34)
   - Extract and update the ClusterServiceVersion (CSV) file
   - Replace digest values in the CSV spec
   - Ensure metadata consistency across operator versions

2. **Image URL Replacement** (line ~17)
   - Replace `quay.io/redhat-user-workloads/` digest with `registry.redhat.io/` format
   - Pattern: `quay.io/redhat-user-workloads/{tenant}/{component}/{image}@sha256:{digest}`
   - Maps to: `registry.redhat.io/workload-availability/{operator-name}@sha256:{digest}`

**Example Mapping:**
```
Source (Quay - non-released):
quay.io/redhat-user-workloads/rhwa-tenant/fence-agents-remediation/far-operator-0-8@sha256:18d0e1c80b306c1ee85bf603684273cbd57e268b2f39c383af6dfff500ccc78a

Target (Registry.redhat.io - official):
registry.redhat.io/workload-availability/fence-agents-remediation-rhel9-operator@sha256:18d0e1c80b306c1ee85bf603684273cbd57e268b2f39c383af6dfff500ccc78a
```

**Script Responsibilities:**
- Parse bundle Dockerfile or container build manifests
- Extract current image digests from successful build outputs
- Update bundle manifests with mapped digest values
- Validate YAML/manifest structure integrity post-replacement
- Generate clean git diffs for MR automation

---

### Step 2: Build Nudge on the Push

Apply `build-nudge-files` annotations strictly on **push events** in the pipeline definition.

**File Location for RHDR:** `.tekton/rhdr-push.yaml` (or equivalent for your component)

**Example Reference:** `.tekton/far-operator-0-8-push.yaml` (from fence-agents-remediation)

**Configuration Template:**

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: rhdr-push
  annotations:
    build.appstudio.openshift.io/build-nudge-files: bundle-hack/update_bundle.sh
    build.appstudio.openshift.io/repo: https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr/-/tree/{{revision}}
    build.appstudio.redhat.com/commit_sha: '{{revision}}'
    build.appstudio.redhat.com/target_branch: '{{target_branch}}'
    pipelinesascode.tekton.dev/cancel-in-progress: "false"
    pipelinesascode.tekton.dev/max-keep-runs: "3"
    pipelinesascode.tekton.dev/on-cel-expression: |
      event == "push" && target_branch == "main" && (
        "Containerfile.rhdr".pathChanged() ||
        ".tekton/rhdr-push.yaml".pathChanged() ||
        "rhdr".pathChanged() ||
        "rpms.in.yaml".pathChanged() ||
        "rpms.lock.yaml".pathChanged() ||
        "rebuild.txt".pathChanged()
      )
spec:
  # ... rest of pipeline configuration
```

**Key Annotations Explained:**

| Annotation | Purpose | Value |
|------------|---------|-------|
| `build-nudge-files` | Files that trigger downstream MRs | Path to `update_bundle.sh` |
| `on-cel-expression` | Activation conditions | **Must include `event == "push"`** |
| `target_branch` | Branch filter | Your specific branch name |
| `max-keep-runs` | Pipeline run retention | Usually `"3"` for efficiency |

**Critical Point:** The `build-nudge-files` annotation **only triggers on push events**, not on pull requests. This ensures controlled, automated downstream updates without spurious MRs from development branches.

**Example MR Created by Nudge:**
- [fence-agents-remediation MR #555](https://gitlab.cee.redhat.com/dragonfly/fence-agents-remediation/-/merge_requests/555)

---

### Step 3: Configure ConfigMap in Your Namespace

Create a namespace-level ConfigMap that enables automatic merging of nudge-generated MRs.

**Prerequisites:** Before applying the ConfigMap, ensure you have:
- Completed Step 1 (bundle scripts created)
- Completed Step 2 (build nudge configured in Tekton)
- Access to your Konflux namespace: `rhdr-tenant`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-wide-nudging-renovate-config
  namespace: rhdr-tenant  # RHDR tenant namespace
  annotations: {}
data:
  automerge: "true"
  automergeType: pr
  fileMatch: ".*Dockerfile.*, .*.yaml, .*Containerfile.*, .*update_bundle.sh"
  ignoreTests: "true"
  platformAutomerge: "true"
```

**Apply via CLI for RHDR:**
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-wide-nudging-renovate-config
  namespace: rhdr-tenant
data:
  automerge: "true"
  automergeType: pr
  fileMatch: ".*Dockerfile.*, .*.yaml, .*Containerfile.*, .*update_bundle.sh"
  ignoreTests: "true"
  platformAutomerge: "true"
EOF
```

**Field Descriptions:**

| Field | Meaning | Example Value |
|-------|---------|---------------|
| `automerge` | Enable automatic merging | `"true"` |
| `automergeType` | Merge strategy | `"pr"` (pull request merge, not squash) |
| `fileMatch` | Regex patterns for files to auto-merge | `.*update_bundle.sh, .*yaml` |
| `ignoreTests` | Skip CI pipeline tests before merge | `"true"` (for internal system MRs) |
| `platformAutomerge` | Use platform bot for merge authorization | `"true"` |

**Reference Configuration (rhodf-tenant example):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace-wide-nudging-renovate-config
  namespace: rhodf-tenant
data:
  automerge: "true"
  automergeType: pr
  fileMatch: ".*Dockerfile.*, .*.yaml, .*Containerfile.*"
  ignoreTests: "true"
  platformAutomerge: "true"
```

---

### Step 4: Create IDMS Mapping

Configure the ImageDigestMirrorSet (IDMS) to handle non-released Quay digest resolution to `registry.redhat.io` paths dynamically.

**What is IDMS?**

The ImageDigestMirrorSet (IDMS) is a Kubernetes resource that automatically rewrites image pull requests. When the Konflux cluster encounters an image digest from `quay.io/redhat-user-workloads`, the IDMS can remap it to the official Red Hat registry path for validation and testing.

**File Location:** `.tekton/images-mirror-set.yaml` in your FBC repository (e.g., `rhdr-fbc` for RHDR, or `rhwa-fbc` for RHWA)

**Configuration Template for RHDR:**

```yaml
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: rhdr-operator-mirror-set
spec:
  imageDigestMirrors:
  - mirrors:
    - registry.redhat.io/rh-ocp-dr
    source: quay.io/redhat-user-workloads/rhdr-tenant/rhdr
```

**Example Reference (RHWA):**

```yaml
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: rhwa-operator-mirror-set
spec:
  imageDigestMirrors:
  - mirrors:
    - registry.redhat.io/workload-availability
    source: quay.io/redhat-user-workloads/rhwa-tenant/fence-agents-remediation
  - mirrors:
    - registry.redhat.io/workload-availability
    source: quay.io/redhat-user-workloads/rhwa-tenant/storage-based-remediation
```

**Mapping Flow:**

1. **Pull Request:** `quay.io/redhat-user-workloads/rhwa-tenant/fence-agents-remediation/far-operator-0-8@sha256:18d0e1c8...`
2. **IDMS Intercepts:** Recognizes source registry and digest
3. **Rewrite:** `registry.redhat.io/workload-availability/fence-agents-remediation-rhel9-operator@sha256:18d0e1c8...`
4. **Validation:** Official Red Hat registry used for isolated FIPS testing

**Deployment to Cluster:**
```bash
oc apply -f .tekton/images-mirror-set.yaml
```

**Verification:**
```bash
oc get imagedigestmirrorset
oc describe imagedigestmirrorset rhwa-operator-mirror-set
```

---

## Technical Clarifications

### Q1: ConfigMap vs. Labels — Is it a Simple Label or a Physical ConfigMap?

**Answer:** You must create an **actual physical ConfigMap object**.

**Not a label.** The `namespace-wide-nudging-renovate-config` is a real Kubernetes resource that:
- Resides in your tenant namespace
- Is read directly by Konflux's automation engine (Renovate bot variant)
- Contains key-value data fields that control auto-merge behavior
- Must be applied once per namespace and persists across MR cycles

**Verification:**
```bash
kubectl get configmap namespace-wide-nudging-renovate-config -n rh-ocp-dr-tenant
kubectl describe configmap namespace-wide-nudging-renovate-config -n rh-ocp-dr-tenant
```

---

### Q2: Automatic MR Permissions — Do I Need a Custom Bot User?

**Answer:** **No.** You do not create a new bot user or group.

**How It Works:**

1. **Platform Bot Identity:** Konflux utilizes a built-in platform automation bot (visible as system GitLab identities like `group_64126_bot_4e8efddbdcca741268d605ca1a4ff2e8`).

2. **Authorization Mechanism:** When the ConfigMap sets `automerge: "true"` and `platformAutomerge: "true"`, it signals the platform bot that it is **pre-authorized** to:
   - Create MRs targeting matched file patterns
   - Bypass manual code review for those MRs
   - Execute the merge operation automatically after CI passes

3. **GitLab Permissions:** Ensure your GitLab project repository has granted the Konflux platform bot **Developer or Maintainer** scope so it can:
   - Push branches directly
   - Merge approved pull requests without manual intervention

**Verification Steps:**

1. Check if the platform bot is already a member of your project:
   ```
   GitLab Project Settings → Members → Search for "bot"
   ```

2. Confirm it has the correct role:
   - Minimum: **Developer** access
   - Recommended: **Maintainer** for full automation

3. If not present, contact your Konflux platform administrator to add the bot to your project.

---

### Q3: Operator-SDK Bundle Installation — Run operator-sdk install bundle?

**Answer:** **No.** Do not use `operator-sdk install bundle` within this FBC delivery pipeline.

**Why Not:**

- The FBC delivery pipeline transforms images into official Red Hat-operator formats via `gen_fbc.sh`
- Installation/validation must proceed through the official OLM-catalog track
- Local installation would require external cluster connectivity and is outside pipeline scope

**What to Do Instead:**

For validation or integration testing within the Tekton run, use:

```bash
operator-sdk bundle validate ./bundle
```

This validates the bundle structure and metadata without installing it.

**Complete Validation Sequence:**
```bash
# 1. Validate bundle structure
operator-sdk bundle validate ./bundle

# 2. Update digests in bundle (via update_bundle.sh)
./bundle-hack/update_bundle.sh

# 3. Verify updated bundle integrity
operator-sdk bundle validate ./bundle

# 4. Generate FBC manifests
./gen_fbc.sh

# 5. Verify FBC output (no installation)
kustomize build ./config/manager | kubectl dry-run=client -f -
```

---

## Implementation Checklist

### Pre-Implementation

- [ ] **Operator Repository:** https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr
- [ ] **FBC Repository:** https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc (or identify your specific FBC repo)
- [ ] Confirm your Konflux namespace name: `rhdr-tenant`
- [ ] Confirm your target branch name in operator repo (e.g., `main` or release branch)
- [ ] Get GitLab project IDs for both repos

### Phase 1: Bundle Script Configuration

- [ ] Copy `update_bundle.sh` template from reference implementation
- [ ] Customize CSV metadata extraction logic (line ~34)
- [ ] Customize image URL replacement logic (line ~17)
- [ ] Test locally against sample bundle and image digests
- [ ] Validate YAML output integrity post-transformation
- [ ] Commit to operator repository under `bundle-hack/` directory

### Phase 2: Build Nudge Configuration

- [ ] Create/update `.tekton/rhdr-push.yaml` (in rh-ocp-dr/rhdr)
- [ ] Add `build-nudge-files: bundle-hack/update_bundle.sh` annotation
- [ ] Set CEL expression to trigger **only on push events**
- [ ] Set `target_branch` to your specific branch name (e.g., `main`)
- [ ] Include all relevant file paths in `pathChanged()` conditions
- [ ] Merge to operator repository main branch

### Phase 3: ConfigMap Deployment

- [ ] Connect to Konflux cluster via `kubectl`/`oc login` (stone-prod-p02)
- [ ] Set default namespace to your tenant: `rhdr-tenant`
- [ ] Apply `namespace-wide-nudging-renovate-config` ConfigMap
- [ ] Verify ConfigMap exists and has correct data:
  ```bash
  kubectl get configmap namespace-wide-nudging-renovate-config -n rhdr-tenant
  ```

### Phase 4: IDMS Mapping Deployment

- [ ] Create `.tekton/images-mirror-set.yaml` in FBC repository (rh-ocp-dr/rhdr-fbc)
- [ ] Define source → mirror mappings for RHDR operator images:
  - Source: `quay.io/redhat-user-workloads/rh-ocp-dr-tenant/rhdr`
  - Mirror: `registry.redhat.io/rh-ocp-dr`
- [ ] Apply IDMS to Konflux cluster:
  ```bash
  oc apply -f .tekton/images-mirror-set.yaml
  ```
- [ ] Verify IDMS resource is active:
  ```bash
  oc get imagedigestmirrorset
  ```

### Testing & Validation

- [ ] Trigger a push event to operator repository target branch
- [ ] Verify Tekton pipeline runs successfully
- [ ] Confirm nudge MR is created in FBC repository
- [ ] Verify MR contains updated digests from `update_bundle.sh`
- [ ] Confirm MR auto-merges without manual approval
- [ ] Verify merged bundle manifests in FBC repository
- [ ] Check IDMS is correctly remapping image pulls during tests

---

## Acceptance Criteria

- [ ] Bundle script (`update_bundle.sh`) effectively swaps text patterns and metadata digests without breaking YAML/manifest structure
- [ ] Tekton pipeline (`.tekton/{component}-push.yaml`) triggers automated downstream MRs exclusively on `push` events to the target branch
- [ ] Downstream MRs target the FBC repository with updated bundle manifests
- [ ] ConfigMap `namespace-wide-nudging-renovate-config` is active in the tenant namespace
- [ ] Automated MRs merge without manual administrative approval
- [ ] Image files in MRs match the `fileMatch` regex pattern in ConfigMap
- [ ] IDMS `ImageDigestMirrorSet` successfully translates non-released `quay.io/redhat-user-workloads` digests to `registry.redhat.io` paths
- [ ] Isolated FIPS verification testing uses correctly mapped official registry paths
- [ ] No manual digest updates required between successful operator builds and bundle catalogs

---

## Troubleshooting

### Issue: Nudge MRs Not Being Created

**Check:**
1. Verify `event == "push"` is in the CEL expression
2. Confirm the target branch name matches exactly in CEL and pipeline
3. Check that the file paths in `pathChanged()` match your repository structure
4. Verify Tekton pipeline ran successfully (check logs in Konflux UI)

### Issue: MRs Not Auto-Merging

**Check:**
1. Verify ConfigMap exists:
   ```bash
   kubectl get configmap namespace-wide-nudging-renovate-config -n rhdr-tenant
   ```
2. Verify `automerge: "true"` and `platformAutomerge: "true"` are set
3. Check that `fileMatch` regex matches the files being modified
4. Confirm GitLab bot user has Developer/Maintainer access to FBC repo

### Issue: Image Digest Mapping Not Working

**Check:**
1. Verify IDMS exists:
   ```bash
   oc get imagedigestmirrorset
   ```
2. Confirm source registry paths match your image pull locations
3. Verify mirror registry paths match official registry format
4. Check cluster events for image pull errors:
   ```bash
   oc describe imagedigestmirrorset <name>
   ```

---

## References

### RHDR Target Repositories
- [RHDR Operator Repository](https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr)
- [RHDR FBC Repository](https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc)
- [RH-OCP-DR Organization](https://gitlab.cee.redhat.com/rh-ocp-dr)

### Reference Implementations (Example)
- [Dragonfly Organization](https://gitlab.cee.redhat.com/dragonfly) - Example reference implementations
- [fence-agents-remediation](https://gitlab.cee.redhat.com/dragonfly/fence-agents-remediation/-/tree/far-0-8)
- [FBC Repository Reference: rhwa-fbc](https://gitlab.cee.redhat.com/dragonfly/rhwa-fbc/-/tree/main)
- [Related MR Example #555](https://gitlab.cee.redhat.com/dragonfly/fence-agents-remediation/-/merge_requests/555)

### Kubernetes & OpenShift Documentation
- [Tekton Build Nudge Documentation](https://tekton.dev/)
- [ImageDigestMirrorSet API Reference](https://docs.openshift.com/container-platform/latest/rest_api/config_apis/imagedigestmirrorset.yaml.html)
- [Konflux Platform Bot (GitLab)](https://gitlab.cee.redhat.com/group_64126)

---

## Related Documents

- [RHDRReleasePlanAndAdmissionImplementation.md](./RHDRReleasePlanAndAdmissionImplementation.md)
- [CreateRHDRFBCApplication.md](./CreateRHDRFBCApplication.md)
- [RHDRCatalog.md](./RHDRCatalog.md)
- [CLI_KUBECTL_ACCESS.md](../CLI_KUBECTL_ACCESS.md)
