# Creating Container Repositories for RHDR Release

**Document version:** 2.0  
**Date:** 2026-06-10  
**Product:** Red Hat Disaster Recovery (RHDR)  
**Product ID (EngID):** 1119  
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

## Prerequisites: Team On-Boarding (Cicada/GitOps)

### Important: Comet Deprecation Notice ⚠️

**Effective immediately (June 2026):**
- **Comet WRITE functions:** Decommissioned June 15, 2026
- **Entire Comet service:** Decommissioned August 17, 2026
- **Recommended approach:** Use Cicada (GitOps-based replacement) for all new team configurations

For on-boarding guidance and support, contact [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ) on Slack.

### Team On-Boarding Using Cicada/GitOps

Before creating container repositories, your team must be on-boarded using the **Cicada configuration as code (GitOps) approach** per [PLMPGM-4958](https://redhat.atlassian.net/browse/PLMPGM-4958).

#### Step 0a: Verify Team On-Boarding Completion

Your RHDR team has been on-boarded using Cicada/GitOps:

**Team Details:**
- **Team Name:** Red Hat Disaster Recovery (RHDR)
- **Team ID (EngID):** `1119` ✓ (Confirmed)
- **On-boarding Status:** Complete
- **On-boarding Method:** Cicada (GitOps-based)
- **On-boarding Template:** PLMPGM-4958

**Verify your team setup:**

```bash
# Check Cicada configuration (if accessible)
git clone https://gitlab.cee.redhat.com/cicada/config
grep -r "1119" config/teams/  # Search for RHDR EngID
```

If team is not found or ID differs, contact the Cicada team in [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ).

#### Step 0b: Confirm Team Permissions & Roles

Before proceeding with repository creation, verify team members have:

1. **GitLab Developer Access**
   - Repository: `releng/pyxis-repo-configs`
   - Role: Developer (minimum required for pushing commits)
   - Request access: Contact release engineering or [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ)

2. **Konflux Access**
   - LDAP group membership for team access
   - Appropriate Konflux roles assigned
   - Verify in Cicada configuration

3. **Contact Roles (Optional - Can Be Updated Later)**
   - Doc Owner (currently: team DL)
   - Image Owner (currently: individual engineer)
   - Product Manager (currently: product lead)
   - These roles can be updated via Cicada MRs post-launch

#### Step 0c: Obtain Team ID from PMM

Your **product EngID is `1119`** (RHDR product identifier). However, you still need to obtain the **team ID** from your Product Manager or PMM team. These are different values:

- **Product EngID:** `1119` ✓ (Confirmed - for RHDR product)
- **Team ID:** To be obtained from PMM (for your team's on-boarding)

The team ID will be used in:
- Pyxis product definitions (`products/rhdr/rhdr.yaml`)
- Container registry metadata
- Release service mappings
- Cicada configuration references

**Action:** Contact your product manager or PMM to provide the official team ID for use in `team_id` field.

---

## Step 1: Create Delivery Repositories in Pyxis

Container repositories must be registered in Pyxis, Red Hat's container catalog backend, before the release service can push to the Red Hat registries.

### Pre-MR Checklist: Open Questions Resolution

The following items have been resolved with the team:

| Question | Status | Value | Notes |
|----------|--------|-------|-------|
| **Product ID (EngID)** | ✓ Resolved | `1119` | RHDR product engineering identifier |
| **Team ID** | ⏳ Pending | To be obtained from PMM | RHDR team identifier (different from product ID) |
| **Contact Email Address** | ✓ Resolved | `team-firefly@redhat.com` | Team DL confirmed as primary contact |
| **Product Doc Owner** | ✓ Resolved | `team-firefly@redhat.com` (team DL) | Using team distribution list for tech-preview |
| **Image Owner** | ✓ Resolved | `nlevanon@redhat.com` | Individual contact for container quality |
| **Product Manager** | ✓ Resolved | `pelauter@redhat.com` (Peter Lauter) | Individual contact for product decisions |
| **Documentation Link** | ✓ Placeholder | `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery` | Using placeholder; update when official link available |

**Status Summary:**
- ✓ **Resolved:** Product EngID (1119), Contact email, Doc Owner, Image Owner, Product Manager, Documentation link
- ⏳ **Pending:** Team ID (will be provided by PMM)

**For MR 1 - Use These Values:**
- Product ID (EngID): `1119` ✓ (RHDR product identifier)
- Team ID: Placeholder `00000000-0000-0000-0000-000000000000` (to be updated with value from PMM)
- Team contact email: `team-firefly@redhat.com`
- Product Doc Owner: `team-firefly@redhat.com` (team DL)
- Image Owner: `nlevanon@redhat.com` (Individual contact)
- Product Manager: `pelauter@redhat.com`
- Documentation URL: `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery`
- **Volsync components:** Excluded from MR 1 pending verification; see [Open Questions / Issues](#open-questions--issues)

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

**Before you start:** The required contact information has been resolved (see [Pre-MR Checklist](#pre-mr-checklist-open-questions-resolution) above). Use these values:
- Team contact email: `team-firefly@redhat.com` ✓
- Product Doc Owner: `team-firefly@redhat.com` (team DL) ✓
- Image Owner: `nlevanon@redhat.com` ✓
- Product Manager: `pelauter@redhat.com` (Peter Lauter) ✓
- Product documentation URL: `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery` ✓
- Team ID: Placeholder (`00000000-0000-0000-0000-000000000000`) - to be updated by PMM

**Template for tech-preview product (RHDR) — Mandatory Fields Only (MR 1 - 10 Repositories):**

```yaml
# Red Hat Disaster Recovery (RHDR) Product Repositories
# Tech Preview Product Definition - MR 1 (Core + Architecture Foundation)

.contacts: &team_contacts
  - email_address: "team-firefly@redhat.com"
    type: "Doc Owner"
  - email_address: "nlevanon@redhat.com"
    type: "Image Owner"
  - email_address: "pelauter@redhat.com"
    type: "Product Manager"

.release_tags: &release_tags
  - "v4.22"

.documentation: &documentation_links
  - title: "Red Hat Disaster Recovery"
    type: "Documentation"
    url: "https://docs.redhat.com/en/documentation/red_hat_disaster_recovery"

.repo_template: &repo_template
  release_categories:
    - "Tech Preview"
  includes_multiple_content_streams: false
  content_stream_tags:
    *release_tags
  team_id: "00000000-0000-0000-0000-000000000000"  # TODO: Replace with actual team_id from PMM (EngID 1119 is product ID, not team ID)
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

  # Additional repositories added in MR 2+ (Layer 4+: Component Images, Volsync)
  # Additional repositories added in MR 3 (Layer 6: FBC)
```

**Notes:**
- This template shows all 8 repositories for MR 1 (4 core + 4 architecture-essential)
- MR 2+ will add volsync components if verified as part of build deliverable: volsync-plugin-operator, volsync-plugin-operator-bundle, volsync-plugin-mover
- MR 2+ will add Layer 5 (4+ component/support images): console, sidecar, must-gather, and volsync-mover if needed
- MR 3+ will add Layer 6 (1 FBC): rhdr-fbc
- All mandatory fields are included; optional fields will be added in MR 2
- **Contact information resolved:** Uses `team-firefly@redhat.com` for Doc Owner and Image Owner; `pelauter@redhat.com` for Product Manager
- **Product EngID:** `1119` (RHDR product identifier); team_id to be obtained from PMM

#### MR 1 Submission - Ready with Pending Team ID

Most items have been resolved. For MR 1 submission:

**Ready to Use:**
- ✓ Product ID (EngID): `1119`
- ✓ Team contact email: `team-firefly@redhat.com`
- ✓ Product Doc Owner: `team-firefly@redhat.com`
- ✓ Image Owner: `nlevanon@redhat.com`
- ✓ Product Manager: `pelauter@redhat.com`
- ✓ Documentation URL: `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery`

**Pending:**
- ⏳ Team ID: Use placeholder `00000000-0000-0000-0000-000000000000` with TODO comment; will be updated in MR 2 once received from PMM

**MR 1 Submission Notes:**

Add to MR description:

```markdown
## RHDR Container Repository On-Boarding (MR 1)

**Product:** Red Hat Disaster Recovery (EngID: 1119)  
**On-boarding Status:** In Progress  
**On-boarding Template:** PLMPGM-4958  
**Repositories:** 8 core and architecture-essential operators  

**Pending:** Team ID to be provided by PMM (currently using placeholder).
Will be updated in MR 2 once confirmed.
```

This allows:
- MR 1 to merge and create repositories immediately
- Team ID updated in follow-up MR
- Complete team on-boarding package

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
| `includes_multiple_content_streams` | Template | **TECH-PREVIEW: Single stream** | `false` |
| `content_stream_tags` | Template | **TECH-PREVIEW: Latest only** | `["latest"]` |
| `use_latest` | Template | **TECH-PREVIEW: Track latest** | `true` |
| `team_id` | Template | Team identifier | Placeholder (pending PMM) |
| `vendor_label` | Template | Vendor identifier | `"redhat"` |
| `contacts` | Template | At least one contact | Use team DL for tech-preview |
| `contacts[].email_address` | Contact | Email address | `"rhdr-team@redhat.com"` |
| `contacts[].type` | Contact | Role type | `"Image Owner"` or `"Doc Owner"` |
| `display_data` | Repository | Display metadata | Required |
| `display_data.name` | Display | Image display name | `"RHDR Hub Operator"` |
| `build_categories` | Repository | Build type | `["Operator"]` |
| `fbc_opt_in` | Repository | **BUNDLES ONLY:** Enable FBC | `true` (on bundle images) |

#### Optional Fields (Add in Follow-Up MRs)

These fields enhance metadata but are **not required** for initial MR. Can be added after MR 1 merges:

| Field | Level | Description | Timing | Notes |
|-------|-------|-------------|--------|-------|
| `application_categories` | Template | Business categorization | MR 2+: When positioning clear | Tech-preview can skip initially |
| `privileged_images_allowed` | Template | Run privileged? | MR 2+: When ready | Default: false |
| `documentation_links` | Template | Documentation URLs | MR 2+: As docs available | Can add in MR 1 if ready |
| `requires_terms` | Template | Subscription required? | MR 2+: When ready | Default: true for RHDR |
| `display_data.short_description` | Display | Brief description | MR 2+: Optional | Add when ready |
| `display_data.long_description` | Display | Detailed description | MR 2+: Optional | Add when ready |

**Note:** For tech-preview products, `includes_multiple_content_streams`, `content_stream_tags`, and `use_latest` are **mandatory** (not optional) - see [Tech-Preview vs GA Product YAML Configuration](#tech-preview-vs-ga-product-yaml-configuration) section above.

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

### Tech-Preview vs GA Product YAML Configuration

The Pyxis product YAML has significant structural differences between tech-preview and GA products. Below are the key differences and what RHDR uses for tech-preview:

#### Content Stream Configuration

| Aspect | Tech-Preview (RHDR) | Generally Available (RHODF) | Purpose |
|--------|-------------------|---------------------------|---------|
| **includes_multiple_content_streams** | `false` | `true` | Single stream vs multiple version streams |
| **content_stream_tags** | `["latest"]` | `["v4.21", "v4.20", "v4.19", ...]` | Release versions supported concurrently |
| **use_latest** | `true` | `false` | Track latest tag vs specific versions |
| **release_categories** | `["Tech Preview"]` | `["Generally Available"]` | Product maturity status |

#### RHDR Tech-Preview Configuration (What Changed)

**Before (Cicada validation FAILED):**
```yaml
content_stream_tags:
  - "v4.22"  # ❌ Single specific version
use_latest: false  # ❌ Not tracking latest
```

**After (Cicada validation PASSED):**
```yaml
content_stream_tags:
  - "latest"  # ✓ Single "latest" tag for tech-preview
use_latest: true  # ✓ Enable latest tag tracking
includes_multiple_content_streams: false  # ✓ Single stream
```

#### Why Single Stream for Tech-Preview?

- **GA products** support multiple concurrent versions (e.g., v4.21, v4.20, v4.19)
  - Different customers may run different versions
  - Need to build/test/support all versions
  - Use `includes_multiple_content_streams: true`

- **Tech-Preview products** only support latest version
  - Single development stream
  - Customers always get latest (no backwards compatibility)
  - Use `includes_multiple_content_streams: false`
  - Use `content_stream_tags: ["latest"]`
  - Set `use_latest: true`

#### Complete Tech-Preview Template (.repo_template)

```yaml
.repo_template: &repo_template
  # Status
  release_categories:
    - "Tech Preview"  # Not GA yet
  
  # Content Streams - TECH-PREVIEW SPECIFIC
  includes_multiple_content_streams: false  # Single stream only
  content_stream_tags:
    - "latest"  # Only "latest", not version numbers
  use_latest: true  # Track latest tag
  
  # Team & Permissions
  team_id: "00000000-0000-0000-0000-000000000000"  # Placeholder (pending PMM)
  vendor_label: "redhat"
  
  # Product Metadata
  application_categories:
    - "Backup & Recovery"
    - "Cloud Management"
  privileged_images_allowed: false
  documentation_links: *documentation_links
  contacts: *team_contacts
  
  # Licensing
  requires_terms: true
```

#### GA Product Example (RHODF - for reference)

For comparison, here's what a GA product looks like:

```yaml
.repo_template: &repo_template
  # Status
  release_categories:
    - "Generally Available"  # GA product
  
  # Content Streams - GA SPECIFIC
  includes_multiple_content_streams: true  # Multiple concurrent versions
  content_stream_tags:
    - "v4.21"
    - "v4.20"
    - "v4.19"
    - "v4.18"
    # ... more versions as needed
  use_latest: false  # Don't track "latest"
  
  # Rest same as tech-preview
  team_id: "5cdc8481d70cc57c44b2888d"
  vendor_label: "redhat"
  # ... other fields
```

#### Migration Path: Tech-Preview → GA

When RHDR transitions from tech-preview to GA, update these fields in MR:

```yaml
# MR to transition to GA:
release_categories:
  - "Generally Available"  # Changed from "Tech Preview"

includes_multiple_content_streams: true  # Now supporting multiple versions

content_stream_tags:
  - "v4.22"  # Replace "latest" with specific version tags
  - "v4.21"  # as you establish support policy
  - "v4.20"

use_latest: false  # Disable latest tracking
```

#### RHDR YAML Cicada Validation Checklist

✓ **Passes Cicada Validation:**
- [x] Single content stream: `includes_multiple_content_streams: false`
- [x] Tag strategy: `content_stream_tags: ["latest"]`
- [x] Latest tracking: `use_latest: true`
- [x] Release status: `release_categories: ["Tech Preview"]`
- [x] All mandatory fields present
- [x] `fbc_opt_in: true` on all bundle images
- [x] Contacts defined with at least one email
- [x] Team ID field present (placeholder acceptable)
- [x] Vendor label: `"redhat"`
- [x] Documentation links provided

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

**Should-Include Architecture-Essential (4 repos):**
- `rhdr/rhdr-multicluster-operator` (Operator Controller) - Multicluster coordination
- `rhdr/rhdr-multicluster-operator-bundle` (Operator Bundle)
- `rhdr/rhdr-csi-addons-operator` (Operator Controller) - Snapshot/restore capability
- `rhdr/rhdr-csi-addons-operator-bundle` (Operator Bundle)

**Pending Verification (Defer to MR 2 if needed):**
- `rhdr/rhdr-volsync-plugin-operator` (Operator Controller) - Volsync integration ⏳
- `rhdr/rhdr-volsync-plugin-operator-bundle` (Operator Bundle) ⏳

**Optional for MR 1 (Add in MR 2 if needed):**
- `rhdr/rhdr-console` or `rhdr/rhdr-multicluster-console` (UI console)
- `rhdr/rhdr-csi-addons-sidecar` (Layered - CSI addons sidecar)
- `rhdr/rhdr-must-gather` (Layered - Diagnostic image)
- `rhdr/rhdr-volsync-plugin-mover` (Layered - Volsync mover) ⏳ *Pending volsync verification*

**FBC (Catalog) - Include in MR 2:**
- `rhdr-fbc` - File-based operator catalog (not needed until after initial operators work)

**Total for MR 1:** 8 core repositories (4 minimum + 4 architecture-essential)
*Note: Volsync components deferred pending verification of build/deliverable inclusion*

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

**Layer 4: Volsync Plugin for Continuous Data Protection (⏳ Pending Verification)**

*Deferred pending confirmation that volsync components are part of the build/deliverable.*

Volsync provides continuous asynchronous data replication (already odr-prefixed in RHODF):

```
rhdr/rhdr-volsync-plugin-operator          ⏳ To be added if verified
rhdr/rhdr-volsync-plugin-operator-bundle   ⏳ To be added if verified
```

**Layer 5: Component/Support Images (Layered)**

Runtime dependencies and component images:

```
rhdr/rhdr-console (or rhdr/rhdr-multicluster-console)  (renamed from odf-console)
rhdr/rhdr-csi-addons-sidecar                          (renamed from odf-csi-addons-sidecar)
rhdr/rhdr-must-gather                                 (NEW: Diagnostic support image)
rhdr/rhdr-volsync-plugin-mover                        (⏳ Volsync mover base image - pending verification)
```

**Layer 6: Operator Catalog (FBC - File-Based Catalog)**

```
rhdr-fbc                                 (Federated bundle catalog - for OperatorHub)
```

#### Phased MR Strategy

Given this is a larger set than typical tech-preview, distribute across MRs:

**MR 1: Core + Architecture Foundation (8 repositories)**
- All of Layer 1 (4 repos)
- All of Layer 2 (2 repos)
- All of Layer 3 (2 repos)
- ⏳ Layer 4 (Volsync - 2 repos) - Deferred pending verification of build/deliverable inclusion
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
    releaseNotes:
      product_id: [1119]  # ← RHDR Product EngID
      product_name: "Red Hat Disaster Recovery"
      product_version: "4.22"
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
        # Volsync (add after MR 2 if verified)
        # - name: rhdr-volsync-plugin-operator
        #   repositories:
        #     - url: registry.redhat.io/rhdr/rhdr-volsync-plugin-operator
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
    releaseNotes:
      product_id: [1119]  # ← RHDR Product EngID (same as production)
      product_name: "Red Hat Disaster Recovery"
      product_version: "4.22"
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
        # Volsync (add after MR 2 if verified)
        # - name: rhdr-volsync-plugin-operator
        #   repositories:
        #     - url: registry.stage.redhat.io/rhdr/rhdr-volsync-plugin-operator
    # ... other RPA configuration
```

**Important:** The URLs must match the `repository` field from your Pyxis YAML:
- Pyxis: `repository: "rhdr/rhdr-hub-operator"`
- Production RPA: `url: registry.redhat.io/rhdr/rhdr-hub-operator`
- Staging RPA: `url: registry.stage.redhat.io/rhdr/rhdr-hub-operator`

**Product ID (EngID) Requirement:**
- The `data.releaseNotes.product_id` field is **required** in every RPA
- Use array format: `[1119]` (not just `1119`)
- Value: `1119` (RHDR Product EngID - confirmed)
- Use the same value for both production and staging RPAs
- This is different from the `team_id` in Pyxis product definitions

See [RHDRReleasePlanAdmissionRequirements.md](./RHDRReleasePlanAdmissionRequirements.md) for complete RPA details.

### Where Product ID (EngID) Goes: Summary

Three different places use different ID values:

| Location | Field | Value | Type | Purpose |
|----------|-------|-------|------|---------|
| **Pyxis Product Definition** | `team_id` | TBD (from PMM) | UUID | Team identifier for role mapping |
| **RPA (ReleasePlanAdmission)** | `data.releaseNotes.product_id` | `[1119]` | Array | RHDR Product EngID for release tracking |
| **Tenant Configuration** | None | N/A | N/A | Tenant configs don't include EngID |

**Product EngID (1119):**
- Goes in: RPA's `data.releaseNotes.product_id: [1119]`
- Use array format: `[1119]` (not just `1119`)
- Use same value for both prod and stage RPAs
- This is confirmed and ready to use

**Team ID (from PMM):**
- Goes in: Pyxis product definition's `team_id` field
- Format: UUID (e.g., `5cdc8481d70cc57c44b2888d`)
- Still pending from PMM
- Different from product EngID

---

## Incremental Workflow (Tech-Preview)

You don't need to define all repositories or metadata at once. Follow this iterative approach based on LLM advisory and Pyxis best practices:

### MR 1: Core + Architecture-Essential Repositories (Mandatory Fields Only) ✓

**What to include:**
- Create `products/rhdr/rhdr.yaml` with **all 8 core repositories** (4 mandatory core + 4 architecture-essential)
- **Layer 1 (4 repos):** `rhdr-hub-operator`, `rhdr-hub-operator-bundle`, `rhdr-cluster-operator`, `rhdr-cluster-operator-bundle`
- **Layer 2 (2 repos):** `rhdr-multicluster-operator`, `rhdr-multicluster-operator-bundle`
- **Layer 3 (2 repos):** `rhdr-csi-addons-operator`, `rhdr-csi-addons-operator-bundle`
- ⏳ **Layer 4 (2 repos - Deferred):** `rhdr-volsync-plugin-operator`, `rhdr-volsync-plugin-operator-bundle` (pending verification)
- Include ONLY [mandatory fields](#mandatory-fields-must-include-in-first-mr)
- Use team DL for all contacts: `"rhdr-team@redhat.com"`
- Minimal `display_data`: just `name` field
- Set `release_categories: ["Tech Preview"]`
- Set `team_id` from PMM (use placeholder with TODO comment if needed)

**Why 8 repositories in MR 1?**
- These 8 are core/essential for RHDR to function (multicluster, CSI Addons)
- Forked/renamed from RHODF; naming is already established
- All use identical template/contacts; efficient to batch together
- Dependencies exist between these operators
- Easier to manage complete architecture upfront
- Volsync components (2 repos) deferred to MR 2 pending verification of build/deliverable inclusion

**Example MR 1 commits:**
- `products/rhdr/rhdr.yaml` (8 repositories with mandatory fields only)
- `CODEOWNERS` entry with team and guard group

**Success criteria:**
- Cicada pipeline validates (Pyxis schema checks pass)
- MR approved and merged to `main`
- All 8 repositories created in both production and staging Pyxis
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
- You can verify volsync component inclusion in build/deliverable
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

## Step 3: Validate Container Repositories Exist in Pyxis

Before creating the RPA or attempting a release, validate that your container repositories have been successfully created in Pyxis. This prevents pipeline failures later.

### Overview: Two Registry Environments

Container repositories exist in **two separate Pyxis environments**:

| Environment | Registry | Timeline | Purpose |
|-----------|----------|----------|---------|
| **Production** | `registry.redhat.io` | Created immediately upon MR merge | Customer-facing releases |
| **Staging** | `registry.stage.redhat.io` | ~24 hours after production | Pre-release validation and testing |

Both environments must have the repositories before the release service can push images. Check both environments to ensure they're ready.

### Validation Method: Pyxis API Query

Query the Pyxis API directly using `curl` with Kerberos authentication to check if repositories exist:

#### Production Pyxis (registry.redhat.io)

```bash
# Template command
curl --negotiate -u: \
  "https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/{REPOSITORY_PATH}"

# Example: Check if rhdr-hub-operator exists
curl --negotiate -u: \
  "https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq .

# With pretty-print and error handling
curl --negotiate -u: -f \
  "https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" 2>/dev/null | jq . || echo "Repository not found or error"
```

#### Staging Pyxis (registry.stage.redhat.io)

```bash
# Template command
curl --negotiate -u: \
  "https://pyxis.stage.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/{REPOSITORY_PATH}"

# Example: Check if rhdr-hub-operator exists in staging
curl --negotiate -u: \
  "https://pyxis.stage.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq .
```

#### Understanding API Response

**Success Response (Repository Exists):**
```json
{
  "repository_id": "5f8d3c9e7b2a1c4d",
  "repository": "rhdr/rhdr-hub-operator",
  "registry_id": "r1234567890",
  "enabled": true,
  "build_categories": ["Operator image"],
  "release_categories": ["Tech Preview"],
  "vendor_label": "redhat",
  "created_at": "2026-06-14T10:30:00Z"
}
```

**Repository Not Found (404):**
```json
{
  "error": "Not found"
}
```

### Quick Validation Script

Use this bash script to validate multiple RHDR repositories at once:

```bash
#!/bin/bash
# validate_rhdr_repos.sh - Check RHDR repositories in both Pyxis environments

set -e

REPOS=(
  "rhdr/rhdr-hub-operator"
  "rhdr/rhdr-hub-operator-bundle"
  "rhdr/rhdr-cluster-operator"
  "rhdr/rhdr-cluster-operator-bundle"
  "rhdr/rhdr-multicluster-operator"
  "rhdr/rhdr-multicluster-operator-bundle"
  "rhdr/rhdr-csi-addons-operator"
  "rhdr/rhdr-csi-addons-operator-bundle"
)

PYXIS_PROD="https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository"
PYXIS_STAGE="https://pyxis.stage.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository"

echo "=== Validating RHDR Repositories ==="
echo ""

validate_repo() {
  local env=$1
  local url=$2
  local repo=$3
  
  echo -n "[$env] $repo: "
  
  if curl --negotiate -u: -s -f "$url/$repo" > /dev/null 2>&1; then
    echo "✓ EXISTS"
    return 0
  else
    echo "✗ NOT FOUND"
    return 1
  fi
}

echo "--- Production (registry.redhat.io) ---"
prod_count=0
for repo in "${REPOS[@]}"; do
  validate_repo "PROD" "$PYXIS_PROD" "$repo" && ((prod_count++))
done
echo "Production: $prod_count/${#REPOS[@]} repositories found"
echo ""

echo "--- Staging (registry.stage.redhat.io) ---"
stage_count=0
for repo in "${REPOS[@]}"; do
  validate_repo "STAGE" "$PYXIS_STAGE" "$repo" && ((stage_count++))
done
echo "Staging: $stage_count/${#REPOS[@]} repositories found"
echo ""

if [ $prod_count -eq ${#REPOS[@]} ]; then
  echo "✓ Production repositories ready"
else
  echo "⚠ Production: Waiting for $((${#REPOS[@]} - prod_count)) repositories"
fi

if [ $stage_count -eq ${#REPOS[@]} ]; then
  echo "✓ Staging repositories ready"
else
  echo "⚠ Staging: Waiting for $((${#REPOS[@]} - stage_count)) repositories (~24 hours)"
fi
```

**Usage:**
```bash
chmod +x validate_rhdr_repos.sh
./validate_rhdr_repos.sh
```

### RHDR Repository Validation Mapping

Below is a complete mapping of all RHDR repositories from your `rhdr.yaml` and how to validate each one:

#### Layer 1: Core Hub & Cluster Operators

| Repository | YAML Path | Production Check | Staging Check |
|-----------|-----------|------------------|---------------|
| **rhdr-hub-operator** | `repositories[0].repository` | `curl ... /rhdr/rhdr-hub-operator` | Same (staging domain) |
| **rhdr-hub-operator-bundle** | `repositories[1].repository` | `curl ... /rhdr/rhdr-hub-operator-bundle` | Same |
| **rhdr-cluster-operator** | `repositories[2].repository` | `curl ... /rhdr/rhdr-cluster-operator` | Same |
| **rhdr-cluster-operator-bundle** | `repositories[3].repository` | `curl ... /rhdr/rhdr-cluster-operator-bundle` | Same |

#### Layer 2: Multicluster Operators

| Repository | YAML Path | Production Check | Staging Check |
|-----------|-----------|------------------|---------------|
| **rhdr-multicluster-operator** | `repositories[4].repository` | `curl ... /rhdr/rhdr-multicluster-operator` | Same (staging domain) |
| **rhdr-multicluster-operator-bundle** | `repositories[5].repository` | `curl ... /rhdr/rhdr-multicluster-operator-bundle` | Same |

#### Layer 3: CSI Addons Operators

| Repository | YAML Path | Production Check | Staging Check |
|-----------|-----------|------------------|---------------|
| **rhdr-csi-addons-operator** | `repositories[6].repository` | `curl ... /rhdr/rhdr-csi-addons-operator` | Same (staging domain) |
| **rhdr-csi-addons-operator-bundle** | `repositories[7].repository` | `curl ... /rhdr/rhdr-csi-addons-operator-bundle` | Same |

#### Layer 4: Volsync Plugin Operators (Pending MR 2)

| Repository | YAML Path | Production Check | Staging Check |
|-----------|-----------|------------------|---------------|
| **rhdr-volsync-plugin-operator** ⏳ | `repositories[8].repository` | `curl ... /rhdr/rhdr-volsync-plugin-operator` | Same (staging domain) |
| **rhdr-volsync-plugin-operator-bundle** ⏳ | `repositories[9].repository` | `curl ... /rhdr/rhdr-volsync-plugin-operator-bundle` | Same |

### Validation Workflow

**Recommended validation sequence:**

#### Step 1: Verify Production Pyxis (immediately after MR merges)

After your `pyxis-repo-configs` MR is **merged and Cicada pipeline completes**:

```bash
# Check one repository from each layer
curl --negotiate -u: \
  "https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq '.repository'

# Expected output:
# "rhdr/rhdr-hub-operator"
```

**Success criteria:**
- API returns 200 (not 404)
- JSON response includes `repository_id` and `enabled: true`

#### Step 2: Wait for Staging Sync (~24 hours)

Staging repositories auto-sync from production with a ~24-hour delay. You can:
- Wait and periodically check, OR
- Use the validation script above to monitor both environments

```bash
# Check every 6 hours (optional - you don't need to do this manually)
for i in {1..4}; do
  echo "Check $i: $(date)"
  ./validate_rhdr_repos.sh
  [ $i -lt 4 ] && sleep 6h
done
```

#### Step 3: Verify Staging Pyxis (after ~24 hours)

Once staging repositories appear:

```bash
# Check one repository from staging
curl --negotiate -u: \
  "https://pyxis.stage.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository/rhdr/rhdr-hub-operator" | jq '.repository'

# Expected output:
# "rhdr/rhdr-hub-operator"
```

**Success criteria:**
- All 8 repositories (or your MR 1 subset) appear in both production and staging
- Both registries now ready to receive releases

#### Step 4: Proceed with RPA Creation

Once validation confirms repositories in both environments:

```bash
# Now safe to create RPAs pointing to these repositories
# Production RPA: registry.redhat.io/rhdr/...
# Staging RPA: registry.stage.redhat.io/rhdr/...
```

### Common Validation Issues

#### Issue: "Repository Not Found (404)"

**Cause:** Repository hasn't been created yet, or MR not merged.

**Debug:**
```bash
# 1. Verify MR is merged
git log --oneline origin/main | grep -i rhdr

# 2. Check Cicada pipeline status
# Visit: https://gitlab.cee.redhat.com/releng/pyxis-repo-configs/-/pipelines

# 3. Verify repository path matches YAML
# In rhdr.yaml, check the 'repository' field value
# Should match curl path exactly (e.g., "rhdr/rhdr-hub-operator")
```

#### Issue: "Production Exists, But Staging Missing"

**Cause:** Normal ~24-hour sync delay (not an error).

**Solution:**
- Wait additional time (sync happens once daily)
- Monitor using the validation script
- Check staging after 24-48 hours

#### Issue: "Curl Authentication Failed"

**Cause:** Missing Kerberos credentials or not authenticated to Red Hat network.

**Solution:**
```bash
# Ensure you have a valid Kerberos ticket
kinit USERNAME@REDHAT.COM

# Or if you have RHEL workstation with auto-auth
# Try again from a Red Hat network-connected machine
```

### What To Do If Validation Fails

| Scenario | Action | Timeline |
|----------|--------|----------|
| **MR just merged, prod repos not found** | Check Cicada pipeline status; wait for pipeline completion | Minutes-hours |
| **Production exists, staging missing** | Wait for ~24-hour sync window | ~24 hours normal |
| **Both missing after 48+ hours** | Contact Release Engineering; check for MR merge errors | Next business day |

---

## Summary: Questions Resolution Status

This section documents the resolution of all open questions for RHDR container repository creation.

### Resolved Questions ✓

#### 1. Team Contact Email: ✓ Resolved

- **Answer:** `team-firefly@redhat.com` (Team DL)
- **Status:** Confirmed with team
- **Usage in template:** Primary contact email for all communications

#### 2. Product Documentation Owner: ✓ Resolved

- **Answer:** `team-firefly@redhat.com` (Team DL)
- **Status:** Confirmed - using team distribution list for tech-preview
- **Usage in template:** `type: "Doc Owner"`
- **Tech-preview note:** Acceptable to use team DL; can assign individual in MR 2

#### 3. Image Owner: ✓ Resolved

- **Answer:** `nlevanon@redhat.com` (Individual contact)
- **Status:** Confirmed with RHDR team
- **Usage in template:** `type: "Image Owner"`
- **Responsibility:** Container image quality and build categories

#### 4. Product Manager: ✓ Resolved

- **Answer:** `pelauter@redhat.com` (Peter Lauter)
- **Status:** Confirmed with architecture team
- **Usage in template:** `type: "Product Manager"`
- **Contact:** Peter Lauter (pelauter@redhat.com)

#### 5. Documentation Link: ✓ Resolved

- **Answer:** `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery`
- **Status:** Using placeholder URL
- **Usage in template:** `documentation_links` field
- **Note:** Update with actual documentation URL once published

### Pending Items ⏳

#### 6. Team ID: ⏳ Pending

- **Current status:** Waiting for PMM to provide
- **Temporary solution:** Using placeholder `00000000-0000-0000-0000-000000000000` in MR 1
- **Usage in template:** `team_id` field (required by Pyxis schema)
- **Plan:** Will be updated in MR 2 once received from product management
- **Action:** Contact PMM for official team_id

### MR 1 Readiness Checklist

All items resolved or have acceptable temporary solutions:

- [x] **Product EngID:** `1119` ✓ (Confirmed)
- [x] **Email:** `team-firefly@redhat.com` ✓
- [x] **Doc Owner:** `team-firefly@redhat.com` ✓
- [x] **Image Owner:** `nlevanon@redhat.com` ✓
- [x] **Product Manager:** `pelauter@redhat.com` (Peter Lauter) ✓
- [x] **Docs URL:** `https://docs.redhat.com/en/documentation/red_hat_disaster_recovery` ✓
- [ ] **Team ID:** Placeholder with TODO comment (awaiting PMM) ⏳
- [x] **Template YAML:** Ready for submission
- [x] **MR Description:** Document team_id as pending item

### Ready for MR 1 Submission

You can now proceed with MR 1 submission with all resolved contact information and documented pending item (team_id).

**Note in MR Description:**
```markdown
## Pending Items

- [ ] **Team ID:** Placeholder currently used. Will update with official team_id from PMM in MR 2.

Product EngID (1119) and all contact information have been resolved and confirmed.
```

---

## Related Resources

### On-Boarding & Team Management

- **Team On-Boarding Template:** [PLMPGM-4958](https://redhat.atlassian.net/browse/PLMPGM-4958) - Cicada configuration as code
- **Cicada Help & Support:** [#forum-cicada](https://redhat.enterprise.slack.com/archives/C095V063YLQ) on Slack
- **Cicada Configuration Repository:** `https://gitlab.cee.redhat.com/cicada/config` (for reference)
- **Comet Deprecation Notice:** [Comet WRITE functions removed June 15, 2026; service decomissioned August 17, 2026]
- **Important Note:** Product EngID (1119) is different from Team ID. Get Team ID from PMM.

### Container Repository & Release Management

- **Pyxis Repo Configs:** [https://gitlab.cee.redhat.com/releng/pyxis-repo-configs](https://gitlab.cee.redhat.com/releng/pyxis-repo-configs)
- **RHDR RPA Configuration:** [RHDRReleasePlanAdmissionRequirements.md](./RHDRReleasePlanAdmissionRequirements.md)
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

---

## Open Questions / Issues

### 🔍 Question 1: Volsync Component Inclusion in Build/Deliverable

**Status:** ⏳ Pending Verification

**Question:**
Are the volsync components part of the RHDR build/deliverable?
- `rhdr-volsync-plugin-operator`
- `rhdr-volsync-plugin-operator-bundle`
- `rhdr-volsync-plugin-mover` (layered)

**Current Action:**
- Volsync components **excluded from MR 1** pending this verification
- MR 1 contains 8 core repositories only (4 core + 4 architecture-essential)
- Volsync can be added in MR 2 if verified as part of the build

**If Volsync IS Part of Build (Add to MR 2):**

1. **Add to Git Repository:**
   - Ensure volsync components are in the RHDR source repositories
   - Fork/create from ODF/RHODF equivalents if needed:
     - `odf4/odr-volsync-plugin-rhel9-operator` → `rhdr/rhdr-volsync-plugin-operator`
     - `odf4/odr-volsync-plugin-operator-bundle` → `rhdr/rhdr-volsync-plugin-operator-bundle`
     - `odf4/odr-volsync-plugin-mover-rhel9` → `rhdr/rhdr-volsync-plugin-mover`

2. **Add Build Component in the Application (Konflux):**
   - Create/verify Konflux Application contains:
     - Build component for `rhdr-volsync-plugin-operator`
     - Build component for `rhdr-volsync-plugin-mover` (if needed as separate image)
   - Pipeline must produce container images for each

3. **Add to Component List in FBC (MR 3):**
   - Update `rhdr-fbc` (File-Based Catalog) to include volsync operator
   - Ensures volsync appears in OperatorHub

4. **Add Repositories to Pyxis Product Definition (MR 2):**
   - Add to `products/rhdr/rhdr.yaml`:
     ```yaml
     - image_type: "Operator Controller"
       repository: "rhdr/rhdr-volsync-plugin-operator"
     - image_type: "Operator Bundle Image"
       repository: "rhdr/rhdr-volsync-plugin-operator-bundle"
     # Layered image (if separate build artifact):
     - image_type: "Layered"
       repository: "rhdr/rhdr-volsync-plugin-mover"
     ```

**If Volsync is NOT Part of Build:**
- Volsync can remain excluded from RHDR release
- Skip all the steps above
- Proceed with 8-repository approach

**Action Required:**
Please verify volsync component status and update this section once confirmed.

---

## Appendix: Product EngID vs Team ID

### Key Distinction

These are **two different identifiers** used in different configuration files:

| Identifier | Value | Configuration File | Field | Status |
|------------|-------|-------------------|-------|--------|
| **Product EngID** | `1119` | **RPA** (config/) | `data.releaseNotes.product_id: [1119]` | ✓ Confirmed |
| **Team ID** | TBD | **Pyxis Product Def** (products/) | `team_id: "..."` | ⏳ Pending |

### Product EngID: 1119 ✓

- **RHDR product identifier** (confirmed)
- **Goes in:** RPA file at `config/stone-prd-rh01.pg1f.p1/product/ReleasePlanAdmission/rhdr/rhdr-*-prod.yaml`
  ```yaml
  data:
    releaseNotes:
      product_id: [1119]  # ← Use array format
      product_name: "Red Hat Disaster Recovery"
      product_version: "4.22"
  ```
- Used for:
  - Release service product tracking
  - Advisory generation
  - Release notes correlation
  - Product mapping in Konflux
- This is the same as "EngID" mentioned in team communications

### Team ID: Pending from PMM

- **RHDR team identifier** (separate from product ID)
- **Goes in:** Pyxis product definition at `products/rhdr/rhdr.yaml`
  ```yaml
  .repo_template: &repo_template
    team_id: "00000000-0000-0000-0000-000000000000"  # ← Replace with actual Team ID
  ```
- Used for:
  - `team_id` field in Pyxis product definition
  - Team role assignments in Cicada
  - Release service team permissions
- Must be obtained from your Product Manager or PMM
- Format: UUID (e.g., `5cdc8481d70cc57c44b2888d`)
- Different teams may work on the same product; this identifies YOUR team specifically

### Why They're Different

- **Product EngID (1119)** = What product this is (Red Hat Disaster Recovery)
  - Everyone working on RHDR uses the same EngID
  - Used for release tracking and advisory correlation
  
- **Team ID** = Which team owns/manages this product (your specific team)
  - Different teams may have different Team IDs
  - Used for role-based access control and permissions

### Configuration Files Summary

**File 1: Pyxis Product Definition** (`products/rhdr/rhdr.yaml`)
- Contains: `team_id: "..."` (pending from PMM)
- Does NOT contain: Product EngID (1119)

**File 2: RPA (ReleasePlanAdmission)** (`config/.../ReleasePlanAdmission/rhdr/rhdr-*-prod.yaml`)
- Contains: `product_id: [1119]` (confirmed)
- Does NOT contain: Team ID

**File 3: Tenant Configuration** (`tenants-config/.../rhdr-tenant/`)
- Contains: Neither (not used in tenant configs)
- Focuses on: Application, Component, and ReleasePlan definitions

### Action Required

**For EngID (1119):**
- ✓ Ready to use in RPA files
- Add to `data.releaseNotes.product_id: [1119]` in every RPA

**For Team ID:**
- ⏳ Contact your Product Manager or PMM to obtain
- Update Pyxis product definition's `team_id` field once received
