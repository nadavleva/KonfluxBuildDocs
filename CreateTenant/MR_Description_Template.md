# rhdr-tenant Onboarding: Merge Request Description

## MR Title
```
Create rhdr-tenant on stone-prod-p02: namespace, infrastructure, and release configuration
```

---

## MR Description (Use as Template)

### 🎯 Objective
Onboard the Red Hat Data Recovery (rhdr) product team to Konflux by creating a new tenant workspace (`rhdr-tenant`) on the `stone-prod-p02` cluster. This replaces the previous `rh-ocp-dr-tenant` and provides dedicated infrastructure for the team to build, test, and release rhdr products through the Red Hat CI/CD pipeline.

### 📋 Changes Included

#### Phase 1: Tenant Infrastructure (Steps 1-5) ✅
- **New Namespace**: `rhdr-tenant` on `stone-prod-p02.hjvn.p1` cluster
- **Cluster Size**: 3.large (supports multiple concurrent builds)
- **RBAC Configuration**:
  - **Admins** (full access): nlevanon, eduffy, nnevin
  - **Maintainers** (manage resources): nlevanon, eduffy, nnevin
  - **Contributors** (execute builds): abeekhof, martjack, oaharoni, sughosh
- **Files Created**:
  - `/tenants-config/cluster/stone-prod-p02/admin/rhdr-tenant/` - RBAC definitions
  - `/tenants-config/cluster/stone-prod-p02/tenants/rhdr-tenant/` - Namespace resources
  - `/tenants-config/auto-generated/cluster/stone-prod-p02/*/rhdr-tenant/` - Kubernetes manifests
- **CODEOWNERS Updated**: Added entries for all tenant directories

#### Phase 2: Release Configuration (Steps 6-8) ✅
Enables the team to release rhdr products through the managed release pipeline:

##### Stage 1: Constraints File
- **File**: `/config/constraints/product/rhdr-tenant.yaml`
- **Purpose**: Validates all Release Plan Admission files created by the team
- **Validates**:
  - Origin workspace = `rhdr-tenant`
  - Policy names match rhdr patterns (e.g., `registry-rhdr-stage`, `registry-rhdr-prod`)
  - Container image URLs use correct registry namespace: `registry.{stage.}redhat.io/rh-disaster-recovery/*`

##### Stage 2: Enterprise Contract Policies
- **Files**: 
  - `/config/stone-prod-p02.hjvn.p1/product/EnterpriseContractPolicy/registry-rhdr-stage.yaml`
  - `/config/stone-prod-p02.hjvn.p1/product/EnterpriseContractPolicy/registry-rhdr-prod.yaml`
- **Purpose**: Define compliance and security rules for releases
- **Staging Policy**: Allows development releases with relaxed constraints
- **Production Policy**: Enforces strict compliance (CVE scanning, license checks)

##### Stage 3: Release Plan Admission Files
- **Directory**: `/config/stone-prod-p02.hjvn.p1/product/ReleasePlanAdmission/rhdr-tenant/`
- **Purpose**: Orchestrate what, where, and how products are released
- **Files Created**: One pair (stage/prod) per supported version
  - Example: `rhdr-1-0-stage.yaml` + `rhdr-1-0-prod.yaml`
- **Components**: rhdr-operator, rhdr-console, rhdr-agent (configurable per version)
- **Registries**:
  - Staging: `registry.stage.redhat.io/rh-disaster-recovery/*`
  - Production: `registry.redhat.io/rh-disaster-recovery/*`

### 🔐 Security & Access Control

- **Registry Credentials**: Uses shared team service account token `konflux-release-service-access-management-token` (configured cluster-wide)
- **Service Accounts**:
  - Staging builds: `release-registry-staging`
  - Production builds: `release-registry-prod`
- **Pipeline**: Uses standard Red Hat release pipeline from `github.com/konflux-ci/release-service-catalog`

### ✅ Validation Performed

All changes pass Konflux requirements:
- `tox -e ruff-check` ✅ Python linting
- `tox -e yamllint` ✅ YAML syntax and structure
- `tox -e codeowners-lint` ✅ CODEOWNERS alphabetically sorted
- `tox -e test` ✅ Schema validation for constraints and RPA files
- Manual kustomize build ✅ Tenant manifests generate correctly

### 🚀 Deployment

After merge to `main`:
1. ArgoCD detects changes in `konflux-release-data` repository
2. ArgoCD syncs new namespace (`rhdr-tenant`) to `stone-prod-p02` cluster
3. Kubernetes manifests create namespace, RBAC, and quotas
4. Release policies and RPA files are deployed to `rhtap-releng-tenant` namespace
5. Team can immediately start creating builds through the Konflux UI

### 👥 Team Impact

**Admins** (nlevanon, eduffy, nnevin):
- Full control over namespace resources
- Can manage team membership and quotas
- Can approve and merge release PRs

**Contributors** (abeekhof, martjack, oaharoni, sughosh):
- Can create and submit release requests
- Can build components in the namespace
- Can test releases in staging environment

### 📝 Related Issues

- Blocks: Creation of rhdr Component definitions in Konflux
- Depends on: Team providing product metadata (product ID, versions)
- Related: [VIRTDR-XXX] - rhdr product naming convention (RHDR = Red Hat Disaster Recovery)

### 🔗 References

- **Onboarding Plan**: [plan-rhdrTenant-clarified.prompt.md](../plan-rhdrTenant-clarified.prompt.md)
- **Constraint File Documentation**: [ConstraintFileStages.md](./ConstraintFileStages.md)
- **Reference Tenants**: 
  - rhwa-tenant (workload availability, 2+ components)
  - rhodf-tenant (ODF, 20+ components)

### 📌 Notes

- **Both tenants coexist**: `rh-ocp-dr-tenant` remains active during transition period
- **Backwards compatible**: No breaking changes to existing tenant configurations
- **Phased approach**: Infrastructure-only MR followed by release configuration update
- **Ready for production**: All validation checks pass, team can start using immediately after deployment

---

## Checklist Before Merging

- [ ] Branch created from `main`: `rhdr-tenant-setup`
- [ ] `add-namespace.sh create` executed with all team members
- [ ] `build-manifests.sh` generated auto-generated/ content
- [ ] CODEOWNERS updated and alphabetically sorted
- [ ] Constraints file validates RPA origin and policies
- [ ] Enterprise Contract Policies created for stage and prod
- [ ] Release Plan Admission files created for each version (stage/prod pairs)
- [ ] All YAML files pass yamllint
- [ ] Schema validation passes (tox -e test)
- [ ] CODEOWNERS lint passes (tox -e codeowners-lint)
- [ ] All tox environments pass (tox)
- [ ] Documentation created in Docs/CreateTenant folder
- [ ] No merge conflicts with main

---

## How to Request Tenant Deletion (If Needed)

If you need to remove `rh-ocp-dr-tenant` after full migration:
1. Verify all releases have migrated to `rhdr-tenant`
2. Create a follow-up MR to remove the old tenant directories
3. Run `build-manifests.sh` to update auto-generated/
4. Merge and ArgoCD will delete the old namespace

