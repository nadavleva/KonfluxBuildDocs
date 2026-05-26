# rhdr-tenant Konflux Onboarding: Constraint File Stages

## Overview

The rhdr-tenant Konflux configuration consists of three interconnected configuration layers that work together to validate and orchestrate product releases. Understanding each stage is critical for proper tenant setup.

---

## Stage 1: Constraints File (`/config/constraints/product/rhdr-tenant.yaml`)

### Purpose
**Validation layer** - Acts as a JSONSchema that validates all ReleasePlanAdmission (RPA) resources created by the product team.

### What It Controls
- **Origin validation**: RPAs must have `spec.origin: rhdr-tenant`
- **Policy validation**: RPAs can only reference approved policies (e.g., `registry-rhdr-stage`, `registry-rhdr-prod`)
- **Registry namespace validation**: Component image URLs must follow allowed patterns
- **Pipeline constraints**: Pipeline configurations must use specific git repositories and revisions

### Key Fields to Customize

| Field | Purpose | Example | Required |
|-------|---------|---------|----------|
| `spec.origin.pattern` | Which tenant namespace can use these policies | `rhdr-tenant` | Yes |
| `spec.policy.pattern` | Allowed policy names | `^(registry-rhdr-stage\|registry-rhdr-prod\|fbc-rhdr-stage\|fbc-rhdr-prod)$` | Yes |
| `spec.data.mapping.components[].repositories[].url.pattern` | Registry namespace for container images | `^registry\.(redhat\|stage\.redhat)\.io/{NAMESPACE}/*` | Yes |

### Template Example

```yaml
---
properties:
  spec:
    properties:
      origin:
        type: string
        pattern: rhdr-tenant  # ← Only rhdr-tenant RPAs validated
      policy:
        pattern: ^(registry-rhdr-stage|registry-rhdr-prod|fbc-rhdr-stage|fbc-rhdr-prod|registry-standard|fbc-standard)$
      data:
        properties:
          mapping:
            properties:
              components:
                type: array
                items:
                  properties:
                    repositories:
                      type: array
                      items:
                        properties:
                          url:
                            type: string
                            pattern: ^registry\.(redhat|stage\.redhat)\.io/rh-disaster-recovery/*  # ← Validates image registry paths
```

### Validation Workflow

1. Product team creates RPA file (e.g., `rhdr-1-0-stage.yaml`)
2. Konflux release pipeline loads this Constraints file
3. RPA is validated against JSONSchema patterns
4. If validation passes → RPA is processed
5. If validation fails → Release is blocked with clear error message

---

## Stage 2: Enterprise Contract Policies (`/config/stone-prod-p02.hjvn.p1/product/EnterpriseContractPolicy/`)

### Purpose
**Compliance & Security layer** - Defines security, policy, and compliance rules for releases.

### What It Controls
- **Data sources**: Where policy rules come from (GitHub repositories, container registries)
- **Policy rules**: Which compliance checks to enforce (CVE scanning, license checks, etc.)
- **Exclusions**: Which rules don't apply (date/schedule restrictions, etc.)
- **Registry prefixes**: Which registries are allowed for container images

### Files Required

| File | Purpose | Usage |
|------|---------|-------|
| `registry-rhdr-stage.yaml` | Policies for **staging** releases | Applied to staging RPA files |
| `registry-rhdr-prod.yaml` | Policies for **production** releases | Applied to production RPA files |

### Key Differences: Stage vs. Production

| Aspect | Staging Policy | Production Policy |
|--------|----------------|-------------------|
| **Data Sources** | Same compliance sources | Same compliance sources |
| **CVE Blocking** | ✅ Excludes CVE blockers | ❌ Enforces CVE blockers |
| **Allowed Registries** | `registry.stage.redhat.io` | `registry.redhat.io` |
| **Strictness** | Lower (allows more exemptions) | Higher (stricter enforcement) |

### Template Example (Staging Policy)

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: EnterpriseContractPolicy
metadata:
  name: registry-rhdr-stage
  namespace: rhtap-releng-tenant
  annotations:
    konflux-release-data/derived-from: registry-standard-stage
