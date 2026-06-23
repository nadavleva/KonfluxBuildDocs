# Compliance Violations and Warnings Analysis

**Date:** 2026-06-22  
**Source:** managed-j7rcp-verify-conforma.log  
**Total Violations:** 72  
**Total Warnings:** 112

---

## Executive Summary

The build pipeline validation identified 72 critical violations and 112 warnings across 11 components in the RHDR (Red Hat Disaster Recovery) multi-cluster operator suite. The violations primarily relate to:
- **Hermetic task execution** - Missing hermetic parameter configuration
- **Source image validation** - Missing source image references
- **Required pipeline tasks** - Missing source-build or source-build-oci-ta tasks
- **Test skipping** - Skipped SAST/security tests due to missing licenses
- **OLM bundle registry compliance** - Images from non-approved registries
- **Image pinning** - Unpinned image references in OLM bundles

---

## Violations by Type

### 1. `hermetic_task.hermetic` - Task Hermetic Execution

**Title:** Task called with hermetic param set  
**Severity:** CRITICAL  
**Affected Components:** 10

| ImageRef | Reason | Solution |
|----------|--------|----------|
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22@sha256:e96ddad6c134e7068b6fcce35662af28cab72dae04790a3f4e38979474c1e6cf` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22@sha256:7a111a6e7f8da65604cc47db161d1945593002aaac0b2309d43e6e72e1ae9e0f` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-bundle-4-22@sha256:d9791872f7cddab52132155429586de7b072db8c4e3cf565b09376b37082cd5a` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-bundle-4-22@sha256:c77036cc6a608029dd51b76edc15613102fd1b826965b9aef094bb8eb3e36a96` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:3982869debe26c4d4ed9cd6a1e59e1de726e7040990b2575fab20e61e199aa9c` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-hub-operator-bundle-4-22@sha256:06b03bc2498ca84d9f65291633b0c277ad445c41d7520c04e9de0d7f00194588` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-csi-addons-operator-bundle-4-22@sha256:a76ec5d9d08b817ba019ebe82e230348b706407752c649424dca58553b10f439` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-csi-addons-operator-bundle-4-22@sha256:71aab2ca44fd97028df0595607ff6ecb279ef8af1b91825cba1c4db2c32bb5a0` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-csi-addons-operator-4-22@sha256:e5e3fd5773553468fe556319480023145db534815a8cbd54cd0faecd82f1c51e` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |
| `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-csi-addons-operator-4-22@sha256:bc1fa8f88e87b6dfc24a772b252fdd6d7e7d6a28356c4ddf2db0593c0c59d325` | Task 'buildah-remote-oci-ta' was not invoked with the hermetic parameter set | Make sure the task has the input parameter 'HERMETIC' set to 'true'. |

**Recommended Action:** Update pipeline configuration to set `HERMETIC=true` parameter for buildah-remote-oci-ta task in all component build pipelines.

---

### 2. `source_image.exists` - Source Image Reference Verification

**Title:** Exists  
**Severity:** CRITICAL  
**Affected Components:** 10

| ImageRef | Issue | Solution |
|----------|-------|----------|
| All multicluster operator images (5 variants) | No source image references found | Verify source container images are properly referenced in the build pipeline and accessible. |
| All hub operator images (2 variants) | No source image references found | Verify source container images are properly referenced in the build pipeline and accessible. |
| All CSI addons images (3 variants) | No source image references found | Verify source container images are properly referenced in the build pipeline and accessible. |

**Description:** Container images must have corresponding source image references for reproducibility and audit compliance.

---

### 3. `tasks.required_tasks_found` - Required Pipeline Tasks

**Title:** All required tasks were included in the pipeline  
**Severity:** CRITICAL  
**Affected Components:** 10

| ImageRef | Missing Task | Solution |
|----------|--------------|----------|
| All 10 affected images | One of "source-build", "source-build-oci-ta" tasks is missing | Ensure build pipeline includes either `source-build` or `source-build-oci-ta` task as per required-tasks configuration at https://conforma.dev/docs/cli/configuration.html#_data_sources |

**Description:** Build pipelines must include one of the required source build tasks for compliance tracking. Missing these tasks prevents proper attestation of the build process.

---

### 4. `test.no_skipped_tests` - Test Execution Compliance

**Title:** No tests were skipped  
**Severity:** CRITICAL  
**Affected Components:** 10

| ImageRef | Test Task | Reason | Solution |
|----------|-----------|--------|----------|
| All 10 affected images | sast-snyk-check-oci-ta | SAST test was skipped - likely missing Snyk license key | Ensure SAST_SNYK_LICENSE_KEY or equivalent credentials are available in the build environment for security scanning. |

**Description:** Skipped tests indicate missing prerequisites (like security license keys) and prevent proper security validation of container images.

---

### 5. `olm.allowed_registries` - OLM Bundle Registry Compliance

**Title:** Images referenced by OLM bundle are from allowed registries  
**Severity:** HIGH  
**Affected Components:** 6 (OLM bundle images)

| ImageRef | Problematic Image Reference | Solution |
|----------|---------------------------|----------|
| `rhdr-multicluster-operator-bundle-4-22` (both SHA variants) | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22:*` | Use images from approved registries OR modify policy configuration to include `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22` in `allowed_olm_image_registry_prefixes` |
| Same bundle | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramendr-console-4-22:*` | Use images from approved registries OR update policy configuration to whitelist registry prefix |
| `rhdr-hub-operator-bundle-4-22` (both SHA variants) | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramen-operator-base-image-4-22:*` | Add registry prefix to policy whitelist OR replace with approved registry |
| `rhdr-cluster-operator-bundle-4-22` (both SHA variants) | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramen-operator-base-image-4-22:*` | Add registry prefix to policy whitelist OR replace with approved registry |

**Description:** OLM bundles must only reference container images from pre-approved registries for security and compliance.

---

### 6. `olm.olm_bundle_multi_arch` - OLM Bundle Architecture

**Title:** OLM bundle images are not multi-arch  
**Severity:** MEDIUM  
**Affected Components:** 4 (OLM bundle images)

| ImageRef | Bundle Image | Solution |
|----------|-------------|----------|
| `rhdr-multicluster-operator-bundle-4-22@sha256:d9791872...` | Multi-arch reference detected | Rebuild bundle image for single architecture (e.g., `linux/amd64`). Do not create OCI image indexes for OLM bundles. |
| `rhdr-multicluster-operator-bundle-4-22@sha256:c77036cc...` | Multi-arch reference detected | Rebuild bundle image for single architecture. |
| `rhdr-hub-operator-bundle-4-22@sha256:06b03bc2...` | Multi-arch reference detected | Rebuild bundle image for single architecture. |
| `rhdr-csi-addons-operator-bundle-4-22@sha256:a76ec5d9...` | Multi-arch reference detected | Rebuild bundle image for single architecture. |

**Description:** OLM bundles must be single-architecture images, not multi-arch manifests or image indexes.

---

### 7. `olm.unpinned_references` - Image Pinning in OLM Bundles

**Title:** Unpinned images in OLM bundle  
**Severity:** HIGH  
**Affected Components:** 3 (bundle images)  
**Total Violations:** 8

| ImageRef | Unpinned Reference | Location | Solution |
|----------|-------------------|----------|----------|
| `rhdr-multicluster-operator-bundle-4-22@sha256:d9791872...` | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-multicluster-operator-image-4-22:73b21f34...` | spec.install.spec.deployments[0].spec.template.spec.containers[0].image | Update CSV to use digest-pinned reference (e.g., `image@sha256:...`) |
| Same bundle | Same image | spec.relatedImages[0].image | Update relatedImages section to include digest |
| Same bundle | `quay.io/redhat-user-workloads/rhdr-tenant/rhdr/rhdr-ramendr-console-4-22:8fa56d60...` | spec.install.spec.deployments[1].spec.template.spec.containers[0].image | Pinned image reference with digest required |
| Same bundle | Same console image | spec.relatedImages[1].image | Update relatedImages to pin digest |
| `rhdr-multicluster-operator-bundle-4-22@sha256:c77036cc...` | Same image references | Multiple locations | Pin all image references with digest (SHA256) |

