# RamenDR Standalone - ProjectDevelopmentStreamTemplate

Template-based project definition for RamenDR Standalone using Konflux ProjectDevelopmentStreamTemplate pattern (based on RHWA template architecture).

---

## Overview

The RHWA template shows the correct Konflux pattern: **each operator consists of TWO linked components**:

1. **Operator Component** - Builds the operator container image (multi-platform)
2. **Bundle Component** - Builds the OLM bundle image (single-platform, depends on operator)

Both components in the same repository, different Containerfiles, automatically coordinated via `build-nudges-ref`.

---

## RamenDR Standalone Template (YAML Format)

This template will generate all necessary Konflux resources for RamenDR Standalone.

```yaml
apiVersion: projctl.konflux.dev/v1beta1
kind: ProjectDevelopmentStreamTemplate
metadata:
  name: ramen-dr-standalone-release
  namespace: rh-ocp-dr-tenant
spec:
  project: ramen-dr-standalone-template
  description: "RamenDR Standalone - Hub and Cluster operators with OLM"
  
  variables:
    - name: operatorShortName
      description: "Operator Short Name (RAMEN, RDR, etc.)"
      default: "ramen"
    
    - name: version
      description: "Hyphenized version in major-minor format (e.g., 0-1 or 4-22)"
      default: "0-1"
    
    - name: versionRHEL
      description: "RHEL version operator built for (9 or 8)"
      default: "9"
    
    - name: gitBranch
      description: "Git branch for operator code (e.g., main, destinfo)"
      default: "main"
    
    - name: gitBranchConsole
      description: "Git branch for console code"
      default: "main"

  resources:
    # ============================================================
    # APPLICATION DEFINITION
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Application
      metadata:
        annotations:
          application.thumbnail: "5"
        name: ramen-dr-standalone-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        displayName: "RamenDR Standalone v{{.version}}"
        description: "RamenDR Hub and Cluster operators with console UI"

    # ============================================================
    # INTEGRATION TEST SCENARIO (Enterprise Contract)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1beta2
      kind: IntegrationTestScenario
      metadata:
        name: ramen-dr-standalone-enterprise-contract
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        contexts:
          - description: "Application compliance testing"
            name: application
        params:
          - name: POLICY_CONFIGURATION
            value: rhtap-releng-tenant/registry-rh-ocp-dr
        resolverRef:
          params:
            - name: url
              value: https://github.com/konflux-ci/build-definitions
            - name: revision
              value: main
            - name: pathInRepo
              value: pipelines/enterprise-contract.yaml
          resolver: git

    # ============================================================
    # HUB OPERATOR COMPONENT (Multi-platform build)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Component
      metadata:
        annotations:
          build.appstudio.openshift.io/pipeline: '{"name":"docker-build-multi-platform-oci-ta","bundle":"latest"}'
        name: ramen-hub-operator-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        build-nudges-ref:
          - ramen-hub-bundle-{{.version}}
        componentName: ramen-hub-operator-{{.version}}
        source:
          git:
            context: ./
            dockerfileUrl: hub.Dockerfile
            revision: "{{.gitBranch}}"
            url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen.git

    # ============================================================
    # HUB BUNDLE COMPONENT (OLM bundle - depends on hub operator)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Component
      metadata:
        annotations:
          build.appstudio.openshift.io/pipeline: '{"name":"docker-build-oci-ta","bundle":"latest"}'
        name: ramen-hub-bundle-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        build-nudges-ref:
          - ramen-fbc-catalog
        componentName: ramen-hub-bundle-{{.version}}
        source:
          git:
            context: ./
            dockerfileUrl: bundle/hub/Dockerfile
            revision: "{{.gitBranch}}"
            url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen.git

    # ============================================================
    # CLUSTER OPERATOR COMPONENT (Multi-platform build)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Component
      metadata:
        annotations:
          build.appstudio.openshift.io/pipeline: '{"name":"docker-build-multi-platform-oci-ta","bundle":"latest"}'
        name: ramen-cluster-operator-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        build-nudges-ref:
          - ramen-cluster-bundle-{{.version}}
        componentName: ramen-cluster-operator-{{.version}}
        source:
          git:
            context: ./
            dockerfileUrl: cluster.Dockerfile
            revision: "{{.gitBranch}}"
            url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen.git

    # ============================================================
    # CLUSTER BUNDLE COMPONENT (OLM bundle - depends on cluster operator)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Component
      metadata:
        annotations:
          build.appstudio.openshift.io/pipeline: '{"name":"docker-build-oci-ta","bundle":"latest"}'
        name: ramen-cluster-bundle-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        build-nudges-ref:
          - ramen-fbc-catalog
        componentName: ramen-cluster-bundle-{{.version}}
        source:
          git:
            context: ./
            dockerfileUrl: bundle/cluster/Dockerfile
            revision: "{{.gitBranch}}"
            url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen.git

    # ============================================================
    # CONSOLE UI COMPONENT (Single-platform web)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Component
      metadata:
        annotations:
          build.appstudio.openshift.io/pipeline: '{"name":"docker-build-oci-ta","bundle":"latest"}'
        name: ramen-console-ui-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        componentName: ramen-console-ui-{{.version}}
        source:
          git:
            context: ./
            dockerfileUrl: Dockerfile
            revision: "{{.gitBranchConsole}}"
            url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console.git

    # ============================================================
    # FBC CATALOG COMPONENT (Filesystem-based catalog)
    # ============================================================
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: Component
      metadata:
        annotations:
          build.appstudio.openshift.io/pipeline: '{"name":"docker-build-oci-ta","bundle":"latest"}'
        name: ramen-fbc-catalog-{{.version}}
        namespace: rh-ocp-dr-tenant
      spec:
        application: ramen-dr-standalone-{{.version}}
        componentName: ramen-fbc-catalog-{{.version}}
        source:
          git:
            context: ./
            dockerfileUrl: fbc/Dockerfile
            revision: "{{.gitBranch}}"
            url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen.git

    # ============================================================
    # IMAGE REPOSITORIES
    # ============================================================
    
    # Hub Operator Image
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: ImageRepository
      metadata:
        annotations:
          image-controller.appstudio.redhat.com/update-component-image: "true"
        labels:
          appstudio.redhat.com/application: ramen-dr-standalone-{{.version}}
          appstudio.redhat.com/component: ramen-hub-operator-{{.version}}
        name: ramen-hub-operator-image-repository
        namespace: rh-ocp-dr-tenant
      spec:
        image:
          name: rh-ocp-dr/ramen/ramen-hub-operator-{{.version}}
          visibility: public
        notifications:
          - config:
              url: https://bombino.api.redhat.com/v1/sbom/quay/push
            event: repo_push
            method: webhook
            title: SBOM-event-to-Bombino

    # Hub Bundle Image
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: ImageRepository
      metadata:
        annotations:
          image-controller.appstudio.redhat.com/update-component-image: "true"
        labels:
          appstudio.redhat.com/application: ramen-dr-standalone-{{.version}}
          appstudio.redhat.com/component: ramen-hub-bundle-{{.version}}
        name: ramen-hub-bundle-image-repository
        namespace: rh-ocp-dr-tenant
      spec:
        image:
          name: rh-ocp-dr/ramen/ramen-hub-bundle-{{.version}}
          visibility: public
        notifications:
          - config:
              url: https://bombino.api.redhat.com/v1/sbom/quay/push
            event: repo_push
            method: webhook
            title: SBOM-event-to-Bombino

    # Cluster Operator Image
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: ImageRepository
      metadata:
        annotations:
          image-controller.appstudio.redhat.com/update-component-image: "true"
        labels:
          appstudio.redhat.com/application: ramen-dr-standalone-{{.version}}
          appstudio.redhat.com/component: ramen-cluster-operator-{{.version}}
        name: ramen-cluster-operator-image-repository
        namespace: rh-ocp-dr-tenant
      spec:
        image:
          name: rh-ocp-dr/ramen/ramen-cluster-operator-{{.version}}
          visibility: public
        notifications:
          - config:
              url: https://bombino.api.redhat.com/v1/sbom/quay/push
            event: repo_push
            method: webhook
            title: SBOM-event-to-Bombino

    # Cluster Bundle Image
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: ImageRepository
      metadata:
        annotations:
          image-controller.appstudio.redhat.com/update-component-image: "true"
        labels:
          appstudio.redhat.com/application: ramen-dr-standalone-{{.version}}
          appstudio.redhat.com/component: ramen-cluster-bundle-{{.version}}
        name: ramen-cluster-bundle-image-repository
        namespace: rh-ocp-dr-tenant
      spec:
        image:
          name: rh-ocp-dr/ramen/ramen-cluster-bundle-{{.version}}
          visibility: public
        notifications:
          - config:
              url: https://bombino.api.redhat.com/v1/sbom/quay/push
            event: repo_push
            method: webhook
            title: SBOM-event-to-Bombino

    # Console UI Image
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: ImageRepository
      metadata:
        annotations:
          image-controller.appstudio.redhat.com/update-component-image: "true"
        labels:
          appstudio.redhat.com/application: ramen-dr-standalone-{{.version}}
          appstudio.redhat.com/component: ramen-console-ui-{{.version}}
        name: ramen-console-ui-image-repository
        namespace: rh-ocp-dr-tenant
      spec:
        image:
          name: rh-ocp-dr/ramen/ramen-console-ui-{{.version}}
          visibility: public
        notifications:
          - config:
              url: https://bombino.api.redhat.com/v1/sbom/quay/push
            event: repo_push
            method: webhook
            title: SBOM-event-to-Bombino

    # FBC Catalog Image
    - apiVersion: appstudio.redhat.com/v1alpha1
      kind: ImageRepository
      metadata:
        annotations:
          image-controller.appstudio.redhat.com/update-component-image: "true"
        labels:
          appstudio.redhat.com/application: ramen-dr-standalone-{{.version}}
          appstudio.redhat.com/component: ramen-fbc-catalog-{{.version}}
        name: ramen-fbc-catalog-image-repository
        namespace: rh-ocp-dr-tenant
      spec:
        image:
          name: rh-ocp-dr/ramen/ramen-fbc-catalog-{{.version}}
          visibility: public
        notifications:
          - config:
              url: https://bombino.api.redhat.com/v1/sbom/quay/push
            event: repo_push
            method: webhook
            title: SBOM-event-to-Bombino
```

