# Conforma Violations Report: rhdr-hub-operator-bundle-4-22

**Report Date:** 2026-06-23  
**Test Run:** managed-8xlwr-verify-conforma  
**Status:** ❌ FAILED  

---

## Overview

The `rhdr-hub-operator-bundle-4-22` component has **3 violations** and **8+ warnings** that must be addressed before release compliance.

---

## Violations

### ✕ Violation 1: olm.allowed_registries

**Bundle SHA(s) Affected:**
- `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e5edef11de0ee164ce39aebec10c00bf56933cfc01884dd7f8c7da12ddde2a6b`
- `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e3f4163bad216fecaa65819a078cb020ade61b3e6ee0fef682b267e6feb81379`

**Error Message:**
```
The "quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramen-operator-base-image-4-22@sha256:d5a43ebb2b147144fd8645aaefe62535c8cc873e6b4bf3cce2ad8d703486a43b" 
CSV image reference is not from an allowed registry.
```

**Rule Code:** `olm.allowed_registries`  
**Severity:** ❌ VIOLATION (Blocks Release)  
**Term:** `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramen-operator-base-image-4-22`

**Description:**
Each image referenced by the OLM bundle should match an entry in the list of prefixes defined by the rule data key `allowed_olm_image_registry_prefixes` in the policy configuration.

**Solution:**
1. Use an image from an allowed registry, OR
2. Update the policy configuration to include `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramen-operator-base-image-4-22` in the `allowed_olm_image_registry_prefixes` list

**Root Cause:** 
The base image reference uses an internal quay.io registry not in the allowed registries list. This image should be sourced from a public Red Hat registry or the policy configuration needs to be updated.

---

### ✕ Violation 2: olm.olm_bundle_multi_arch

**Bundle SHA(s) Affected:**
- `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e5edef11de0ee164ce39aebec10c00bf56933cfc01884dd7f8c7da12ddde2a6b`

**Error Message:**
```
The "quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e5edef11de0ee164ce39aebec10c00bf56933cfc01884dd7f8c7da12ddde2a6b" 
bundle image is a multi-arch reference.
```

**Rule Code:** `olm.olm_bundle_multi_arch`  
**Severity:** ❌ VIOLATION (Blocks Release)  
**Effective Since:** 2025-05-01  
**Term:** `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e5edef11de0ee164ce39aebec10c00bf56933cfc01884dd7f8c7da12ddde2a6b`

**Description:**
OLM bundle images should be built for a single architecture. They should not be OCI image indexes nor Docker v2s2 manifest lists.

**Solution:**
Rebuild your bundle image using a **single architecture only** (e.g., `linux/amd64`). Do not create an image index for the OLM bundle.

**Fix Implementation:**
Update the `.tekton/rhdr-hub-operator-bundle-4-22-*.yaml` pipeline files:

```yaml
spec:
  params:
  - name: build-platforms
    value:
      - linux/x86_64    # Single architecture only, NOT an array of multiple architectures
  - name: hermetic
    value: "true"
  - name: build-source-image
    value: "true"
```

**Technical Details:**
- Current build: Creating multi-arch image index
- Required: Single-arch image for `linux/x86_64` only
- This affects OLM bundle distribution and deployment reliability

---

### ✕ Violation 3: test.no_skipped_tests

**Bundle SHA(s) Affected:**
- `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e5edef11de0ee164ce39aebec10c00bf56933cfc01884dd7f8c7da12ddde2a6b`
- `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:e3f4163bad216fecaa65819a078cb020ade61b3e6ee0fef682b267e6feb81379`

**Error Message:**
```
The Task "sast-snyk-check-oci-ta" from the build Pipeline reports a test was skipped
```

**Rule Code:** `test.no_skipped_tests`  
**Severity:** ❌ VIOLATION (Blocks Release)  
**Term:** `sast-snyk-check-oci-ta`

**Description:**
A test was skipped during the build pipeline. This violation occurs when a pre-requirement for executing a test was not met (e.g., missing license key, environment variable not set).

**Solution:**
1. Ensure the `sast-snyk-check-oci-ta` task has access to required licenses/credentials
2. Verify environment variables are properly configured in the build pipeline
3. Check Snyk CLI license availability in the build environment
4. Alternatively, set the task to not be skipped by ensuring its preconditions are met

**Conforma Configuration Option:**
To exclude this specific test, add to the policy configuration:
```yaml
exclude:
  - test.no_skipped_tests:sast-snyk-check-oci-ta
```

---

## Warnings

### ⚠️  Warning: Outdated Tekton Tasks

Multiple tasks in the pipeline are running outdated versions and should be updated before their expiration dates:

