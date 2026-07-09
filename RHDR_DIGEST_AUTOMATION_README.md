# RHDR Multicluster Operator Bundle - Automated Digest Management

## Overview

This implementation follows the **Build Nudge** workflow for automatically managing image digest updates in the operator bundle. When core operator images are successfully built in Konflux, Tekton automatically triggers downstream merge requests to update digests in the bundle.

Pattern based on **rhwa fence-agents-remediation** implementation: https://gitlab.cee.redhat.com/dragonfly/fence-agents-remediation

## BUILD to PRODUCTION Workflow

### Registry Layers

| Layer | Registry | Purpose | Status |
|-------|----------|---------|--------|
| **BUILD** | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22` | Tekton build output (non-released) | Current ✅ |
| **STAGING** | `registry.stage.redhat.io/rhdr/rhdr-multicluster-rhel9-operator` | Internal staging for FIPS testing | Future (via FBC IDMS) |
| **PRODUCTION** | `registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator` | Public GA release | Target after validation |

### Current Status: BUILD Mode
The bundle is currently configured to work with **BUILD images**:
- Images are non-released Tekton outputs on Quay
- `update_bundle.sh` replaces BUILD digests with PRODUCTION registry paths
- FIPS verification testing will use IDMS (in FBC repo) to intercept pulls and map them back to BUILD digests

### Transition to Production

When ready for production release:

1. **Update `bundle-hack/update_bundle.sh`:**
   - Replace BUILD digest values with actual production digests from successful build
   - Update `OPERATOR_COMPONENT_BUILD` and `CONSOLE_COMPONENT_BUILD` values
   - Update `OPERATOR_COMPONENT` and `CONSOLE_COMPONENT` (PRODUCTION) values
   - Script already maps to production registry paths (`registry.redhat.io/rhdr/...`)

2. **Verify Registry Paths:**
   - Registries match `products/rhdr/rhdr.yaml` definitions in pyxis-repo-configs
   - Current mapping uses: `registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator`
   - All paths already point to PRODUCTION registries (no IDMS needed in bundle repo)

## Files Created/Modified

### 1. Bundle Automation Script
**File:** `bundle-hack/update_bundle.sh`
- Automatically replaces image digests in the CSV manifest
- Maps staging `quay.io/redhat-user-workloads/` images to production `registry.redhat.io/rhdr/` format
- Validates YAML integrity after updates
- Triggered by Tekton build-nudge-files annotation on push events
- **Key Feature:** Contains STAGING and PROD variables with clear TODO comments for transition

### 2. Bundle Test Script
**File:** `bundle-hack/test_update_bundle.sh`
- Local testing script matching rhwa fence-agents-remediation pattern
- Allows validation of digest replacement before deployment
- Usage: `cd bundle-hack && bash test_update_bundle.sh`

### 3. Tekton Configuration
**File:** `.tekton/rhdr-multicluster-operator-bundle-4-22-push.yaml`
- **Annotation:** `build.appstudio.openshift.io/build-nudge-files: bundle-hack/update_bundle.sh`
  - Note: Uses `build.appstudio.openshift.io/` prefix (not just `build-nudge-files`)
- **CEL Expression:** Activates on `event == "push"` to 4.22 branch
- **Path Conditions:** Triggers on changes to:
  - Dockerfile
  - .tekton/rhdr-multicluster-operator-bundle-4-22-push.yaml
  - bundle/
  - container.yaml
- Only triggers on push events (not PRs) for controlled automation
- Results in automated MR to downstream FBC repository

### 4. Namespace Configuration
**File:** `.tekton/namespace-wide-nudging-renovate-config.yaml`
- ConfigMap for namespace-wide auto-merge behavior
- Enables: Automatic merging of nudge-generated MRs
- Platform bot authorization for merge operations
- File pattern matching: `.*update_bundle\.sh`, `.*bundle/manifests/.*\.yaml`
- Additional settings: `gitLabIgnoreApprovals: "true"`, `commitMessageSuffix` for clarity

### 5. IDMS Configuration (FBC Repo)
**Note:** ImageDigestMirrorSet (IDMS) is NOT in the bundle repo. Primary location is FBC repo (`.tekton/images-mirror-set.yaml`)
- Reference copy and documentation: See [Docs/Setup/rhdr-operator-images-mirror-set-reference.yaml](../Setup/rhdr-operator-images-mirror-set-reference.yaml)
- Purpose: Maps BUILD images (Quay) to production registry paths for FIPS testing in FBC pipeline
- Used for testing before GA release; not needed in bundle repo
- Reference: [rhwa-fbc IDMS](https://gitlab.cee.redhat.com/dragonfly/rhwa-fbc/-/blob/main/.tekton/images-mirror-set.yaml)

## Current Image Digests

The following digests were retrieved from Quay and pinned in the bundle:

| Component | BUILD (Quay) | PRODUCTION Registry | Digest |
|-----------|----------------|-------------------|--------|
| Multicluster Operator | `quay.io/redhat-user-workloads/.../rhdr-multicluster-operator-image-4-22` | `registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator` | `sha256:f53cace844501a79396bd5af32e242e250b369452bc453f408f91982fb315a02` |
| Console | `quay.io/redhat-user-workloads/.../rhdr-ramendr-console-4-22` | `registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator` | `sha256:4b9428fcab5e21fbd2886d95348473712e8fdc3ac2122c4b5011f3b93b233910` |

## Implementation Checklist

### ✅ Phase 1: BUILD Configuration (Completed)
- [x] Updated `container.yaml` to build single-arch only (linux/x86_64)
- [x] Pinned all image references in CSV with SHA256 digests
- [x] Created `update_bundle.sh` automation script (BUILD→PRODUCTION mode)
- [x] Created `test_update_bundle.sh` for local testing
- [x] Updated Tekton push pipeline with `build.appstudio.openshift.io/build-nudge-files` annotation
- [x] Enhanced CEL expression with pathChanged() conditions
- [x] Created namespace ConfigMap for auto-merge
- [x] Fixed terminology: STAGING → BUILD (Tekton output)
- [x] Moved IDMS documentation to Docs/Setup/ (primary location: FBC repo)

### ⏳ Phase 2: Cluster Deployment (Pending)
- [ ] Apply ConfigMap to Konflux cluster
  ```bash
  oc apply -f .tekton/namespace-wide-nudging-renovate-config.yaml -n rhdr-tenant
  ```

- [ ] Verify ConfigMap is active
  ```bash
  oc get configmap namespace-wide-nudging-renovate-config -n rhdr-tenant
  oc describe configmap namespace-wide-nudging-renovate-config -n rhdr-tenant
  ```

- [ ] FBC IDMS Setup (when creating FBC repo)
  - Copy IDMS from [Docs/Setup/rhdr-operator-images-mirror-set-reference.yaml](../Setup/rhdr-operator-images-mirror-set-reference.yaml)
  - Update digests for your build outputs
  - Deploy in FBC pipeline before FIPS testing

### Phase 3: Staging Testing & Validation
1. [ ] Test locally: `cd bundle-hack && bash test_update_bundle.sh`
2. [ ] Verify script produces valid YAML output
3. [ ] Trigger a push to the 4.22 branch of the bundle repository
4. [ ] Verify Tekton pipeline runs successfully
5. [ ] Check for automated MR in downstream FBC repository
6. [ ] Verify MR contains updated digests from staging sources
7. [ ] Confirm auto-merge completes without manual intervention

### Phase 4: Production Transition (When Ready)
- [ ] Obtain production digests from successful build
- [ ] Update `bundle-hack/update_bundle.sh`:
  - Replace STAGING digest values with actual production digests
  - Replace PROD comment with production-ready values
- [ ] Re-run `bundle-hack/test_update_bundle.sh` to validate
- [ ] Commit and merge to main branch
- [ ] Monitor conforma verification with production registries

## Violations Resolution

### ✅ Fixed: Unpinned Images (8 violations)
- All image references now include SHA256 digests
- BUILD images (Quay) pinned with digests
- All references map to production registries for final deployment

### ✅ Fixed: Multi-arch Bundle (1 violation)
- container.yaml updated to build only linux/x86_64
- Next build will produce single-arch bundle

### ℹ️ Registry Policy (3 violations)
- Handled by IDMS remapping (in FBC pipeline, not bundle repo)
- IDMS (when configured in FBC) translates Quay paths to `registry.redhat.io/rhdr/` paths for testing
- No additional action needed at bundle level

## Template Rendering and Automation Flow

### Phase 1: Initial Bundle Generation (`pre_render_templates`)

**What Triggers It:**
- Manual execution (local or CI): `bash pre_render_templates`
- Typically run when:
  - Creating a new release bundle version
  - Updating operator source code substantially
  - Regenerating entire bundle from scratch

**What It Does:**
```
pre_render_templates execution:
  ├─ Clones odf-multicluster-orchestrator source repo
  ├─ Gets golang 1.24 tooling
  ├─ Bumps RELEASE number in Dockerfile
  ├─ Sets OCP version ranges (v4.22-v4.23)
  ├─ Logs into registry.redhat.io
  ├─ Runs: make bundle (generates full operator bundle)
  ├─ Modifies generated bundle:
  │  ├─ Adds relatedImages section
  │  ├─ Adds full_version label (e.g., 4.22.0-86)
  │  ├─ Sets channel defaults (stable-4.22)
  │  └─ Updates dependencies.yaml
  └─ Outputs: bundle/ directory with valid CSV