---

## Component Architecture (Corrected)

### Six Components Total (Not Three!)

```
Application: ramen-dr-standalone-0-1
│
├── Component 1: ramen-hub-operator-0-1
│   ├─ Dockerfile: hub.Dockerfile
│   ├─ Pipeline: docker-build-multi-platform-oci-ta
│   ├─ Platforms: x86_64, ppc64le, s390x, arm64
│   ├─ Output: quay.io/rh-ocp-dr/ramen/ramen-hub-operator-0-1:TAG
│   └─ build-nudges-ref: [ramen-hub-bundle-0-1]
│
├── Component 2: ramen-hub-bundle-0-1
│   ├─ Dockerfile: bundle/hub/Dockerfile
│   ├─ Pipeline: docker-build-oci-ta
│   ├─ Depends on: Component 1 (hub-operator)
│   ├─ Output: quay.io/rh-ocp-dr/ramen/ramen-hub-bundle-0-1:TAG
│   └─ build-nudges-ref: [ramen-fbc-catalog-0-1]
│
├── Component 3: ramen-cluster-operator-0-1
│   ├─ Dockerfile: cluster.Dockerfile
│   ├─ Pipeline: docker-build-multi-platform-oci-ta
│   ├─ Platforms: x86_64, ppc64le, s390x, arm64
│   ├─ Output: quay.io/rh-ocp-dr/ramen/ramen-cluster-operator-0-1:TAG
│   └─ build-nudges-ref: [ramen-cluster-bundle-0-1]
│
├── Component 4: ramen-cluster-bundle-0-1
│   ├─ Dockerfile: bundle/cluster/Dockerfile
│   ├─ Pipeline: docker-build-oci-ta
│   ├─ Depends on: Component 3 (cluster-operator)
│   ├─ Output: quay.io/rh-ocp-dr/ramen/ramen-cluster-bundle-0-1:TAG
│   └─ build-nudges-ref: [ramen-fbc-catalog-0-1]
│
├── Component 5: ramen-console-ui-0-1
│   ├─ Dockerfile: Dockerfile (from ramen-console repo)
│   ├─ Pipeline: docker-build-oci-ta
│   ├─ Output: quay.io/rh-ocp-dr/ramen/ramen-console-ui-0-1:TAG
│   └─ (no dependencies)
│
└── Component 6: ramen-fbc-catalog-0-1
    ├─ Dockerfile: fbc/Dockerfile
    ├─ Pipeline: docker-build-oci-ta
    ├─ Depends on: hub-bundle-0-1, cluster-bundle-0-1
    ├─ Output: quay.io/rh-ocp-dr/ramen/ramen-fbc-catalog-0-1:TAG
    └─ Filesystem-based OLM catalog
```

