# Konflux Trusted Tasks Reference

Complete technical reference for all Trusted Tasks used in the ODR/ODF Konflux pipeline, with parameter documentation and troubleshooting guidance.

---

## Table of Contents

1. [Overview](#overview)
2. [Task Reference](#task-reference)
3. [Task Versioning & Bundles](#task-versioning--bundles)
4. [OCI Artifact Format](#oci-artifact-format)
5. [Parameter Reference by Category](#parameter-reference-by-category)
6. [Troubleshooting by Task](#troubleshooting-by-task)

---

## Overview

### What Are Trusted Tasks?

Trusted Tasks are Tekton tasks that Konflux hosts in secure bundle registries. They are:

- ✅ **Pre-approved** by Konflux security team
- ✅ **Reproducible** - exact SHA pinning
- ✅ **Auditable** - origin tracked in Tekton ProvenanceData
- ✅ **SLSA-compliant** - used for security compliance
- ✅ **Version-controlled** - multiple versions available

### Why Use Them?

```
❌ Custom Task:
task:
  spec:
    steps:
    - image: some-random-image:latest
      command: ["/bin/bash", "-c", "echo $SECRET | curl..."]
    # Problem: No audit, not reproducible, security risk

✅ Trusted Task:
taskRef:
  params:
    - name: bundle
      value: quay.io/konflux-ci/tekton-catalog/task-build-image-index:0.3@sha256:...
    - name: kind
      value: task
  resolver: bundles
# Benefit: Auditable, reproducible, SLSA-compliant
```

### Task Catalog Location

All Konflux Trusted Tasks are published at:
```
Registry: quay.io
Organization: konflux-ci
Repository: tekton-catalog
Prefix: task-<name>:<version>@sha256:<digest>

Example:
quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:13d49df7dc9ae301627e45f95a236011422996152f1bea46cd60217b0f057407
```

---

## Task Reference

### 1. init

**Purpose**: Initialize Konflux build environment

**Location**: `quay.io/konflux-ci/tekton-catalog/task-init:0.4`

**Parameters**: None (usually)

**Inputs**:
- Working directory prepared by Tekton

**Outputs**:
- Configured build environment
- AUTH credentials (if available)

**Typical Usage**:
```yaml
- name: init
  taskRef:
    params:
      - name: name
        value: init
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-init:0.4@sha256:b797dd453ddad669365de6de4649e3a9e37e77aa26eb9862ca079a36cbfe64a4
      - name: kind
        value: task
    resolver: bundles
```

**Example Output**:
```
INFO: Initializing build environment
INFO: Detecting build tool: buildah
INFO: AUTH: Setting up container registry credentials
INFO: GOPATH: Configured for Go builds
```

---

### 2. git-clone-oci-ta

**Purpose**: Clone Git repository into OCI artifact storage

**Location**: `quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `url` | string | Yes | `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen` | Git repository URL |
| `revision` | string | Yes | `abc123def456...` | Git SHA, branch, or tag |
| `ociStorage` | string | Yes | `quay.io/rh-ocp-dr/ramen-hub-operator:latest.git` | Where to store OCI artifact |
| `ociArtifactExpiresAfter` | string | No | `24h` | How long to keep OCI artifact |
| `deleteExisting` | string | No | `true` | Remove previous clone artifacts |
| `httpProxy` | string | No | HTTP proxy URL for git | Only if network requires |
| `httpsProxy` | string | No | HTTPS proxy URL for git | Only if network requires |
| `noProxy` | string | No | Comma-separated no-proxy list | Network exclusions |
| `verbose` | string | No | `true` | Increase logging verbosity |
| `sparseCheckoutDirectories` | string | No | `cmd/ pkg/` | Clone specific dirs only |

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `SOURCE_ARTIFACT` | `quay.io/rh-ocp-dr/ramen-hub-operator:latest.git@sha256:abc...` | Immutable ref to cloned repo |
| `url` | `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen` | Canonical git URL |
| `commit` | `abc123def456...` | Resolved git SHA |
| `committer-date` | `2026-05-19T10:30:00Z` | Commit timestamp |
| `author` | `John Doe` | Commit author |

**Typical Usage**:
```yaml
- name: clone-repository
  params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.revision)
    - name: ociStorage
      value: $(params.output-image).git
    - name: ociArtifactExpiresAfter
      value: $(params.image-expires-after)
  taskRef:
    params:
      - name: name
        value: git-clone-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:13d49...
      - name: kind
        value: task
    resolver: bundles
  workspaces:
    - name: basic-auth
      workspace: git-auth
```

**Workspace**: `basic-auth` (optional)
- Expects `.gitconfig` or SSH keys for private repos
- Populated from Tekton Secret

---

### 3. prefetch-dependencies-oci-ta

**Purpose**: Pre-fetch build dependencies (Go modules, NPM packages, etc.) using Cachi2

**Location**: `quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta:0.3`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `input` | string | Yes | `{"type": "gomod", "path": "remote_source/app"}` | Prefetch configuration (JSON) |
| `SOURCE_ARTIFACT` | string | Yes | `quay.io/.../latest.git@sha256:...` | Source code OCI artifact |
| `ociStorage` | string | Yes | `quay.io/rh-ocp-dr/ramen:latest.prefetch` | Where to store prefetch artifact |
| `ociArtifactExpiresAfter` | string | No | `24h` | Artifact retention time |
| `dev-package-managers` | string | No | `true` | Include dev dependencies |
| `enable-package-registry-proxy` | string | Yes | `true` | Use Konflux package proxy |

**Input Configuration Examples**:

For Go modules:
```json
{"type": "gomod", "path": "remote_source/app"}
```

For npm:
```json
{"type": "npm", "path": "."}
```

For pip:
```json
{"type": "pip", "path": "."}
```

For yarn:
```json
{"type": "yarn", "path": "."}
```

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `SOURCE_ARTIFACT` | `quay.io/.../latest.prefetch@sha256:abc...` | Source + dependencies |
| `CACHI2_ARTIFACT` | `quay.io/.../latest.cachi2@sha256:def...` | Cached dependencies only |
| `CACHI2_ARTIFACT_HTTP_HEADERS` | Stringified JSON | HTTP cache headers |

**Cachi2 Details**:

Cachi2 is Red Hat's hermetic dependency prefetcher:
- Downloads dependencies in secure, isolated environment
- Creates reproducible artifact with all dependencies
- Injects at build time via `--mount=type=cache` in buildah
- Network-isolated (hermetic)

**Typical Usage**:
```yaml
- name: prefetch-dependencies
  params:
    - name: input
      value: '{"type": "gomod", "path": "remote_source/app"}'
    - name: SOURCE_ARTIFACT
      value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
    - name: ociStorage
      value: $(params.output-image).prefetch
    - name: dev-package-managers
      value: "true"
    - name: enable-package-registry-proxy
      value: "true"
  taskRef:
    params:
      - name: name
        value: prefetch-dependencies-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta:0.3@sha256:1b209c0d...
      - name: kind
        value: task
    resolver: bundles
  workspaces:
    - name: git-basic-auth
      workspace: git-auth
    - name: netrc
      workspace: netrc
```

**Supported Package Managers**:
- ✅ Go modules (`gomod`)
- ✅ npm (`npm`)
- ✅ pip (`pip`)
- ✅ yarn (`yarn`)
- ✅ Java Maven (`maven`)

---

### 4. buildah-remote-oci-ta

**Purpose**: Build container image using buildah, with remote multi-platform support

**Location**: `quay.io/konflux-ci/tekton-catalog/task-buildah-remote-oci-ta:0.9`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `IMAGE` | string | Yes | `quay.io/rh-ocp-dr/ramen-hub-operator:sha-abc123` | Output image reference |
| `DOCKERFILE` | string | Yes | `hub.Dockerfile` | Dockerfile path relative to CONTEXT |
| `CONTEXT` | string | Yes | `.` | Build context path |
| `HERMETIC` | string | No | `true` | Network-isolated build |
| `PREFETCH_INPUT` | string | No | `{"type": "gomod", "path": "..."}` | Dependency prefetch config |
| `IMAGE_EXPIRES_AFTER` | string | No | `5d` | Image retention time |
| `COMMIT_SHA` | string | No | `abc123def456...` | Git SHA for labels |
| `BUILD_ARGS` | array | No | `["KEY=value"]` | Buildah `--build-arg` values |
| `BUILD_ARGS_FILE` | string | No | `build-args.txt` | File with build arguments |
| `SOURCE_ARTIFACT` | string | Yes (if prefetch) | `quay.io/.../latest@sha256:...` | Source code artifact |
| `CACHI2_ARTIFACT` | string | Yes (if prefetch) | `quay.io/.../latest.cachi2@sha256:...` | Cached dependencies |
| `PLATFORM` | string | Yes (in matrix) | `linux/amd64` | Target platform |
| `IMAGE_APPEND_PLATFORM` | string | Yes | `true` | Append platform to image tag |
| `BUILDAH_FORMAT` | string | No | `oci` | Image format: oci or docker |
| `BUILD_STAGES_TARGET` | string | No | `runtime` | Target stage in multi-stage build |
| `DOCKERFILE_PATH` | string | No | `./Dockerfile` | Alternative dockerfile path |

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `IMAGE_REF` | `quay.io/.../image:sha-abc123-linux-amd64@sha256:...` | Full image reference with platform |
| `IMAGE_DIGEST` | `sha256:def456...` | Image digest |
| `BASE_IMAGE_DIGEST` | `sha256:base...` | Base image digest for tracking |
| `BUILD_RESULT` | `BUILT` | Success indicator |

**Matrix Execution**:

When used with matrix, creates parallel task for each platform:
```yaml
matrix:
  params:
    - name: PLATFORM
      value:
        - $(params.build-platforms)  # [linux/x86_64, linux/ppc64le, ...]
```

Each instance:
- Builds for specific PLATFORM
- Appends platform to IMAGE tag
- Runs in parallel (if cluster supports)
- Results in IMAGE_REF[*] array

**Cachi2 Integration**:

Buildah automatically injects Cachi2 artifact:
```
Inside container:
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,source=/tmp/cachi2,target=/tmp/cachi2 \
    go build -o manager cmd/main.go
```

**Typical Usage**:
```yaml
- name: build-images
  matrix:
    params:
      - name: PLATFORM
        value:
          - $(params.build-platforms)
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
      value: $(PLATFORM)
    - name: SOURCE_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.SOURCE_ARTIFACT)
    - name: CACHI2_ARTIFACT
      value: $(tasks.prefetch-dependencies.results.CACHI2_ARTIFACT)
    - name: IMAGE_APPEND_PLATFORM
      value: "true"
  taskRef:
    params:
      - name: name
        value: buildah-remote-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-buildah-remote-oci-ta:0.9@sha256:f667d1...
      - name: kind
        value: task
    resolver: bundles
```

---

### 5. build-image-index

**Purpose**: Create OCI Image Index from platform-specific images

**Location**: `quay.io/konflux-ci/tekton-catalog/task-build-image-index:0.3`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `IMAGE` | string | Yes | `quay.io/rh-ocp-dr/ramen-hub-operator` | Base image reference (without tag) |
| `ALWAYS_BUILD_INDEX` | string | No | `true` | Build index even for single image |
| `IMAGES` | array | Yes | `[image1@sha256:..., image2@sha256:...]` | Platform-specific images |
| `BUILDAH_FORMAT` | string | No | `oci` | Format: oci or docker |

**What It Does**:

1. Takes array of platform-specific images
2. Creates OCI Image Manifest Index (media type: application/vnd.docker.distribution.manifest.list.v2+json)
3. Each entry points to platform-specific image digest
4. Container runtimes automatically select correct platform

**Example Output**:

```
quay.io/rh-ocp-dr/ramen-hub-operator:v0.1.0 (Image Index)
├── manifests[0]:
│   └── mediaType: application/vnd.docker.container.image.v1+json
│   └── platform.architecture: amd64
│   └── platform.os: linux
│   └── digest: sha256:abc111...
├── manifests[1]:
│   └── mediaType: application/vnd.docker.container.image.v1+json
│   └── platform.architecture: ppc64le
│   └── platform.os: linux
│   └── digest: sha256:abc222...
├── manifests[2]:
│   └── mediaType: application/vnd.docker.container.image.v1+json
│   └── platform.architecture: s390x
│   └── platform.os: linux
│   └── digest: sha256:abc333...
└── manifests[3]:
    └── mediaType: application/vnd.docker.container.image.v1+json
    └── platform.architecture: arm64
    └── platform.os: linux
    └── digest: sha256:abc444...
```

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `IMAGE_URL` | `quay.io/rh-ocp-dr/ramen:v0.1.0` | Final multi-arch image URL |
| `IMAGE_DIGEST` | `sha256:indexdigest...` | Index manifest digest |
| `IMAGE_REF` | Full reference with digest | Complete image reference |

**Typical Usage**:
```yaml
- name: build-image-index
  params:
    - name: IMAGE
      value: $(params.output-image)
    - name: ALWAYS_BUILD_INDEX
      value: "true"
    - name: IMAGES
      value:
        - $(tasks.build-images.results.IMAGE_REF[*])
  taskRef:
    params:
      - name: name
        value: build-image-index
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-build-image-index:0.3@sha256:550afde...
      - name: kind
        value: task
    resolver: bundles
```

---

### 6. source-build-oci-ta

**Purpose**: Generate SBOM (Software Bill of Materials) and create source image

**Location**: `quay.io/konflux-ci/tekton-catalog/task-source-build-oci-ta:0.3`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `BINARY_IMAGE` | string | Yes | `quay.io/rh-ocp-dr/ramen:v0.1.0` | Binary image URL |
| `SOURCE_ARTIFACT` | string | Yes | `quay.io/.../latest@sha256:...` | Source code artifact |
| `CACHI2_ARTIFACT` | string | No | `quay.io/.../latest.cachi2@sha256:...` | Cached dependencies |
| `BINARY_IMAGE_DIGEST` | string | Yes | `sha256:bindigest...` | Binary image digest |
| `SBOM_FORMAT` | string | No | `spdx` | Format: spdx, cyclonedx |
| `SOURCE_ARTIFACT_EXPIRATION_TIME` | string | No | `5d` | Retention time |

**What It Does**:

1. Scans binary image for installed packages
2. Combines with source code info
3. Generates SBOM in SPDX or CycloneDX format
4. Creates "source image" containing:
   - Source code
   - Dependencies
   - SBOM document
   - Provenance metadata

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `SOURCE_IMAGE_URL` | `quay.io/.../source:v0.1.0` | Source image reference |
| `SOURCE_IMAGE_DIGEST` | `sha256:sourcedigest...` | Source image digest |
| `SBOM` | JSON/SPDX doc | Bill of Materials |
| `SBOM_LINK_TYPE` | `application/vnd.cyclonedx+json` | SBOM media type |

**Typical Usage**:
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
  taskRef:
    params:
      - name: name
        value: source-build-oci-ta
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-source-build-oci-ta:0.3@sha256:0917cfc...
      - name: kind
        value: task
    resolver: bundles
```

---

### 7. deprecated-base-image-check

**Purpose**: Validate base image is not deprecated or too old

**Location**: `quay.io/konflux-ci/tekton-catalog/task-deprecated-base-image-check:0.4`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `IMAGE_URL` | string | Yes | `quay.io/rh-ocp-dr/ramen:v0.1.0` | Image to check |
| `SKIP_CHECKS` | string | No | `false` | Skip validation |

**What It Does**:

1. Extracts base image reference from Dockerfile
2. Checks against list of deprecated images
3. Validates base image is recently updated
4. Fails build if base image too old or deprecated

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `BASE_IMAGE` | `registry.redhat.io/ubi9:latest` | Detected base image |
| `BASE_IMAGE_REPOSITORY` | `registry.redhat.io/ubi9` | Base image repo |
| `PASSED_TESTS` | `true` | Validation passed |

**Typical Usage**:
```yaml
- name: deprecated-base-image-check
  params:
    - name: IMAGE_URL
      value: $(tasks.build-image-index.results.IMAGE_URL)
  when:
    - input: $(params.skip-checks)
      operator: in
      values:
        - "false"
  taskRef:
    params:
      - name: name
        value: deprecated-base-image-check
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-deprecated-base-image-check:0.4@sha256:7f0e2a...
      - name: kind
        value: task
    resolver: bundles
```

---

### 8. image-scan

**Purpose**: Scan built image for security vulnerabilities

**Location**: `quay.io/konflux-ci/tekton-catalog/task-image-scan:0.8`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `IMAGE_URL` | string | Yes | `quay.io/rh-ocp-dr/ramen:v0.1.0` | Image to scan |
| `SKIP_CHECKS` | string | No | `false` | Skip scan |
| `EC_TASK_FAILURE_THRESHOLD` | string | No | `ERROR` | Fail on: CRITICAL, HIGH, ERROR, WARNING |

**What It Does**:

1. Scans image for known CVEs
2. Uses Trivy, Grype, or similar scanner
3. Checks against vulnerability databases
4. Fails build if vulnerabilities found above threshold

**Results**:

| Result | Example | Purpose |
|--------|---------|---------|
| `SCAN_RESULT` | `PASSED` | Scan result |
| `VULNERABILITIES_FOUND` | `[CVE-2026-1234, ...]` | List of CVEs |
| `CRITICAL_CVE_COUNT` | `0` | Count of critical CVEs |
| `HIGH_CVE_COUNT` | `2` | Count of high CVEs |

**Typical Usage**:
```yaml
- name: image-scan
  params:
    - name: IMAGE_URL
      value: $(tasks.build-image-index.results.IMAGE_URL)
    - name: EC_TASK_FAILURE_THRESHOLD
      value: "ERROR"  # Fail only on ERROR or CRITICAL
  when:
    - input: $(params.skip-checks)
      operator: in
      values:
        - "false"
  taskRef:
    params:
      - name: name
        value: image-scan
      - name: bundle
        value: quay.io/konflux-ci/tekton-catalog/task-image-scan:0.8@sha256:f7bef2...
      - name: kind
        value: task
    resolver: bundles
```

---

### 9. show-sbom

**Purpose**: Display SBOM results (informational, always runs)

**Location**: `quay.io/konflux-ci/tekton-catalog/task-show-sbom:0.1`

**Parameters**:

| Parameter | Type | Required | Example | Notes |
|-----------|------|----------|---------|-------|
| `IMAGE_URL` | string | Yes | `quay.io/rh-ocp-dr/ramen:v0.1.0` | Image reference |
| `SBOM_DOWNLOAD_DIR` | string | No | `/sbom` | Where to download SBOM |

**What It Does**:

1. Retrieves SBOM from image
2. Displays in human-readable format
3. (Informational only; doesn't affect build result)

**Typical Usage** (in `finally` section):
```yaml
finally:
  - name: show-sbom
    params:
      - name: IMAGE_URL
        value: $(tasks.build-image-index.results.IMAGE_URL)
    taskRef:
      params:
        - name: name
          value: show-sbom
        - name: bundle
          value: quay.io/konflux-ci/tekton-catalog/task-show-sbom:0.1@sha256:a7346...
        - name: kind
          value: task
      resolver: bundles
```

---

## Task Versioning & Bundles

### Version Strategy

Konflux Trusted Tasks use semantic versioning:

```
quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:abc...
                                                       ↑
                                                   version

0 = major (breaking changes)
1 = minor (features, non-breaking)
```

### SHA Pinning

Always pin to exact SHA digest, NOT just version:

```yaml
# ❌ Bad (floating version):
bundle: quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1

# ✅ Good (pinned SHA):
bundle: quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:13d49df7dc9ae301627e45f95a236011422996152f1bea46cd60217b0f057407
```

### Finding Latest SHAs

```bash
# Method 1: Quay.io UI
# Navigate: quay.io/konflux-ci/tekton-catalog
# Find task name and version
# Copy full reference with SHA

# Method 2: Docker CLI
docker inspect quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1
# Shows full digest

# Method 3: Skopeo (preferred for air-gapped)
skopeo inspect docker://quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1
```

---

## OCI Artifact Format

### Immutable References

OCI artifacts use immutable digest-based references:

```
quay.io/rh-ocp-dr/ramen-hub-operator:v0.1.0@sha256:abc123def456...
                                      ↑
                                   optional tag (mutable)
                                                   ↑
                                              digest (immutable)
```

### Creating OCI Artifact References

In tasks, OCI artifacts created by combining:

```yaml
# Base: $(params.output-image)
quay.io/rh-ocp-dr/ramen-hub-operator:{{revision}}

# With suffix added by task
.git          → source code artifact
.prefetch     → prefetch artifact  
.cachi2       → cachi2 dependencies

# Final OCI artifact:
quay.io/rh-ocp-dr/ramen-hub-operator:{{revision}}.git@sha256:abc...
quay.io/rh-ocp-dr/ramen-hub-operator:{{revision}}.cachi2@sha256:def...
quay.io/rh-ocp-dr/ramen-hub-operator:{{revision}}.prefetch@sha256:ghi...
```

### Artifact Expiration

OCI artifacts are temporary build intermediates:

```yaml
ociArtifactExpiresAfter: "24h"  # Clean up after 24 hours

Duration formats:
5m   = 5 minutes
2h   = 2 hours
7d   = 7 days
4w   = 4 weeks
```

---

## Parameter Reference by Category

### Build Configuration Parameters

| Parameter | Task | Type | Example |
|-----------|------|------|---------|
| `IMAGE` | buildah-remote-oci-ta | string | `quay.io/rh-ocp-dr/ramen:tag` |
| `DOCKERFILE` | buildah-remote-oci-ta | string | `hub.Dockerfile` |
| `CONTEXT` | buildah-remote-oci-ta | string | `.` |
| `PLATFORM` | buildah-remote-oci-ta | string | `linux/amd64` |
| `BUILD_ARGS` | buildah-remote-oci-ta | array | `["KEY=value"]` |
| `HERMETIC` | buildah-remote-oci-ta | string | `true`/`false` |

### Artifact Parameters

| Parameter | Task | Type | Example |
|-----------|------|------|---------|
| `SOURCE_ARTIFACT` | prefetch, buildah | string | `quay.io/.../src@sha256:...` |
| `CACHI2_ARTIFACT` | buildah, source-build | string | `quay.io/.../cachi2@sha256:...` |
| `ociStorage` | git-clone, prefetch | string | `quay.io/.../image.suffix` |
| `ociArtifactExpiresAfter` | all OCI tasks | string | `24h` |

### Git/Source Parameters

| Parameter | Task | Type | Example |
|-----------|------|------|---------|
| `url` | git-clone-oci-ta | string | `https://github.com/...` |
| `revision` | git-clone-oci-ta | string | `abc123def456...` |
| `sparseCheckoutDirectories` | git-clone-oci-ta | string | `cmd/ pkg/` |

### Dependency Parameters

| Parameter | Task | Type | Example |
|-----------|------|------|---------|
| `input` | prefetch-dependencies | string (JSON) | `{"type": "gomod", "path": "."}` |
| `dev-package-managers` | prefetch-dependencies | string | `true`/`false` |
| `enable-package-registry-proxy` | prefetch-dependencies | string | `true`/`false` |

### Image/Registry Parameters

| Parameter | Task | Type | Example |
|-----------|------|------|---------|
| `IMAGE_URL` | image-scan, show-sbom | string | `quay.io/rh-ocp-dr/ramen:tag` |
| `BUILDAH_FORMAT` | buildah, build-image-index | string | `oci`/`docker` |
| `IMAGE_EXPIRES_AFTER` | buildah, git-clone | string | `5d` |

---

## Troubleshooting by Task

### git-clone-oci-ta Failures

**Error**: "Failed to clone repository"
```
Solution:
1. Verify URL is correct and accessible
2. Check revision exists: git ls-remote <url> <revision>
3. Ensure git-auth workspace has credentials (if private repo)
4. Check network/firewall allows outbound git
```

**Error**: "OCI artifact storage full"
```
Solution:
1. Reduce ociArtifactExpiresAfter to clean up old artifacts
2. Check quay.io storage quota
3. Delete old artifact images manually
```

### prefetch-dependencies-oci-ta Failures

**Error**: "Module not found"
```
Solution:
1. Verify go.mod in the specified path exists
2. Check prefetch-input path is correct
3. Ensure packages are in public repositories
4. Review Cachi2 logs for actual error
```

**Error**: "Network timeout during prefetch"
```
Solution:
1. Increase task timeout
2. Check if enable-package-registry-proxy is true
3. Verify package repositories are accessible
4. Try with single package manager first
```

### buildah-remote-oci-ta Failures

**Error**: "Build failed: no Dockerfile found"
```
Solution:
1. Verify DOCKERFILE parameter matches actual file
2. Check CONTEXT parameter points to correct directory
3. List directory contents: ls -la Dockerfile
4. Use relative paths from repository root
```

**Error**: "HERMETIC build failed: network access"
```
Solution:
1. Disable hermetic mode (if temporary):
   HERMETIC: "false"
2. Fix Dockerfile to not need network:
   - Use Cachi2 for dependencies
   - Don't curl external resources in RUN
3. Add allowed domains to network policy
```

**Error**: "Source artifact not found"
```
Solution:
1. Verify SOURCE_ARTIFACT from prefetch-dependencies task
2. Check artifact hasn't expired
3. Ensure clone-repository task succeeded
4. Review OCI artifact retention settings
```

**Error**: "Multi-platform build stuck"
```
Solution:
1. Check multi-platform-controller is deployed:
   kubectl get deployment -n tekton-pipelines | grep multi
2. Verify remote build clusters are accessible
3. Try single platform build first:
   PLATFORM: linux/x86_64
4. Increase task timeout for remote builds
```

### build-image-index Failures

**Error**: "Platform-specific images missing"
```
Solution:
1. Verify build-images matrix completed
2. Check IMAGE_REF array from buildah task
3. Ensure each platform build succeeded
4. Review buildah logs for platform failures
```

### SLSA/EC Compliance Failures

**Error**: "trusted_task.trusted = FAIL"
```
Solution:
1. Ensure using Trusted Task (correct bundle ref)
2. Verify SHA digest is pinned (not floating version)
3. Check task version is approved by EC policy
4. Review EC policy configuration
```

**Error**: "image_signature = FAIL"
```
Solution:
1. Verify image is signed (signing keys configured)
2. Check image registry allows unsigned images
3. Ensure Tekton Chains is configured
4. Review signing task in pipeline
```

---

## Quick Copy-Paste References

### Minimal Trusted Task Reference

```yaml
taskRef:
  params:
    - name: name
      value: git-clone-oci-ta
    - name: bundle
      value: quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:13d49df7dc9ae301627e45f95a236011422996152f1bea46cd60217b0f057407
    - name: kind
      value: task
  resolver: bundles
```

### All Tasks Bundle References

```yaml
# init
quay.io/konflux-ci/tekton-catalog/task-init:0.4@sha256:b797dd453ddad669365de6de4649e3a9e37e77aa26eb9862ca079a36cbfe64a4

# git-clone-oci-ta
quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:13d49df7dc9ae301627e45f95a236011422996152f1bea46cd60217b0f057407

# prefetch-dependencies-oci-ta
quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta:0.3@sha256:1b209c0d93e52e418f3e6cd4b4fd915a84e4bd7f68e1cfd0d6446133540d7f43

# buildah-remote-oci-ta
quay.io/konflux-ci/tekton-catalog/task-buildah-remote-oci-ta:0.9@sha256:f667d1146533b1d49829c08097e31faf27db24563da576434a707353de62099f

# build-image-index
quay.io/konflux-ci/tekton-catalog/task-build-image-index:0.3@sha256:550afde50349e22ec11191ea0db9a49395ab46fef4e8317d820b6e946677ebeb

# source-build-oci-ta
quay.io/konflux-ci/tekton-catalog/task-source-build-oci-ta:0.3@sha256:0917cfc7772e82cb8e74743c2104f43bcf2596aceafe87eec6fce69a8cac5f06

# deprecated-base-image-check
quay.io/konflux-ci/tekton-catalog/task-deprecated-base-image-check:0.4@sha256:7f0e2a90c869c3339d6b1e57f39b83e27c53436fdfbe3767a8990e1f5113c9b7

# image-scan
quay.io/konflux-ci/tekton-catalog/task-image-scan:0.8@sha256:f7bef2b8f48f5a30fa2ed0ae0d33a8beae3affe7d58f7c3b29c5d1d60e62f9e4

# show-sbom
quay.io/konflux-ci/tekton-catalog/task-show-sbom:0.1@sha256:a7346ed61237db4f82ff782e0c9e8b30536e0e67b907ad600341a6d192e80012
```

---

## Summary

### Golden Rules

1. **Always use SHA pins** - Never float on version tags
2. **Understand OCI artifacts** - They're immutable and passed between tasks
3. **Enable hermetic mode** - For security and reproducibility
4. **Use Cachi2** - For dependency prefetching (not pip install)
5. **Handle matrix parallelization** - IMAGE_REF becomes array
6. **Check EC policies** - Understand what your policies require
7. **Test one platform first** - Debug before adding multi-platform

### Next Steps

- **Use these references** in your Tekton YAML
- **Pin all SHAs** before running pipelines
- **Test build task locally** with buildah before deploying
- **Monitor multi-platform builds** - They take longer

See [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md) to use these tasks in your pipelines.
