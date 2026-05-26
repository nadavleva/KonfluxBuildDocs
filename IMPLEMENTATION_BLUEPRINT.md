# RamenDR Standalone - Implementation Blueprint

Step-by-step roadmap for implementing the RamenDR Standalone build infrastructure using Konflux, based on ODF/ODR architecture patterns.

---

## Table of Contents

1. [Implementation Overview](#implementation-overview)
2. [Phase 1: Foundation Setup](#phase-1-foundation-setup)
3. [Phase 2: Component Dockerfiles](#phase-2-component-dockerfiles)
4. [Phase 3: Tekton Pipelines](#phase-3-tekton-pipelines)
5. [Phase 4: Integration & Validation](#phase-4-integration--validation)
6. [Phase 5: OLM & Catalog (Future)](#phase-5-olm--catalog-future)
7. [Troubleshooting Guide](#troubleshooting-guide)

---

## Implementation Overview

### Current State
- ✅ ODF/ODR reference repo analyzed
- ✅ Multi-platform Tekton pattern documented
- ✅ Trusted tasks identified
- ❌ RamenDR workspace not yet configured

### Target State

```
Konflux Application: ramen-dr-standalone
├── Component 1: ramen-hub-operator
│   ├── Source: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
│   ├── Dockerfile: hub.Dockerfile
│   ├── Output: quay.io/rh-ocp-dr/ramen-hub-operator:TAG
│   └── .tekton/: ramen-hub-operator-on-push.yaml
│
├── Component 2: ramen-cluster-operator
│   ├── Source: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
│   ├── Dockerfile: cluster.Dockerfile
│   ├── Output: quay.io/rh-ocp-dr/ramen-cluster-operator:TAG
│   └── .tekton/: ramen-cluster-operator-on-push.yaml
│
└── Component 3: ramen-console-ui
    ├── Source: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console
    ├── Dockerfile: Dockerfile
    ├── Output: quay.io/rh-ocp-dr/ramen-console-ui:TAG
    └── .tekton/: ramen-console-ui-on-push.yaml
```

### Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Foundation | 1-2 hours | ⏳ To Start |
| Phase 2: Dockerfiles | 2-3 hours | ⏳ To Start |
| Phase 3: Tekton Pipelines | 4-6 hours | ⏳ To Start |
| Phase 4: Integration & Validation | 3-4 hours | ⏳ To Start |
| Phase 5: OLM & Catalog | 2+ weeks | 🔮 Future |
| **Total Phase 1-4** | **10-15 hours** | |

---

## Phase 1: Foundation Setup

### 1.1 Verify Konflux Workspace Access

**Goal**: Ensure you have access to the Konflux workspace and can deploy components.

**Steps**:

```bash
# 1. Check current context
kubectl config current-context
# Expected output: konflux-cluster or similar

# 2. Verify namespace exists
kubectl get namespace rh-ocp-dr
# Expected: STATUS Active

# 3. Check ApplicationStudio console access
# Navigate to: https://console.redhat.com/preview/hac/teams (or your Konflux instance)
# Verify: Can see/create Applications and Components
```

**Validation**:
- [ ] kubectl shows correct context
- [ ] `rh-ocp-dr` namespace exists
- [ ] Can access ApplicationStudio console
- [ ] User has "owner" or "admin" role in namespace

### 1.2 Repository Preparation

**Goal**: Ensure all three repositories are in correct state for Konflux integration.

#### Repository 1: Ramen Operators (`https://gitlab.cee.redhat.com/rh-ocp-dr/ramen`)

**Verify structure**:
```bash
cd /home/nlevanon/workspace/RamenDRStandAlone/ramen

# Check for Go modules
ls -la go.mod go.sum remote_source/

# Verify build structure (if hub/cluster are separate)
find cmd -name main.go

# Check for existing Dockerfile
ls -la Dockerfile
```

**Expected structure**:
```
ramen/
├── go.mod
├── go.sum
├── cmd/
│   ├── main.go          (or hub/cluster specific)
│   ├── hub/
│   │   └── main.go      (if separate)
│   └── cluster/
│       └── main.go      (if separate)
├── Dockerfile           (existing)
├── remote_source/
│   ├── cachito.env
│   └── app/             (for prefetching)
└── .tekton/             (to create)
    ├── ramen-hub-operator-on-push.yaml (to create)
    └── ramen-cluster-operator-on-push.yaml (to create)
```

#### Repository 2: Console UI (`https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console`)

**Verify structure**:
```bash
cd /home/nlevanon/workspace/RamenDRStandAlone/ramen-console

# Check for build files
ls -la Dockerfile package.json tsconfig.json

# Check structure
find packages -type d -name "*mco*" -o -name "*ramen*"
```

**Expected structure**:
```
ramen-console/
├── Dockerfile           (for UI plugin image)
├── package.json
├── tsconfig.json
├── packages/
│   ├── mco/             (MCO/RamenDR plugin)
│   └── ...
└── .tekton/             (to create)
    └── ramen-console-ui-on-push.yaml (to create)
```

### 1.3 Understand Current Build Structure

**Goal**: Determine if Hub/Cluster are built from same entry point or separate.

**Research questions**:

1. **Are Hub and Cluster built from same Go binary?**
   ```bash
   grep -r "func main" cmd/main.go
   # If yes: single binary with feature flags
   # If no: separate entry points
   ```

2. **Do they share build flags?**
   ```bash
   grep -r "LDFLAGS\|ldflags" Makefile Dockerfile .
   # Look for hub-specific vs cluster-specific flags
   ```

3. **What's the current build command?**
   ```bash
   cat Dockerfile | grep -i "go build"
   # Check if any flags differentiate hub vs cluster
   ```

**Determine build strategy**:

| Scenario | Approach |
|----------|----------|
| Single binary, feature-flagged | Create hub.Dockerfile and cluster.Dockerfile with build flags |
| Separate entry points (hub/main.go, cluster/main.go) | Create separate Dockerfiles targeting different cmd paths |
| Makefile-driven builds | Move Makefile commands into Dockerfile RUN statements |

### 1.4 Create Konflux Application Definition

**Goal**: Define the RamenDR Standalone application in Konflux.

**Steps**:

1. **Via ApplicationStudio Console** (Recommended):
   - Navigate to: https://console.redhat.com/preview/hac/teams
   - Click: "Create Application"
   - Application name: `ramen-dr-standalone`
   - Namespace: `rh-ocp-dr`
   - Description: "RamenDR Standalone - Hub and Cluster operators with console UI"
   - Leave components empty (will add in next phase)

2. **Via kubectl** (Alternative):
   ```bash
   cat > /tmp/application.yaml <<'EOF'
   apiVersion: appstudio.redhat.com/v1alpha1
   kind: Application
   metadata:
     name: ramen-dr-standalone
     namespace: rh-ocp-dr
   spec:
     displayName: RamenDR Standalone
     description: Hub and Cluster operators with console UI
   EOF
   
   kubectl apply -f /tmp/application.yaml
   ```

**Validation**:
- [ ] Application created in Konflux
- [ ] Visible in ApplicationStudio console
- [ ] Namespace is `rh-ocp-dr`

---

## Phase 2: Component Dockerfiles

### 2.1 Create hub.Dockerfile

**Goal**: Define container build for Hub Operator with proper multi-stage pattern.

**File path**: `/home/nlevanon/workspace/RamenDRStandAlone/ramen/hub.Dockerfile`

**Determine build entry point** (from research in 1.3):
- If separate file: `cmd/hub/main.go` 
- If flags-based: `cmd/main.go` with HUB_MODE=true or similar
- If combined: `cmd/main.go` with runtime detection

**Template for hub.Dockerfile**:

```dockerfile
# Stage 0: Policy Configuration
FROM registry.redhat.io/ubi9/ubi@sha256:8ca59004c1c505bdabadd5202bd3363986f5bf873fcfb36f60561d7362fe52a7 as policy

RUN update-crypto-policies --set DEFAULT:PQ

# Stage 1: Go Builder
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder@sha256:977bd041377a1367c8b102a460ae8e63f89905f7cf9d8235484ae658c9b47646 as builder

ENV GOFLAGS=''
ENV GOMODCACHE=$GOCACHE/pkg/mod

COPY remote_source /src/remote_source

WORKDIR /src/remote_source/app

RUN go version | tee -a /go.version

# BUILD FOR HUB OPERATOR
# Adjust the following based on your actual hub entry point:
RUN GOOS=linux go build -a -o hub-manager cmd/hub/main.go
# OR if using feature flags:
# RUN GOOS=linux go build -a -ldflags "-X main.OperatorMode=hub" -o hub-manager cmd/main.go

# Stage 2: Runtime (Minimal)
FROM registry.redhat.io/ubi9/ubi-minimal@sha256:12db9874bd753eb98b1ab3d840e75de5d6842ac0604fbd68c012adefe97140be

ENV OPBIN=/hub-manager

COPY --from=policy /etc/crypto-policies /etc/crypto-policies
COPY --from=builder /src/remote_source/app/hub-manager "$OPBIN"
COPY --from=builder /go.version /go.version

LABEL maintainer="RamenDR Team"
LABEL com.redhat.component="ramen-hub-operator-container"
LABEL name="rh-ocp-dr/ramen-hub-operator"
LABEL version="v0.1.0"
LABEL description="OpenShift RamenDR Hub Operator"
LABEL summary="Provides Hub Operator for RamenDR disaster recovery"
LABEL io.k8s.display-name="RamenDR Hub Operator"

RUN chmod +x "$OPBIN"

ENTRYPOINT ["/hub-manager"]

# Include Dockerfile in image for supply chain transparency
COPY hub.Dockerfile /root/buildinfo/Dockerfile
```

**Key adjustments needed**:

1. **Replace**: `cmd/hub/main.go` with actual hub entry point
2. **Replace**: `hub-manager` with actual binary name if different
3. **Replace**: Labels with your metadata
4. **Verify**: Base image SHAs are current (check for updates)

### 2.2 Create cluster.Dockerfile

**Goal**: Define container build for Cluster Operator.

**File path**: `/home/nlevanon/workspace/RamenDRStandAlone/ramen/cluster.Dockerfile`

**Template for cluster.Dockerfile**:

```dockerfile
# Stage 0: Policy Configuration
FROM registry.redhat.io/ubi9/ubi@sha256:8ca59004c1c505bdabadd5202bd3363986f5bf873fcfb36f60561d7362fe52a7 as policy

RUN update-crypto-policies --set DEFAULT:PQ

# Stage 1: Go Builder
FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder@sha256:977bd041377a1367c8b102a460ae8e63f89905f7cf9d8235484ae658c9b47646 as builder

ENV GOFLAGS=''
ENV GOMODCACHE=$GOCACHE/pkg/mod

COPY remote_source /src/remote_source

WORKDIR /src/remote_source/app

RUN go version | tee -a /go.version

# BUILD FOR CLUSTER OPERATOR
# Adjust the following based on your actual cluster entry point:
RUN GOOS=linux go build -a -o cluster-manager cmd/cluster/main.go
# OR if using feature flags:
# RUN GOOS=linux go build -a -ldflags "-X main.OperatorMode=cluster" -o cluster-manager cmd/main.go

# Stage 2: Runtime (Minimal)
FROM registry.redhat.io/ubi9/ubi-minimal@sha256:12db9874bd753eb98b1ab3d840e75de5d6842ac0604fbd68c012adefe97140be

ENV OPBIN=/cluster-manager

COPY --from=policy /etc/crypto-policies /etc/crypto-policies
COPY --from=builder /src/remote_source/app/cluster-manager "$OPBIN"
COPY --from=builder /go.version /go.version

LABEL maintainer="RamenDR Team"
LABEL com.redhat.component="ramen-cluster-operator-container"
LABEL name="rh-ocp-dr/ramen-cluster-operator"
LABEL version="v0.1.0"
LABEL description="OpenShift RamenDR Cluster Operator"
LABEL summary="Provides Cluster Operator for RamenDR disaster recovery"
LABEL io.k8s.display-name="RamenDR Cluster Operator"

RUN chmod +x "$OPBIN"

ENTRYPOINT ["/cluster-manager"]

# Include Dockerfile in image for supply chain transparency
COPY cluster.Dockerfile /root/buildinfo/Dockerfile
```

### 2.3 Verify/Adapt Console Dockerfile

**Goal**: Ensure Console Dockerfile follows Konflux patterns.

**File path**: `/home/nlevanon/workspace/RamenDRStandAlone/ramen-console/Dockerfile`

**Check existing structure**:
```bash
head -50 ramen-console/Dockerfile
```

**Expected pattern** (Node.js/React project):
```dockerfile
# Stage 1: Build
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json .
RUN npm ci --only=production
COPY . .
RUN npm run build

# Stage 2: Runtime
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/node_modules /app/node_modules
EXPOSE 3000
CMD ["npm", "start"]
```

**Validation**:
- [ ] Multi-stage build pattern
- [ ] Uses Red Hat base image (or standard maintained image)
- [ ] No excessive layer bloat
- [ ] Dependencies locked in lock file

### 2.4 Create container.yaml Files

**Goal**: Define dist-git configuration for each component.

#### File 1: `/home/nlevanon/workspace/RamenDRStandAlone/ramen/container.yaml`

```yaml
---
image_build_method: imagebuilder
compose:
  pulp_repos: true
remote_source:
    repo: https://github.com/nicknevin/ramen  # Or your fork
    ref: destinfo  # Branch or specific SHA
tags:
  - "v0.1.0"
  - "latest"
  # Add more version tags as appropriate
```

#### File 2: `/home/nlevanon/workspace/RamenDRStandAlone/ramen-console/container.yaml`

```yaml
---
image_build_method: imagebuilder
compose:
  pulp_repos: true
remote_source:
    repo: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console
    ref: main  # Or your default branch
tags:
  - "v0.1.0"
  - "latest"
```

---

## Phase 3: Tekton Pipelines

### 3.1 Create ramen-hub-operator-on-push.yaml

**Goal**: Define Tekton PipelineRun for Hub Operator multi-platform build.

**File path**: `/home/nlevanon/workspace/RamenDRStandAlone/ramen/.tekton/ramen-hub-operator-on-push.yaml`

**Template**:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  annotations:
    build.appstudio.openshift.io/repo: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen/-/tree/{{revision}}
    build.appstudio.redhat.com/commit_sha: '{{revision}}'
    build.appstudio.redhat.com/target_branch: '{{target_branch}}'
    pipelinesascode.tekton.dev/cancel-in-progress: "false"
    pipelinesascode.tekton.dev/max-keep-runs: "3"
    pipelinesascode.tekton.dev/on-cel-expression: event == "push" && target_branch == "main"
  creationTimestamp:
  labels:
    appstudio.openshift.io/application: ramen-dr-standalone
    appstudio.openshift.io/component: ramen-hub-operator
    pipelines.appstudio.openshift.io/type: build
  name: ramen-hub-operator-on-push
  namespace: rh-ocp-dr
spec:
  timeouts:
    pipeline: 6h
  params:
    - name: git-url
      value: '{{source_url}}'
    - name: revision
      value: '{{revision}}'
    - name: output-image
      value: quay.io/rh-ocp-dr/ramen-hub-operator:{{revision}}
    - name: build-platforms
      value:
        - linux/x86_64
        - linux/ppc64le
        - linux/s390x
        - linux/arm64
    - name: dockerfile
      value: hub.Dockerfile
    - name: path-context
      value: .
    - name: hermetic
      value: "true"
    - name: prefetch-input
      value: '{"type": "gomod", "path": "remote_source/app"}'
    - name: build-source-image
      value: "true"
  pipelineSpec:
    description: |
      RamenDR Hub Operator build pipeline using Konflux Trusted Tasks.
      Builds multi-platform container image (x86_64, ppc64le, s390x, arm64).
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
              value: quay.io/konflux-ci/tekton-catalog/task-show-sbom:0.1@sha256:a7346ed61237db4f82ff782e0c9e8b30536e0e67b907ad600341a6d192e80012
            - name: kind
              value: task
          resolver: bundles
    params:
      - description: Source Repository URL
        name: git-url
        type: string
      - default: ""
        description: Revision of the Source Repository
        name: revision
        type: string
      - description: Fully Qualified Output Image
        name: output-image
        type: string
      - default: .
        description: Path to the source code of an application's component
        name: path-context
        type: string
      - default: Dockerfile
        description: Path to the Dockerfile
        name: dockerfile
        type: string
      - default: "false"
        description: Skip checks against built image
        name: skip-checks
        type: string
      - default: "false"
        description: Execute the build with network isolation
        name: hermetic
        type: string
      - default: ""
        description: Build dependencies to be prefetched by Cachi2
        name: prefetch-input
        type: string
      - default: ""
        description: Image tag expiration time
        name: image-expires-after
      - default: "false"
        description: Build a source image
        name: build-source-image
        type: string
      - default: "true"
        description: Add built image into an OCI image index
        name: build-image-index
        type: string
      - default: []
        description: Array of --build-arg values for buildah
        name: build-args
        type: array
      - default: ""
        description: Path to a file with build arguments for buildah
        name: build-args-file
        type: string
      - default:
          - linux/x86_64
        description: List of platforms to build
        name: build-platforms
        type: array
      - name: buildah-format
        default: oci
        type: string
      - name: enable-package-registry-proxy
        default: 'true'
        type: string
    results:
      - description: ""
        name: IMAGE_URL
        value: $(tasks.build-image-index.results.IMAGE_URL)
      - description: ""
        name: IMAGE_DIGEST
        value: $(tasks.build-image-index.results.IMAGE_DIGEST)
      - description: ""
        name: CHAINS-GIT_URL
        value: $(tasks.clone-repository.results.url)
      - description: ""
        name: CHAINS-GIT_COMMIT
        value: $(tasks.clone-repository.results.commit)
    tasks:
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
        runAfter:
          - init
        taskRef:
          params:
            - name: name
              value: git-clone-oci-ta
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-git-clone-oci-ta:0.1@sha256:13d49df7dc9ae301627e45f95a236011422996152f1bea46cd60217b0f057407
            - name: kind
              value: task
          resolver: bundles
        workspaces:
          - name: basic-auth
            workspace: git-auth
      - name: prefetch-dependencies
        params:
          - name: input
            value: $(params.prefetch-input)
          - name: SOURCE_ARTIFACT
            value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
          - name: ociStorage
            value: $(params.output-image).prefetch
          - name: ociArtifactExpiresAfter
            value: $(params.image-expires-after)
          - name: dev-package-managers
            value: "true"
          - name: enable-package-registry-proxy
            value: $(params.enable-package-registry-proxy)
        runAfter:
          - clone-repository
        taskRef:
          params:
            - name: name
              value: prefetch-dependencies-oci-ta
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-prefetch-dependencies-oci-ta:0.3@sha256:1b209c0d93e52e418f3e6cd4b4fd915a84e4bd7f68e1cfd0d6446133540d7f43
            - name: kind
              value: task
          resolver: bundles
        workspaces:
          - name: git-basic-auth
            workspace: git-auth
          - name: netrc
            workspace: netrc
      - matrix:
          params:
            - name: PLATFORM
              value:
                - $(params.build-platforms)
        name: build-images
        params:
          - name: IMAGE
            value: $(params.output-image)
          - name: DOCKERFILE
            value: $(params.dockerfile)
          - name: CONTEXT
            value: $(params.path-context)
          - name: HERMETIC
            value: $(params.hermetic)
          - name: PREFETCH_INPUT
            value: $(params.prefetch-input)
          - name: IMAGE_EXPIRES_AFTER
            value: $(params.image-expires-after)
          - name: COMMIT_SHA
            value: $(tasks.clone-repository.results.commit)
          - name: BUILD_ARGS
            value:
              - $(params.build-args[*])
          - name: BUILD_ARGS_FILE
            value: $(params.build-args-file)
          - name: SOURCE_ARTIFACT
            value: $(tasks.prefetch-dependencies.results.SOURCE_ARTIFACT)
          - name: CACHI2_ARTIFACT
            value: $(tasks.prefetch-dependencies.results.CACHI2_ARTIFACT)
          - name: IMAGE_APPEND_PLATFORM
            value: "true"
          - name: BUILDAH_FORMAT
            value: $(params.buildah-format)
        runAfter:
          - prefetch-dependencies
        taskRef:
          params:
            - name: name
              value: buildah-remote-oci-ta
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-buildah-remote-oci-ta:0.9@sha256:f667d1146533b1d49829c08097e31faf27db24563da576434a707353de62099f
            - name: kind
              value: task
          resolver: bundles
      - name: build-image-index
        params:
          - name: IMAGE
            value: $(params.output-image)
          - name: ALWAYS_BUILD_INDEX
            value: $(params.build-image-index)
          - name: IMAGES
            value:
              - $(tasks.build-images.results.IMAGE_REF[*])
          - name: BUILDAH_FORMAT
            value: $(params.buildah-format)
        runAfter:
          - build-images
        taskRef:
          params:
            - name: name
              value: build-image-index
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-build-image-index:0.3@sha256:550afde50349e22ec11191ea0db9a49395ab46fef4e8317d820b6e946677ebeb
            - name: kind
              value: task
          resolver: bundles
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
        runAfter:
          - build-image-index
        taskRef:
          params:
            - name: name
              value: source-build-oci-ta
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-source-build-oci-ta:0.3@sha256:0917cfc7772e82cb8e74743c2104f43bcf2596aceafe87eec6fce69a8cac5f06
            - name: kind
              value: task
          resolver: bundles
        when:
          - input: $(params.build-source-image)
            operator: in
            values:
              - "true"
      - name: deprecated-base-image-check
        params:
          - name: IMAGE_URL
            value: $(tasks.build-image-index.results.IMAGE_URL)
        runAfter:
          - build-image-index
        taskRef:
          params:
            - name: name
              value: deprecated-base-image-check
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-deprecated-base-image-check:0.4@sha256:7f0e2a90c869c3339d6b1e57f39b83e27c53436fdfbe3767a8990e1f5113c9b7
            - name: kind
              value: task
          resolver: bundles
        when:
          - input: $(params.skip-checks)
            operator: in
            values:
              - "false"
      - name: image-scan
        params:
          - name: IMAGE_URL
            value: $(tasks.build-image-index.results.IMAGE_URL)
        runAfter:
          - build-image-index
        taskRef:
          params:
            - name: name
              value: image-scan
            - name: bundle
              value: quay.io/konflux-ci/tekton-catalog/task-image-scan:0.8@sha256:f7bef2b8f48f5a30fa2ed0ae0d33a8beae3affe7d58f7c3b29c5d1d60e62f9e4
            - name: kind
              value: task
          resolver: bundles
        when:
          - input: $(params.skip-checks)
            operator: in
            values:
              - "false"
    workspaces:
      - name: git-auth
        optional: true
      - name: netrc
        optional: true
```

### 3.2 Create ramen-cluster-operator-on-push.yaml

**Goal**: Create identical pipeline for Cluster Operator (different Dockerfile, component labels).

**File path**: `/home/nlevanon/workspace/RamenDRStandAlone/ramen/.tekton/ramen-cluster-operator-on-push.yaml`

**Changes from hub version**:
- `name: ramen-cluster-operator-on-push`
- `component: ramen-cluster-operator`
- `output-image: quay.io/rh-ocp-dr/ramen-cluster-operator:{{revision}}`
- `dockerfile: cluster.Dockerfile`

**Simplest approach**: Copy `ramen-hub-operator-on-push.yaml` and replace:
```bash
sed -i 's/ramen-hub-operator/ramen-cluster-operator/g' ramen-cluster-operator-on-push.yaml
sed -i 's/hub.Dockerfile/cluster.Dockerfile/g' ramen-cluster-operator-on-push.yaml
```

### 3.3 Create ramen-console-ui-on-push.yaml

**Goal**: Create pipeline for Console UI (different repo, probably Node.js not Go).

**File path**: `/home/nlevanon/workspace/RamenDRStandAlone/ramen-console/.tekton/ramen-console-ui-on-push.yaml`

**Note**: This might be simpler (no Go prefetch needed). Copy the hub version and adjust:

```yaml
# Key changes:
- name: ramen-console-ui-on-push
- component: ramen-console-ui
- output-image: quay.io/rh-ocp-dr/ramen-console-ui:{{revision}}
- dockerfile: Dockerfile
- REMOVE: prefetch-dependencies task (if Node.js doesn't need prefetch)
  OR UPDATE: prefetch-input for npm/yarn instead of gomod

# If using npm:
- name: prefetch-input
  value: '{"type": "npm", "path": "."}'
```

---

## Phase 4: Integration & Validation

### 4.1 Register Components in Konflux

**Goal**: Add three components to the Ramen DR Standalone application.

**Via ApplicationStudio Console**:

1. Navigate to: https://console.redhat.com/preview/hac/teams
2. Find: "ramen-dr-standalone" application
3. Click: "Add component" (3 times)

**Component 1: Hub Operator**
- Component name: `ramen-hub-operator`
- Git repository: `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen`
- Git branch: `main` (or your default)
- Dockerfile: `hub.Dockerfile`
- Container registry: `quay.io/rh-ocp-dr`
- Container image name: `ramen-hub-operator`

**Component 2: Cluster Operator**
- Component name: `ramen-cluster-operator`
- Git repository: `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen`
- Git branch: `main`
- Dockerfile: `cluster.Dockerfile`
- Container registry: `quay.io/rh-ocp-dr`
- Container image name: `ramen-cluster-operator`

**Component 3: Console UI**
- Component name: `ramen-console-ui`
- Git repository: `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console`
- Git branch: `main`
- Dockerfile: `Dockerfile`
- Container registry: `quay.io/rh-ocp-dr`
- Container image name: `ramen-console-ui`

**Validation**:
- [ ] All three components appear in application
- [ ] Each shows correct git repo and branch
- [ ] Container registries point to quay.io/rh-ocp-dr

### 4.2 Trigger Initial Builds

**Goal**: Start first build for each component to validate pipeline configuration.

**Method 1: Push trigger**:
```bash
cd /home/nlevanon/workspace/RamenDRStandAlone/ramen
# Make a minor change and push
echo "# Build trigger" >> README.md
git add README.md
git commit -m "Trigger initial build"
git push origin main
```

**Method 2: Manual trigger via console**:
- Navigate to component
- Click: "Start build"
- Select branch: `main`

**Monitor build**:
```bash
# In ApplicationStudio console:
1. Navigate to component
2. Watch "PipelineRun" section
3. Monitor task progress in real-time

# Via kubectl:
kubectl -n rh-ocp-dr get pipelinerun
kubectl -n rh-ocp-dr describe pipelinerun <name>
kubectl -n rh-ocp-dr logs <pipelinerun-pod> -f
```

### 4.3 Validate Build Results

**Goal**: Ensure builds complete successfully and artifacts are correct.

**Check 1: Pipeline completion**:
```bash
kubectl -n rh-ocp-dr get pipelinerun -o wide
# Look for STATUS: "Succeeded"
```

**Check 2: Image registry**:
```bash
# Verify images pushed to registry
podman pull quay.io/rh-ocp-dr/ramen-hub-operator:latest
podman inspect quay.io/rh-ocp-dr/ramen-hub-operator:latest
```

**Check 3: Multi-platform support**:
```bash
podman pull quay.io/rh-ocp-dr/ramen-hub-operator:latest
podman manifest inspect quay.io/rh-ocp-dr/ramen-hub-operator:latest
# Should show platforms: amd64, ppc64le, s390x, arm64
```

**Check 4: SBOM generation**:
```bash
# SBOM should be available in image
podman pull quay.io/rh-ocp-dr/ramen-hub-operator:latest
podman run quay.io/rh-ocp-dr/ramen-hub-operator:latest \
  cat /root/buildinfo/Dockerfile
```

### 4.4 Validate SLSA Compliance

**Goal**: Ensure Enterprise Contract policies pass.

**Check 1: EC policy in Konflux**:
- Navigate to component
- Look for "Compliance" tab
- Verify: "SLSA L3" checks passing

**Check 2: Policy details**:
- [ ] trusted_task.trusted = PASS
- [ ] container.image_signature = PASS (if signed)
- [ ] container.base_image_known = PASS
- [ ] create_container_image_using_file_with_relative_symlinks = PASS

**Troubleshoot failures**:
- Review EC policy docs: https://enterprisecontract.dev/
- Check task bundle versions match policy requirements
- Verify buildah-remote-oci-ta versions

---

## Phase 5: OLM & Catalog (Future)

### 5.1 Operator Bundle Structure

After Phase 4 succeeds, prepare for OLM:

```
ramen/
├── config/
│   └── manager/
│       └── kustomization.yaml
├── bundle/
│   ├── metadata/
│   │   └── annotations.yaml
│   ├── manifests/
│   │   ├── ramen.clusterserviceversion.yaml
│   │   ├── ramen.crd.yaml
│   │   └── ...
│   └── Dockerfile
├── bundle-hub/
│   ├── metadata/
│   │   └── annotations.yaml
│   ├── manifests/
│   │   ├── ramen-hub.clusterserviceversion.yaml
│   │   └── ...
│   └── Dockerfile
└── bundle-cluster/
    ├── metadata/
    │   └── annotations.yaml
    ├── manifests/
    │   ├── ramen-cluster.clusterserviceversion.yaml
    │   └── ...
    └── Dockerfile
```

### 5.2 FBC (Filesystem-Based Catalog) Pipeline

Create separate Tekton pipeline for FBC:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: ramen-fbc-on-push
spec:
  params:
    - name: hub-bundle-image
      value: quay.io/rh-ocp-dr/ramen-hub-bundle:{{revision}}
    - name: cluster-bundle-image
      value: quay.io/rh-ocp-dr/ramen-cluster-bundle:{{revision}}
    - name: output-image
      value: quay.io/rh-ocp-dr/ramen-catalog:{{revision}}
  tasks:
    # clone source with FBC build definitions
    # pull bundle images
    # run fbc-builder task to create catalog
    # push catalog image
```

---

## Troubleshooting Guide

### Build Timeout

**Problem**: Pipeline runs for >6 hours and times out

**Solutions**:
1. Increase timeout in PipelineRun spec:
   ```yaml
   spec:
     timeouts:
       pipeline: 8h  # or more
   ```

2. Check task logs for hanging tasks:
   ```bash
   kubectl -n rh-ocp-dr logs <pod> --tail=100
   ```

3. Disable multi-platform (temporary):
   ```yaml
   build-platforms:
     - linux/x86_64  # only one for now
   ```

### Build Fails with "Image not found"

**Problem**: buildah-remote-oci-ta can't access OCI artifacts

**Solution**:
1. Verify OCI artifact storage is configured
2. Check artifact expiration times
3. Review prefetch-dependencies logs

### SLSA/EC Policy Fails

**Problem**: Enterprise Contract rejects build

**Solution**:
1. Check EC policy violations: https://enterprisecontract.dev/
2. Ensure task bundle versions are approved
3. Verify hermetic mode is enabled
4. Check if task is in trusted catalog

### Image Doesn't Have Multi-Platform Support

**Problem**: Image only exists for one platform

**Solution**:
1. Verify `build-platforms` parameter includes desired platforms
2. Check if multi-platform-controller is deployed
3. Verify matrix parallelization is working:
   ```bash
   kubectl -n rh-ocp-dr get pipelinerun <name> -o yaml | grep -A 20 build-images
   ```

### Registry Push Fails

**Problem**: Images can't be pushed to quay.io

**Solution**:
1. Verify authentication to registry
2. Check if repository exists:
   ```bash
   podman login quay.io
   podman pull quay.io/rh-ocp-dr/ramen-hub-operator:latest
   ```
3. Check Konflux ServiceAccount permissions

---

## Success Checklist

Mark off each item as you complete it:

### Phase 1
- [ ] Konflux workspace verified
- [ ] Repositories prepared
- [ ] Build structure understood
- [ ] Application created

### Phase 2
- [ ] hub.Dockerfile created
- [ ] cluster.Dockerfile created
- [ ] Console Dockerfile verified
- [ ] container.yaml files created

### Phase 3
- [ ] ramen-hub-operator-on-push.yaml created
- [ ] ramen-cluster-operator-on-push.yaml created
- [ ] ramen-console-ui-on-push.yaml created
- [ ] All YAML files validated

### Phase 4
- [ ] All three components registered
- [ ] Initial builds triggered
- [ ] Builds completed successfully
- [ ] Multi-platform support verified
- [ ] SLSA/EC policies pass
- [ ] SBOM generated
- [ ] Component snapshots created

### Phase 5 (Future)
- [ ] OLM bundle structure created
- [ ] FBC pipeline defined
- [ ] Catalog image building
- [ ] OLM installation tested

---

## Next Steps

1. **Start Phase 1** - Verify workspace access
2. **Analyze Go code** - Determine hub/cluster build structure
3. **Create Dockerfiles** - Phase 2
4. **Copy Tekton YAML** - Phase 3
5. **Test builds** - Phase 4
6. **Plan OLM** - Phase 5

See [MULTI_COMPONENT_STRATEGY.md](./MULTI_COMPONENT_STRATEGY.md) for component planning details.