### Build Execution Order

```
Time 0:00   Trigger push to main
    ↓
Time 0:05   All components triggered
    ├─ Hub Operator build starts (multi-platform)
    ├─ Cluster Operator build starts (multi-platform)
    └─ Console UI build starts (single platform)
    ↓
Time 0:35   Hub Operator complete → Image pushed
            Hub Bundle build triggered (build-nudges-ref dependency)
    ↓
Time 0:40   Cluster Operator complete → Image pushed
            Cluster Bundle build triggered (build-nudges-ref dependency)
    ↓
Time 0:45   Console UI complete → Image pushed
    ↓
Time 0:50   Hub Bundle build complete → Image pushed
            FBC Catalog build triggered (build-nudges-ref dependency)
    ↓
Time 0:55   Cluster Bundle build complete → Image pushed
            FBC Catalog build triggered again (ready now)
    ↓
Time 1:05   FBC Catalog build complete → Image pushed
    ↓
Time 1:10   Snapshot created with all 6 images
```

---

## Key Differences from Original Documentation

### What Was Wrong

1. ❌ I suggested separating operator and bundle into different phases
2. ❌ I suggested FBC as optional future work
3. ❌ I suggested 3 components total

### What's Correct (from RHWA template)

1. ✅ **Each operator = 2 components** (operator + bundle linked)
2. ✅ **FBC is core component** (part of standard release)
3. ✅ **6 components total** for RamenDR Standalone
4. ✅ **build-nudges-ref** creates automatic build dependencies
5. ✅ **Same repository** for operator + bundle (different Dockerfiles)
6. ✅ **ProjectDevelopmentStreamTemplate** for templated project creation

