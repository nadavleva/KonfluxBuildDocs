# RamenDR Standalone - Konflux Build Infrastructure

Complete analysis and implementation blueprint for building RamenDR Standalone with Konflux CI/CD platform, based on ODF reference architecture.

## 📋 Documentation Index

### Core Documentation
- **[CLI_KUBECTL_ACCESS.md](./CLI_KUBECTL_ACCESS.md)** - How to set up CLI/kubectl access to the Konflux cluster (BEFORE Phase 1)
- **[WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md)** - **PHASE 1 START HERE** How to create Konflux application workspace and register 6 components (UI + CLI)
- **[RAMEN_PROJECT_TEMPLATE.md](./RAMEN_PROJECT_TEMPLATE.md)** - ProjectDevelopmentStreamTemplate for 6-component architecture (optional reference)
- **[KONFLUX_ARCHITECTURE.md](./KONFLUX_ARCHITECTURE.md)** - Detailed analysis of ODR/ODF Konflux pipeline architecture
- **[IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md)** - Step-by-step implementation roadmap for RamenDR Standalone
- **[TRUSTED_TASKS_REFERENCE.md](./TRUSTED_TASKS_REFERENCE.md)** - Complete reference of Konflux Trusted Tasks used in ODR pipeline
- **[MULTI_COMPONENT_STRATEGY.md](./MULTI_COMPONENT_STRATEGY.md)** - Multi-component architecture patterns
- **[OpenIssues.md](./OpenIssues.md)** - 🔴 **BLOCKING ISSUES** - Red Hat registry credentials and infrastructure problems to resolve

### Existing Documentation
- **[Konflux_build_hint.md](./Konflux_build_hint.md)** - High-level Konflux adoption strategy
- **[RAMENDR_UI_BUILD_DOCUMENTATION.md](./RAMENDR_UI_BUILD_DOCUMENTATION.md)** - RamenDR UI/Console architecture and build details

---

## 🎯 Quick Start

### Current State
✅ **ODR-Operator** is already built successfully with Konflux using Trusted Tasks
✅ **Ramen repositories** are available in GitLab (hub/cluster operators, console)
❌ **RamenDR Standalone** needs Konflux workspace and component configuration

### What You'll Build

Six Konflux Components under **one RamenDR Standalone Application** (based on RHWA pattern):

| Component | Source Repo | Pipeline | Output | Status |
|-----------|-------------|----------|--------|--------|
| **ramen-hub-operator** | `rh-ocp-dr/ramen` | docker-build-multi-platform-oci-ta | Hub controller image | To Build |
| **ramen-hub-bundle** | `rh-ocp-dr/ramen` | docker-build-oci-ta | Hub OLM bundle | To Build |
| **ramen-cluster-operator** | `rh-ocp-dr/ramen` | docker-build-multi-platform-oci-ta | Cluster controller image | To Build |
| **ramen-cluster-bundle** | `rh-ocp-dr/ramen` | docker-build-oci-ta | Cluster OLM bundle | To Build |
| **ramen-console-ui** | `rh-ocp-dr/ramen-console` | docker-build-oci-ta | Console plugin image | To Build |
| **ramen-fbc-catalog** | `rh-ocp-dr/ramen` | docker-build-oci-ta | FBC catalog image | To Build |

**Note**: Bundles have `build-nudges-ref` dependencies on their operators (automatic sequencing)

### Next Steps

1. **Set up CLI access** - See [CLI_KUBECTL_ACCESS.md](./CLI_KUBECTL_ACCESS.md) (needed for programmatic access)
2. **Execute [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md)** - Create workspace and register 6 components (Phase 1)
3. **Then see [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md)** for Phase 2-5 roadmap
4. **Reference materials:**
   - [RAMEN_PROJECT_TEMPLATE.md](./RAMEN_PROJECT_TEMPLATE.md) - Component architecture details
   - [TRUSTED_TASKS_REFERENCE.md](./TRUSTED_TASKS_REFERENCE.md) - Tekton task details
   - [KONFLUX_ARCHITECTURE.md](./KONFLUX_ARCHITECTURE.md) - ODR pipeline deep dive
   - [MULTI_COMPONENT_STRATEGY.md](./MULTI_COMPONENT_STRATEGY.md) - Component patterns

---

## 🔑 Key Insights from ODR Analysis

### Why ODR Reference Works

The ODR pipeline succeeds because it:

1. **Uses only Trusted Tasks** - No raw `make` commands in pipeline; all security-critical operations in trusted bundles
2. **Handles builds in Dockerfile** - Go compilation happens inside container (trusted execution context)
3. **Properly chains OCI artifacts** - Uses OCI artifact storage between tasks instead of PVCs
4. **Multi-platform by design** - Leverages `buildah-remote-oci-ta` for x86_64, ppc64le, s390x, arm64
5. **Hermetic mode enabled** - Network isolation ensures reproducible builds

### Critical Pattern You Must Follow