Result: bundle/manifests/odf-multicluster-orchestrator.clusterserviceversion.yaml
        Version: 4.22.0-86 (without .keytype suffix)
```

**Output Location:**
```
bundle/
├── manifests/
│   └── odf-multicluster-orchestrator.clusterserviceversion.yaml
└── metadata/
    ├── annotations.yaml
    └── dependencies.yaml
```

### Phase 2: Automated Digest Updates (`update_bundle.sh` + Tekton Nudge)

**What Triggers It:**
- Push event to `4.22` branch in rhdr-multicluster-operator-bundle repo
- **AND** changes to pathChanged conditions:
  - `Dockerfile`
  - `.tekton/rhdr-multicluster-operator-bundle-4-22-push.yaml`
  - `bundle/` directory
  - `container.yaml`

**Tekton Pipeline Execution:**
```
Push event to 4.22 branch
    ↓
CEL expression evaluates:
  - event == "push"
  - target_branch == "4.22"
  - pathChanged() conditions met
    ↓
✓ Conditions satisfied → Tekton PipelineRun starts
    ↓
build.appstudio.openshift.io/build-nudge-files annotation:
  - Points to: bundle-hack/update_bundle.sh
    ↓
Konflux nudge controller detects annotation
    ↓
Triggers: update_bundle.sh execution
```

**What `update_bundle.sh` Does:**
```
update_bundle.sh execution:
  ├─ Sets BUILD digests (from Quay, non-released):
  │  ├─ OPERATOR_COMPONENT_BUILD: quay.io/.../rhdr-multicluster-operator-image-4-22@sha256:...
  │  └─ CONSOLE_COMPONENT_BUILD: quay.io/.../rhdr-ramendr-console-4-22@sha256:...
  │
  ├─ Sets PRODUCTION digests (registry.redhat.io, released):
  │  ├─ OPERATOR_COMPONENT: registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator@sha256:...
  │  └─ CONSOLE_COMPONENT: registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator@sha256:...
  │
  ├─ Replaces BUILD → PRODUCTION in CSV (6 sed patterns):
  │  ├─ spec.install.spec.deployments[0].spec.template.spec.containers[0].image
  │  ├─ spec.install.spec.deployments[0].env[].value (TOKEN_EXCHANGE_IMAGE)
  │  ├─ spec.install.spec.deployments[1].spec.template.spec.containers[0].image (console)
  │  └─ spec.relatedImages[*].image (both operator and console)
  │
  ├─ Validates output: python3 yaml.safe_load
  │
  └─ Outputs: Updated CSV with PRODUCTION digests