**Description:** All image references in OLM CSV must be pinned to specific digests to ensure reproducibility and prevent unexpected updates.

---

### 8. `olm.unmapped_references` - Unmapped/Inaccessible Images

**Title:** Unmapped images in OLM bundle  
**Severity:** CRITICAL  
**Affected Components:** 2 (CSI addons operator bundle)  
**Total Violations:** 4

| ImageRef | Unmapped Image | Status | Solution |
|----------|----------------|--------|----------|
| `rhdr-csi-addons-operator-bundle-4-22@sha256:a76ec5d9...` | `registry.redhat.io/rh-ocp-dr/rhdr/rhdr-csi-addons-rhel9-operator@sha256:3e5a13fa...` | Not in snapshot or inaccessible | Add image to release snapshot OR verify CSV pullspec is valid and accessible |
| Same bundle | `registry.redhat.io/rh-ocp-dr/rhdr/rhdr-csi-addons-sidecar-rhel9@sha256:e77d943d...` | Not in snapshot or inaccessible | Add image to release snapshot OR verify pullspec validity |
| `rhdr-csi-addons-operator-bundle-4-22@sha256:71aab2ca...` | Same csi-addons-rhel9-operator image | Not accessible (401 Unauthorized) | Verify registry credentials and image availability |
| Same bundle | Same sidecar image | Not accessible | Check registry.redhat.io access permissions |