spec:
  description: 'Rules for shipping Red Hat Data Recovery content to staging registry'
  publicKey: 'k8s://openshift-pipelines/public-key'
  sources:
    - data:
        - github.com/release-engineering/rhtap-ec-policy//data
        - oci::quay.io/konflux-ci/tekton-catalog/data-acceptable-bundles:latest
      name: Release Policies
      policy:
        - oci::quay.io/conforma/release-policy:konflux
      config:
        exclude:
          - schedule.weekday_restriction  # ← Can release any day in staging
          - schedule.date_restriction      # ← Can release any date in staging
          - cve.cve_blockers              # ← Allows blocked CVEs in staging
        include:
          - "@redhat"
      ruleData:
        allowed_registry_prefixes:
          - registry.stage.redhat.io/     # ← Only staging registry
          - registry.access.redhat.com/
```

### Validation Workflow

1. RPA passes Constraints validation (Stage 1)
2. Release pipeline loads Enterprise Contract Policies
3. Policy rules are applied to all artifacts in the release
4. Compliance checks run (CVE scanning, license validation, etc.)
5. If all checks pass → Release proceeds
6. If any check fails → Release is blocked with compliance report

---

## Stage 3: Release Plan Admission Files (`/config/stone-prod-p02.hjvn.p1/product/ReleasePlanAdmission/rhdr-tenant/`)

### Purpose
**Orchestration layer** - Defines **what**, **where**, and **how** products are released.

### What It Controls
- **Product metadata**: Name, version, product ID
- **Component mapping**: Which components get released and where
- **Registry targets**: Staging vs. production registries
- **Pipeline configuration**: Which Tekton pipeline runs the release
- **Service accounts**: Which accounts have permissions to perform the release

### Files Required (One Pair Per Product Version)

| File Pattern | Purpose | When Used |
|--------------|---------|-----------|
| `rhdr-{version}-stage.yaml` | Release to **staging** registry | Testing, validation |
| `rhdr-{version}-prod.yaml` | Release to **production** registry | Customer-facing releases |

### Example: rhdr-1-0-stage.yaml

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: ReleasePlanAdmission
metadata:
  name: rhdr-1-0-stage
  namespace: rhtap-releng-tenant
spec:
  applications:
    - rhdr-1-0  # ← Konflux Application name
  origin: rhdr-tenant  # ← Links to Constraints validation
  policy: registry-rhdr-stage  # ← Links to Stage Enterprise Contract Policy
  data:
    releaseNotes:
      product_name: "Red Hat Disaster  Recovery"  # ← Product marketing name
      product_version: "1.0"
      product_id: XXX  # ← Engineering database ID
    intention: staging  # ← "staging" or "production"
    mapping:
      registrySecret: konflux-release-service-access-management-token  # ← Shared team credentials
      defaults:
        public: false
        pushSourceContainer: true
      components:
        - name: rhdr-operator-1-0
          repositories:
            - url: "registry.stage.redhat.io/rh-disaster-recovery/rhdr-operator-rhel9"  # ← Staging registry
        - name: rhdr-console-1-0
          repositories:
            - url: "registry.stage.redhat.io/rh-disaster-recovery/rhdr-console-rhel9"
  pipeline:
    pipelineRef:
      resolver: git
      params:
        - name: url
          value: "https://github.com/konflux-ci/release-service-catalog.git"
        - name: revision
          value: development  # ← Development pipeline for staging
        - name: pathInRepo
          value: "pipelines/managed/rh-advisories/rh-advisories.yaml"
    serviceAccountName: release-registry-staging  # ← Staging SA
    timeouts:
      pipeline: "4h0m0s"
      tasks: "3h50m0s"
```

### Example: rhdr-1-0-prod.yaml

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: ReleasePlanAdmission
metadata:
  name: rhdr-1-0-prod
  namespace: rhtap-releng-tenant
spec:
  applications:
    - rhdr-1-0
  origin: rhdr-tenant
  policy: registry-rhdr-prod  # ← Links to Production Enterprise Contract Policy
  data:
    releaseNotes:
      product_name: "Red Hat Data Recovery"
      product_version: "1.0"
      product_id: XXX
    intention: production  # ← "production" (stricter validation)
    mapping:
      registrySecret: konflux-release-service-access-management-token
      defaults:
        public: false
        pushSourceContainer: true
      components:
        - name: rhdr-operator-1-0
          repositories:
            - url: "registry.redhat.io/rh-disaster-recovery/rhdr-operator-rhel9"  # ← Production registry
        - name: rhdr-console-1-0
          repositories:
            - url: "registry.redhat.io/rh-disaster-recovery/rhdr-console-rhel9"
  pipeline:
    pipelineRef:
      resolver: git
      params:
        - name: url
          value: "https://github.com/konflux-ci/release-service-catalog.git"
        - name: revision
          value: production  # ← Production pipeline for prod
        - name: pathInRepo
          value: "pipelines/managed/rh-advisories/rh-advisories.yaml"
    serviceAccountName: release-registry-prod  # ← Production SA
    timeouts:
      pipeline: "4h0m0s"
      tasks: "3h50m0s"
