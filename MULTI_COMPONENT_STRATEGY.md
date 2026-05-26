# Multi-Component Strategy for RamenDR Standalone

Detailed strategy for managing Hub Operator, Cluster Operator, and Console UI as separate Konflux components within a single RamenDR Standalone application.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Design Rationale](#component-design-rationale)
3. [Repository Structure Strategy](#repository-structure-strategy)
4. [Dockerfile Strategy](#dockerfile-strategy)
5. [Tekton Pipeline Distribution](#tekton-pipeline-distribution)
6. [Build Coordination](#build-coordination)
7. [Artifact Management](#artifact-management)
8. [OLM Bundle Strategy](#olm-bundle-strategy)
9. [Deployment & Delivery](#deployment--delivery)

---

## Architecture Overview

### Target Application Structure

```
Konflux Application: ramen-dr-standalone
│
├─── Component 1: ramen-hub-operator
│    ├─ Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
│    ├─ Dockerfile: hub.Dockerfile
│    ├─ Build Output: quay.io/rh-ocp-dr/ramen-hub-operator:TAG
│    ├─ .tekton/ramen-hub-operator-on-push.yaml
│    └─ OLM: ramen-hub-operator-bundle:TAG
│
├─── Component 2: ramen-cluster-operator
│    ├─ Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
│    ├─ Dockerfile: cluster.Dockerfile
│    ├─ Build Output: quay.io/rh-ocp-dr/ramen-cluster-operator:TAG
│    ├─ .tekton/ramen-cluster-operator-on-push.yaml
│    └─ OLM: ramen-cluster-operator-bundle:TAG
│
├─── Component 3: ramen-console-ui
│    ├─ Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console
│    ├─ Dockerfile: Dockerfile
│    ├─ Build Output: quay.io/rh-ocp-dr/ramen-console-ui:TAG
│    ├─ .tekton/ramen-console-ui-on-push.yaml
│    └─ OLM: (Part of console operator bundle)
│
└─── Component 4 (Future): ramen-fbc
     ├─ Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-fbc
     ├─ Output: quay.io/rh-ocp-dr/ramen-catalog:TAG
     └─ Purpose: Filesystem-based Catalog with Hub & Cluster bundles
```

### Application Grouping Benefits

| Benefit | Why It Matters |
|---------|----------------|
| **Single Snapshot** | All three components build together; snapshot tracks all |
| **Coordinated Release** | Version all three together (release-v0.1.0) |
| **Shared Infrastructure** | Both operators use same Konflux namespace, RBAC |
| **Unified Testing** | Integration tests can validate all components |
| **Catalog Simplification** | FBC can reference all bundles from single snapshot |
| **Release Pipeline** | Single release process for all artifacts |

---

## Component Design Rationale

### Why Three Components (Not One)?

**Question**: Why not build everything from a single component with a matrix of Dockerfiles?

**Answer**: 

| Aspect | Single Component | Three Components |
|--------|-----------------|------------------|
| **Build Time** | 3 sequential Dockerfiles | 3 parallel builds |
| **Failure Isolation** | One fails → all fail rebuild | One fails → rebuild only that one |
| **Version Tracking** | All same version | Each can have own version |
| **Registry Organization** | Single image with variants | Separate images per purpose |
| **OLM Structure** | Complex, mixed manifests | Clean separation (hub vs cluster) |
| **Documentation** | Unclear what's what | Clear component purpose |
| **Maintenance** | Complex filtering logic | Simple per-component logic |

**Best Practice**: Separate components = clearer semantics, better parallelization, easier debugging.

### Hub Operator as Separate Component

**Purpose**: Runs on **hub cluster** only (central, always-on)

**Responsibilities**:
- Manager multi-cluster DR policies (DRPolicy CRD)
- Track cluster connections (DRClusterConnection)
- Orchestrate hub-side replication setup
- Manage hub workload placement

**Characteristics**:
- Single instance per hub cluster
- Long-running, stateful
- Accesses multiple managed clusters via network
- Requires RBAC for hub-scoped resources

**Dockerfile Strategy**:
```dockerfile
# hub.Dockerfile
# ... multi-stage build ...
RUN go build -o hub-manager ./cmd/hub/main.go
# OR
RUN go build -o manager ./cmd/main.go -ldflags "-X mode=hub"
```

### Cluster Operator as Separate Component

**Purpose**: Runs on **managed clusters** (many, distributed)

**Responsibilities**:
- Implement DR on each managed cluster
- Manage cluster-side replication agents
- Monitor local data protection status
- Report status back to hub

**Characteristics**:
- Multiple instances (one per managed cluster)
- Short-lived workload placement (Subscription)
- Limited cluster network access (typically inbound from hub only)
- Requires RBAC for local cluster resources

**Dockerfile Strategy**:
```dockerfile
# cluster.Dockerfile
# ... multi-stage build ...
RUN go build -o cluster-manager ./cmd/cluster/main.go
# OR
RUN go build -o manager ./cmd/main.go -ldflags "-X mode=cluster"
```

### Console UI as Separate Component

**Purpose**: Plugin for **OpenShift Console** (dashboard)

**Responsibilities**:
- UI for RamenDR objects (DRPolicy, DRPlacement, etc.)
- Forms for creating/editing DR configurations
- Dashboard for monitoring status
- Integration with MCO console plugin framework

**Characteristics**:
- Frontend/JavaScript/React
- Runs in console container or as dynamic plugin
- Network-isolated from operator clusters
- Read-mostly access to API (kubectl proxy)

**Dockerfile Strategy**:
```dockerfile
# ramen-console/Dockerfile
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist /app/dist
EXPOSE 3000
CMD ["npm", "start"]
```

---

## Repository Structure Strategy

### Why Keep Both Operators in Same Repository?

**Question**: Should Hub and Cluster be in separate repos or same repo?

**Current State**: Both operators are in same repo (`rh-ocp-dr/ramen`)

**Advantages of Same Repo**:
- ✅ Shared Go modules (common dependencies)
- ✅ Shared code libraries (pkg/, internal/)
- ✅ Atomic commits (both change together)
- ✅ Easier testing (integration tests in one place)
- ✅ Single CI/CD configuration

**Disadvantages of Same Repo**:
- ❌ Can't version independently
- ❌ Changes to one trigger builds of both
- ❌ Harder to maintain separate release cycles

**Recommendation**: Keep in same repo, build separately via Dockerfiles.

### Repository Layout

```
ramen/
├── go.mod
├── go.sum
├── Makefile
├── cmd/
│   ├── main.go              (Shared entry point, if flags-based)
│   ├── hub/
│   │   └── main.go          (If hub-specific entry point)
│   └── cluster/
│       └── main.go          (If cluster-specific entry point)
├── pkg/
│   ├── hub/                 (Hub operator logic)
│   │   ├── manager.go
│   │   ├── controller/
│   │   └── ...
│   ├── cluster/             (Cluster operator logic)
│   │   ├── manager.go
│   │   ├── controller/
│   │   └── ...
│   └── common/              (Shared code)
│       ├── types.go
│       ├── crd.go
│       └── ...
├── config/
│   ├── hub/                 (Hub operator kustomize)
│   │   └── kustomization.yaml
│   ├── cluster/             (Cluster operator kustomize)
│   │   └── kustomization.yaml
│   └── crd/                 (Shared CRDs)
├── Dockerfile              (Generic or choose one)
├── hub.Dockerfile          (Hub-specific build)
├── cluster.Dockerfile      (Cluster-specific build)
├── bundle/
│   ├── hub/                (Hub operator bundle)
│   │   ├── manifests/
│   │   └── Dockerfile
│   └── cluster/            (Cluster operator bundle)
│       ├── manifests/
│       └── Dockerfile
├── .tekton/
│   ├── ramen-hub-operator-on-push.yaml
│   ├── ramen-cluster-operator-on-push.yaml
│   └── ramen-fbc-on-push.yaml (future)
├── remote_source/
│   ├── cachito.env
│   └── app/                (Link to repo root, for Cachi2)
├── container.yaml
└── README.md
```

### Console Repository Layout

```
ramen-console/
├── package.json
├── package-lock.json
├── tsconfig.json
├── Dockerfile              (Build console plugin image)
├── packages/
│   ├── mco/                (Multi-Cluster Operations plugin)
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── odf/                (ODF plugin, if reused)
│   └── ...
├── scripts/
│   ├── build.sh
│   └── test.sh
├── .tekton/
│   ├── ramen-console-ui-on-push.yaml
│   └── ramen-console-ui-on-pr.yaml
├── container.yaml
└── README.md
```

---

## Dockerfile Strategy

### Determining Build Entry Points

**Research your code**:

1. **Do separate entry points exist?**
   ```bash
   ls cmd/hub/main.go cmd/cluster/main.go 2>/dev/null && echo "Separate" || echo "Shared"
   ```

2. **Is there a feature flag system?**
   ```bash
   grep -r "OperatorMode\|MODE\|hubMode" cmd/ pkg/
   ```

3. **Do binaries have different names or must they be the same?**
   ```bash
   grep -r "manager-hub\|manager-cluster" config/
   ```

### Option 1: Separate Entry Points

**If code structure supports it** (recommended):

```dockerfile
# hub.Dockerfile
FROM registry.redhat.io/ubi9/ubi@sha256:... as policy
RUN update-crypto-policies --set DEFAULT:PQ

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder@sha256:... as builder
ENV GOFLAGS=''
ENV GOMODCACHE=$GOCACHE/pkg/mod
COPY remote_source /src/remote_source
WORKDIR /src/remote_source/app
RUN go version | tee -a /go.version
RUN GOOS=linux go build -a -o hub-manager cmd/hub/main.go

FROM registry.redhat.io/ubi9/ubi-minimal@sha256:...
ENV OPBIN=/hub-manager
COPY --from=policy /etc/crypto-policies /etc/crypto-policies
COPY --from=builder /src/remote_source/app/hub-manager "$OPBIN"
COPY --from=builder /go.version /go.version
RUN chmod +x "$OPBIN"
ENTRYPOINT ["/hub-manager"]
COPY hub.Dockerfile /root/buildinfo/Dockerfile
```

```dockerfile
# cluster.Dockerfile
FROM registry.redhat.io/ubi9/ubi@sha256:... as policy
RUN update-crypto-policies --set DEFAULT:PQ

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder@sha256:... as builder
ENV GOFLAGS=''
ENV GOMODCACHE=$GOCACHE/pkg/mod
COPY remote_source /src/remote_source
WORKDIR /src/remote_source/app
RUN go version | tee -a /go.version
RUN GOOS=linux go build -a -o cluster-manager cmd/cluster/main.go

FROM registry.redhat.io/ubi9/ubi-minimal@sha256:...
ENV OPBIN=/cluster-manager
COPY --from=policy /etc/crypto-policies /etc/crypto-policies
COPY --from=builder /src/remote_source/app/cluster-manager "$OPBIN"
COPY --from=builder /go.version /go.version
RUN chmod +x "$OPBIN"
ENTRYPOINT ["/cluster-manager"]
COPY cluster.Dockerfile /root/buildinfo/Dockerfile
```

**Advantages**:
- Clear, separate binaries
- Easy to understand what each does
- Separate image tags in registry

**Disadvantages**:
- Requires separate entry points in code

### Option 2: Feature Flags at Build Time

**If code uses build-time flags** (alternative):

```dockerfile
# hub.Dockerfile
FROM registry.redhat.io/ubi9/ubi@sha256:... as policy
RUN update-crypto-policies --set DEFAULT:PQ

FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder@sha256:... as builder
ENV GOFLAGS=''
ENV GOMODCACHE=$GOCACHE/pkg/mod
COPY remote_source /src/remote_source
WORKDIR /src/remote_source/app
RUN go version | tee -a /go.version
RUN GOOS=linux go build -a \
  -ldflags="-X main.OperatorMode=hub" \
  -o manager cmd/main.go

FROM registry.redhat.io/ubi9/ubi-minimal@sha256:...
ENV OPBIN=/manager
COPY --from=policy /etc/crypto-policies /etc/crypto-policies
COPY --from=builder /src/remote_source/app/manager "$OPBIN"
COPY --from=builder /go.version /go.version
RUN chmod +x "$OPBIN"
ENTRYPOINT ["/manager"]
COPY hub.Dockerfile /root/buildinfo/Dockerfile
```

**Go code** (must support this):
```go
// cmd/main.go
var OperatorMode string

func main() {
    if OperatorMode == "hub" {
        // Start hub-specific manager
        startHubManager()
    } else if OperatorMode == "cluster" {
        // Start cluster-specific manager
        startClusterManager()
    }
}
```

**Advantages**:
- Single binary, multiple modes
- Smaller image sizes
- Shared code paths

**Disadvantages**:
- Requires feature flag support in code
- Binary always contains both codepaths

### Option 3: Runtime Environment Variables

**If code inspects environment at runtime** (least preferred):

```dockerfile
# hub.Dockerfile (identical binary, different env)
FROM ... as builder
# Build single binary (cmd/main.go)
RUN GOOS=linux go build -a -o manager cmd/main.go

FROM ...
COPY --from=builder .../manager /manager
ENV OPERATOR_MODE=hub    # ← Set at build time
ENTRYPOINT ["/manager"]
```

**Disadvantages**:
- Binary contains all code paths
- Environment can be accidentally overridden
- Harder to separate concerns

---

## Tekton Pipeline Distribution

### Pipeline File Organization

**Location**: `.tekton/` directory in each repository

#### For Ramen Operators (in `rh-ocp-dr/ramen`):

```
.tekton/
├── ramen-hub-operator-on-push.yaml
├── ramen-hub-operator-on-pull-request.yaml
├── ramen-cluster-operator-on-push.yaml
└── ramen-cluster-operator-on-pull-request.yaml
```

**Each file**: Independent PipelineRun definition

#### For Console UI (in `rh-ocp-dr/ramen-console`):

```
.tekton/
├── ramen-console-ui-on-push.yaml
└── ramen-console-ui-on-pull-request.yaml
```

### PipelineRun Naming Convention

**Pattern**: `<component-name>-on-<trigger-type>.yaml`

| Component | On-Push | On-PR |
|-----------|---------|-------|
| Hub | `ramen-hub-operator-on-push.yaml` | `ramen-hub-operator-on-pull-request.yaml` |
| Cluster | `ramen-cluster-operator-on-push.yaml` | `ramen-cluster-operator-on-pull-request.yaml` |
| Console | `ramen-console-ui-on-push.yaml` | `ramen-console-ui-on-pull-request.yaml` |

### Pipeline Trigger Configuration

**pipelinesascode CEL expressions**:

```yaml
# Hub Operator: Trigger on push to main branch
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "push" && target_branch == "main"

# Cluster Operator: Trigger on push to main branch (same repo)
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "push" && target_branch == "main"

# Console UI: Trigger on push to main branch (different repo)
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "push" && target_branch == "main"
```

**Advanced triggers** (if needed):

```yaml
# Hub: Only if hub-specific files changed
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "push" && 
  target_branch == "main" &&
  changed_files.contains("cmd/hub/") ||
  changed_files.contains("pkg/hub/") ||
  changed_files.contains("hub.Dockerfile")

# Cluster: Only if cluster-specific files changed
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "push" && 
  target_branch == "main" &&
  changed_files.contains("cmd/cluster/") ||
  changed_files.contains("pkg/cluster/") ||
  changed_files.contains("cluster.Dockerfile")
```

---

## Build Coordination

### Parallel Build Strategy

**Goal**: All three components build independently and in parallel.

**Timeline**:

```
Time 0:00   Push to main
    ↓
Time 0:05   PipelineRun created for all 3 components
    ├─ Hub pipeline starts
    ├─ Cluster pipeline starts
    └─ Console pipeline starts
    ↓
Time 0:35   Hub builds complete → Image pushed
Time 0:40   Cluster builds complete → Image pushed
Time 0:45   Console builds complete → Image pushed
    ↓
Time 0:50   All components done
    ↓
Time 1:00   Snapshot created with all three images
```

**Key**: Pipelines run in parallel, not sequentially.

### Avoiding Build Conflicts

**Consideration 1: Shared Git Repo (Hub & Cluster)**

If both trigger on same push event:

```
✅ Good: Each has own output image registry
  quay.io/rh-ocp-dr/ramen-hub-operator:v0.1.0
  quay.io/rh-ocp-dr/ramen-cluster-operator:v0.1.0
  
❌ Bad: Same output image
  quay.io/rh-ocp-dr/ramen-operator:v0.1.0 (conflict!)
```

**Solution**: Ensure each component has unique `output-image` parameter.

**Consideration 2: Pull Request Builds**

For PR validation (not release):

```yaml
# PR trigger (optional, for validation)
pipelinesascode.tekton.dev/on-cel-expression: |
  event == "pull_request" && target_branch == "main"

# On-PR PipelineRun can skip some checks:
spec:
  params:
    - name: skip-checks
      value: "false"  # Still validate
    - name: build-source-image
      value: "false"  # Skip SBOM on PR (faster)
    - name: build-image-index
      value: "false"  # Skip multi-arch on PR (faster)
```

### Coordinating Releases

**Release Process** (future):

1. Tag commit with release version: `v0.1.0`
2. All three pipelines trigger with same tag
3. All three images built with same version tag
4. Bundle images built: `ramen-hub-bundle:v0.1.0`, `ramen-cluster-bundle:v0.1.0`
5. FBC pipeline combines bundles into catalog
6. Release artifact: `ramen-catalog:v0.1.0`

**Version Tagging Strategy**:

```yaml
# In PipelineRun annotations
build.appstudio.redhat.com/commit_sha: '{{revision}}'
# Can be:
#   - Branch: main, destinfo
#   - Tag: v0.1.0
#   - SHA: abc123def456...

# Output images use same tag:
output-image: quay.io/rh-ocp-dr/ramen-hub-operator:{{revision}}
# Expands to:
#   quay.io/rh-ocp-dr/ramen-hub-operator:v0.1.0 (if tagged)
#   quay.io/rh-ocp-dr/ramen-hub-operator:abc123def456... (if SHA)
```

---

## Artifact Management

### Image Registry Strategy

**Recommended structure**:

```
quay.io/rh-ocp-dr/                          # Organization
├── ramen-hub-operator:v0.1.0
├── ramen-hub-operator:latest
├── ramen-cluster-operator:v0.1.0
├── ramen-cluster-operator:latest
├── ramen-console-ui:v0.1.0
├── ramen-console-ui:latest
├── ramen-hub-bundle:v0.1.0                  # OLM bundles
├── ramen-hub-bundle:latest
├── ramen-cluster-bundle:v0.1.0
├── ramen-cluster-bundle:latest
├── ramen-catalog:v0.1.0                     # FBC catalog
└── ramen-catalog:latest
```

### Component Snapshots

**Konflux Snapshots**: Group all component artifacts for a release

After all three builds complete, Konflux automatically creates a Snapshot:

```
Snapshot: ramen-dr-standalone-<timestamp>
├── ramen-hub-operator:v0.1.0@sha256:abc...
├── ramen-cluster-operator:v0.1.0@sha256:def...
└── ramen-console-ui:v0.1.0@sha256:ghi...
```

**Snapshot Use Cases**:
1. **Release artifact**: Track all three components released together
2. **FBC pipeline**: Input to catalog generation
3. **Deployment**: Deploy all three via single snapshot reference
4. **Compliance**: All three validated to SLSA L3

### Image Tagging Strategy

**Tag Semantics**:

| Tag | Meaning | Persistence |
|-----|---------|-------------|
| `latest` | Latest successful build | Floating (changes each build) |
| `v0.1.0` | Release version | Immutable (fixed forever) |
| `sha-abc123` | Git SHA | Immutable (one per commit) |
| `v0.1.0-rc1` | Pre-release | Fixed for release cycle |

**Implementation**:

```yaml
# In hub.Dockerfile (labels for tracking)
LABEL upstream-vcs-ref="{{revision}}"
LABEL konflux.additional-tags="v0.1.0"  # Ask Konflux to tag as v0.1.0

# In PipelineRun (container.yaml handles tagging)
container.yaml:
  tags:
    - v0.1.0
    - latest
```

---

## OLM Bundle Strategy

### Bundle Structure

**Hub Bundle**:

```
bundle-hub/
├── manifests/
│   ├── ramen-hub.clusterserviceversion.yaml
│   ├── ramen-crd-hub.yaml           # Hub-specific CRDs
│   ├── ramen.clusterrole.yaml       # Hub RBAC
│   └── ramen.clusterrolebinding.yaml
├── metadata/
│   ├── annotations.yaml
│   └── dependencies.yaml            # Declare dependencies
└── Dockerfile                        # Bundle image
```

**Cluster Bundle**:

```
bundle-cluster/
├── manifests/
│   ├── ramen-cluster.clusterserviceversion.yaml
│   ├── ramen-crd-cluster.yaml       # Cluster-specific CRDs
│   ├── ramen.clusterrole.yaml       # Cluster RBAC
│   └── ramen.clusterrolebinding.yaml
├── metadata/
│   ├── annotations.yaml
│   └── dependencies.yaml
└── Dockerfile
```

### Bundle Image Builds

**Bundle Dockerfiles** (simple):

```dockerfile
# bundle-hub/Dockerfile
FROM scratch
COPY bundle-hub/manifests /manifests/
COPY bundle-hub/metadata /metadata/
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
```

**Bundle Tekton Pipeline** (builds from manifests):

```yaml
# .tekton/ramen-hub-operator-bundle-on-push.yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  labels:
    appstudio.openshift.io/component: ramen-hub-operator-bundle
spec:
  params:
    - name: dockerfile
      value: bundle-hub/Dockerfile
    - name: output-image
      value: quay.io/rh-ocp-dr/ramen-hub-bundle:{{revision}}
  # ... standard build pipeline ...
```

### Shared vs Separate CRDs

**Decision**: Should CRDs be in both bundles or shared?

| Approach | Pro | Con |
|----------|-----|-----|
| **Shared CRD bundle** | Single source of truth | Extra bundle image |
| **Duplicated in each** | Simpler OLM setup | Risk of inconsistency |

**Recommendation**: Duplicate CRDs in each bundle (OLM standard), mark one as "owner" for updates.

---

## Deployment & Delivery

### Single vs Multi-Release

**Single Release** (Recommended Initial Approach):

```
All three components released together:
- v0.1.0-hub
- v0.1.0-cluster
- v0.1.0-console

As one "RamenDR Standalone v0.1.0" release
```

**Multi-Release** (Future):

```
Each component versioned independently:
- ramen-hub-operator v1.0.0
- ramen-cluster-operator v1.0.0
- ramen-console-ui v0.5.0 (can be different)

Requires more complex FBC & OLM setup
```

### Deployment Sequence

**For End Users**:

```
1. Subscribe to OLM catalog (ramen-catalog:v0.1.0)
2. OLM resolves dependencies → Hub & Cluster bundles
3. Install Hub Operator on hub cluster
4. Install Cluster Operator on managed clusters
5. Deploy console plugin (if desired)
```

**For Automation**:

```
1. Get snapshot digest: ramen-dr-standalone@sha256:snap123
2. Extract component images from snapshot
3. Deploy hub-operator from snapshot
4. Deploy cluster-operator from snapshot
5. Deploy console from snapshot
```

### Artifact Delivery Chain

```
Git commit with tag v0.1.0
    ↓
Trigger all 3 component pipelines
    ↓
Build 3 images:
  - ramen-hub-operator:v0.1.0
  - ramen-cluster-operator:v0.1.0
  - ramen-console-ui:v0.1.0
    ↓
Konflux creates Snapshot
    ↓
Build 2 bundle images:
  - ramen-hub-bundle:v0.1.0
  - ramen-cluster-bundle:v0.1.0
    ↓
FBC pipeline combines bundles
    ↓
Build FBC catalog:
  - ramen-catalog:v0.1.0 (OCI image index with gRPC)
    ↓
Push to external registries (if needed)
    ↓
Publish release on GitHub/GitLab
```

---

## Summary: Multi-Component Checklist

### Pre-Implementation

- [ ] Determine Hub/Cluster build strategy (separate entry points, flags, or shared)
- [ ] Analyze Go code structure (cmd/, pkg/ organization)
- [ ] Plan repository layout (keep in same repo vs separate)
- [ ] Define image naming convention (use consistent format)
- [ ] Plan version/tagging strategy (semver, git SHA, etc.)

### Dockerfiles

- [ ] Create hub.Dockerfile (or update existing)
- [ ] Create cluster.Dockerfile (or update existing)
- [ ] Verify console Dockerfile (use standard multi-stage)
- [ ] Test builds locally with buildah

### Konflux Components

- [ ] Register hub-operator component
- [ ] Register cluster-operator component
- [ ] Register console-ui component
- [ ] Verify all three linked to same application

### Tekton Pipelines

- [ ] Create hub-operator-on-push.yaml
- [ ] Create cluster-operator-on-push.yaml
- [ ] Create console-ui-on-push.yaml
- [ ] Create hub-operator-on-pr.yaml (for validation)
- [ ] Create cluster-operator-on-pr.yaml (for validation)
- [ ] Create console-ui-on-pr.yaml (for validation)
- [ ] Test trigger events

### Validation

- [ ] Trigger all three builds simultaneously
- [ ] Verify all complete successfully
- [ ] Check multi-platform support for each
- [ ] Verify snapshot created with all three
- [ ] Validate SLSA/EC compliance for all
- [ ] Check SBOM generated for all

### OLM (Future)

- [ ] Plan bundle structure (hub vs cluster)
- [ ] Create ClusterServiceVersion manifests
- [ ] Create CRD manifests
- [ ] Create bundle Dockerfiles
- [ ] Configure OLM bundle pipeline
- [ ] Test OLM installation

---

## Next Steps

1. **Analyze your Go code** - Determine build entry points
2. **Create hub.Dockerfile** - Start with template, adapt as needed
3. **Create cluster.Dockerfile** - Copy hub template, adjust binary name
4. **Test locally** - `buildah build -f hub.Dockerfile`
5. **Register components** - Via ApplicationStudio console
6. **Create Tekton YAML** - Use [TRUSTED_TASKS_REFERENCE.md](./TRUSTED_TASKS_REFERENCE.md) as guide
7. **Trigger test builds** - Validate parallel execution
8. **Plan OLM strategy** - Separate bundle images per operator

See [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md) for detailed step-by-step instructions.
