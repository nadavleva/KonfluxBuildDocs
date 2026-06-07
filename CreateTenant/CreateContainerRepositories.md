# Creating Container Repositories for RHDR Release

**Document version:** 1.0  
**Date:** 2026-06-07  
**Product:** Red Hat Disaster Recovery (RHDR)  
**Related documents:** 
- [RHDRReleasePlanAdmissionRequirements.md](./RHDRReleasePlanAdmissionRequirements.md)
- [Pyxis Repo Configs README](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs/-/blob/main/README.md)

---

## Overview

Container repositories must be created in **both the production and staging Red Hat registries** before RHDR can release managed container images:
- **Production:** `registry.redhat.io/rhdr/<image>`
- **Staging:** `registry.stage.redhat.io/rhdr/<image>`

These repositories are separate from the build-time Quay repositories where Konflux stores images during CI/CD.

### Two-Phase Release Flow

```
┌─────────────────────────────────────────────────────┐
│ Build Phase (Konflux / Quay)                       │
│ • Konflux builds images                             │
│ • Images stored in: quay.io/redhat-services-prod/  │
│ • Used by: Integration tests, development           │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│ Release Phase (Managed Release Service)            │
│ • Release service copies images from Quay           │
│ • Pushes to Red Hat registries (requires repos)    │
│ • Targets: registry.stage.redhat.io/ or            │
│            registry.redhat.io/                      │
└─────────────────────────────────────────────────────┘
```

**Key point:** Build and release use different registries. Repository creation only affects the **release phase** (Step 1 below).

---

## Step 1: Create Delivery Repositories in Pyxis

Container repositories must be registered in Pyxis, Red Hat's container catalog backend, before the release service can push to the Red Hat registries.

### Pre-MR Checklist: Open Questions to Resolve

Before creating the Pyxis YAML configuration, resolve these items with your team:

| Question | Status | Details | Action |
|----------|--------|---------|--------|
| **Contact Email Address** | ❓ Open | Should we use `team-firefly@redhat.com` as the team contact? | Confirm team email with team lead |
| **Product Doc Owner** | ❓ Open | Who is the Product Documentation Owner? (Individual name or team DL?) | Assign or use team DL |
| **Image Owner** | ❓ Open | Who is the Image Owner responsible for container quality? (Individual name or team DL?) | Assign or use team DL |
| **Product Manager** | ❓ Open | Who is the Product Manager for RHDR? (Individual name or team DL?) | Assign or use team DL |
| **Documentation Link** | ❓ Open | What is the official RHDR documentation URL? | Provide URL (e.g., `https://docs.redhat.com/...`) |
| **Team ID** | ❓ Open | What is the official team_id from PMM/product database? | Contact PMM; use placeholder if unavailable |

**Note:** For tech-preview product, it's acceptable to use team distribution list (DL) for all contact types. You can update with individual names in follow-up MRs once roles are assigned.

**Temporary Workaround (if needed):**
If any of these are not yet determined, you can:
- Use `team-firefly@redhat.com` for all contacts in MR 1
- Use placeholder `team_id: "00000000-0000-0000-0000-000000000000"` with TODO comment
- Use generic documentation URL or placeholder
- Submit MR 1 with these placeholders; update in MR 2 once confirmed

---

### Prerequisites

- **GitLab access:** Developer membership in [releng/pyxis-repo-configs](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs) repository
  - If you don't have access, request it in [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ) and mention `@cicada-support`
  - Message example: "Could you grant me `Developer` role in Pyxis Repo Configs repository?"

- **GitLab repository:** Must push to **main branch** of `git@gitlab.cee.redhat.com:releng/pyxis-repo-configs`
  - Do NOT use a fork; push your branch directly to the origin repository
  - MR target: `main` branch (default branch of the repository)
  - All changes merge to `main` before Cicada automation executes

### Procedure

#### 1a. Create Product Directory

In your local clone of `pyxis-repo-configs`, create the directory structure:

```bash
mkdir -p products/rhdr
```

#### 1b. Author the Product Definition YAML

Create `products/rhdr/rhdr.yaml` following the template below. This file defines all container repositories for RHDR release.