### Component Dependencies (build-nudges-ref)

```
Hub Operator ──nudges──> Hub Bundle ──nudges──> FBC Catalog
Cluster Operator ──nudges──> Cluster Bundle ──nudges──> FBC Catalog
Console UI (no dependencies)
```

This means:
- Operator builds independently (multi-platform)
- Bundle waits for operator to complete, then builds
- FBC waits for both bundles to complete, then builds
- All automatically coordinated via Konflux

---

## Repository Structure (Corrected)

```
ramen/ (same repo for both hub and cluster)
├── hub.Dockerfile              # Hub operator build
├── cluster.Dockerfile          # Cluster operator build
├── bundle/
│   ├── hub/
│   │   ├── Dockerfile          # Hub bundle image
│   │   ├── manifests/
│   │   │   ├── ramen-hub.clusterserviceversion.yaml
│   │   │   ├── ramen-crd-hub.yaml
│   │   │   └── ...
│   │   └── metadata/
│   │       └── annotations.yaml
│   └── cluster/
│       ├── Dockerfile          # Cluster bundle image
│       ├── manifests/
│       │   ├── ramen-cluster.clusterserviceversion.yaml
│       │   ├── ramen-crd-cluster.yaml
│       │   └── ...
│       └── metadata/
│           └── annotations.yaml
├── fbc/
│   ├── Dockerfile              # FBC catalog image
│   ├── catalog.yaml            # Catalog configuration
│   └── ramen-operator/
│       ├── hub/                # Hub channel definition
│       ├── cluster/            # Cluster channel definition
│       └── ...
├── cmd/
│   ├── hub/main.go
│   ├── cluster/main.go
│   └── main.go (if shared)
├── pkg/
│   ├── hub/
│   ├── cluster/
│   └── common/
└── .tekton/
    ├── ramen-hub-operator-on-push.yaml
    ├── ramen-cluster-operator-on-push.yaml
    ├── ramen-hub-bundle-on-push.yaml
    ├── ramen-cluster-bundle-on-push.yaml
    └── ramen-fbc-catalog-on-push.yaml

ramen-console/ (separate repo)
├── Dockerfile
├── package.json
├── packages/
│   ├── mco/
│   └── ...
└── .tekton/
    └── ramen-console-ui-on-push.yaml
```