**Do NOT do this** (what fails in Konflux):
```bash
# ❌ Running make directly in Tekton task
oc run make build  # Fails security policy
```

**Do THIS instead** (what ODR does):
```dockerfile
# ✅ Invoke make inside Dockerfile RUN statement
FROM ubi9/go-toolset:latest
RUN go build -o manager cmd/main.go  # Runs in trusted context
```

---

## 📊 Repository Structure

```
RamenDRStandAlone/
├── Docs/
│   ├── README.md (this file)
│   ├── KONFLUX_ARCHITECTURE.md
│   ├── IMPLEMENTATION_BLUEPRINT.md
│   ├── TRUSTED_TASKS_REFERENCE.md
│   ├── MULTI_COMPONENT_STRATEGY.md
│   ├── Konflux_build_hint.md
│   └── RAMENDR_UI_BUILD_DOCUMENTATION.md
├── odr-operator/                    # ODF reference (for learning)
│   ├── .tekton/
│   ├── Dockerfile
│   └── container.yaml
├── ramen/                            # Hub & Cluster operators
│   ├── cmd/main.go
│   ├── Dockerfile                    # Single or split?
│   └── hub.Dockerfile / cluster.Dockerfile (to create)
├── ramen-console/                    # Console UI
│   ├── Dockerfile
│   └── packages/
└── tenants-config/                   # Konflux tenant configuration
    └── cluster/
        └── rh-ocp-dr/                # Your workspace config
```

---

## 🚀 Phase Overview

### Phase 1: Foundation (Ready to Execute)
- ✅ Analyze ODR pipeline architecture
- ✅ Understand Trusted Tasks pattern
- ⏳ **Create Konflux application workspace** - See [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md)
- ⏳ **Define component structure** - See [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md) (both UI and CLI methods)
Dockerfiles & Bundle Structure (Next)
- ⏳ Create hub.Dockerfile and cluster.Dockerfile (operator builds)
- ⏳ Create bundle/hub/Dockerfile and bundle/cluster/Dockerfile (bundle images)
- ⏳ Create fbc/Dockerfile (FBC catalog image)
- ⏳ Configure container.yaml for repositories

### Phase 3: Tekton Pipelines (Next)
- ⏳ Set up .tekton/ pipeline files (6 total):
  - ramen-hub-operator-on-push.yaml (multi-platform)
  - ramen-hub-bundle-on-push.yaml (depends on hub-operator)
  - ramen-cluster-operator-on-push.yaml (multi-platform)
  - ramen-cluster-bundle-on-push.yaml (depends on cluster-operator)
  - ramen-console-ui-on-push.yaml (standalone)
  - ramen-fbc-catalog-on-push.yaml (depends on both bundles)

### Phase 4: Integration & Testing (Later)
- ⏳ Apply ProjectDevelopmentStreamTemplate to create all components
- ⏳ Trigger test builds on operator components
- ⏳ Validate bundle builds triggered automatically (build-nudges-ref)
- ⏳ Verify FBC catalog builds after bundles complete
- ⏳ Test component snapshot creation
- ⏳ Configure OLM manifests for Hub and Cluster operators

---

## 🛠️ Technical Foundation

### Konflux Platform Features You'll Use

| Feature | Purpose | Status |
|---------|---------|--------|
| **Trusted Tasks** | Security-compliant pipeline execution | ✅ Ready |
| **Multi-Platform Builds** | Build for x86_64, ppc64le, s390x, arm64 | ✅ Ready |
| **OCI Artifact Chaining** | Pass data between tasks securely | ✅ Ready |
| **Cachi2 Prefetching** | Go module dependency isolation | ✅ Ready |
| **Hermetic Mode** | Network isolation for reproducibility | ✅ Ready |
| **Enterprise Contract** | SLSA compliance validation | ✅ Ready |

### ODR Pipeline Stack (Your Template)

```
git-clone-oci-ta         → Clone source code
    ↓
prefetch-dependencies    → Fetch Go modules with Cachi2
    ↓
build-images (matrix)    → Multi-platform builds with buildah-remote-oci-ta
    ↓
build-image-index        → Create OCI multi-arch index
    ↓
source-build-oci-ta      → Generate SBOM and source image
    ↓
deprecated-base-image-check → Security validation
    ↓
image-scan → SLSA checks
```

---

## 📚 Document Reference Map

| Question | Find Answer In |
|----------|-----------------|
| What Trusted Tasks are available? | [TRUSTED_TASKS_REFERENCE.md](./TRUSTED_TASKS_REFERENCE.md) |
| How should I structure my operators? | [MULTI_COMPONENT_STRATEGY.md](./MULTI_COMPONENT_STRATEGY.md) |
| What are the exact ODR configurations? | [KONFLUX_ARCHITECTURE.md](./KONFLUX_ARCHITECTURE.md) |
| What do I implement first? | [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md) |
| Why does ODR work and what will work for us? | [Konflux_build_hint.md](./Konflux_build_hint.md) |
| How is the Console built? | [RAMENDR_UI_BUILD_DOCUMENTATION.md](./RAMENDR_UI_BUILD_DOCUMENTATION.md) |

