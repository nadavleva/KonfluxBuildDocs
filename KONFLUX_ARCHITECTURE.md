# ODR/ODF Konflux Architecture Deep Dive

Detailed technical analysis of how ODF successfully builds the downstream Ramen operator (called ODR) using Konflux, including Tekton pipeline configuration, Dockerfile architecture, and dist-git integration.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [ODR Pipeline Architecture](#odr-pipeline-architecture)
3. [Tekton Configuration Analysis](#tekton-configuration-analysis)
4. [Dockerfile Architecture](#dockerfile-architecture)
5. [Multi-Platform Build Strategy](#multi-platform-build-strategy)
6. [Dist-Git Integration](#dist-git-integration)
7. [OCI Artifact Chaining](#oci-artifact-chaining)
8. [Security & SLSA Compliance](#security--slsa-compliance)
9. [What Works & Why](#what-works--why)

---

## Executive Summary

### Why ODF's ODR Pipeline Works

The ODR pipeline succeeds because it:

1. **Uses ONLY Trusted Tasks** from Konflux Tekton catalog
2. **Builds inside Dockerfile** (not in raw Tekton tasks)
3. **Chains OCI artifacts** between tasks (no PVCs)
4. **Enables hermetic mode** for security/reproducibility
5. **Multi-platform first** with buildah-remote-oci-ta
6. **Properly integrates dist-git** for automation

### Key Pattern: Build Inside Container, Not In Pipeline

```
❌ WRONG (What Fails):
Tekton Task → Run "make build" → Fails security policy

✅ CORRECT (What ODR Does):
Tekton Task → Run Dockerfile → RUN "go build ..." → Success
```

---

## ODR Pipeline Architecture

### Overview Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                 ODR Konflux PipelineRun                         │
│                                                                 │
│  Trigger: push to rhodf-4.22-rhel-9 branch                    │
│  Output: Multi-arch operator image (x86_64, ppc64le, s390x)   │
│  Registry: quay.io/rhceph-dev/odf4-odr-rhel9-operator:TAG    │
└─────────────────────────────────────────────────────────────────┘
                              │
                 ┌────────────┼────────────┐
                 │            │            │
                 ▼            ▼            ▼
           ┌─────────┐  ┌──────────┐ ┌──────────────┐
           │  init   │  │   git    │ │  prefetch    │
           │ Trusted │  │  clone   │ │ dependencies │
           │  Task   │  │ OCI TA   │ │   OCI TA     │
           └─────────┘  └──────────┘ └──────────────┘
                              │             │
                              └──────┬──────┘
                                     │
                      ┌──────────────┼──────────────┐
                      │                             │
                      ▼                             ▼
            ┌──────────────────┐        ┌──────────────────┐
            │  build-images    │        │  build-images    │
            │ (multi-platform) │ MATRIX │  linux/ppc64le   │
            │  buildah-remote  │────┼───│  buildah-remote  │
            │  OCI TA          │    │   │  OCI TA          │
            └──────────────────┘    │   └──────────────────┘
                      │             │             │
                      └─────────────┼─────────────┘
                                    │
                                    ▼
                      ┌──────────────────────────┐
                      │  build-image-index       │
                      │  Create multi-arch index │
                      │  buildah                 │
                      └──────────────────────────┘
                                    │
                                    ▼
                      ┌──────────────────────────┐
                      │  source-build-oci-ta     │
                      │  Generate SBOM           │
                      │  Create source image     │
                      └──────────────────────────┘
                                    │
                 ┌──────────────────┼──────────────────┐
                 ▼                  ▼                  ▼
        ┌──────────────────┐ ┌─────────────┐ ┌──────────────┐
        │ deprecated-base  │ │ image-scan  │ │  show-sbom   │
        │ image-check      │ │   Check     │ │  Display     │
        └──────────────────┘ └─────────────┘ │  Results     │
                                             └──────────────┘
```

### Pipeline Execution Flow

**Duration**: ~6 hours (typical for multi-platform builds)

**Sequence**:
1. **init** → Initialize workspace (Konflux standard)
2. **clone-repository** → Fetch source via trusted git-clone-oci-ta
3. **prefetch-dependencies** → Cachi2 fetches Go modules hermetically
4. **build-images** → Matrix parallel builds for each platform:
   - linux/x86_64
   - linux/ppc64le
   - linux/s390x
   - linux/arm64
5. **build-image-index** → Merge platform-specific images into OCI index
6. **source-build-oci-ta** → Generate SBOM and source image
7. **deprecated-base-image-check** → Security scan
8. **image-scan** → SLSA compliance checks
9. **show-sbom** → Display results

---

## Tekton Configuration Analysis

### PipelineRun Metadata

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: odr-operator-4-22-on-push
  namespace: rhodf-tenant
  labels:
    appstudio.openshift.io/application: rhodf-4-22
    appstudio.openshift.io/component: odr-operator-4-22
    pipelines.appstudio.openshift.io/type: build
  annotations:
    build.appstudio.openshift.io/repo: https://gitlab.cee.redhat.com/rhodf/konflux/odr-operator/-/tree/{{revision}}
    build.appstudio.redhat.com/commit_sha: '{{revision}}'
    build.appstudio.redhat.com/target_branch: '{{target_branch}}'
    pipelinesascode.tekton.dev/on-cel-expression: event == "push" && target_branch == "rhodf-4.22-rhel-9"
```

**Key Elements**:
- **Namespace**: `rhodf-tenant` (downstream Konflux workspace)
- **Application**: `rhodf-4-22` (groups multiple components)
- **Component**: `odr-operator-4-22` (specific built artifact)
- **Type**: `build` (indicates build pipeline, not test)
- **Trigger**: CEL expression evaluates to true on push to specific branch

### Pipeline Parameters

```yaml
params:
  - name: git-url
    value: '{{source_url}}'
  - name: revision
    value: '{{revision}}'
  - name: output-image
    value: quay.io/rhceph-dev/odf4-odr-rhel9-operator:{{revision}}
  - name: build-platforms
    value:
      - linux/x86_64
      - linux/ppc64le
      - linux/s390x
      - linux/arm64
  - name: dockerfile
    value: Dockerfile
  - name: path-context
    value: .
  - name: hermetic
    value: "true"
  - name: prefetch-input
    value: '{"type": "gomod", "path": "remote_source/app"}'
  - name: build-source-image
    value: "true"
```

**Critical Parameters**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `output-image` | `quay.io/rhceph-dev/odf4-odr-rhel9-operator:{{revision}}` | Registry, repo, and tag (revision = git SHA) |
| `build-platforms` | [x86_64, ppc64le, s390x, arm64] | **Multi-platform**: builds on all 4 architectures |
| `hermetic` | "true" | **Network isolation**: No external network access during build |
| `prefetch-input` | `{"type": "gomod", "path": "remote_source/app"}` | **Cachi2 config**: Fetch Go modules from specific path |
| `build-source-image` | "true" | **SBOM**: Generate Software Bill of Materials |

### Task: git-clone-oci-ta (Trusted Task)

```yaml
- name: clone-repository
  taskRef:
    params:
      - name: name
        value: git-clone-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:...
      - name: kind
        value: task
    resolver: bundles
  params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.revision)
    - name: ociStorage
      value: $(params.output-image).git
    - name: ociArtifactExpiresAfter
      value: $(params.image-expires-after)
```

**What It Does**:
- Clones git repository to specified revision
- **Outputs to OCI artifact storage** (not filesystem PVC)
- Result available at: `$(tasks.clone-repository.results.SOURCE_ARTIFACT)`
- Expires after specified time to save registry space

**Why OCI Storage?**:
- No PVC bottlenecks
- Immutable artifact references
- SLSA provenance tracking
- Parallel task execution

### Task: prefetch-dependencies-oci-ta (Trusted Task)

```yaml
- name: prefetch-dependencies
  taskRef:
    params:
      - name: name
        value: prefetch-dependencies-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta:0.3@sha256:...
    resolver: bundles
  params:
    - name: input
      value: $(params.prefetch-input)  # {"type": "gomod", "path": "remote_source/app"}
    - name: SOURCE_ARTIFACT
      value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
    - name: ociStorage
      value: $(params.output-image).prefetch
    - name: dev-package-managers
      value: "true"
    - name: enable-package-registry-proxy
      value: $(params.enable-package-registry-proxy)
```

**What It Does**:
- **Cachi2** (Cachito) fetches Go module dependencies
- Runs in **hermetic/network-isolated** mode
- Path: `remote_source/app` (where go.mod is located)
- Outputs:
  - `SOURCE_ARTIFACT` - Source code with dependencies
  - `CACHI2_ARTIFACT` - Cached Go modules for build

**Why Cachi2?**:
- Hermetic dependency fetching (no surprises during build)
- Reproducible builds (same dependencies, same time)
- SLSA compliance (proves dependency provenance)

### Task: buildah-remote-oci-ta (Trusted Task - Matrix)

```yaml
- name: build-images
  matrix:
    params:
      - name: PLATFORM
        value:
          - $(params.build-platforms)  # Expands to [x86_64, ppc64le, s390x, arm64]
  taskRef:
    params:
      - name: name
        value: buildah-remote-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-buildah-remote-oci-ta:0.9@sha256:...
    resolver: bundles
  params:
    - name: IMAGE
      value: $(params.output-image)
    - name: DOCKERFILE
      value: $(params.dockerfile)
    - name: CONTEXT
      value: $(params.path-context)
    - name: HERMETIC
      value: $(params.hermetic)
    - name: PLATFORM
      value: $(PLATFORM)  # Each task instance gets one platform
    - name: SOURCE_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.SOURCE_ARTIFACT)
    - name: CACHI2_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.CACHI2_ARTIFACT)
    - name: IMAGE_APPEND_PLATFORM
      value: "true"
```

**What It Does**:
- **Builds container image for specific platform** (runs in parallel, one per platform)
- Uses `buildah` (rootless, secure container builder)
- Accesses source and cached modules from OCI artifacts
- Injects platform suffix into image tag (e.g., `-linux-amd64`)

**Matrix Parallelization**:
- Instead of 4 sequential builds, creates 4 parallel tasks:
  - `build-images[0]` → linux/x86_64
  - `build-images[1]` → linux/ppc64le
  - `build-images[2]` → linux/s390x
  - `build-images[3]` → linux/arm64
- All run simultaneously (if cluster resources allow)
- Dramatically reduces total pipeline time

### Task: build-image-index (Trusted Task)

```yaml
- name: build-image-index
  params:
    - name: IMAGE
      value: $(params.output-image)
    - name: ALWAYS_BUILD_INDEX
      value: $(params.build-image-index)
    - name: IMAGES
      value:
        - $(tasks.build-images.results.IMAGE_REF[*])  # All platform-specific images
    - name: BUILDAH_FORMAT
      value: $(params.buildah-format)
  runAfter:
    - build-images
  taskRef:
    params:
      - name: name
        value: build-image-index
```

**What It Does**:
- Takes all platform-specific images from matrix build
- Merges them into a **single OCI Image Index**
- OCI Index points to platform-specific image digests
- Container runtimes can automatically pick the right platform

**Example Output**:
```
quay.io/rhceph-dev/odf4-odr-rhel9-operator:abc123

├── Digest (Linux/amd64): sha256:111...
├── Digest (Linux/ppc64le): sha256:222...
├── Digest (Linux/s390x): sha256:333...
└── Digest (Linux/arm64): sha256:444...
```

### Task: source-build-oci-ta (Trusted Task)

```yaml
- name: build-source-image
  params:
    - name: BINARY_IMAGE
      value: $(tasks.build-image-index.results.IMAGE_URL)
    - name: SOURCE_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.SOURCE_ARTIFACT)
    - name: CACHI2_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.CACHI2_ARTIFACT)
    - name: BINARY_IMAGE_DIGEST
      value: $(tasks.build-image-index.results.IMAGE_DIGEST)
  when:
    - input: $(params.build-source-image)
      operator: in
      values:
        - "true"
```

**What It Does**:
- Generates **Software Bill of Materials (SBOM)**
- Creates **source image** (container image with source code)
- SBOM format: SPDX or CycloneDX
- Links source image to binary image digest
- Enables supply chain traceability

**Why Source Images?**:
- Compliance: Proves source code used to build
- Auditability: Full dependency tree available
- Security: Can scan source artifacts for vulnerabilities

---

## Dockerfile Architecture

### Multi-Stage Build Strategy

The ODR Dockerfile uses **3-stage build** pattern:

```dockerfile
# Stage 0: Policy Configuration
FROM registry.redhat.io/ubi9/ubi@sha256:... as policy
RUN update-crypto-policies --set DEFAULT:PQ

# Stage 1: Go Builder
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder@sha256:... as builder
ENV GOFLAGS=''
ENV GOMODCACHE=$GOCACHE/pkg/mod
COPY remote_source /src/remote_source
WORKDIR /src/remote_source/app
RUN go version | tee -a /go.version
RUN GOOS=linux go build -a -o manager cmd/main.go

# Stage 2: Runtime (Minimal)
FROM registry.redhat.io/ubi9/ubi-minimal@sha256:...
ENV OPBIN=/manager
COPY --from=policy /etc/crypto-policies /etc/crypto-policies
COPY --from=builder /src/remote_source/app/manager "$OPBIN"
COPY --from=builder /go.version /go.version
# ... Labels ...
RUN chmod +x "$OPBIN"
ENTRYPOINT ["/manager"]
```

### Why This Architecture?

| Stage | Purpose | Size |
|-------|---------|------|
| **policy** | Set FIPS-compliant crypto policies | Small |
| **builder** | Full Go build environment | Large (2GB+) |
| **runtime** | Minimal image with binary only | Small (50-100MB) |

**Benefits**:
- Final image is minimal (only binary + runtime)
- Build environment not in production image
- FIPS compliance built-in
- Red Hat-supported base images only

### Dockerfile Locations

In your ODR reference:
- **Single operator**: `Dockerfile` (used as-is)

For your RamenDR Standalone (TWO operators from same repo):
- **Hub operator**: `hub.Dockerfile` (to create)
- **Cluster operator**: `cluster.Dockerfile` (to create)

Both would follow the same 3-stage pattern but with different build outputs:

```dockerfile
# hub.Dockerfile
RUN GOOS=linux go build -a -o hub-manager ./cmd/hub/main.go

# cluster.Dockerfile
RUN GOOS=linux go build -a -o cluster-manager ./cmd/cluster/main.go
```

---

## Multi-Platform Build Strategy

### Why Multi-Platform?

ODR builds for 4 platforms:
- **linux/x86_64** - Intel/AMD servers (standard)
- **linux/ppc64le** - IBM Power servers (enterprise)
- **linux/s390x** - IBM System z mainframes (enterprise)
- **linux/arm64** - ARM servers (emerging)

### How It Works: buildah-remote-oci-ta

```
buildah-remote-oci-ta runs on Konflux multi-platform-controller

┌────────────────────────────────────────────┐
│  Konflux Hub (Default Cluster - x86_64)    │
│                                            │
│  └─ Matrix[0]: build-images[0]             │
│     └─ buildah-remote-oci-ta[0]            │
│        └─ Builds for linux/x86_64          │
│           └─ Output: image-x86_64:TAG      │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│  Remote Cluster 1 (ppc64le-capable)        │
│                                            │
│  └─ Matrix[1]: build-images[1]             │
│     └─ buildah-remote-oci-ta[1]            │
│        └─ Builds for linux/ppc64le         │
│           └─ Output: image-ppc64le:TAG     │
└────────────────────────────────────────────┘

[Similar for s390x and arm64...]

Final merge in build-image-index:
Image Index (TAG) = {x86_64, ppc64le, s390x, arm64}
```

### Configuration for Multi-Platform

In PipelineRun:
```yaml
params:
  - name: build-platforms
    value:
      - linux/x86_64
      - linux/ppc64le
      - linux/s390x
      - linux/arm64
```

Matrix expansion in task:
```yaml
matrix:
  params:
    - name: PLATFORM
      value:
        - $(params.build-platforms)  # Creates 4 parallel task instances
```

### Time Implications

- **Single platform build**: ~45 minutes
- **4-platform parallel build**: ~45 minutes (same, due to parallelization)
- **4-platform sequential build**: ~180 minutes (3x slower)

**Key**: Konflux multi-platform-controller enables true parallelization.

---

## Dist-Git Integration

### container.yaml (Downstream Configuration)

```yaml
---
image_build_method: imagebuilder
compose:
  pulp_repos: true
remote_source:
    repo: https://github.com/red-hat-storage/ramen  # Upstream source
    ref: 171a740c9c1ef772715738764cac2cd22a63ba55   # Git SHA
tags:
  - "v4.22"
  - "v4.22.0"
  - "4.22"
  - "4.22.0"
  - "v4.22.0-171a740c9c1ef772715738764cac2cd22a63ba55"
```

### What This Does

**image_build_method**: `imagebuilder`
- Specifies how to build: using imagebuilder (not direct buildah)
- Aligns with OSBS (Red Hat's build system)

**compose.pulp_repos**: `true`
- Uses Red Hat Pulp repository infrastructure
- Enables access to internal RPM repositories during build

**remote_source.repo**: `https://github.com/red-hat-storage/ramen`
- Points to upstream repository
- This is the canonical source

**remote_source.ref**: `171a740c9c1ef772715738764cac2cd22a63ba55`
- Git SHA pinning
- Ensures reproducible builds (not floating tags)

**tags**: Array of image tags
- Multiple tags for same image digest
- Enables version tracking (v4.22, v4.22.0, SHA-based tag)
- Container registry will store all tag references

### Dist-Git Automation Hook

When Konflux detects changes:

```
Commit to rhodf-4.22-rhel-9 branch
    ↓
PipelineRun trigger (CEL: event == "push" && target_branch == "...")
    ↓
Konflux pipeline executes (clone → prefetch → build → index → scan)
    ↓
Successful build outputs image digest to registry
    ↓
Dist-git automation (Tekton Pipeline Automation) creates:
    - NVR (Name-Version-Release) metadata
    - Tags image with product version info
    - Updates dist-git tracking
    ↓
ArgoCD GitOps deployment triggers (if configured)
```

---

## OCI Artifact Chaining

### Why Not PVCs?

Traditional Tekton uses PVCs (Persistent Volume Claims) to pass data between tasks:

```
❌ PVC Approach (Old, Konflux doesn't use):
Task 1 (clone) → Write to /workspace/source → PVC
Task 2 (build) → Read from /workspace/source → PVC

Problems:
- Single PVC bottleneck
- Sequential task execution
- No artifact signing/verification
- Difficult to scale horizontally
```

### OCI Artifact Solution (Konflux Standard)

```
✅ OCI Artifact Approach (Konflux Best Practice):
Task 1 (clone-repository)
    ↓ Outputs: SOURCE_ARTIFACT = quay.io/...@sha256:abc...
    ↓ (Immutable reference to source code container image)

Task 2 (prefetch-dependencies)
    ↓ Input: SOURCE_ARTIFACT
    ↓ Outputs: CACHI2_ARTIFACT = quay.io/...@sha256:def...
    ↓ (Immutable reference to cached modules image)

Task 3+ (build-images)
    ↓ Input: SOURCE_ARTIFACT, CACHI2_ARTIFACT
    ↓ Runs in parallel (no bottleneck)
    ↓ Outputs: IMAGE_REF = quay.io/...@sha256:ghi...
```

### Benefits

| Aspect | PVC | OCI Artifact |
|--------|-----|-------------|
| **Parallelization** | Sequential (PVC bottleneck) | Parallel (immutable refs) |
| **Artifact Signing** | Not supported | Full provenance tracking |
| **SLSA Compliance** | Difficult | Native support |
| **Horizontal Scaling** | Limited (local storage) | Unlimited (registry-based) |
| **Auditability** | Poor (filesystem) | Excellent (registry logs) |
| **Reproducibility** | Poor (mutable) | Excellent (immutable digests) |

### How It Works in Build Task

```yaml
- name: build-images
  params:
    - name: SOURCE_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.SOURCE_ARTIFACT)
      # Example: quay.io/konflux/build/source@sha256:abc...
    - name: CACHI2_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.CACHI2_ARTIFACT)
      # Example: quay.io/konflux/build/cachi2@sha256:def...
```

In the buildah-remote-oci-ta task:
1. Pulls SOURCE_ARTIFACT container (contains source code)
2. Extracts to filesystem for building
3. Pulls CACHI2_ARTIFACT container (contains Go modules)
4. Mounts into build environment
5. Runs `go build` with modules available
6. Creates binary image
7. Pushes result back to registry as IMAGE_REF

---

## Security & SLSA Compliance

### Enterprise Contract (EC) Policies

ODR pipeline passes EC policies because:

1. **All tasks are trusted** - From Konflux Tekton catalog
2. **No custom scripts** - No arbitrary shell code injection
3. **Immutable artifacts** - OCI artifact digests are tamper-proof
4. **Hermetic build** - Network isolated, reproducible
5. **SBOM generated** - Source image with full dependency tree
6. **Base image scanned** - deprecated-base-image-check task
7. **Image scanned** - image-scan task validates security

### SLSA Level Achievement

ODR achieves **SLSA L3** (Supply-chain Levels for Software Artifacts):

```
✅ SLSA L1: Basic provenance (what sources were used)
✅ SLSA L2: Version controlled sources (git SHA pinning)
✅ SLSA L3: Hardened builds (hermetic + trusted tasks)
   - Hermetic mode: Yes
   - Signed provenance: Yes
   - Trusted build process: Yes
   - Isolated execution: Yes
⏳ SLSA L4: Secure development (requires additional governance)
```

### Security Tasks in Pipeline

**deprecated-base-image-check**:
- Scans base image for deprecated components
- Ensures up-to-date security patches
- Fails build if base image too old

**image-scan**:
- Scans built image for vulnerabilities
- Uses Quay or other CVE database
- Can fail build if CVE severity too high (configurable)

**show-sbom**:
- Displays Software Bill of Materials
- SPDX or CycloneDX format
- Enables compliance scanning

---

## What Works & Why

### Why ODR Succeeds (Replicable Pattern)

| Factor | Why It Works |
|--------|-------------|
| **Trusted Tasks Only** | Konflux enforces SLSA compliance; custom code fails EC policy |
| **Dockerfile Build** | Go compilation happens in trusted container build context |
| **OCI Artifacts** | Immutable references enable parallelization & auditability |
| **Hermetic Mode** | Network isolation ensures reproducibility & security |
| **Multi-Platform** | Matrix parallelization keeps build time constant |
| **Dist-Git Integration** | Automation ensures consistent downstream releases |
| **SBOM Generation** | Compliance & auditability for enterprise deployments |

### What You MUST Copy for RamenDR Standalone

✅ **DO COPY**:
1. Task reference pattern (git-clone-oci-ta, buildah-remote-oci-ta, etc.)
2. OCI artifact chaining (SOURCE_ARTIFACT → CACHI2_ARTIFACT → IMAGE_REF)
3. Matrix parallelization for build-images
4. Hermetic mode configuration
5. Multi-platform build parameter
6. Dockerfile multi-stage pattern

❌ **DON'T COPY** (these are ODR-specific):
1. Exact image names (change to your registry/repos)
2. Exact git repository URL
3. Namespace name (use your rh-ocp-dr workspace)
4. Component labels (match your components)
5. Tag strategies (adjust for your versioning)

### Adaptation Strategy for RamenDR Standalone

Since you need **TWO operators from the SAME repository**:

```
Ramen Repository (Single Repo, Two Components)
├── cmd/
│   ├── main.go          (Could be generic or platform-specific)
│   ├── hub/main.go      (If hub-specific entry point exists)
│   └── cluster/main.go  (If cluster-specific entry point exists)
├── Dockerfile           (Generic or shared)
├── hub.Dockerfile       (Hub-specific build)
└── cluster.Dockerfile   (Cluster-specific build)
```

**Two components, same git repo, different Dockerfiles**:
- Component 1 (`ramen-hub-operator`): Uses `hub.Dockerfile`
- Component 2 (`ramen-cluster-operator`): Uses `cluster.Dockerfile`

Each gets its own:
- Konflux component definition
- `.tekton/ramen-hub-operator-on-push.yaml`
- `.tekton/ramen-cluster-operator-on-push.yaml`
- Unique output image registry

Both inherit the same secure Tekton pattern.

---

## Quick Reference: Critical Configuration

### Must-Have Parameters

```yaml
# Hermetic build (security)
hermetic: "true"

# Multi-platform
build-platforms:
  - linux/x86_64
  - linux/ppc64le
  - linux/s390x
  - linux/arm64

# Dependency prefetch
prefetch-input: '{"type": "gomod", "path": "remote_source/app"}'

# SBOM generation
build-source-image: "true"

# Timeout (6 hours for multi-platform)
timeouts:
  pipeline: 6h
```

### Must-Have Trusted Tasks

```
git-clone-oci-ta          v0.1
prefetch-dependencies-oci-ta v0.3
buildah-remote-oci-ta     v0.9
build-image-index         v0.3
source-build-oci-ta       v0.3
deprecated-base-image-check v0.3
image-scan                v0.8
```

### Must-Have Artifact Flows

```
clone-repository → SOURCE_ARTIFACT
    ↓
prefetch-dependencies → CACHI2_ARTIFACT
    ↓
build-images (matrix) → IMAGE_REF[] per platform
    ↓
build-image-index → IMAGE_URL (multi-arch)
    ↓
source-build-oci-ta → SBOM
```

---

## Summary: The ODR Success Formula

```
Trusted Tasks + Dockerfile Build + OCI Artifacts + Hermetic + Multi-Platform + SBOM
                                = SLSA L3 Compliant Build Pipeline
```

This is the exact formula you need to replicate for RamenDR Standalone.

Next: See [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md) for step-by-step instructions.