```

### Validation Workflow

1. RPA passes Constraints validation (Stage 1)
2. Enterprise Contract Policy checks pass (Stage 2)
3. Release pipeline reads component mapping from RPA
4. Each component is built and pushed to specified registry
5. Release artifacts are tagged with metadata (version, timestamp, SHA)
6. Release succeeds → components available in registry

---

## Complete Flow: How the Three Stages Work Together

```
┌─────────────────────────────────────────────────────────────────┐
│ Product Team Creates Release Request                            │
│ File: rhdr-1-0-stage.yaml                                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 1: Constraints Validation                                 │
│ File: /config/constraints/product/rhdr-tenant.yaml              │
│                                                                 │
│ Checks:                                                         │
│ ✓ origin == "rhdr-tenant"                                       │
│ ✓ policy in ["registry-rhdr-stage", "registry-rhdr-prod"]       │
│ ✓ registry URLs match rh-disaster-recovery namespace                │
│                                                                 │
│ Result: PASS or FAIL with schema validation error               │
└─────────────────────────────────────────────────────────────────┘
                              ↓ PASS
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 2: Enterprise Contract Policies                           │
│ File: /config/.../EnterpriseContractPolicy/registry-rhdr-stage  │
│                                                                 │
│ Checks:                                                         │
│ ✓ Run CVE scanning (excluded in staging)                        │
│ ✓ Run license compliance                                        │
│ ✓ Verify build provenance                                       │
│ ✓ Check allowed registries                                      │
│                                                                 │
│ Result: PASS or FAIL with compliance report                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓ PASS
┌─────────────────────────────────────────────────────────────────┐
│ STAGE 3: Release Execution                                      │
│ File: /config/.../ReleasePlanAdmission/rhdr-tenant/             │
│                                                                 │
│ Actions:                                                        │
│ ✓ Load component mapping from RPA                               │
│ ✓ Use service account: release-registry-staging                 │
│ ✓ Push to: registry.stage.redhat.io/rh-disaster-recovery/*          │
│ ✓ Tag with: version, timestamp, git SHA                         │
│ ✓ Generate release notes                                        │
│                                                                 │
│ Result: Release complete → Images available in registry         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ✅ RELEASE SUCCESSFUL
           Images available in staging registry
```

---

## Required Product Information (What to Ask the Team)

Before creating all three files, gather this information from the product team:

| Information | Used In | Example |
|-------------|---------|---------|
| **Product Name** | Stage 3 (RPA) | "Red Hat Data Recovery" |
| **Product ID** | Stage 3 (RPA) | 999 |
| **Versions** | Stage 3 (RPA filenames) | "1.0, 1.1, 2.0" |
| **Registry Namespace** | Stage 1 & 2 | "rh-disaster-recovery" |
| **Component Names** | Stage 3 (RPA components) | "rhdr-operator", "rhdr-console" |

---

## Implementation Checklist

- [ ] **Product team provides**: Product name, ID, versions, registry namespace, component names
- [ ] **Step 6 - Create Constraints File**: `/config/constraints/product/rhdr-tenant.yaml` with registry namespace pattern
- [ ] **Step 7 - Create EC Policies**: Two files for staging and production with product namespace in allowed registries
- [ ] **Step 8 - Create RPAs**: One pair (stage/prod) per version with product metadata and components
- [ ] **Step 9 - Run Validation**: `tox` to validate all YAML, schemas, and CODEOWNERS ordering
- [ ] **Commit & Deploy**: All three stages deployed together via ArgoCD

---

## Key Points to Remember

1. **Constraints File**: Validates the shape and content of RPAs (JSONSchema)
2. **Enterprise Contract Policies**: Enforces compliance and security rules
3. **Release Plan Admission**: Orchestrates the actual release process
4. **All three must be in sync**: Same namespace, policy names, and component names
5. **Version determines which files exist**: Create RPA pairs for each supported version
6. **Staging vs. Production**: Different registries, different policies, different strictness levels

