# Plan: Create rhdr-tenant to Replace rh-ocp-dr-tenant

**TL;DR:** Create a new tenant `rhdr-tenant` on `stone-prod-p02` using the `add-namespace.sh` script with the same admins/maintainers/contributors as the current `rh-ocp-dr-tenant`, then update CODEOWNERS and build manifests. Run in a fresh branch from `main` (superseding MR 17811). Create documentation of the process in the Docs folder.

## Steps

### 1. Create new branch from `main`
- Location: `/home/nlevanon/workspace/Konflux/konflux-release-data/`
- Branch name: `rhdr-tenant-setup` (similar to current `rh-ocp-dr-tenant-setup`)
- This will be your working branch for the entire process

### 2. Navigate to tenants-config working directory
- Change to `/home/nlevanon/workspace/Konflux/tenants-config/`

### 3. Run add-namespace.sh to create the new tenant
- **Depends on**: Step 1
- Command structure:
```bash
./add-namespace.sh create \
  --cluster stone-prod-p02 \
  --namespace rhdr-tenant \
  --size 3.large \
  --admin nlevanon \
  --admin eduffy \
  --admin nnevin \
  --maintainer nlevanon \
  --maintainer eduffy \
  --maintainer nnevin \
  --contributor abeekhof \
  --contributor martjack \
  --contributor oaharoni \
  --contributor sughosh \
  --codeowner nlevanon \
  --codeowner eduffy
```
- This will create: `/cluster/stone-prod-p02/{admin,tenants}/rhdr-tenant/` directories with auto-generated RBAC files and update the CODEOWNERS file
- Size mapping note: `add-namespace.sh` uses format `3.large` which references `/lib/quota/3.large/` directory

### 4. Generate manifests
- **Depends on**: Step 3
- Run: `./build-manifests.sh`
- This populates `auto-generated/` directory with final Kubernetes manifests
- Both source and generated files must be committed

### 5. Update CODEOWNERS file in konflux-release-data root
- **Depends on**: Step 4
- Verify entries for:
  - `/tenants-config/cluster/stone-prod-p02/tenants/rhdr-tenant/`
  - `/tenants-config/cluster/stone-prod-p02/admin/rhdr-tenant/`
  - `/tenants-config/auto-generated/cluster/stone-prod-p02/tenants/rhdr-tenant/`
  - `/tenants-config/auto-generated/cluster/stone-prod-p02/admin/rhdr-tenant/`
- All codeowners must be alphabetically sorted per `tox -e codeowners-lint`

### 6. Run validation tests
- **Depends on**: Step 5
- From repo root (`/home/nlevanon/workspace/Konflux/konflux-release-data/`):
  - `tox -e ruff-check` — Python linting
  - `tox -e yamllint` — YAML validation
  - `tox -e codeowners-lint` — Verify alphabetical ordering
  - `tox` — Run all validations
- Fix any issues (CODEOWNERS ordering is most common)

### 7. Create planning document
- **Parallel with**: Step 6
- Create: `/home/nlevanon/workspace/RamenDRStandAlone/Docs/CreateTenant.md`
- Document should include:
  - Objective (replace rh-ocp-dr with rhdr)
  - `add-namespace.sh` command used
  - Cluster selection rationale (stone-prod-p02, size 3.large)
  - Team composition (admins: nlevanon/eduffy/nnevin, contributors: abeekhof/martjack/oaharoni/sughosh)
  - Validation steps performed
  - References to both tenants coexisting during transition

### 8. Commit changes
- **Depends on**: Step 6 & 7
- Files to stage:
  - `/tenants-config/cluster/stone-prod-p02/admin/rhdr-tenant/`
  - `/tenants-config/cluster/stone-prod-p02/tenants/rhdr-tenant/`
  - `/tenants-config/auto-generated/cluster/stone-prod-p02/admin/rhdr-tenant/`
  - `/tenants-config/auto-generated/cluster/stone-prod-p02/tenants/rhdr-tenant/`
  - `/CODEOWNERS` (root)
  - `/Docs/CreateTenant.md` (RamenDRStandAlone)