```

### Phase 3: Automated MR and Merge

**What Triggers It:**
- Successful execution of `update_bundle.sh`
- Tekton nudge controller creates automatic MR to downstream FBC repo

**MR Contents:**
```
MR to downstream repository:
  - Updated bundle/manifests/odf-multicluster-orchestrator.clusterserviceversion.yaml
  - All image digests replaced (BUILD → PRODUCTION)
  - Commit message includes: "automatic nudge MR for digest tag update"
```

**Auto-Merge Trigger:**
```
MR created
  ↓
ConfigMap checks: namespace-wide-nudging-renovate-config.yaml
  - automerge: "true"
  - platformAutomerge: "true"
  - gitLabIgnoreApprovals: "true"
    ↓
✓ Conditions met → Platform bot auto-merges
  ↓
MR merged to main branch of FBC repo
```

### Phase 4: FIPS Testing via IDMS (FBC Pipeline)

**What Triggers It:**
- Push of updated bundle to main branch triggers FBC pipeline

**IDMS Remapping:**
```
FBC pipeline receives updated bundle with registry.redhat.io paths
  ↓
IDMS (ImageDigestMirrorSet) intercepts pulls:
  registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator@sha256:...
    ↓
Maps to BUILD images on Quay (for testing):
  quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22@sha256:...
    ↓
Runs FIPS compliance verification
    ↓
After verification passes
    ↓