---
ProjectDevelopmentStreamTemplate applied to `rh-ocp-dr` namespace
- [ ] All six components created (2 operator + 2 bundle + 1 console + 1 FBC)
- [ ] All six `.tekton/` pipeline files created and validated
- [ ] Multi-platform builds successful for operator components
- [ ] Hub and Cluster operator images produced with correct digests
- [ ] Hub and Cluster bundle images auto-built (via build-nudges-ref)
- [ ] Console image builds successfully
- [ ] FBC catalog auto-built after bundles complete
- [ ] Component snapshots created successfully with all six artifacts
- [ ] SLSA compliance checks pass for all componentine files created and validated
- [ ] Multi-platform builds successful for all components
- [ ] Hub and Cluster operator images produced with correct digests
- [ ] Console image builds and integrates correctly
- [ ] Component snapshots created successfully
- [ ] SLSA compliance checks pass
- [ ] Enterprise Contract policies validate all artifacts

---

## 🤝 References & Links

### ODF Reference Repository
- **ODR Operator** (Your Template): https://gitlab.cee.redhat.com/rhodf/konflux/odr-operator/-/tree/rhodf-4.22-rhel-9

### Your Repositories
- **Ramen Operators (Hub & Cluster)**: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
- **Ramen Console UI**: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console
- **Konflux Tenants Config**: `/home/nlevanon/workspace/Konflux/tenants-config`

### Konflux Documentation
- [Konflux Official Docs](https://konflux-ci.dev/)
- [Trusted Artifacts Architecture](https://konflux-ci.dev/architecture/ADR/0036-trusted-artifacts.html)
- [Enterprise Contract Policies](https://enterprisecontract.dev/)

---

## 📝 Document Status

| Document | Status | Last Updated |
|----------|--------|---------------|
| README.md | ✅ Complete | 2026-05-19 |
| KONFLUX_ARCHITECTURE.md | ✅ Complete | 2026-05-19 |
| IMPLEMENTATION_BLUEPRINT.md | ✅ Complete | 2026-05-19 |
| TRUSTED_TASKS_REFERENCE.md | ✅ Complete | 2026-05-19 |
| MULTI_COMPONENT_STRATEGY.md | ✅ Complete | 2026-05-19 |

---

## 🎓 Learning Path Recommendation

**If you want to START RIGHT NOW:**

1. **Execute [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md)** (30-60 min) - Create workspace + components
2. **Then create Dockerfiles** (Phase 2 in [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md))
3. **Then trigger builds and test** (Phase 3-4)

**If you want to UNDERSTAND FIRST:**

1. Start with **[Konflux_build_hint.md](./Konflux_build_hint.md)** (10 min) - High-level strategy
2. Review **[RAMENDR_UI_BUILD_DOCUMENTATION.md](./RAMENDR_UI_BUILD_DOCUMENTATION.md)** (15 min) - What you're building
3. Study **[KONFLUX_ARCHITECTURE.md](./KONFLUX_ARCHITECTURE.md)** (30 min) - Deep dive into ODR architecture
4. Read **[TRUSTED_TASKS_REFERENCE.md](./TRUSTED_TASKS_REFERENCE.md)** (20 min) - Tekton tasks
5. Review **[RAMEN_PROJECT_TEMPLATE.md](./RAMEN_PROJECT_TEMPLATE.md)** (15 min) - 6-component architecture
6. **Then execute [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md)** (30-60 min) - Create workspace
7. Follow **[IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md)** (2-3 hours) - Complete roadmap

**Recommended: Start with 30 min overview, then execute WORKSPACE_SETUP_GUIDE immediately**

---

## 💡 Pro Tips

- **Always use Trusted Tasks** - Never try to bypass Konflux security policies
- **Copy from merged files** - Don't fork; push branches directly to your repo
- **Test incrementally** - Get one component building before adding others
- **Monitor multi-platform builds** - They take longer; plan accordingly
- **Use OCI artifacts** - Never use PVCs for inter-task communication in Konflux
- **Enable hermetic mode** - Ensures reproducible, audit-able builds

---

## 🆘 Common Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| Makefile commands fail in Tekton | Move build logic inside Dockerfile RUN statements |
| Multi-platform builds timeout | Increase timeout, consider building single platform first |
| Image doesn't have correct digest | Ensure all build inputs are from Trusted Tasks |
| Enterprise Contract policy fails | Check SLSA compliance requirements in EC docs |
| SBOM generation fails | Verify hermetic mode is properly configured |

---

## 📞 Next Steps

1. **Read the next document** in the learning path above
2. **Ask questions** about any Konflux concepts
3. **Implement Phase 1** of the blueprint
4. **Validate** each component individually before integration

Good luck! 🚀