**⚠️ Important:** See [Required vs Optional Fields](#required-vs-optional-fields) section below. For your **first MR, include mandatory fields only**. Add optional fields in follow-up MRs per the LLM advisory and tech-preview guidance.

**Before you start:** Review the [Pre-MR Checklist: Open Questions to Resolve](#pre-mr-checklist-open-questions-to-resolve) section above. You'll need to fill in:
- Team contact email: `team-firefly@redhat.com` or another email?
- Product documentation URL
- Team ID (from PMM; can use placeholder with TODO if not available yet)
- Contact roles: Product Manager, Image Owner, Doc Owner names (can use team DL for all)

**Template for tech-preview product (RHDR) — Mandatory Fields Only (MR 1 - 10 Repositories):**

```yaml
# Red Hat Disaster Recovery (RHDR) Product Repositories
# Tech Preview Product Definition - MR 1 (Core + Architecture Foundation)

.contacts: &team_contacts
  - email_address: "team-firefly@redhat.com"  # TODO: Verify team email (open question #1)
    type: "Doc Owner"  # TODO: Assign specific person or confirm team DL
  - email_address: "team-firefly@redhat.com"  # TODO: Verify team email
    type: "Image Owner"  # TODO: Assign specific person or confirm team DL (open question #2)
  - email_address: "team-firefly@redhat.com"  # TODO: Verify team email
    type: "Product Manager"  # TODO: Assign specific person or confirm team DL (open question #3)

.release_tags: &release_tags
  - "v4.22"

.documentation: &documentation_links
  - title: "Red Hat Disaster Recovery"
    type: "Documentation"
    url: "https://docs.redhat.com/en/documentation/red_hat_disaster_recovery"  # TODO: Verify documentation URL (open question #4)

.repo_template: &repo_template
  release_categories:
    - "Tech Preview"
  includes_multiple_content_streams: false
  content_stream_tags:
    *release_tags
  team_id: "00000000-0000-0000-0000-000000000000"  # TODO: Replace with actual team_id from PMM (open question #5)
  vendor_label: "redhat"
  application_categories:
    - "Disaster Recovery"
    - "High Availability"
  privileged_images_allowed: false
  documentation_links:
    *documentation_links
  contacts:
    *team_contacts
  use_latest: false
  requires_terms: true

repositories:
  # Layer 1: Core Hub & Cluster Operators
  - image_type: "Operator Controller"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-hub-operator"
      build_categories:
        - "Operator"
      display_data:
        name: "Red Hat Disaster Recovery Hub Operator"

  - image_type: "Operator Bundle Image"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-hub-operator-bundle"
      build_categories:
        - "Operator"
      display_data:
        name: "Red Hat Disaster Recovery Hub Operator Bundle"

  - image_type: "Operator Controller"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-cluster-operator"
      build_categories:
        - "Operator"
      display_data:
        name: "Red Hat Disaster Recovery Cluster Operator"

  - image_type: "Operator Bundle Image"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-cluster-operator-bundle"
      build_categories:
        - "Operator"
      display_data:
        name: "Red Hat Disaster Recovery Cluster Operator Bundle"

  # Layer 2: Multicluster Coordination
  - image_type: "Operator Controller"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-multicluster-operator"
      build_categories:
        - "Operator"
      display_data:
        name: "RHDR Multicluster Operator"

  - image_type: "Operator Bundle Image"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-multicluster-operator-bundle"
      build_categories:
        - "Operator"
      display_data:
        name: "RHDR Multicluster Operator Bundle"

  # Layer 3: CSI Addons for Snapshot/Restore
  - image_type: "Operator Controller"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-csi-addons-operator"
      build_categories:
        - "Operator"
      display_data:
        name: "RHDR CSI Addons Operator"

  - image_type: "Operator Bundle Image"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-csi-addons-operator-bundle"
      build_categories:
        - "Operator"
      display_data:
        name: "RHDR CSI Addons Operator Bundle"

  # Layer 4: Volsync Plugin
  - image_type: "Operator Controller"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-volsync-plugin-operator"
      build_categories:
        - "Operator"
      display_data:
        name: "RHDR Volsync Plugin Operator"

  - image_type: "Operator Bundle Image"
    base_rhel_version: "rhel9"
    repository:
      <<: *repo_template
      repository: "rhdr/rhdr-volsync-plugin-operator-bundle"
      build_categories:
        - "Operator"
      display_data:
        name: "RHDR Volsync Plugin Operator Bundle"

  # Additional repositories added in MR 2 (Layer 5: Component Images)
  # Additional repositories added in MR 3 (Layer 6: FBC)
```

**Notes:**
- This template shows all 10 repositories for MR 1 (4 core + 6 architecture-essential)
- MR 2 will add Layer 5 (4 component/support images): console, mover, sidecar, must-gather
- MR 3 will add Layer 6 (1 FBC): rhdr-fbc
- All mandatory fields are included; optional fields will be added in MR 2
- **TODO items in template:** Replace placeholders before submitting MR. See [Pre-MR Checklist](#pre-mr-checklist-open-questions-to-resolve) above.

#### Handling Open Questions During MR 1

If any of the [open questions](#pre-mr-checklist-open-questions-to-resolve) are not yet resolved, you have two options:

**Option A: Use Placeholders (Recommended for Tech-Preview)**

Submit MR 1 with placeholders and TODO comments. Then add to MR description:

```markdown
## Open Questions - To Be Resolved

- [ ] **Team Contact Email:** Confirm `team-firefly@redhat.com` is correct
- [ ] **Product Doc Owner:** Assign individual or confirm team DL
- [ ] **Image Owner:** Assign individual or confirm team DL
- [ ] **Product Manager:** Assign individual or confirm team DL
- [ ] **Documentation Link:** Update from placeholder URL to actual RHDR docs
- [ ] **Team ID:** Update from placeholder to actual team_id from PMM

These will be resolved in MR 2 or by comment reply.
```

This allows:
- MR 1 to merge and create repositories immediately
- Blocking reviews on schema validation only, not on team assignments
- Follow-up MR 2 to update contact details once determined

**Option B: Wait for Full Information**

If you prefer to have all details before submitting, collect:
- Team contact email confirmation (team lead)
- Specific individuals for Product Manager, Doc Owner, Image Owner roles
- Official `team_id` from PMM/product database
- Official RHDR documentation URL

**Recommendation:** Use Option A for tech-preview. It's faster and aligns with tech-preview methodology of iterating in follow-up MRs.

---

### Required vs Optional Fields

Based on the Pyxis schema and LLM advisory guidance for tech-preview products, here are the fields you **must** include vs. fields you **can add later**:

#### Mandatory Fields (Must Include in First MR)

These fields are **required** by the Pyxis schema and Cicada validation. Your MR will fail without them.

| Field | Level | Description | RHDR Example |
|-------|-------|-------------|-----------------|
| `image_type` | Repository | Type of container image | `"Operator Controller"` |
| `base_rhel_version` | Repository | Base RHEL version | `"rhel9"` |
| `repository` | Repository | Registry path | `"rhdr/rhdr-hub-operator"` |
| `release_categories` | Template | Product status | `["Tech Preview"]` |
| `team_id` | Template | PMM product ID | From your product manager |
| `vendor_label` | Template | Vendor identifier | `"redhat"` |
| `contacts` | Template | At least one contact | Use team DL for tech-preview |
| `contacts[].email_address` | Contact | Email address | `"rhdr-team@redhat.com"` |
| `contacts[].type` | Contact | Role type | `"Image Owner"` or `"Doc Owner"` |
| `display_data` | Repository | Display metadata | Required |
| `display_data.name` | Display | Image display name | `"RHDR Hub Operator"` |
| `build_categories` | Repository | Build type | `["Operator"]` |

#### Optional Fields (Add in Follow-Up MRs)

These fields enhance metadata but are **not required** for initial MR. Per LLM advisory: start minimal, iterate.

| Field | Level | Description | Timing |
|-------|-------|-------------|--------|
| `includes_multiple_content_streams` | Template | Multiple version streams? | MR 2+: After MR 1 merges |
| `content_stream_tags` | Template | Supported versions | MR 2+: As versions defined |
| `application_categories` | Template | Business categorization | MR 2+: When positioning clear |
| `privileged_images_allowed` | Template | Run privileged? | MR 2+: When ready |
| `documentation_links` | Template | Documentation URLs | MR 2+: As docs available |
| `use_latest` | Template | Track latest tag? | MR 2+: When ready |
| `requires_terms` | Template | Subscription required? | MR 2+: When ready |
| `display_data.short_description` | Display | Brief description | MR 2+: Optional |
| `display_data.long_description` | Display | Detailed description | MR 2+: Optional |
| `fbc_opt_in` | Repository | Enable FBC | Only if using FBC |

#### Tech-Preview Contacts (Mandatory but Minimal)

The **contacts** field is mandatory but can be minimal:

```yaml
contacts:
  - email_address: "rhdr-team@redhat.com"
    type: "Image Owner"
```

**LLM advisory guidance:**
- Don't need all roles assigned upfront
- Team DL for tech-preview is acceptable and normal
- Add specific individuals (Product Manager, QE Owner, Errata Writer) in follow-up MRs
- Each MR is independent; no blocking on incomplete team structure

### Key Fields Explained

| Field | Description | RHDR Value |
|-------|-------------|-----------|
| `image_type` | Container image type | `"Operator Controller"`, `"Operator Bundle Image"`, or `"Layered"` |
| `base_rhel_version` | Base RHEL version | `"rhel9"` (current standard) |
| `release_categories` | Product status | `["Tech Preview"]` for RHDR (not yet GA) |
| `team_id` | PMM team identifier | Request from PMM or your product manager |
| `repository` | Registry path after `registry.redhat.io/` | e.g., `"rhdr/rhdr-hub-operator"` → `registry.redhat.io/rhdr/rhdr-hub-operator` |
| `contacts` | Team roles | Use team DL email for tech-preview; update roles as team grows |
| `application_categories` | Business domains | e.g., `["Disaster Recovery", "High Availability"]` |

### Tech-Preview Considerations

For RHDR as a tech-preview product:

- **`release_categories`:** Use `["Tech Preview"]` instead of `["Generally Available"]`
- **`contacts`:** It's normal and acceptable to:
  - Use a team distribution list (DL) for multiple contact types
  - Have fewer distinct people than a GA product
  - Update contact details in follow-up MRs once roles are assigned
- **Repository count:** Start with core repositories; add more via future MRs
- **Documentation links:** Can be simplified or marked as "In Progress" initially

**Example tech-preview contacts block:**

```yaml
.contacts: &team_contacts
  - email_address: "rhdr-team@redhat.com"  # Team DL for flexibility
    type: "Doc Owner"
  - email_address: "rhdr-team@redhat.com"
    type: "Image Owner"
  - email_address: "rhdr-team@redhat.com"
    type: "Product Manager"
```

#### 1c. Update CODEOWNERS

Add an entry to the `CODEOWNERS` file in the root of `pyxis-repo-configs`:

```text
# Red Hat Disaster Recovery
/products/rhdr/ @pyxis-repo-configs-guards @YOUR_GITLAB_USERNAME
```

**Important:** `@pyxis-repo-configs-guards` must be listed first. For team approval, add your team members' GitLab usernames.

#### 1d. Submit Merge Request

1. **Ensure you're on the main branch** (not a fork):
   ```bash
   cd pyxis-repo-configs
   git remote -v  # Verify origin is git@gitlab.cee.redhat.com:releng/pyxis-repo-configs
   git checkout main
   git pull origin main
   ```

2. Create and checkout a feature branch:
   ```bash
   git checkout -b add-rhdr-repos
   ```

3. Commit your changes:
   ```bash
   git add products/rhdr/rhdr.yaml CODEOWNERS
   git commit -m "Add RHDR product repository definitions"
   ```

4. Push to the **main repository** (not a fork):
   ```bash
   git push origin add-rhdr-repos
   ```
   **Note:** Do NOT push to a personal fork; the MR must target the origin `main` branch

5. Create a Merge Request (MR) on [GitLab](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs):
   - **Title:** "Add RHDR container repositories"
   - **Description:**
     ```markdown
     ## Summary
     Creates container repository definitions for Red Hat Disaster Recovery (RHDR) tech-preview product.

     ## Repositories
     - rhdr/rhdr-hub-operator
     - rhdr/rhdr-cluster-operator

     ## Next Steps
     - Staging environment will sync once daily
     - Once merged, RPA can reference these repositories
     - Team contacts will be updated in follow-up MR
     ```

4. Request review from Release Engineering (mentioned in CODEOWNERS)

### Deployment Timeline

| Stage | Timeline | Status |
|-------|----------|--------|
| **Production (registry.redhat.io)** | Upon MR merge | Repositories created immediately in production Pyxis |
| **Staging (registry.stage.redhat.io)** | ~24 hours after production | Auto-synced once daily from production Pyxis |

**Important:** Both environments are created, but staging syncs with a ~24-hour delay. Repositories exist in both registries:
- Use `registry.redhat.io` for production RPA releases
- Use `registry.stage.redhat.io` for staging RPA releases and testing

If testing release pipelines, you may need to wait ~24 hours after MR merge for repositories to appear in staging registry.

### Example: RHODF Reference

For a complete example, see the [RHODF product definition](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs/-/blob/main/products/rhodf/rhodf.yaml):
- 15+ repository entries
- Multiple operator bundle images
- Full team contact structure
- GA product (release_categories: ["Generally Available"])

**Direct GitLab link:**
```
https://gitlab.cee.redhat.com/releng/pyxis-repo-configs/-/blob/main/products/rhodf/rhodf.yaml
```

#### RHODF Repository Mapping to RHDR

Below is the complete reference showing RHODF repositories and RHDR equivalents, organized by inclusion strategy:

**Core DR Operators (Include in MR 1 - Mandatory):**

| RHODF Repository | Image Type | RHDR Equivalent | Include in MR 1? | Notes |
|------------------|-----------|-----------------|------------------|-------|
| `odf4/odr-hub-operator-bundle` | Operator Bundle | `rhdr/rhdr-hub-operator-bundle` | ✓ Yes | Core hub operator |
| `odf4/odr-cluster-operator-bundle` | Operator Bundle | `rhdr/rhdr-cluster-operator-bundle` | ✓ Yes | Core cluster operator |
| `odf4/odr-rhel9-operator` | Operator Controller | `rhdr/rhdr-hub-operator` | ✓ Yes | Hub operator controller |
| `odf4/odr-cluster-rhel9-operator` | Operator Controller | `rhdr/rhdr-cluster-operator` | ✓ Yes | Cluster operator controller |

**Extended Operators (Include in MR 1 or MR 2 - Architecture-Required):**

| RHODF Repository | Image Type | RHDR Equivalent | Include in MR 1? | Notes |
|------------------|-----------|-----------------|------------------|-------|
| `odf4/odr-volsync-plugin-operator-bundle` | Operator Bundle | `rhdr/rhdr-volsync-plugin-operator-bundle` | ✓ Yes | Volsync plugin for snapshots |
| `odf4/odr-volsync-plugin-rhel9-operator` | Operator Controller | `rhdr/rhdr-volsync-plugin-operator` | ✓ Yes | Volsync plugin controller |
| `odf-multicluster-operator-bundle` | Operator Bundle | `rhdr/rhdr-multicluster-operator-bundle` | ✓ Yes | Multicluster coordination |
| `odf-multicluster-rhel9-operator` | Operator Controller | `rhdr/rhdr-multicluster-operator` | ✓ Yes | Multicluster controller |
| `odf-csi-addons-operator-bundle` | Operator Bundle | `rhdr/rhdr-csi-addons-operator-bundle` | ✓ Yes | CSI addons for snapshots |
| `odf-csi-addons-rhel9-operator` | Operator Controller | `rhdr/rhdr-csi-addons-operator` | ✓ Yes | CSI addons controller |

**Support/Component Images (Include in MR 1 or MR 2):**

| RHODF Repository | Image Type | RHDR Equivalent | Include in MR 1? | Notes |
|------------------|-----------|-----------------|------------------|-------|
| `odf4/odr-volsync-plugin-mover-rhel9` | Layered | `rhdr/rhdr-volsync-plugin-mover` | ✓ Yes | Volsync mover base image |
| `odf-csi-addons-sidecar-rhel9` | Layered | `rhdr/rhdr-csi-addons-sidecar` | ✓ Yes | CSI addons sidecar for snapshots |
| `odf-console` | Layered/UI | `rhdr/rhdr-console` | ✓ Maybe | Console for RHDR management UI |
| (or) `odf-multicluster-console` | Layered/UI | `rhdr/rhdr-multicluster-console` | ✓ Maybe | Multicluster console UI |
| — | Layered | `rhdr/rhdr-must-gather` | ✓ Yes | Diagnostic must-gather image (new) |

**FBC/Catalog (Include in MR 2):**

| RHODF Repository | Image Type | RHDR Equivalent | Include in MR 1? | Notes |
|------------------|-----------|-----------------|------------------|-------|
| `rhodf-fbc` | FBC (File-Based Catalog) | `rhdr-fbc` | ✗ No (MR 2) | Operator catalog; not needed for MR 1 |

**NOT Needed (ODF-Specific, Don't Include):**

| RHODF Repository | Image Type | RHDR Equivalent | Include? | Notes |
|------------------|-----------|-----------------|----------|-------|
| `cephcsi-*` (all) | Operator/Layered | — | ✗ No | **RHDR doesn't use CephCSI** |
| `mcg-*` (all) | Operator/Layered | — | ✗ No | MCG not needed for RHDR |
| `ocs-*` (all) | Operator/Layered | — | ✗ No | OCS specific to ODF |
| `odf-*` (most others) | Operator/Layered | — | ✗ No | ODF infrastructure; RHDR independent |

**Key Differences:**
- **RHDR doesn't include CephCSI:** RHDR is disaster recovery (works WITH storage); RHODF provides storage
- **Multicluster required:** `odr-multicluster-operator` is essential for RHDR federation
- **CSI Addons required:** `odr-csi-addons-operator` enables snapshot/restore operations
- **Console UI:** Include `rhdr-console` or `rhdr-multicluster-console` for management UI
- **Must-gather:** New image for diagnostic support collections
- RHODF depends heavily on CephCSI for storage operations
- **RHDR (tech-preview) does NOT use CephCSI**; it's a disaster recovery solution that works with existing storage
- Remove all `cephcsi*` repositories from your RHDR definition
- Focus on DR-specific operators and their supporting images

---

### Layered Images in RHODF (and RHDR)

**What are Layered Images?**

Layered images are base container images that include runtime dependencies and libraries for operators. Unlike Operator Bundle Images (which are metadata) or Operator Controller images (which are the operators themselves), Layered images are **component/support images** that operators may reference or depend on.

**RHODF Layered Image Categories:**

| Purpose | RHODF Examples | RHDR Needed? |
|---------|---|---|
| **Volsync Integration** | `odf4/odr-volsync-plugin-mover-rhel9` | ✓ Yes |
| **Storage Drivers** | `odf4/cephcsi-rhel9`, `odf4/rook-ceph-rhel9`, `odf4/ocs-rhel9` | ✗ No (RHDR independent) |
| **Database Support** | `odf4/odf-cloudnative-pg-rhel9`, `odf4/postgresql-*` | ✗ No (tech-preview) |
| **Monitoring** | `odf4/prometheus-rhel9`, `odf4/alertmanager-*` | ✗ No (tech-preview) |
| **Other ODF Support** | `odf4/mcg-rhel9`, `odf4/odf-multicluster-*`, etc. | ✗ No (RHDR independent) |

**RHDR Layered Images (Minimum for Tech-Preview):**

For MR 1, RHDR likely needs **0-1 layered images**:
- **Optional:** `rhdr/rhdr-volsync-plugin-mover` (if Volsync integration is used)
- Most operator controller images may not need separate layered images initially

**Why no CephCSI-related images?**

RHDR is designed to work **with** existing storage systems, not to provide storage. It doesn't manage CephCSI or manage Ceph clusters. This is a fundamental architectural difference from ODF/RHODF.

**When to add Layered Images:**

- **MR 1 (tech-preview):** Focus on operators only; add layered images only if operators explicitly depend on them
- **MR 2:** Add layered images as you identify runtime dependencies
- **MR 3 (GA):** Add complete support images once full feature set is defined

**Recommendation for RHDR MR 1:**
Start with **no layered images**. Add them in MR 2 once you know which operators need external dependencies.

**Key differences for RHDR:**
- **Namespace:** RHDR repositories use `rhdr/` prefix instead of `odf4/`
- **Repository location:** GitLab repos for RHDR are at [https://gitlab.cee.redhat.com/rh-ocp-dr](https://gitlab.cee.redhat.com/rh-ocp-dr) (not under releng/)
- **Pyxis config location:** Configuration still goes in `releng/pyxis-repo-configs` (shared across all products)
- **Core operators:** RHDR will have fewer operators initially (tech-preview); focus on:
  - `rhdr-hub-operator`
  - `rhdr-cluster-operator`
  - `rhdr-recipe-operator` (if applicable)

**RHDR MR 1 minimum recommendation (Core + Essential):**

Start with these repositories in MR 1 (mandatory fields only):

**Must-Include Core Operators (4 repos):**
- `rhdr/rhdr-hub-operator` (Operator Controller)
- `rhdr/rhdr-cluster-operator` (Operator Controller)
- `rhdr/rhdr-hub-operator-bundle` (Operator Bundle)
- `rhdr/rhdr-cluster-operator-bundle` (Operator Bundle)

**Should-Include Architecture-Essential (6 repos):**
- `rhdr/rhdr-multicluster-operator` (Operator Controller) - Multicluster coordination
- `rhdr/rhdr-multicluster-operator-bundle` (Operator Bundle)
- `rhdr/rhdr-csi-addons-operator` (Operator Controller) - Snapshot/restore capability
- `rhdr/rhdr-csi-addons-operator-bundle` (Operator Bundle)
- `rhdr/rhdr-volsync-plugin-operator` (Operator Controller) - Volsync integration
- `rhdr/rhdr-volsync-plugin-operator-bundle` (Operator Bundle)

**Optional for MR 1 (Add in MR 2 if uncertain):**
- `rhdr/rhdr-console` or `rhdr/rhdr-multicluster-console` (UI console)
- `rhdr/rhdr-volsync-plugin-mover` (Layered - Volsync mover)
- `rhdr/rhdr-csi-addons-sidecar` (Layered - CSI addons sidecar)
- `rhdr/rhdr-must-gather` (Layered - Diagnostic image)

**FBC (Catalog) - Include in MR 2:**
- `rhdr-fbc` - File-based operator catalog (not needed until after initial operators work)

**Total for MR 1:** 10 core repositories (4 minimum + 6 architecture-essential)

---

### Complete Repository Set for RHDR

Per the RHDR architecture requirements, the following complete set of repositories is needed for a functional RHDR release. This includes repositories forked/renamed from RHODF:

#### Architecture Layers

**Layer 1: Core Hub & Cluster Operators (Mandatory)**

These operators form the foundation of RHDR:

```
rhdr/rhdr-hub-operator
rhdr/rhdr-hub-operator-bundle
rhdr/rhdr-cluster-operator
rhdr/rhdr-cluster-operator-bundle
```

**Layer 2: Multicluster Coordination (Required for Federation)**

RHDR's disaster recovery requires multicluster management (forked from ODF):

```
rhdr/rhdr-multicluster-operator          (renamed from odf-multicluster-operator)
rhdr/rhdr-multicluster-operator-bundle   (renamed from odf-multicluster-operator-bundle)
```

**Layer 3: CSI Addons for Snapshot/Restore (Required for DR Operations)**

CSI Addons enable snapshot and restore operations across storage backends (forked from ODF):

```
rhdr/rhdr-csi-addons-operator            (renamed from odf-csi-addons-operator)
rhdr/rhdr-csi-addons-operator-bundle     (renamed from odf-csi-addons-operator-bundle)
```

**Layer 4: Volsync Plugin for Continuous Data Protection (Recommended)**

Volsync provides continuous asynchronous data replication (already odr-prefixed in RHODF):

```
rhdr/rhdr-volsync-plugin-operator
rhdr/rhdr-volsync-plugin-operator-bundle
```

**Layer 5: Component/Support Images (Layered)**

Runtime dependencies and component images:

```
rhdr/rhdr-console (or rhdr/rhdr-multicluster-console)  (renamed from odf-console)
rhdr/rhdr-volsync-plugin-mover                        (Volsync mover base image)
rhdr/rhdr-csi-addons-sidecar                          (renamed from odf-csi-addons-sidecar)
rhdr/rhdr-must-gather                                 (NEW: Diagnostic support image)
```

**Layer 6: Operator Catalog (FBC - File-Based Catalog)**

```
rhdr-fbc                                 (Federated bundle catalog - for OperatorHub)
```

#### Phased MR Strategy

Given this is a larger set than typical tech-preview, distribute across MRs:

**MR 1: Core + Architecture Foundation (10 repositories)**
- All of Layer 1 (4 repos)
- All of Layer 2 (2 repos)
- All of Layer 3 (2 repos)
- All of Layer 4 (2 repos)
- Mandatory fields only; team DL for contacts

**MR 2: Component/Support Images (4 repositories)**
- Layer 5 (4 repos)
- Optional/layered images; add metadata enhancements
- Specific contacts; descriptions

**MR 3: Operator Catalog & GA Transition (1 repository)**
- Layer 6: `rhdr-fbc`
- Update `release_categories` to `["Generally Available"]` when ready

#### Repository Naming Conventions

| Source | Target | Reason | Example |
|--------|--------|--------|---------|
| RHODF `odf-*` operator | RHDR `odr-*` operator | Namespace clarity; avoid confusion with ODF | `odf-multicluster-operator` → `odr-multicluster-operator` |
| RHODF `odf-*-bundle` | RHDR `odr-*-bundle` | Consistent naming | `odf-multicluster-operator-bundle` → `odr-multicluster-operator-bundle` |
| RHODF `odf-*-rhel9` (controller) | RHDR `odr-*` (Pyxis config) | Pyxis simplifies naming | Pyxis: `rhdr/rhdr-multicluster-operator` |
| RHODF `odf-*-rhel9` (layered) | RHDR `odr-*` (Pyxis config) | Component images use same scheme | Pyxis: `rhdr/rhdr-csi-addons-sidecar` |
| RHODF `rhodf-fbc` | RHDR `rhdr-fbc` | Catalog naming matches product | Rename to `rhdr-fbc` |
| New (no RHODF equivalent) | RHDR `odr-*` | New RHDR-specific image | `rhdr/rhdr-must-gather` (diagnostic) |

#### Corresponding RHODF Source Repositories

For reference, these are the RHODF source repositories to fork/copy from. See [https://gitlab.cee.redhat.com/rhodf/konflux](https://gitlab.cee.redhat.com/rhodf/konflux):

```
rhodf/konflux:
  - odr-cluster-operator
  - odr-hub-operator
  - odr-volsync-plugin-operator
  - odf-multicluster-operator             ← Fork and rename to odr-multicluster-operator
  - odf-csi-addons-operator               ← Fork and rename to odr-csi-addons-operator
  - Any other repositories with 'odr' prefix

Also required:
  - rhodf-fbc                             ← Fork/copy and rename to rhdr-fbc
  - odf-console or odf-multicluster-console ← Fork and rename to odr-console or odr-multicluster-console
```

---

## Step 2: Configure RPA to Use These Repositories

Once repositories are created in Pyxis, the ReleasePlanAdmission (RPA) in `konflux-release-data` must map RHDR components to those repositories.

### In Your RPA YAML

Create **separate RPAs for staging and production**, each referencing the appropriate registry.

**Production RPA example (with expanded repositories):**

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: ReleasePlanAdmission
metadata:
  name: rhdr-4-22-prod
  namespace: rhtap-releng-tenant
spec:
  applications:
    - rhdr-4-22
  data:
    mapping:
      components:
        # Core operators
        - name: rhdr-hub-operator
          repositories:
            - url: registry.redhat.io/rhdr/rhdr-hub-operator
        - name: rhdr-cluster-operator
          repositories:
            - url: registry.redhat.io/rhdr/rhdr-cluster-operator
        # Multicluster
        - name: rhdr-multicluster-operator
          repositories:
            - url: registry.redhat.io/rhdr/rhdr-multicluster-operator
        # CSI Addons
        - name: rhdr-csi-addons-operator
          repositories:
            - url: registry.redhat.io/rhdr/rhdr-csi-addons-operator
        # Volsync
        - name: rhdr-volsync-plugin-operator
          repositories:
            - url: registry.redhat.io/rhdr/rhdr-volsync-plugin-operator
    # ... other RPA configuration
```

**Staging RPA example (with expanded repositories):**

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: ReleasePlanAdmission
metadata:
  name: rhdr-4-22-stage
  namespace: rhtap-releng-tenant
spec:
  applications:
    - rhdr-4-22
  data:
    mapping:
      components:
        # Core operators
        - name: rhdr-hub-operator
          repositories:
            - url: registry.stage.redhat.io/rhdr/rhdr-hub-operator
        - name: rhdr-cluster-operator
          repositories:
            - url: registry.stage.redhat.io/rhdr/rhdr-cluster-operator
        # Multicluster
        - name: rhdr-multicluster-operator
          repositories:
            - url: registry.stage.redhat.io/rhdr/rhdr-multicluster-operator
        # CSI Addons
        - name: rhdr-csi-addons-operator
          repositories:
            - url: registry.stage.redhat.io/rhdr/rhdr-csi-addons-operator
        # Volsync
        - name: rhdr-volsync-plugin-operator
          repositories:
            - url: registry.stage.redhat.io/rhdr/rhdr-volsync-plugin-operator
    # ... other RPA configuration
```

**Important:** The URLs must match the `repository` field from your Pyxis YAML:
- Pyxis: `repository: "rhdr/rhdr-hub-operator"`
- Production RPA: `url: registry.redhat.io/rhdr/rhdr-hub-operator`
- Staging RPA: `url: registry.stage.redhat.io/rhdr/rhdr-hub-operator`

See [RHDRReleasePlanAdmissionRequirements.md](./RHDRReleasePlanAdmissionRequirements.md) for complete RPA details.

---

## Incremental Workflow (Tech-Preview)

You don't need to define all repositories or metadata at once. Follow this iterative approach based on LLM advisory and Pyxis best practices:

### MR 1: Core + Architecture-Essential Repositories (Mandatory Fields Only) ✓

**What to include:**
- Create `products/rhdr/rhdr.yaml` with **all 10 core repositories** (4 mandatory core + 6 architecture-essential)
- **Layer 1 (4 repos):** `rhdr-hub-operator`, `rhdr-hub-operator-bundle`, `rhdr-cluster-operator`, `rhdr-cluster-operator-bundle`
- **Layer 2 (2 repos):** `rhdr-multicluster-operator`, `rhdr-multicluster-operator-bundle`
- **Layer 3 (2 repos):** `rhdr-csi-addons-operator`, `rhdr-csi-addons-operator-bundle`
- **Layer 4 (2 repos):** `rhdr-volsync-plugin-operator`, `rhdr-volsync-plugin-operator-bundle`
- Include ONLY [mandatory fields](#mandatory-fields-must-include-in-first-mr)
- Use team DL for all contacts: `"rhdr-team@redhat.com"`
- Minimal `display_data`: just `name` field
- Set `release_categories: ["Tech Preview"]`
- Set `team_id` from PMM (use placeholder with TODO comment if needed)

**Why 10 repositories in MR 1?**
- These are architecturally required for RHDR to function (multicluster, CSI Addons, Volsync)
- Forked/renamed from RHODF; naming is already established
- All use identical template/contacts; efficient to batch together
- Dependencies exist between these operators
- Easier to manage complete architecture upfront

**Example MR 1 commits:**
- `products/rhdr/rhdr.yaml` (10 repositories with mandatory fields only)
- `CODEOWNERS` entry with team and guard group

**Success criteria:**
- Cicada pipeline validates (Pyxis schema checks pass)
- MR approved and merged to `main`
- All 10 repositories created in both production and staging Pyxis
- Staging repos appear within 24 hours

### MR 2: Component/Support Images & Enhanced Metadata (After MR 1 Merged)

**What to add:**
- **Layer 5 (4 repos):** Component/support images
  - `rhdr-console` (or `rhdr-multicluster-console`)
  - `rhdr-volsync-plugin-mover`
  - `rhdr-csi-addons-sidecar`
  - `rhdr-must-gather`
- Optional fields: `short_description`, `long_description`, `application_categories`
- Specific contact individuals (Product Manager, QE Owner, Errata Writer)
- Documentation links
- Version tags

**Why MR 2?**
- Allows RPA team to start work immediately after MR 1 merges (uses MR 1 operators)
- You can refine product metadata without blocking core functionality
- Component images may have different build timelines than operators
- Easier review: metadata updates and new images separate from initial setup

### MR 3: Operator Catalog & GA Transition

**What to add:**
- **Layer 6 (1 repo):** `rhdr-fbc` (Federated Bundle Catalog for OperatorHub)
- Update `release_categories` from `["Tech Preview"]` to `["Generally Available"]` if GA-ready

**Why separate MR?**
- FBC depends on stable operators from MR 1 & 2
- Catalog can be added later after operators are stabilized
- Clear Git history of tech-preview → GA transition phases
- Simplifies rollback if needed

---

## Important Reminders

✓ **Do NOT fork** the releng/pyxis-repo-configs repository  
✓ **Push to main** branch; MR target is `main`  
✓ **Start with mandatory fields** in MR 1  
✓ **Use team DL** for contacts in tech-preview  
✓ **Iterate via follow-up MRs** for optional fields  
✓ **Wait ~24 hours** for staging sync after MR 1 merges  
✓ **Run `tox`** on RPA after repositories exist

---

## Troubleshooting

### Staging Repositories Not Appearing

**Problem:** Created repositories appear in production but not in staging registry.

**Solution:**
- **Expected delay:** Staging syncs once daily (~24 hours after production merge)
  - Production repositories are created immediately upon MR merge
  - Staging repositories auto-sync from production with ~24-hour lag
- **Check:** Verify MR was merged and Cicada pipeline completed successfully
- **Verify:** Use `curl` to test registry access:
  ```bash
  curl -I https://registry.stage.redhat.io/v2/rhdr/rhdr-hub-operator/manifests/latest
  ```
- **Both exist:** Once synced, both production AND staging repositories are available for release pipelines to push to

### Repository Already Exists Error

**Problem:** MR validation fails saying repository already exists.

**Solution:**
- Repository may have been created in a previous MR or by another team
- Verify the repository path in Pyxis before re-creating
- If it's the wrong namespace, use a different `repository` path in your YAML

### Missing Team ID

**Problem:** Validation error "team_id is missing or invalid".

**Solution:**
- Contact your product manager or PMM team for the official `team_id`
- For tech-preview, you can use a temporary ID with a comment and update it in a follow-up MR
- Example:
  ```yaml
  team_id: "000000000000000000000000"  # TODO: Replace with actual team_id from PMM
  ```

### Release Service Can't Push to Repository

**Problem:** Release service fails with "unauthorized" when pushing to repository.

**Solution:**
- Ensure repository is created in Pyxis (Step 1 completed and merged)
- Wait 24 hours for staging repos to sync if using staging
- Release service uses its service account; no additional permissions needed if repo exists
- Contact [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ) if issue persists

---

## Summary: Open Questions to Resolve Before MR Submission

This section provides a quick reference for all items that need to be finalized before submitting your Pyxis MR. See the [Pre-MR Checklist](#pre-mr-checklist-open-questions-to-resolve) for full context.

### Team Contact Information

**Question 1: Should we use `team-firefly@redhat.com` as the team contact?**

- **Current placeholder in template:** `team-firefly@redhat.com`
- **Where it's used:** All three contact types (Doc Owner, Image Owner, Product Manager)
- **What to confirm:** 
  - Is this the official team email for RHDR?
  - Should we use a different DL or individual emails?
- **Action:** Confirm with team lead and update template before MR submission
- **Tech-preview flexibility:** For now, using team DL is acceptable. You can update with individuals in MR 2.

### Product Owner Assignments

**Question 2: Who is the Product Documentation Owner?**

- **Current placeholder in template:** `team-firefly@redhat.com` (team DL)
- **Type in template:** `type: "Doc Owner"`
- **What to confirm:** Individual name or confirm team DL is responsible
- **Action:** Assign in template or keep as team DL for tech-preview

**Question 3: Who is the Image Owner?**

- **Current placeholder in template:** `team-firefly@redhat.com` (team DL)
- **Type in template:** `type: "Image Owner"`
- **What to confirm:** Individual responsible for container image quality
- **Action:** Assign in template or keep as team DL for tech-preview

**Question 4: Who is the Product Manager?**

- **Current placeholder in template:** `team-firefly@redhat.com` (team DL)
- **Type in template:** `type: "Product Manager"`
- **What to confirm:** Individual responsible for product decisions
- **Action:** Assign in template or keep as team DL for tech-preview

### Documentation and Product Identifiers

**Question 5: What is the official RHDR documentation URL?**

- **Current placeholder in template:** `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery`
- **Where it's used:** `documentation_links` field in template
- **What to confirm:** Actual URL to official RHDR documentation
- **Action:** Update template with correct URL before MR submission
- **Fallback:** If documentation not yet published, use a placeholder with note in MR description

**Question 6: What is our team ID?**

- **Current placeholder in template:** `00000000-0000-0000-0000-000000000000`
- **Where it's used:** `team_id` field in template (required by Pyxis schema)
- **What to confirm:** Official team identifier from PMM/product database
- **Action:** Contact PMM and update template before MR submission
- **Tech-preview flexibility:** Can submit with placeholder and TODO comment; update in MR 2

### Pre-Submission Checklist

Before you submit your MR, ensure you've addressed these questions:

- [ ] **Email:** Confirmed `team-firefly@redhat.com` is correct (or identified alternative)
- [ ] **Doc Owner:** Assigned or confirmed team DL
- [ ] **Image Owner:** Assigned or confirmed team DL
- [ ] **Product Manager:** Assigned or confirmed team DL
- [ ] **Docs URL:** Updated placeholder with actual RHDR documentation URL (or documented why it's a placeholder)
- [ ] **Team ID:** Obtained from PMM (or included TODO comment with placeholder)
- [ ] **Template YAML:** All TODO comments addressed or flagged as "open questions" in MR description
- [ ] **MR Description:** Listed any remaining open questions and plan to resolve in follow-up MRs

**Recommendation:** If any item is blocking, use the tech-preview approach (placeholders + MR description notes). You can update in MR 2 without impacting MR 1 merge.

---

## Related Resources

- **Pyxis Repo Configs:** [https://gitlab.cee.redhat.com/releng/pyxis-repo-configs](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs)
- **RHDR RPA Configuration:** [RHDRReleasePlanAdmissionRequirements.md](./RHDRReleasePlanAdmissionRequirements.md)
- **Konflux Help:** [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ) on Slack
- **Red Hat Registries:**
  - Production: `registry.redhat.io`
  - Staging: `registry.stage.redhat.io`

---

## Checklist: Creating RHDR Container Repositories

- [ ] **Request GitLab access** to releng/pyxis-repo-configs (Developer role)
- [ ] **Create product YAML** (`products/rhdr/rhdr.yaml`) with your repositories
- [ ] **Define contacts** (team DL acceptable for tech-preview)
- [ ] **Set release_categories** to `["Tech Preview"]`
- [ ] **Update CODEOWNERS** with your team and `@pyxis-repo-configs-guards` first
- [ ] **Submit MR** to pyxis-repo-configs
- [ ] **Wait for merge** and Cicada pipeline completion
- [ ] **Verify production repos** are accessible via `curl` or registry UI
- [ ] **Wait ~24 hours** for staging repositories to sync (both production and staging will be available)
- [ ] **Create staging RPA** in konflux-release-data using `registry.stage.redhat.io`
- [ ] **Create production RPA** in konflux-release-data using `registry.redhat.io`
- [ ] **Run `tox`** on both RPAs to validate mapping and schema
- [ ] **Submit RPA MRs** to konflux-release-data (can be separate MRs or same MR)