---

## Pipeline Files Structure

Each component gets its own `.tekton/` pipeline file:

```
.tekton/
├── ramen-hub-operator-on-push.yaml
│   └─ Trigger: event == "push" && target_branch == "main"
│   └─ Pipeline: docker-build-multi-platform-oci-ta
│   └─ Dockerfile: hub.Dockerfile
│   └─ Output: ramen-hub-operator:{{revision}}
│
├── ramen-cluster-operator-on-push.yaml
│   └─ Trigger: event == "push" && target_branch == "main"
│   └─ Pipeline: docker-build-multi-platform-oci-ta
│   └─ Dockerfile: cluster.Dockerfile
│   └─ Output: ramen-cluster-operator:{{revision}}
│
├── ramen-hub-bundle-on-push.yaml
│   └─ Trigger: build-nudges-ref from hub-operator
│   └─ Pipeline: docker-build-oci-ta
│   └─ Dockerfile: bundle/hub/Dockerfile
│   └─ Output: ramen-hub-bundle:{{revision}}
│
├── ramen-cluster-bundle-on-push.yaml
│   └─ Trigger: build-nudges-ref from cluster-operator
│   └─ Pipeline: docker-build-oci-ta
│   └─ Dockerfile: bundle/cluster/Dockerfile
│   └─ Output: ramen-cluster-bundle:{{revision}}
│
└── ramen-fbc-catalog-on-push.yaml
    └─ Trigger: build-nudges-ref from both bundles
    └─ Pipeline: docker-build-oci-ta
    └─ Dockerfile: fbc/Dockerfile
    └─ Output: ramen-fbc-catalog:{{revision}}
```

---

## Using ProjectDevelopmentStreamTemplate

### To Create the Project Programmatically

1. **Save the template** as `ramen-dr-standalone-template.yaml`
2. **Apply to Konflux namespace**:
   ```bash
   kubectl apply -f ramen-dr-standalone-template.yaml
   ```

3. **Konflux instantly creates all 6 components with proper linkages**

### Variable Substitution

When applied, template variables are replaced:

```yaml
variables:
  - name: operatorShortName
    value: ramen              # expands to {{.operatorShortName}} = ramen
  
  - name: version
    value: 0-1                # expands to {{.version}} = 0-1
  
  - name: versionRHEL
    value: 9                  # expands to {{.versionRHEL}} = 9
```

Results in:
- Application: `ramen-dr-standalone-0-1`
- Components: `ramen-hub-operator-0-1`, `ramen-hub-bundle-0-1`, etc.
- Images: `ramen-hub-operator-0-1:TAG`, `ramen-hub-bundle-0-1:TAG`, etc.

---

## Summary: Corrected Architecture

### Old (Incorrect) Approach
- 3 components (hub, cluster, console)
- FBC as separate future work
- Bundle built separately from operator

### New (Correct) Approach  
- 6 components (3 operators + 3 bundles + console + FBC)
- Each operator paired with bundle via build-nudges-ref
- FBC is core component that combines bundles
- ProjectDevelopmentStreamTemplate for automated project setup

### Key RHWA Template Features to Reuse
1. ✅ Component pairing (operator + bundle)
2. ✅ build-nudges-ref for dependencies
3. ✅ ProjectDevelopmentStreamTemplate for templating
4. ✅ ImageRepository resources per component
5. ✅ IntegrationTestScenario for EC compliance
6. ✅ Template variables for versioning

---

## Next Steps

1. **Adapt the template above** for your specific needs
2. **Update all documentation** to reflect 6-component architecture
3. **Create correct .tekton/ files** for each component
4. **Define bundle Dockerfiles** (bundle/hub/Dockerfile, bundle/cluster/Dockerfile)
5. **Create FBC structure** (fbc/Dockerfile, catalog configuration)
6. **Apply template** to Konflux namespace to generate all resources

See corrected [IMPLEMENTATION_BLUEPRINT.md](./IMPLEMENTATION_BLUEPRINT.md) for step-by-step instructions.