| Task | Current Version | Expiration Date | Updated Bundle |
|------|-----------------|-----------------|-----------------|
| **git-clone-oci-ta** | 0.1@sha256:13d49df7dc9ae301627e45f95a236011422996152f1bea46cd60217b0f057407 | 2026-07-21 | sha256:d30f13dd15daf89dd6dc645243b3444d35570d13f7840c3fd65e366022515205 |
| **sast-shell-check-oci-ta** | 0.1@sha256:c4ef47e3b4e0508572d266fb745be7e374c29dc02580328cbe9f4d472a8aca57 | 2026-07-26 | sha256:fc685d6f7dfb7c9ab2f2db38bbe2c8d383407847350ccd8b96352322c487b13c |
| **sast-snyk-check-oci-ta** | 0.4@sha256:8f3ecbeaff579e41b8278f82d7fabac27845db17a8e687ea6c510c0c9aceabbb | 2026-07-25 | sha256:8d794f3c04de1b47b76f9e48a2be19520568d8b467598976cbd440c44532f970 |
| **sast-unicode-check-oci-ta** | 0.4@sha256:90efa582de7770d55102b74014a765cd16a25a56f2cf644b56a788c70c4dc749 | 2026-07-25 | sha256:5807ffe3a0cca5cf970076bbc7a404642cc6e3eebe64e9e5e6a4f20da740bf73 |
| **build-image-index** | 0.3@sha256:550afde50349e22ec11191ea0db9a49395ab46fef4e8317d820b6e946677ebeb | 2026-07-19 | sha256:e1d79f08fb96babb606b2cd0a3f1dc9d9084c5e7206365d1e51e3dc1f923c949 |
| **buildah-remote-oci-ta** | 0.9@sha256:f667d1146533b1d49829c08097e31faf27db24563da576434a707353de62099f | 2026-07-25 | sha256:148347cf1a291bc3ebe0700d7f61c12f7f4d5e78e59a162f5e622ad67106c4a9 |
| **source-build-oci-ta** | 0.3@sha256:0917cfc7772e82cb8e74743c2104f43bcf2596aceafe87eec6fce69a8cac5f06 | 2026-07-26 | sha256:8567bb7bf8fa9147c96b297533336fa7079ecf972cb86c09ccdd6bddedb25711 |

**Action Required:**
Update all task references in the `.tekton/` YAML files before the expiration dates. The most urgent is **build-image-index** (expires 2026-07-19).

---

### ⚠️  Warning: Missing NetworkPolicy RBAC

**Code:** `olm.required_network_policy_rbac_for_operands`  
**Effective Since:** 2026-08-07

The operator is missing required RBAC permissions for managing NetworkPolicy resources:

```
Operator "rhdr-hub-operator" is missing required NetworkPolicy RBAC 
(networking.k8s.io/networkpolicies with create, delete, and update/patch)
```

**Solution:**
Add the following to the ClusterServiceVersion `spec.install.spec.clusterPermissions`:

```yaml
- serviceAccountName: rhdr-hub-operator
  rules:
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["create", "delete", "update", "patch"]
```

OR add to `operator_network_policy_rbac_exceptions` in policy configuration if exemption is justified.

---

## Remediation Steps (In Priority Order)

### 1️⃣ Fix Multi-Arch Bundle Issue (CRITICAL)

**File(s):** 
- `/home/nlevanon/workspace/RamenDRStandAlone/rhdr/rhdr-hub-operator-bundle/.tekton/rhdr-hub-operator-bundle-4-22-pull-request.yaml`
- `/home/nlevanon/workspace/RamenDRStandAlone/rhdr/rhdr-hub-operator-bundle/.tekton/rhdr-hub-operator-bundle-4-22-push.yaml`

**Change:**
```yaml
spec:
  params:
  - name: build-platforms
    value:
      - linux/x86_64    # Single architecture
  - name: hermetic
    value: "true"
  - name: build-source-image
    value: "true"
```

### 2️⃣ Verify SAST Snyk License (HIGH)

Check if Snyk license/token is available in the build environment:
- Verify `SNYK_TOKEN` environment variable is set
- Ensure build pipeline has access to Snyk credentials
- Or exclude the check if not applicable to this component

### 3️⃣ Update Allowed Registries (MEDIUM)

Either:
- Move `rhdr-ramen-operator-base-image-4-22` to an approved registry, OR
- Update policy to allow internal quay.io registries

### 4️⃣ Update Tekton Task References (MEDIUM)

Update all task SHA references to the newer versions before expiration dates, starting with `build-image-index`.

### 5️⃣ Add NetworkPolicy RBAC (MEDIUM)

Update operator ClusterServiceVersion to include NetworkPolicy RBAC permissions before 2026-08-07.

---

## Test Execution Details

**Log File:** `managed-8xlwr-verify-conforma.log`  
**Test Timestamp:** 2026-06-23T21:23:00Z  
**Total Violations (All Components):** 28  
**Total Warnings (All Components):** 122  
**Test Result:** FAILURE

**Related Components in Same Run:**
- rhdr-multicluster-operator-image-4-22 (violations)
- rhdr-multicluster-operator-bundle-4-22 (violations)
- rhdr-csi-addons-operator-bundle-4-22 (violations)
- rhdr-cluster-operator-bundle-4-22 (violations)

---

## Policy References

- **Policy Package:** Enterprise Contract (EC)
- **Rule Set:** redhat, minimal, slsa3
- **Configuration URL:** https://conforma.dev/docs/cli/configuration.html

---

## Contact & Resolution

**Component Owner:** rhdr-hub-operator  
**Next Steps:**
1. Apply fixes in priority order
2. Commit changes to source repository
3. Trigger new build pipeline run
4. Verify Conforma test passes before release

**For Violations Explanation:** See individual violation sections above  
**For Policy Details:** Reference the Conforma documentation URLs in each violation message
