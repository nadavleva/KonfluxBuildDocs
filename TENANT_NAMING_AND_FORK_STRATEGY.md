# Tenant Naming and Repository Forking Strategy

**Status:** ✅ APPROVED - RHDR Naming Convention Validated & Selected  
**Owner:** Andrew (Final decision approved), Nadav/Evan (Implementation)  
**Related Issue:** [OpenIssues.md#Issue 4](./OpenIssues.md#L204-L250) - Global Standalone Component Renaming & Multi-Repo Forking  
**JIRA Story:** https://redhat.atlassian.net/browse/VIRTDR-141  
**Date Created:** 2026-05-25  
**Date Approved:** 2026-05-25  
**Date Validated:** 2026-05-25 - Verified `rhdr` is not in use and is available

---

## Executive Summary

To completely decouple RamenDR Standalone from ODF's downstream infrastructure, we must:

1. **Choose a naming prefix** (suggested: `rhdr` for Red Hat Disaster Recovery)
2. **Fork all required ODF repositories** into the `rh-ocp-dr` GitLab group
3. **Configure Konflux tenant** to use the new forked repositories
4. **Update all internal references** to point to the new naming scheme

This document captures Andrew's fork/rename strategy with complete repository inventory and tenant configuration changes.

---

## Part 1: Naming Prefix Decision

### Current Options

| Prefix | Pros | Cons |
|--------|------|------|
| **`rhdr`** (Red Hat DR) | ✅ Clear brand identity; separates from ODF; distinct from `odr` | Shorter, may conflict |
| **`odr`** | ✅ Aligns with ODF downstream naming; established pattern | ❌ Implies ODF dependency |
| **`rdr`** (Ramen DR) | ✅ Product-focused; clean abbreviation | ❌ Less clear to external teams |
| **`ramen`** | ✅ Product name; easy to understand | ❌ Verbose in configs |

### ✅ **SELECTED: `rhdr`** (Red Hat Disaster Recovery)

- **Full form**: Red Hat Disaster Recovery
- **Acronym**: RHDR
- **Status**: ✅ **VALIDATED** - Confirmed as available and not currently in use
- **Validation Date**: 2026-05-25
- **Scope**: Operator/container names, repository names, namespace prefixes
- **Example**: `rhdr-hub-operator`, `rhdr-multicluster-operator`, `rh-ocp-dr/rhdr-*`

**Approval Status**: ✅ **APPROVED by Andrew (2026-05-25)**
**Validation Status**: ✅ **CONFIRMED - Name is free and available for use**

This naming convention completely decouples RamenDR from ODF and provides a clear, distinct brand identity for the Red Hat Disaster Recovery standalone product.

**Key Decision**: The `rhdr` prefix ensures complete independence from ODF's `odr` downstream naming, establishing RamenDR Standalone as a distinct product with its own brand identity.

---

## Part 2: Complete Repository Forking Checklist

All repositories should be forked to: `https://gitlab.cee.redhat.com/rh-ocp-dr/`

### A. Ramen Operators (EXISTING - No Fork Needed)

| Repository | Status | Notes |
|------------|--------|-------|
| `ramen` | ✅ Exists | Hub & Cluster operators from upstream |
| `ramen-console` | ✅ Exists | Console UI plugin (fork of odf-console) |

**Build components from existing repos:**
- Component: `rhdr-hub-operator` → Source: `rh-ocp-dr/ramen` + `hub.Dockerfile`
- Component: `rhdr-cluster-operator` → Source: `rh-ocp-dr/ramen` + `cluster.Dockerfile`
- Component: `rhdr-console-ui` → Source: `rh-ocp-dr/ramen-console` + `Dockerfile`

---

### B. ODF Multicluster Operator (FORK REQUIRED)

**Source (ODF):** `https://github.com/red-hat-storage/odf-operator`

**Target (RamenDR):**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-multicluster-operator
```

**Action:**
1. Fork from ODF GitHub repo
2. Rename all references: `odf-multicluster-operator` → `rhdr-multicluster-operator`
3. Update image names in Dockerfile: `quay.io/odf/...` → `quay.io/rh-ocp-dr/rhdr/...`
4. Create `.tekton/rhdr-multicluster-operator-on-push.yaml`

**Build Components:**
- Component: `rhdr-multicluster-operator`
  - Dockerfile: `Dockerfile`
  - Pipeline: `docker-build-multi-platform-oci-ta`
  - Output: `quay.io/rh-ocp-dr/rhdr/rhdr-multicluster-operator:TAG`
  - Build nudges: `[rhdr-multicluster-operator-bundle]`

---

### C. ODF Multicluster Operator Bundle (FORK REQUIRED)

**Source (ODF):** `https://github.com/red-hat-storage/odf-operator` (bundle/ subdirectory)

**Target (RamenDR):**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-multicluster-operator-bundle
```

**Action:**
1. Fork bundle configs from ODF repo
2. Update references to point to `rhdr-multicluster-operator` image
3. Create `.tekton/rhdr-multicluster-operator-bundle-on-push.yaml`

**Build Components:**
- Component: `rhdr-multicluster-operator-bundle`
  - Dockerfile: `bundle/Dockerfile`
  - Pipeline: `docker-build-oci-ta`
  - Output: `quay.io/rh-ocp-dr/rhdr/rhdr-multicluster-operator-bundle:TAG`
  - Build nudges: `[rhdr-fbc-catalog]`

---

### D. ODF CSI Addons Sidecar (FORK REQUIRED - If Needed)

**Source (ODF):** `https://github.com/red-hat-storage/odf-operator` (csi-addons-sidecar)

**Target (RamenDR):**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-csi-addons-sidecar
```

**Status:** ⏳ PENDING design review (see Issue 4, Task 3)

**Decision Required:**
> Does standalone VDR release profile require CSI addons sidecar?

**If YES:**
1. Fork CSI addons sidecar from ODF
2. Create dedicated `Dockerfile` for Konflux
3. Create `.tekton/rhdr-csi-addons-sidecar-on-push.yaml`
4. Add as component to application

**If NO:**
- Skip this repository and remove from forking checklist

---

### E. ODF CSI Addons Operator (FORK REQUIRED - If Needed)

**Source (ODF):** `https://github.com/red-hat-storage/odf-operator` (csi-addons)

**Target (RamenDR):**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-csi-addons-operator
```

**Status:** ⏳ PENDING design review (see Issue 4, Task 3)

**If required, mirror structure of multicluster operator:**
- Component: `rhdr-csi-addons-operator` (multi-platform)
- Component: `rhdr-csi-addons-operator-bundle` (single-platform)
- Nudge dependency to FBC catalog

---

### F. ODF CSI Addons Operator Bundle (FORK REQUIRED - If Needed)

**Source (ODF):** `https://github.com/red-hat-storage/odf-operator` (csi-addons bundle/)

**Target (RamenDR):**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-csi-addons-operator-bundle
```

**If required:** Follow same pattern as multicluster bundle

---

### G. RamenDR FBC Catalog (NEW REPOSITORY)

**Source:** None (new)

**Target:**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-fbc-catalog
```

**Purpose:** Filesystem-based OLM catalog aggregating all operator bundles

**Structure:**
```
rhdr-fbc-catalog/
├── Dockerfile                    # FBC image build
├── catalog/
│   ├── rhdr-hub-operator/        # Reference hub bundle
│   ├── rhdr-cluster-operator/    # Reference cluster bundle
│   ├── rhdr-multicluster-operator/  # Reference MCO bundle
│   └── ...                       # Additional bundles as needed
├── .tekton/
│   ├── rhdr-fbc-catalog-on-push.yaml
│   └── rhdr-fbc-catalog-on-pull-request.yaml
└── remote_source/
    ├── cachito.env
    └── app/
```

**Build Component:**
- Component: `rhdr-fbc-catalog`
  - Dockerfile: `Dockerfile`
  - Pipeline: `docker-build-oci-ta`
  - Output: `quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:TAG`
  - Build nudges from: All bundle components

---

### H. RamenDR Must-Gather (NEW REPOSITORY)

**Source:** None (new)

**Target:**
```
https://gitlab.cee.redhat.com/rh-ocp-dr/rhdr-must-gather
```

**Purpose:** Custom must-gather plugin for RamenDR diagnostics

**Build Component:**
- Component: `rhdr-must-gather`
  - Dockerfile: `Dockerfile`
  - Pipeline: `docker-build-multi-platform-oci-ta` (if multi-arch support needed)
  - Output: `quay.io/rh-ocp-dr/rhdr/rhdr-must-gather:TAG`

---

### I. Console Repository (DECISION PENDING)

**Current Status:** Forked as `rh-ocp-dr/ramen-console`

**Options:**

#### Option A: Rename Fork to `rhdr-console`
```
Source: rh-ocp-dr/ramen-console
Target: rh-ocp-dr/rhdr-console
Action: Git mv repository + update all references
```

#### Option B: Keep as `ramen-console` (Product-aligned)
```
Rationale: Emphasizes product identity over operator naming
Implication: Console stays "ramen" while operators become "rhdr"
```

#### Option C: Fork Both (odf-console and odf-multicluster-console)
```
rhdr-console: Full console UI with all plugins
rhdr-multicluster-console: MCO plugin only
```

**Recommendation:** Option A (Rename to `rhdr-console`)
- Consistent with operator naming scheme
- Clear that this is RamenDR-specific, not generic ODF console
- Avoid confusion with upstream odf-console

---

## Part 3: Complete Build Application Architecture

### Final Component Layout

```
Konflux Application: ramen-dr-standalone-0-1
Namespace: rh-ocp-dr-tenant
Prefix: rhdr (Red Hat Disaster Recovery)

├── OPERATOR COMPONENTS (Multi-Platform)
│
├─ rhdr-hub-operator
│  ├─ Repository: rh-ocp-dr/ramen
│  ├─ Dockerfile: hub.Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-hub-operator:TAG
│  └─ Build nudges: [rhdr-hub-operator-bundle]
│
├─ rhdr-cluster-operator
│  ├─ Repository: rh-ocp-dr/ramen
│  ├─ Dockerfile: cluster.Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-cluster-operator:TAG
│  └─ Build nudges: [rhdr-cluster-operator-bundle]
│
├─ rhdr-multicluster-operator
│  ├─ Repository: rh-ocp-dr/rhdr-multicluster-operator
│  ├─ Dockerfile: Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-multicluster-operator:TAG
│  └─ Build nudges: [rhdr-multicluster-operator-bundle]
│
├─ [CONDITIONAL] rhdr-csi-addons-operator
│  ├─ Repository: rh-ocp-dr/rhdr-csi-addons-operator
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-csi-addons-operator:TAG
│  └─ Build nudges: [rhdr-csi-addons-operator-bundle]
│
├─ [NEW] rhdr-console-ui
│  ├─ Repository: rh-ocp-dr/rhdr-console (or ramen-console)
│  ├─ Dockerfile: Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-console-ui:TAG
│  └─ (No nudges - terminal component)
│
├── BUNDLE COMPONENTS (Single-Platform)
│
├─ rhdr-hub-operator-bundle
│  ├─ Repository: rh-ocp-dr/ramen
│  ├─ Dockerfile: bundle/hub/Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-hub-operator-bundle:TAG
│  └─ Build nudges: [rhdr-fbc-catalog]
│
├─ rhdr-cluster-operator-bundle
│  ├─ Repository: rh-ocp-dr/ramen
│  ├─ Dockerfile: bundle/cluster/Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-cluster-operator-bundle:TAG
│  └─ Build nudges: [rhdr-fbc-catalog]
│
├─ rhdr-multicluster-operator-bundle
│  ├─ Repository: rh-ocp-dr/rhdr-multicluster-operator-bundle
│  ├─ Dockerfile: bundle/Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-multicluster-operator-bundle:TAG
│  └─ Build nudges: [rhdr-fbc-catalog]
│
├─ [CONDITIONAL] rhdr-csi-addons-operator-bundle
│  ├─ Repository: rh-ocp-dr/rhdr-csi-addons-operator-bundle
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-csi-addons-operator-bundle:TAG
│  └─ Build nudges: [rhdr-fbc-catalog]
│
├── CATALOG & UTILITIES
│
├─ rhdr-fbc-catalog
│  ├─ Repository: rh-ocp-dr/rhdr-fbc-catalog (NEW)
│  ├─ Dockerfile: Dockerfile
│  ├─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-fbc-catalog:TAG
│  └─ Build nudges from: All bundle components
│
└─ rhdr-must-gather
   ├─ Repository: rh-ocp-dr/rhdr-must-gather (NEW)
   ├─ Dockerfile: Dockerfile
   └─ Output: quay.io/rh-ocp-dr/rhdr/rhdr-must-gather:TAG
```

---

## Part 4: Tenant Configuration Changes

Once repositories are forked and renamed, update the Konflux tenant configuration:

### 4.1 Update Application Metadata

**File location:** `rh-ocp-dr-tenant` namespace, Konflux UI

**Changes:**
```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: Application
metadata:
  name: ramen-dr-standalone-0-1  # Or rhdr-0-1 if renaming app too
  namespace: rh-ocp-dr-tenant
  labels:
    app.kubernetes.io/name: rhdr  # Updated label
spec:
  displayName: "RamenDR Standalone - rhdr"
  description: "Red Hat Disaster Recovery - Hub, Cluster, and Console components"
```

### 4.2 Update Component Repository URLs

**Example - Hub Operator Component:**

```bash
kubectl patch component rhdr-hub-operator \
  -n rh-ocp-dr-tenant \
  --type merge \
  -p '{"spec": {"source": {"git": {"url": "https://gitlab.cee.redhat.com/rh-ocp-dr/ramen"}}}}'
```

### 4.3 Update Image Output Registry Paths

**For all components:**

Pattern change:
```
OLD: quay.io/rh-ocp-dr/<operator-name>:TAG
NEW: quay.io/rh-ocp-dr/rhdr/<operator-name>:TAG
```

**Example - Hub Operator Component:**

```bash
kubectl patch component rhdr-hub-operator \
  -n rh-ocp-dr-tenant \
  --type merge \
  -p '{"spec": {"containerImage": "quay.io/rh-ocp-dr/rhdr/rhdr-hub-operator:latest"}}'
```

### 4.4 Update Tekton Pipeline References

**For components using forked repositories** (multicluster, csi-addons, fbc, must-gather):

Update the `.tekton/` directory references in each repository to match new pipeline naming:

```
OLD: .tekton/odf-multicluster-operator-on-push.yaml
NEW: .tekton/rhdr-multicluster-operator-on-push.yaml
```

---

## Part 5: Implementation Sequence

### Phase 1: Foundation (Week 1)
- [x] ✅ Get final naming approval from Andrew (rhdr vs alternatives) - **COMPLETED 2026-05-25**
- [x] ✅ Document naming decision in this file - **COMPLETED 2026-05-25**
- [x] ✅ Validate RHDR is available and not in use - **COMPLETED 2026-05-25**
- [ ] Create stub repositories in `rh-ocp-dr` GitLab group:
  - `rhdr-multicluster-operator`
  - `rhdr-multicluster-operator-bundle`
  - `rhdr-csi-addons-operator` (if approved)
  - `rhdr-csi-addons-operator-bundle` (if approved)
  - `rhdr-fbc-catalog`
  - `rhdr-must-gather`

### Phase 2: Repository Forking & Cloning (Week 1-2)
- [ ] Fork ODF repositories to rh-ocp-dr group
- [ ] Clone existing ramen + ramen-console to rh-ocp-dr if not already there
- [ ] Verify all source code is accessible in target location

### Phase 3: Rename All References (Week 2)
- [ ] Update Dockerfiles: Image names, registry paths
- [ ] Rename Tekton pipeline files in `.tekton/` directories
- [ ] Update Konflux component names
- [ ] Update bundle references in FBC catalog

### Phase 4: Tenant Configuration (Week 2-3)
- [ ] Update Application metadata in Konflux
- [ ] Patch all Component resources with new URLs and image paths
- [ ] Verify build-nudges-ref dependencies are correct
- [ ] Test individual component builds

### Phase 5: Integration & Validation (Week 3)
- [ ] Trigger full multi-component build
- [ ] Verify snapshot is created with all components
- [ ] Validate FBC catalog generation
- [ ] Test OLM installation from generated catalog

---

## Part 6: CSI Addons Design Review

**To be determined in parallel with Phase 1:**

### Questions to Answer:

1. **Scope**: Does standalone VDR release include CSI replication sidecars?
   - If YES → Include csi-addons operator + bundle
   - If NO → Remove from forking checklist

2. **Implementation**: If included, how to handle CSI addons build?
   - Option A: Multi-Dockerfile approach (like ramen operators)
   - Option B: New repository (like multicluster operator)
   - Option C: Handled via operator (not standalone component)

3. **Dependency**: Does FBC catalog reference CSI addons bundle?
   - Include in `catalog/` directory structure
   - Update catalog index generation

**Action Item:** Schedule design review with storage team before Phase 2 begins.

---

## Part 7: Appendix - Naming Reference

### All References to Update

**Global search/replace patterns:**

| OLD Pattern | NEW Pattern | Where |
|------------|-----------|-------|
| `odf-multicluster-operator` | `rhdr-multicluster-operator` | Image names, component names, registry paths |
| `odf-csi-addons-sidecar` | `rhdr-csi-addons-sidecar` | (If approved) |
| `odf-csi-addons-operator` | `rhdr-csi-addons-operator` | (If approved) |
| `quay.io/odf/` | `quay.io/rh-ocp-dr/rhdr/` | All Dockerfile registry pulls |
| `quay.io/rh-ocp-dr/<name>` | `quay.io/rh-ocp-dr/rhdr/<name>` | All image outputs |
| `odf` (in labels) | `rhdr` | Kubernetes labels |
| `ODF` (in comments) | `RamenDR` or `RHDR` | Documentation, comments |

### Repository Structure Template

All new repositories should follow this structure:

```
gitlab.cee.redhat.com/rh-ocp-dr/rhdr-<component>/
├── Dockerfile (or <component>.Dockerfile for multi-Dockerfile repos)
├── bundle/
│   └── Dockerfile
├── .tekton/
│   ├── rhdr-<component>-on-push.yaml
│   └── rhdr-<component>-on-pull-request.yaml
├── remote_source/
│   ├── cachito.env
│   └── app/
├── README.md
└── [source code]
```

---

## Related Documentation

- [Issue 4: Global Standalone Component Renaming & Multi-Repo Forking](./OpenIssues.md#L204-L250)
- [MULTI_COMPONENT_STRATEGY.md](./MULTI_COMPONENT_STRATEGY.md) - Component design rationale
- [RAMEN_PROJECT_TEMPLATE.md](./RAMEN_PROJECT_TEMPLATE.md) - ProjectDevelopmentStreamTemplate details
- [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md) - Phase-by-phase implementation guide
- [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md) - Step-by-step kubectl commands

---

## Sign-Off

| Role | Name | Approval Status |
|------|------|-----------------|
| Product Owner | Andrew | ✅ APPROVED (2026-05-25) |
| Technical Lead | Nadav | ✅ Documentation Complete (2026-05-25) |
| Implementation | Evan | ⏳ Awaiting Implementation Kickoff |

**Status Summary:**
- [x] ✅ Final naming decision received: **RHDR (Red Hat Disaster Recovery)**
- [x] ✅ Naming validated as available and free to use
- [x] ✅ Strategy document created and linked to OpenIssues#4
- [x] ✅ JIRA comment added to VIRTDR-141 with strategy overview
- [ ] ⏳ CSI addons scope determination (pending design review)
- [ ] ⏳ Ready to begin Phase 1 forking (after this approval, proceeding to repo creation)

**Documentation Status**: ✅ COMPLETE  
**JIRA Integration**: ✅ COMPLETE (comment posted to VIRTDR-141)  
**Next Action**: Create stub repositories in rh-ocp-dr GitLab group