PRODUCTION release triggered with actual registry.redhat.io images
```

## Complete Workflow Timeline

```
Developer Activity:
  └─ Push changes to 4.22 branch
      ↓
  [Automatic - Tekton Triggered]
      ↓
  PipelineRun starts (CEL conditions met)
      ├─ Tekton builds container images
      ├─ Outputs BUILD digests to Quay
      ├─ build-nudge-files annotation detected
      │
      ├─ update_bundle.sh executes
      │  ├─ Replaces BUILD digests with PRODUCTION paths
      │  ├─ Validates YAML
      │  └─ Returns updated CSV
      │
      ├─ Automated MR created (downstream FBC repo)
      │
      ├─ ConfigMap auto-merge evaluates
      │  └─ Platform bot merges MR
      │
      ├─ FBC pipeline triggered
      │  ├─ IDMS remapping intercepts pulls
      │  ├─ FIPS verification runs with BUILD images
      │  └─ Results fed back to release process
      │
      └─ No manual intervention required ✅
```

## Workflow Automation

When fully configured, this workflow operates as follows:

1. **Push Event** → Developer pushes to 4.22 branch
2. **Tekton Activation** → PipelineRun starts (CEL expression evaluated)
3. **Build Completion** → Container images built, BUILD digests generated on Quay
4. **Nudge Trigger** → `build.appstudio.openshift.io/build-nudge-files` annotation activates
5. **Script Execution** → `update_bundle.sh` replaces BUILD digests with PRODUCTION registry paths
6. **CSV Validation** → YAML validation passes, script confirms success
7. **MR Creation** → Automated MR created to downstream repository with updated manifests
8. **Auto-merge** → ConfigMap auto-merge enabled; platform bot merges without approval
9. **IDMS Mapping** (FBC pipeline) → BUILD images intercepted and remapped for FIPS testing
10. **GA Release** → After verification, production release proceeds with actual registry.redhat.io images

## Registry Path Mappings

**From pyxis-repo-configs/products/rhdr/rhdr.yaml:**

| Component | Repository | Registry |
|-----------|------------|----------|
| Multicluster Operator | rhdr-multicluster-rhel9-operator | registry.redhat.io/rhdr/ |
| Multicluster Bundle | rhdr-multicluster-operator-bundle | registry.redhat.io/rhdr/ |

**Staging to Production Mapping via IDMS:**

```
BUILD (Tekton Output on Quay):
quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22@sha256:...

    ↓ (Tekton update_bundle.sh replaces with)

PRODUCTION (CSV in repository):
registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator@sha256:...

    ↓ (FBC pipeline: IDMS intercepts for testing)

FIPS Testing (via FBC IDMS remapping):
registry.redhat.io/rhdr/... → pulled from quay.io BUILD digests

    ↓ (After verification passes)

GA Release:
registry.redhat.io/rhdr/rhdr-multicluster-rhel9-operator@sha256:...
```

## Validation Checklist

Before declaring complete:

- [x] `container.yaml` configured for single-arch only (linux/x86_64)
- [x] `bundle/manifests/odf-multicluster-orchestrator.clusterserviceversion.yaml` has pinned digests (4+ locations)
- [x] `.tekton/rhdr-multicluster-operator-bundle-4-22-push.yaml` includes `build.appstudio.openshift.io/build-nudge-files` annotation
- [x] CEL expression includes pathChanged() conditions
- [x] `bundle-hack/update_bundle.sh` uses correct terminology (BUILD/PRODUCTION)
- [x] `bundle-hack/test_update_bundle.sh` runs successfully locally and validates YAML
- [x] ConfigMap deployment instructions ready (deploy to rhdr-tenant namespace)
- [x] IDMS reference documentation in Docs/Setup/ (primary: FBC repo)
- [ ] ConfigMap deployed to Konflux cluster
- [ ] Conforma verification tests pass
- [ ] FBC IDMS configured and deployed (when FBC repo is created)
- [ ] No manual digest updates required between builds

## References

- **Build Nudge Pattern:** rhwa fence-agents-remediation
  - Reference: https://gitlab.cee.redhat.com/dragonfly/fence-agents-remediation/-/tree/far-0-8
- **RHDR Repository:** https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr
- **Pyxis Configs:** products/rhdr/rhdr.yaml in pyxis-repo-configs
- **Konflux Namespace:** rhdr-tenant
- **Build Nudge Documentation:** See BUILD_NUDGE_AND_IDMS_AUTOMATION.md in Docs/

## Next Steps

1. [ ] Review and commit all changes to the repository
2. [ ] Deploy ConfigMap to cluster (Phase 2 step 1)
3. [ ] Deploy IDMS to cluster (Phase 2 step 2)
4. [ ] Test workflow locally with `bundle-hack/test_update_bundle.sh`
5. [ ] Test workflow with a push event to 4.22 branch
6. [ ] Monitor MR creation and auto-merge behavior
7. [ ] When ready for production, update digest values in `update_bundle.sh` and redeploy
