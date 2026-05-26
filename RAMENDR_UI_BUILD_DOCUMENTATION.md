# ODF Console RamenDR UI Build Documentation

## Project Information

### Repository & Upstream

**ODF Console is an UPSTREAM/COMMUNITY project** maintained by Red Hat:

- **Repository**: https://github.com/red-hat-storage/odf-console (Public, Open Source)
- **License**: Apache 2.0
- **Organization**: Red Hat Storage (red-hat-storage)
- **Maintainers**: Red Hat team members (bipuladh, SanjalKatiyar, vbnrh)

**Project Type**:
- ✅ **Upstream** - This IS the canonical repository for ODF Console
- ✅ **Open Source** - Licensed under Apache 2.0, freely available
- ✅ **Community-driven** - Contributions welcome from community
- ✅ **Part of OpenShift Ecosystem** - Plugin for OpenShift Container Platform

**Dependency Chain**:
```
ODF Console (Upstream)
    ↓ depends on
OpenShift Console (github.com/openshift/console)
    ↓ depends on
OpenShift Container Platform (Kubernetes-based)
```

### Build Artifacts & Distribution

- **Source**: Red Hat Storage GitHub organization
- **Artifacts**: Published to Quay.io (Red Hat's container registry)
  - `quay.io/odf-console` - ODF plugin image
  - `quay.io/odf-multicluster-console` - MCO/RamenDR plugin image
  - `quay.io/ocs-client-console` - Client plugin image
- **CI/CD**: OpenShift CI (`.ci-operator.yaml`)

## Overview

The **RamenDR (Ramen Disaster Recovery) UI** is part of the ODF Console project, implemented as an **OpenShift Console Dynamic Plugin**. It provides the user interface for OpenShift's multi-cluster disaster recovery and application failover capabilities.

### What is RamenDR UI?

The RamenDR UI is a TypeScript/React-based plugin that integrates with OpenShift Container Platform (OCP) Console to **manage and monitor RamenDR Kubernetes objects**. It provides a dashboard and forms for interacting with RamenDR Custom Resource Definitions (CRDs):

**RamenDR Objects Managed**:
- **DRPolicy** - Defines disaster recovery policies and replication rules
- **DRPlacement** - Specifies which applications and data are protected and how they're placed
- **DRClusterConnection** - Establishes secure connections between hub and managed clusters
- **DRStatus** - Tracks replication and recovery status

**UI Features**:
- **Disaster Recovery Dashboard** - View and manage DR policies, cluster connections, and recovery status
- **DR Policy Management** - Create, edit, and manage DRPolicy CRD resources
- **Application Failover/Relocation** - UI for failing over applications between clusters via DRPlacement
- **Application Enrollment** - Manage applications for disaster recovery protection (declarative via DRPlacement)
- **Multi-cluster Visibility** - Monitor DR status across Kubernetes clusters using ACM (Advanced Cluster Management)

## Architecture

### Is it a Standalone Build?

**No** - RamenDR UI is **a plugin that manages RamenDR Kubernetes objects** within the OCP Console. It's built as:

- ✅ **A dynamic plugin module** within the ODF/MCO Console
- ✅ **Provides UI/Dashboard** for managing RamenDR Custom Resource Definitions (CRDs)
- ✅ **Manages RamenDR objects** like `DRPolicy`, `DRPlacement`, `DRClusterConnection`, etc.
- ✅ **Loaded at runtime** by OpenShift Console
- ❌ **NOT a standalone application** - requires OCP Console host and RamenDR Operator

### Plugin Architecture

```
OpenShift Console (Host)
    ↓
ODF Console Plugins (Remote Modules)
    ├── ODF Plugin (Storage UI - manages ODF/Ceph resources)
    ├── MCO Plugin (Multi-cluster Operations) ← Contains RamenDR UI
    │   └── RamenDR UI manages RamenDR CRD objects:
    │       - DRPolicy (disaster recovery policy configuration)
    │       - DRPlacement (application placement across clusters)
    │       - DRClusterConnection (inter-cluster connections)
    │       - etc.
    └── Client Plugin (ODF Client Console)
```

**RamenDR UI is part of the MCO (Multi-Cluster Operator) Plugin**, which provides:

- **Disaster Recovery Dashboard** - View DRPolicy, DRPlacement status
- **DR Policy Creation & Management** - Create/edit DRPolicy CRD objects
- **Application Protection** - Manage which applications are protected via DRPlacement
- **Multi-cluster Visibility** - Monitor replication and failover status
- **Integration with ACM** - Leverages Advanced Cluster Management

## RamenDR Object Management

The RamenDR UI manages **Kubernetes Custom Resources** (CRDs) provided by the **Ramen Operator**:

### Object Model

```
Cluster Hub (OCP + Ramen Controller)
    ├── DRPolicy CRD
    │   └── Defines replication schedule, retention, target clusters
    ├── DRPlacement CRD
    │   └── Specifies which workloads are protected and where
    ├── DRClusterConnection CRD
    │   └── Secure connections between hub and managed clusters
    └── DRPlacementStatus
        └── Reports replication/recovery status

Managed Cluster
    └── Receives replicated data based on DRPolicy/DRPlacement
```

### Typical Workflow

1. **User creates DRPolicy** via RamenDR UI
   - Specifies replication schedule, backup retention, target clusters
   - Policy is stored as Kubernetes object in etcd

2. **User creates DRPlacement** via RamenDR UI
   - Specifies which applications/PVCs to protect
   - Links to DRPolicy for replication settings
   - Triggers Ramen Operator to set up replication

3. **Ramen Operator watches objects** and:
   - Configures Ceph/ODF replication based on DRPolicy
   - Establishes cluster connections
   - Updates DRPlacementStatus with replication/recovery status

4. **RamenDR UI displays status**
   - Shows replication progress
   - Enables failover/relocation operations
   - Monitors application protection status

### DRPolicy Example
```yaml
kind: DRPolicy
metadata:
  name: my-dr-policy
spec:
  drClusterConnections:
    - name: cluster-connection-1
  schedingMechanism: peer
  replicationClassMechanism: copy
```

### DRPlacement Example
```yaml
kind: DRPlacement
metadata:
  name: app-protection
spec:
  placementRef:
    name: app-placement  # PlacementRule from ACM
  drPolicyRef:
    name: my-dr-policy
  preferredCluster: cluster-1
```

## Build System

### Build Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Package Manager** | Yarn Berry (v4) / Corepack | Monorepo dependency management |
| **Bundler** | Webpack 5 | Module bundling and code splitting |
| **Language** | TypeScript | Type-safe development |
| **Build Framework** | OpenShift Dynamic Plugin SDK | Console integration layer |
| **CSS** | SCSS + PostCSS | Styling with theme support |
| **Runtime** | Node.js 16+ | Build environment |
| **CI System** | OpenShift CI | `.ci-operator.yaml` for CI/CD |

### Build Environment

**OpenShift CI Integration**:
```yaml
# .ci-operator.yaml
build_root_image:
  name: odf-console-ci-runner
  namespace: ci
  tag: node22  # Node 22 runtime container
```

The project uses OpenShift's CI system for automated builds and testing on each commit/PR.

### How it's Built

#### 1. **Build Process Overview**

```
Development Code (TypeScript/React)
    ↓
[build:generate] Generate plugin package metadata
    ↓
[webpack] Bundle and transpile code
    ↓
Distribution Bundle (dist/)
    ↓
Served on localhost:9001 (dev) or remote registry (prod)
    ↓
Loaded by OCP Console at runtime
```

#### 2. **Build Commands**

The project uses **Yarn scripts** defined in `package.json`:

```bash
# For MCO/RamenDR specifically:
yarn build-mco                  # Production build of MCO plugin
yarn dev-mco                    # Development mode with webpack-dev-server
yarn analyze-mco                # Bundle analysis for optimization

# Universal builds (all plugins):
yarn build                      # Production build (default ODF plugin)
yarn dev                        # Development mode
yarn lint                       # Code linting
yarn test                       # Unit tests
```

#### 3. **Build Workflow Details**

**Step 1: Preparation (`build:generate`)**

```bash
NODE_ENV=production PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn build:generate
```

This step:
- Cleans previous build artifacts (`plugins/mco/dist/`)
- Validates plugin version via `scripts/versionCheck.mts`
- Generates plugin metadata via `scripts/generatePluginPackage.mts`
- Creates `plugins/mco/package.json` with console-plugin configuration

**Step 2: Webpack Bundling (`build:plugin`)**

```bash
NODE_OPTIONS='--max-old-space-size=4096' yarn tsx node_modules/.bin/webpack -c ./webpack.config.ts
```

Webpack Configuration:
- **Entry Point**: `plugins/mco/` directory
- **Output**: `plugins/mco/dist/`
- **Format**: Remote Module Bundle (ConsoleRemotePlugin format)
- **Splitting**: Code splitting via named chunks
- **Optimization**: Minification, tree-shaking (production only)

#### 4. **Webpack Configuration Details**

**File**: `webpack.config.ts`

Key configurations for RamenDR:

```typescript
// Environment variables control the build
const PLUGIN = process.env.PLUGIN;              // 'mco', 'odf', or 'client'
const NODE_ENV = process.env.NODE_ENV;          // 'production' or 'development'
const I8N_NS = process.env.I8N_NS;              // 'plugin__odf-multicluster-console'

// Plugin-specific setup
process.chdir(path.resolve(__dirname, `plugins/${PLUGIN}`));

// Output configuration
output: {
  path: path.resolve('./dist'),
  filename: '[name]-bundle.js',
  chunkFilename: '[name]-chunk.js',
}

// Module resolution
resolve: {
  extensions: ['.ts', '.tsx', '.js', '.jsx'],
  alias: {
    '@odf/shared': path.resolve(__dirname, './packages/shared/src/'),
  }
}
```

**Loaders**:
- `ts-loader` - TypeScript transpilation
- `css-loader` + `sass-loader` - SCSS to CSS
- `MiniCssExtractPlugin` - Separate CSS output
- `CopyPlugin` - Copy localization files (i18n)

**Plugins**:
- `ConsoleRemotePlugin` - OpenShift Console integration
- `ForkTsCheckerWebpackPlugin` - Type checking
- `BundleAnalyzerPlugin` - Optional bundle analysis
- `MiniCssExtractPlugin` - CSS extraction

### Plugin Structure

```
odf-console/
├── packages/                           # Source code monorepo
│   ├── mco/                           # MCO/RamenDR plugin source
│   │   ├── components/
│   │   │   ├── disaster-recovery-page/    # Main DR dashboard
│   │   │   ├── create-dr-policy/          # Policy creation UI
│   │   │   ├── modals/
│   │   │   │   ├── app-failover-relocate/ # Failover UI
│   │   │   │   └── app-manage-policies/   # Policy management
│   │   │   ├── discovered-application-wizard/
│   │   │   └── topology/                  # Cluster topology view
│   │   ├── hooks/                     # Custom React hooks
│   │   ├── constants/                 # Constants and config
│   │   ├── features.ts                # Feature flag detection
│   │   └── types/                     # TypeScript interfaces
│   ├── shared/                        # Shared ODF utilities
│   ├── odf/                          # ODF storage plugin
│   ├── client/                       # ODF client plugin
│   └── odf-plugin-sdk/               # SDK utilities
├── plugins/                           # Built plugin outputs
│   ├── mco/                          # MCO plugin distribution
│   │   ├── dist/                     # Compiled output
│   │   ├── console-plugin.json       # Plugin manifest
│   │   └── console-extensions.json   # Extension definitions
│   ├── odf/                          # ODF storage plugin
│   └── client/                       # Client plugin
├── webpack.config.ts                 # Universal webpack config
├── tsconfig.json                     # TypeScript config
└── package.json                      # Root dependencies
```

## Dependencies

### Kubernetes CRD Dependencies

The RamenDR UI watches and interacts with these external Kubernetes objects:

#### RamenDR Operator CRDs (Ramen-specific)
- **DRPolicy** - Disaster recovery policy configuration
- **DRPlacement** - Application placement and protection spec
- **DRClusterConnection** - Inter-cluster DR connections
- **DRPlacementStatus** - Replication/recovery status (watched)

#### ACM (Advanced Cluster Management) CRDs (Required Integration)
- **PlacementRule** (or Placement) - ACM object referenced in DRPlacement.spec.placementRef
- **MultiClusterObservability** - ACM observability CRD (watched for feature flag detection)
- **ManagedCluster** - ACM managed cluster definitions (read for multi-cluster context)

#### ODF/Ceph CRDs (Storage Integration)
- **MirrorPeer** - ODF peer replication configuration (watched for SSAR checks)
- **StorageClass** - Kubernetes storage classes used for replica storage

#### Feature Flag Detection (in features.ts)
```typescript
// Checks ACM MultiClusterObservability status
const acmObservability = k8sList({
  model: AcmMultiClusterObservabilityModel,
  queryParams: { cluster: HUB_CLUSTER_NAME }
});

// Checks admin access to MirrorPeer (ODF)
const ssarChecks = {
  [ADMIN_FLAG]: {
    group: MirrorPeerModel.apiGroup,
    resource: MirrorPeerModel.plural,
    verb: 'create'
  }
};
```

### Direct Dependencies

**RamenDR/MCO Package** (`packages/mco/package.json`):
```json
{
  "name": "@odf/mco",
  "dependencies": {
    "@odf-console/shared": "workspace:*"  // Local workspace reference
  }
}
```

### Shared Dependencies (Root `package.json`)

#### Console/Framework
- `@openshift-console/dynamic-plugin-sdk` (v4.21.0) - Plugin SDK
- `@openshift-console/dynamic-plugin-sdk-webpack` (v4.21.0) - Webpack integration
- `@openshift-console/plugin-shared` - Shared console components

#### UI Components
- `@patternfly/react-core` (v6.4.0) - Base component library
- `@patternfly/react-charts` (v8.4.0) - Charting library
- `@patternfly/react-topology` (v6.4.0) - Topology/graph visualization
- `@patternfly/react-table` (v6.4.0) - Data tables

#### React Core
- `react` (^17) - React framework
- `react-dom` (^17) - DOM binding
- `react-helmet` - Document head management
- `react-i18next` - Internationalization
- `react-redux` - State management

#### API/Kubernetes
- `@openshift/dynamic-plugin-sdk` - Kubernetes API integration
- `@types/react` (^17) - React type definitions

#### AWS Services (for S3/Object Storage)
- `@aws-sdk/client-iam` (^3.1011.0)
- `@aws-sdk/client-s3` (^3.1011.0)
- `@aws-sdk/lib-storage` (^3.1011.0)
- `@aws-sdk/s3-request-presigner` (^3.1011.0)

#### Code Quality (Development)
- `typescript` - TypeScript compiler
- `eslint` - JavaScript linting
- `prettier` - Code formatting
- `jest` - Unit testing
- `cypress` - E2E testing

#### Build Tools
- `webpack` (v5) - Module bundler
- `ts-loader` - TypeScript webpack loader
- `sass-loader` - SCSS webpack loader
- `mini-css-extract-plugin` - CSS extraction
- `fork-ts-checker-webpack-plugin` - Type checking

### Transitive Dependencies

The build system includes indirect dependencies such as:
- `lodash-es` - Utility library
- `yaml` - YAML parsing
- `axios` - HTTP client
- `date-fns` - Date utilities
- `recharts` - Visualization library (via PatternFly)

## Build Output

### Distribution Files

After building, the plugin generates:

```
plugins/mco/dist/
├── mco-bundle.js                 # Main plugin bundle
├── [component]-chunk.js          # Code-split chunks
├── *.css                         # Extracted stylesheets
├── locales/
│   ├── en/plugin__odf-multicluster-console.json
│   ├── ja/plugin__odf-multicluster-console.json
│   └── ...other-languages
└── assets/
    └── images, fonts, etc.
```

### Plugin Manifest

**Console Plugin Metadata** (`plugins/mco/console-plugin.json`):
```json
{
  "name": "odf-multicluster-console",
  "version": "0.0.0",
  "displayName": "ODF MCO(ODF Multicluster Orchestrator) Plugin",
  "description": "Console plugin for ODF and DR",
  "exposedModules": {
    "features": "@odf/mco/features",
    "disasterRecoveryPage": "@odf/mco/components/disaster-recovery-page/disaster-recovery",
    "createDataPolicy": "@odf/mco/components/create-dr-policy/create-dr-policy",
    "appFailoverRelocate": "@odf/mco/components/modals/app-failover-relocate/acm-action-callback",
    "appManagePolicy": "@odf/mco/components/modals/app-manage-policies/app-manage-policies-modal",
    "enrollDiscoveredApplication": "@odf/mco/components/discovered-application-wizard/enroll-discovered-application"
  }
}
```

**Extensions** (`plugins/mco/console-extensions.json`):
- Registers navigation menu items
- Defines routes and pages
- Connects feature flags
- Registers modals and components

## Development Workflow

### Local Development Setup

#### Prerequisites
```bash
# Node.js 16+
node --version

# Enable Yarn Berry via Corepack
corepack enable

# Install dependencies
yarn install
```

#### Running in Development Mode

**Option 1: With Console Container**
```bash
CONSOLE_VERSION=4.19 \
BRIDGE_PLUGINS='odf-console=http://localhost:9001' \
PLUGIN=mco \
I8N_NS=plugin__odf-multicluster-console \
yarn dev-mco
```

- Starts webpack-dev-server on port 9001
- Bundles code in development mode
- Enables source maps and hot reload

**Option 2: Manual Console Setup**
```bash
# Terminal 1: Run OCP Console bridge
./bin/bridge -plugins odf-console=http://localhost:9001/

# Terminal 2: Run webpack dev server
PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn dev-mco
```

### Console Extension Points

**RamenDR registers these extension points**:

1. **Navigation**
   - Section: "mco-data-services" (under ACM perspective)
   - Menu Item: "Disaster recovery" → `/multicloud/data-services/disaster-recovery`

2. **Pages/Routes**
   - DR Dashboard: `/multicloud/data-services/disaster-recovery`
   - Create DR Policy: `/multicloud/data-services/disaster-recovery/policies/.../~new`

3. **Modals/Components**
   - Application Failover/Relocate modal
   - Policy Management modal
   - Application Enrollment wizard

4. **Feature Flags**
   - `ADMIN` - User has cluster admin permissions
   - `ACM_OBSERVABILITY_FLAG` - ACM Multi-cluster Observability enabled

## Building the ODF Console

### Full Build Process (All Plugins)

```bash
# Step 1: Setup environment
cd odf-console
corepack enable
yarn install

# Step 2: Build all plugins (ODF, MCO, Client)
yarn build

# Step 3: Verify builds
ls -la plugins/*/dist/
```

### Building Individual Plugins

```bash
# Build only MCO/RamenDR plugin
NODE_ENV=production PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn build-mco

# Build only ODF plugin
NODE_ENV=production PLUGIN=odf I8N_NS=plugin__odf-console yarn build

# Build only Client plugin
NODE_ENV=production PLUGIN=client I8N_NS=plugin__odf-client-console yarn build-client
```

### Build Output Locations

```
After successful build:
├── plugins/mco/dist/          # MCO/RamenDR plugin (ready to serve)
│   └── mco-bundle.js          # Main bundle
├── plugins/odf/dist/          # ODF storage plugin
│   └── odf-bundle.js
└── plugins/client/dist/       # Client plugin
    └── client-bundle.js
```

### Production Release Build

```bash
# Set version and build for production
export PLUGIN_VERSION=1.0.0
NODE_ENV=production PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn build-mco
NODE_ENV=production PLUGIN=odf I8N_NS=plugin__odf-console yarn build
NODE_ENV=production PLUGIN=client I8N_NS=plugin__odf-client-console yarn build-client
```

## Removing ACM/Ceph Dependencies from Console

### Understanding the Dependencies

The RamenDR UI has **optional** dependencies on external systems:

- **ACM (Advanced Cluster Management)** - Used for PlacementRule references and feature flags
- **ODF/Ceph** - Used for MirrorPeer SSAR checks and storage classes

These are **not strict requirements** for the UI to render, but provide additional functionality.

### Building Without ACM Integration

If you want to build RamenDR UI without ACM dependencies:

#### 1. **Modify Feature Flag Detection** (`packages/mco/features.ts`)

```typescript
// Comment out ACM observability detection
// export const detectACMObservability = async (setFlag, flagKey, id) => { ... }

// Set ACM_OBSERVABILITY_FLAG to true by default
const handleACMFlag = async (setFlag: SetFeatureFlag, flagKey: string) => {
  setFlag(flagKey, true); // Skip ACM check
};
```

#### 2. **Modify DRPlacement Forms** (`packages/mco/components/create-dr-policy/`)

Remove ACM PlacementRule references:

```typescript
// Before: Expects PlacementRule from ACM
placementRef: {
  name: 'app-placement'  // ACM PlacementRule
}

// After: Allow direct workload selection
workloads: [
  { name: 'my-app', namespace: 'default' }
]
```

#### 3. **Build Without ACM**

```bash
NODE_ENV=production PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn build-mco
# The plugin will still build, but without ACM integration features
```

### Building Without ODF/Ceph Integration

If you want to build RamenDR UI without ODF dependencies:

#### 1. **Modify SSAR Checks** (`packages/mco/features.ts`)

```typescript
// Comment out ODF MirrorPeer SSAR checks
const ssarChecks = {
  // [ADMIN_FLAG]: {
  //   group: MirrorPeerModel.apiGroup,
  //   resource: MirrorPeerModel.plural,
  //   verb: 'create'
  // }
};
```

#### 2. **Skip MirrorPeer References** (`packages/mco/constants/`)

Remove or mock MirrorPeerModel imports:

```typescript
// Remove: import { MirrorPeerModel } from '@odf/shared';

// Add mock if needed:
export const MirrorPeerModel = { apiGroup: 'ramen.io', plural: 'mirrorpeers' };
```

#### 3. **Build Without ODF**

```bash
NODE_ENV=production PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn build-mco
```

### Minimal RamenDR UI (Ramen-Only)

For a **Ramen-only deployment** without ACM or ODF:

#### Changes Required

**1. Update `packages/mco/package.json`**:
```json
{
  "name": "@odf/mco",
  "dependencies": {
    "@odf-console/shared": "workspace:*"
  }
  // Remove ACM and ODF model imports
}
```

**2. Update `packages/mco/features.ts`**:
```typescript
// Disable ACM feature checks
export const setFeatureFlag = async (setFlag: SetFeatureFlag) => {
  setFlag('ACM_OBSERVABILITY_FLAG', true);  // Assume enabled
  setFlag('ADMIN_FLAG', true);              // Assume admin
};
```

**3. Update `packages/mco/components/create-dr-policy/`**:
```typescript
// Remove ACM PlacementRule picker
// Allow direct cluster/workload selection
```

**4. Build minimal version**:
```bash
NODE_ENV=production PLUGIN=mco I8N_NS=plugin__odf-multicluster-console yarn build-mco
```

### Functional Coverage by Build Type

| Feature | Full Build | No-ACM | No-ODF | Ramen-Only |
|---------|-----------|--------|--------|-----------|
| DRPolicy UI | ✅ | ✅ | ✅ | ✅ |
| DRPlacement UI | ✅ | ⚠️ Limited | ✅ | ⚠️ Limited |
| ACM Integration | ✅ | ❌ | ✅ | ❌ |
| ODF Storage | ✅ | ✅ | ❌ | ❌ |
| Feature Flags | ✅ | Static | ✅ | Static |
| SSAR Checks | ✅ | ✅ | ❌ | ❌ |
| Bundle Size | ~500KB | ~400KB | ~450KB | ~350KB |

## Build Characteristics

### Production vs Development Build

| Aspect | Production | Development |
|--------|-----------|-------------|
| **Size** | Minified (~500KB main) | Unminified (~2MB main) |
| **Source Maps** | Separate `*.map` files | Inline (eval-cheap-module) |
| **Type Checking** | ✅ Full validation | Can skip with `DEV_NO_TYPE_CHECK=true` |
| **Performance** | Optimized | Fast rebuild |
| **Dev Tools** | 🔴 Limited | ✅ Full debugging |

### Memory Requirements
- Production build: ~4GB Node heap (`--max-old-space-size=4096`)
- Development: Platform dependent

### Performance Optimization
- Code splitting by component
- Lazy loading of modal dialogs
- Separate CSS extraction
- Localization files loaded per-locale

## Console Platform Integration

### Multi-Cluster Architecture

RamenDR integrates with:

**Ramen Ecosystem (Managed by RamenDR UI)**:
1. **Ramen Operator** - Watches DRPolicy/DRPlacement CRDs and manages replication

**External Ecosystem Dependencies (Referenced/Watched)**:
2. **OpenShift Container Platform (OCP)** - Host console runs on OCP (hub cluster)
3. **Advanced Cluster Management (ACM)** 
   - Provides PlacementRule (referenced in DRPlacement)
   - Provides MultiClusterObservability (feature flag checking)
   - Provides ManagedCluster definitions
4. **ODF/Ceph** 
   - Provides MirrorPeer CRD (SSAR checking)
   - Provides storage classes for replication data
5. **Managed Clusters** - Remote OCP clusters receiving replicated data based on DRPolicy/DRPlacement

### Runtime Loading

```
OCP Console starts
    ↓
Loads MCO plugin from URL: http://localhost:9001/ (dev)
    ↓
RamenDR UI Component initializes
    ↓
Watches Kubernetes objects:
    ├── DRPolicy (Ramen CRD) - Managed by UI
    ├── DRPlacement (Ramen CRD) - Managed by UI
    ├── PlacementRule (ACM CRD) - Referenced in DRPlacement
    ├── MirrorPeer (ODF CRD) - For SSAR checks
    └── MultiClusterObservability (ACM CRD) - For feature flags
    ↓
RamenDR UI rendered in ACM perspective
```

## Troubleshooting Build Issues

### Common Issues

| Issue | Solution |
|-------|----------|
| **Out of Memory** | Increase Node heap: `NODE_OPTIONS='--max-old-space-size=8192'` |
| **Port 9001 Already in Use** | Change: `devServer.port` in webpack.config.ts |
| **Circular Dependencies** | Check: CircularDependencyPlugin errors in console |
| **Type Errors** | Run: `yarn lint` and fix violations |
| **Missing Locales** | Ensure i18n files copied from `locales/` directory |
| **Plugin Not Loading** | Verify: BRIDGE_PLUGINS environment variable set correctly |

## Build Validation

### Tests

```bash
# Unit tests
yarn test

# E2E tests (Cypress)
yarn test-cypress

# Bundle analysis
yarn analyze-mco
```

### Linting & Formatting

```bash
# Check code style
yarn lint

# Auto-fix issues
yarn lint-fix

# Format code
yarn format
```

## References

- **ODF Console Upstream**: https://github.com/red-hat-storage/odf-console
- **OCP Console Plugin SDK**: https://github.com/openshift/dynamic-plugin-sdk
- **OpenShift Console**: https://github.com/openshift/console
- **PatternFly Components**: https://www.patternfly.org
- **Ramen DR Project**: https://github.com/RamenDR/ramen
- **Webpack Documentation**: https://webpack.js.org

### Related Projects

**ODF Console Ecosystem**:
- **OpenShift Console** - Host console runtime
- **ODF Operator** - Kubernetes operator providing ODF/Ceph services
- **Ramen Operator** - Provides DR CRDs (DRPolicy, DRPlacement)
- **ACM/OCM** - Advanced Cluster Management for multi-cluster features
- **Konflux** - Red Hat's internal GitOps platform for managing deployments

**Downstream Consumer Examples**:
- **tenants-config** (rh-ocp-dr branch) - May use Konflux for deploying ODF Console with RamenDR UI
- **Other Red Hat Internal Projects** - May customize or extend ODF Console for specific use cases

## Summary

| Aspect | Details |
|--------|---------|
| **What** | RamenDR is ODF Console's disaster recovery UI plugin |
| **Type** | OpenShift Dynamic Plugin (remote module) |
| **Manages** | RamenDR CRDs (DRPolicy, DRPlacement, DRClusterConnection) |
| **Depends On** | ACM PlacementRule, ODF MirrorPeer, RamenDR Operator |
| **Build Tool** | Webpack 5 with TypeScript |
| **Build Options** | Full build, No-ACM, No-ODF, or Ramen-Only |
| **Dependencies** | React, PatternFly, OpenShift SDK, AWS SDK |
| **Output** | `plugins/mco/dist/` with JS bundles, CSS, and locales |
| **Integration** | Loaded at runtime by OCP Console via Module Federation |
| **Dev Env** | Localhost 9001 with webpack-dev-server |
| **Perspective** | ACM (Advanced Cluster Management) |

### Build Options Summary

- **Full Build**: All features, ACM + ODF integration (~500KB)
- **No-ACM Build**: RamenDR + ODF, skip ACM features (~400KB)  
- **No-ODF Build**: RamenDR + ACM, skip ODF features (~450KB)
- **Ramen-Only Build**: RamenDR standalone, minimal (~350KB)

### Key Distinctions

- **Managed by RamenDR UI**: DRPolicy, DRPlacement, DRClusterConnection (Ramen Operator CRDs)
- **Consumed by RamenDR UI**: PlacementRule (from ACM), MirrorPeer (from ODF) - **optional**
- **Not directly managed**: ACM objects, ODF storage classes, ManagedClusters (read-only references)

The RamenDR UI is a production-grade TypeScript/React plugin that integrates seamlessly with OpenShift's console to provide enterprise-grade disaster recovery features for Kubernetes applications. It can be deployed with full external integration or in a minimal Ramen-only configuration.

## Project Landscape

### ODF Console Position in Red Hat Ecosystem

```
Red Hat's Kubernetes/OpenShift Stack
│
├── [UPSTREAM] github.com/red-hat-storage/odf-console
│   │   OpenShift Plugins: ODF Storage, MCO (RamenDR), Client
│   │   License: Apache 2.0
│   └── Builds artifacts → quay.io/odf-console, quay.io/odf-multicluster-console
│
└── [DOWNSTREAM/INTERNAL] Red Hat Internal Tools
    ├── Konflux - GitOps Platform for managing deployments
    │   └── Uses tenants-config for cluster/tenant definitions
    │
    └── tenants-config (rh-ocp-dr branch)
        └── May deploy ODF Console plugins to Konflux clusters
```

### Source Code Models

| Component | Model | Source | Availability |
|-----------|-------|--------|----------------|
| **ODF Console** | Upstream | github.com/red-hat-storage | ✅ Public, Open Source |
| **Ramen Operator** | Upstream | github.com/RamenDR/ramen | ✅ Public, Open Source |
| **OpenShift Console** | Upstream | github.com/openshift/console | ✅ Public, Open Source |
| **Konflux** | Downstream/Internal | Red Hat Internal | ❌ Red Hat Internal |
| **tenants-config** | Downstream/Internal | Konflux Workspace | ❌ Red Hat Internal |

### Development Workflow

```
Public Upstream (ODF Console)
    ↓ [cherry-picks/depends on]
Red Hat Internal (Konflux/tenants-config)
    ↓ [deploys]
Production OCP Clusters
```

The odf-console itself is **fully open source and upstream**. Red Hat's internal projects may use or extend it, but the core project welcomes community contributions.