- Commit message: `Create rhdr-tenant on stone-prod-p02 with large size - replaces rh-ocp-dr-tenant`

## Configuration Details

### Current Tenant Reference (rh-ocp-dr-tenant)
- **Location**: `/tenants-config/cluster/stone-prod-p02/{admin,tenants}/rh-ocp-dr-tenant/`
- **Admins**: nlevanon, eduffy, nnevin
- **Maintainers**: nlevanon, eduffy, nnevin
- **Contributors**: abeekhof, martjack, oaharoni, sughosh
- **Size**: 3.large
- **Structure**: admin/ + tenants/ directories with kustomization.yaml files

### New Tenant Specs (rhdr-tenant)
- **Namespace**: rhdr-tenant
- **Cluster**: stone-prod-p02
- **Size**: 3.large (same as original)
- **Admins**: nlevanon, eduffy, nnevin (same)
- **Maintainers**: nlevanon, eduffy, nnevin (same)
- **Contributors**: abeekhof, martjack, oaharoni, sughosh (same)
- **Codeowners**: nlevanon, eduffy (2 primary contacts)

### Key Decisions
- **Namespace name**: rhdr-tenant
- **Old tenant handling**: Keep both (don't delete rh-ocp-dr-tenant)
- **Branch approach**: Completely separate new branch from main (ignore MR 17811)

## Relevant Files

- [/tenants-config/add-namespace.sh](tenants-config/add-namespace.sh) — Script to create tenant
- [/tenants-config/build-manifests.sh](tenants-config/build-manifests.sh) — Generate manifests post-creation
- [/tenants-config/lib/quota/3.large/](tenants-config/lib/quota/3.large/) — Resource quota reference for size (pre-existing)
- [/CODEOWNERS](CODEOWNERS) — Update with new tenant entries (maintain alphabetical order)
- [/tenants-config/cluster/stone-prod-p02/tenants/rh-ocp-dr-tenant/](tenants-config/cluster/stone-prod-p02/tenants/rh-ocp-dr-tenant/) — Existing tenant for reference (keep as-is)
- [/Docs/CreateTenant.md](../RamenDRStandAlone/Docs/CreateTenant.md) — Documentation to create

## Verification Checklist

- [ ] Create new branch from main (`rhdr-tenant-setup`)
- [ ] Run add-namespace.sh with all specified parameters
- [ ] Run build-manifests.sh to generate auto-generated/ content
- [ ] Verify CODEOWNERS entries exist and are alphabetically sorted
- [ ] Run tox -e ruff-check (pass)
- [ ] Run tox -e yamllint (pass)
- [ ] Run tox -e codeowners-lint (pass)
- [ ] Run tox (all environments pass)
- [ ] Create CreateTenant.md documentation
- [ ] Verify rhdr-tenant manifests exist in auto-generated/
- [ ] Confirm both rh-ocp-dr-tenant and rhdr-tenant directories coexist
- [ ] Verify CODEOWNERS includes all four roles for rhdr-tenant
- [ ] Commit all changes with proper message

## Architecture Reuse

- Use existing quota templates at [3.large/](tenants-config/lib/quota/3.large/) — no new quota profile needed
- RBAC pattern matches [existing rh-ocp-dr tenant structure](tenants-config/cluster/stone-prod-p02/tenants/rh-ocp-dr-tenant/) — admins/maintainers/contributors rolebindings
- Deployment happens via ArgoCD post-merge (no manual cluster operations required)

## Scope & Exclusions

**Included:**
- Create new tenant with add-namespace.sh
- Update CODEOWNERS
- Run validation tests
- Create documentation in Docs folder
- Keep both tenants (migration period)
- New branch from main

**Excluded:**
- Deleting rh-ocp-dr-tenant (keeping both)
- Modifying quota or resource templates (using existing 3.large)
- GitLab group/project setup (config only)
- Manual cluster operations