**Description:** Images referenced in OLM bundle must be in the release snapshot and accessible. Build logs show 401 Unauthorized errors for registry.redhat.io.

---

## Warnings Summary

### 1. `test.no_failed_informative_tests` - Failed Informative Tests

**Count:** 21 warnings across components

| Image Component | Failed Task | Impact |
|-----------------|-------------|--------|
| All components | coverity-availability-check | Coverity scan failed (likely service unavailable) |
| All components | sast-shell-check-oci-ta | Shell script scanning failed (informative, not blocking) |
| All components | ecosystem-cert-preflight-checks | Ecosystem certification checks failed |

**Action:** While informative, investigate these failures to improve security posture.

---

### 2. `test.no_test_warnings` - Tests with Warnings

**Count:** 2 warnings

| Image Component | Task | Issue |
|-----------------|------|-------|
| rhdr-multicluster-operator-image (both SHA) | deprecated-image-check | Deprecated image detected in pipeline |

**Action:** Review and update deprecated base images.

---

### 3. `trusted_task.current` - Outdated Tekton Tasks

**Count:** 36 warnings across all components

| Task Name | Current Version | Expiry Date | Action Required |
|-----------|-----------------|-------------|-----------------|
| build-image-index | 0.3 | 2026-07-19 | Update to sha256:b33bfa8d... |
| buildah-remote-oci-ta (build-images) | 0.9 | 2026-07-25 | Update to sha256:148347cf... |
| git-clone-oci-ta (clone-repository) | 0.1 | 2026-07-21 | Update to sha256:d30f13dd... |
| sast-shell-check-oci-ta | 0.1 | 2026-07-26 | Update to sha256:fc685d6f... |
| sast-snyk-check-oci-ta | 0.4 | 2026-07-25 | Update to sha256:8d794f3c... |
| sast-unicode-check-oci-ta | 0.4 | 2026-07-25 | Update to sha256:5807ffe3... |

**Action:** Update all Tekton tasks to latest versions before expiry dates to maintain compliance.

---

### 4. `olm.required_network_policy_rbac_for_operands` - Missing RBAC

**Count:** 1 warning

| Component | Issue | Solution |
|-----------|-------|----------|
| rhdr-multicluster-orchestrator (v4.22.0-86) | Missing NetworkPolicy RBAC permissions | Add RBAC rule granting create, delete, update/patch on `networking.k8s.io/networkpolicies` to ClusterServiceVersion, OR add operator to `operator_network_policy_rbac_exceptions` rule data |

**Impact:** Operator cannot manage network policies for its operands.

---

## Remediation Roadmap

### Priority 1: Critical Violations (Blocking)
1. **Hermetic Task Execution** - Update all pipelines to set `HERMETIC=true`
2. **Required Pipeline Tasks** - Add source-build or source-build-oci-ta tasks
3. **Test Skipping** - Configure SAST license keys in build environment
4. **Unmapped/Inaccessible Images** - Resolve registry.redhat.io authentication issues (401 errors)

### Priority 2: High Violations (Registry & Pinning)
5. **Registry Compliance** - Update policy to whitelist `quay.io/redhat-user-workloads` OR migrate images to approved registries
6. **Image Pinning** - Update all OLM CSVs to use digest-pinned image references
7. **OLM Bundle Architecture** - Rebuild bundle images as single-architecture

### Priority 3: Medium Issues (Warnings & RBAC)
8. **Tekton Task Updates** - Update all tasks to latest versions before expiry dates
9. **RBAC Configuration** - Add NetworkPolicy permissions to rhdr-multicluster-orchestrator
10. **Test Failures** - Investigate Coverity and ecosystem-cert-preflight failures

### Priority 4: Improvements
11. Address deprecated image warnings
12. Monitor and maintain security scanning compliance

---

## Summary Statistics

| Category | Count |
|----------|-------|
| Total Violations | 72 |
| Total Warnings | 112 |
| **Affected Components** | **11** |
| **Critical Violations** | **28** (hermetic, source_image, required_tasks, test.skipped, unmapped) |
| **High Severity** | **20** (registry, unpinned_references) |
| **Medium/Low** | **24** + **112 warnings** |

**Overall Status:** ❌ **BUILD FAILED** - Multiple critical compliance violations prevent release.

