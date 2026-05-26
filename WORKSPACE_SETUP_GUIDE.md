# Phase 1: Create Konflux Workspace & Components

Step-by-step guide to create your Konflux application workspace and register all 6 RamenDR Standalone components, based on real RHWA project samples.

---

## 🎯 What You're Creating

**Final State:**
```
Konflux Namespace: rh-ocp-dr-tenant
  └─ Application: ramen-dr-standalone-0-1
      ├─ Component 1: ramen-hub-operator (multi-platform)
      ├─ Component 2: ramen-hub-bundle
      ├─ Component 3: ramen-cluster-operator (multi-platform)
      ├─ Component 4: ramen-cluster-bundle
      ├─ Component 5: ramen-console-ui
      └─ Component 6: ramen-fbc-catalog
```

Each component will have:
- `.tekton/` directory with `on-push.yaml` and `on-pull-request.yaml` pipelines
- Auto-generated Tekton pipeline in the repository
- Automatic builds on every push to `main` branch

---

## 📊 Two Approaches

### Approach A: UI-Based (Recommended for First Time)
**Pros:** Visual, easy to understand, confirms everything works
**Cons:** Manual for each component (6 times), slower
**Time:** ~30 minutes

### Approach B: Programmatic (CLI + YAML)
**Pros:** Fast, repeatable, scriptable
**Cons:** Requires kubectl, need YAML files ready
**Time:** ~10 minutes

**Recommendation:** Start with Approach A for **1-2 components** to understand the flow, then use Approach B for remaining components.

---

## ✅ Prerequisites

### For Both Approaches

1. **Konflux instance URL and credentials** - From platform engineer
2. **GitLab access** - Can push to:
   - `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen`
   - `https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console`

3. **Namespace access:**
   ```bash
   # Verify you have access to rh-ocp-dr-tenant namespace
   kubectl get namespace rh-ocp-dr-tenant
   kubectl get components -n rh-ocp-dr-tenant
   ```

### For Approach B Only

**Before using Approach B, you must set up CLI access. See:** [CLI_KUBECTL_ACCESS.md](./CLI_KUBECTL_ACCESS.md)

#### How to Get Your Login Token

**Option 1: From ArgoCD UI (You Have This)**

1. Open the ArgoCD dashboard (you're already viewing it)
2. Look for your user profile/account in top-right corner
3. Click on account menu → "Copy Login Command" or similar
4. The command will look like:
   ```bash
   oc login --token=sha256~xxxxx... --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
   ```
5. Copy the entire command and paste it in your terminal

**Option 2: From Your Platform Engineer**

Ask your PE: "Can you provide me with an oc login command or token for rh-ocp-dr-tenant namespace?"

**Option 3: If You Already Have kubeconfig**

```bash
# Check your existing kubeconfig
cat ~/.kube/config

# Look for: "token:" field - that's your token
# Then use it:
oc login --token=<token-from-kubeconfig> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
```

#### Using the Token

Once you have your token:

```bash
# Install kubectl CLI
kubectl version --client

# Login to Konflux cluster (replace <YOUR_TOKEN> with actual token)
oc login --token=<YOUR_TOKEN> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Verify access
kubectl get namespace rh-ocp-dr-tenant
kubectl get components -n rh-ocp-dr-tenant
```

#### How to Get Your Cluster URL

You have several options:

**Option 1: From Your Platform Engineer (Easiest)**
```
Ask: "What is the Konflux cluster API endpoint?"
Example (yours): https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
Example (other Red Hat): https://api.workbench.konflux-ci.dev:6443
```

**Option 2: From Konflux UI You're Already Using**
```
If you already have the UI open:
- Look at the address bar: https://<cluster-url>/applications
- Extract just the cluster part: https://<cluster-url>
```

**Option 3: If You Already Have kubeconfig**
```bash
# Shows current cluster
kubectl cluster-info

# Example output:
# Kubernetes control plane is running at https://api.example.redhat.com:6443
# Use this URL structure (https://api.example.redhat.com) or ask PE

# Or extract from kubeconfig file
grep "server:" ~/.kube/config
# Example: server: https://api.konflux.example.com:6443
```

**Option 4: From tenants-config Git Repository**
```bash
# Check your tenants-config/.kubeconfig or documentation
cat ~/.config/kubeconfig
grep "server:" 

# Or check the GitOps cluster definition
cat /home/nlevanon/workspace/Konflux/tenants-config/cluster/rh-ocp-dr/*/kustomization.yaml
```

**Option 5: Ask in Documentation**
```bash
# Check if there's documentation in your workspace
grep -r "cluster.*url" /home/nlevanon/workspace/Konflux/

# Check tenants-config README
cat /home/nlevanon/workspace/Konflux/tenants-config/README.md
```

#### Common Cluster API Endpoint Formats

- **Your RH Konflux:** `https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443`
- **Other Internal Red Hat:** `https://api.workbench.konflux-ci.dev:6443`
- **Public Konflux:** `https://api.konflux-ci.dev:6443`
- **Custom instance:** `https://api.your-instance.example.com:6443`

#### Quick Test

Once you have the URL, test if it works:
```bash
# Test cluster connectivity
kubectl cluster-info

# If not connected yet:
kubectl login https://<your-cluster-url>

# Then verify you can access the namespace
kubectl get namespace rh-ocp-dr
kubectl get components -n rh-ocp-dr
```

#### For Red Hat Internal (Your Setup)

Your workspace is using the **stone-prod-p02** cluster from ArgoCD:

```bash
# Your cluster API endpoint is:
https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Your namespace is:
rh-ocp-dr-tenant

# Test with:
kubectl cluster-info
kubectl get namespace rh-ocp-dr-tenant
kubectl get components -n rh-ocp-dr-tenant
```

If you're still unsure, **ask your platform engineer** for the exact URL and credentials.

---

## 🚀 Approach A: UI-Based Component Registration

### Step 1: Create Application (Once)

1. **Open Konflux Dashboard:**
   - Navigate to: `https://<your-konflux-instance>/applications`
   - Sign in with credentials

2. **Click "Create application"**
   
3. **Fill in details:**
   - Name: `ramen-dr-standalone-0-1`
   - Display Name: `RamenDR Standalone v0.1`
   
4. **Click Create**

✅ Application now exists in namespace `rh-ocp-dr`

---

### Step 2: Register Component 1 - Hub Operator (Multi-Platform)

#### 2a. Start Component Registration

1. **On Applications page, click on** `ramen-dr-standalone-0-1`
2. **Click "Add component"**
3. **Select provider:** GitLab

#### 2b. Configure Repository

1. **Enter GitLab repository URL:**
   ```
   https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
   ```

2. **Branch:** `main`
3. **Click Next**

#### 2c. Authenticate (if needed)

- Select your GitLab credentials or create new
- Click "Authorize"

#### 2d: Configure Component Details

1. **Component name:** `ramen-hub-operator`
2. **Dockerfile path:** `hub.Dockerfile`
   (You'll create this in Phase 2)
3. **Pipeline:** `docker-build-multi-platform-oci-ta` (or let it auto-detect)

#### 2e: Registry Settings

1. **Image repository:** Select default (quay.io/redhat-user-workloads)
2. **Click Create component**

✅ Konflux creates `.tekton/ramen-hub-operator-on-push.yaml` in your repo

---

### Step 3: Repeat for Remaining 5 Components

Repeat Steps 2a-2e for each component, using these settings:

#### Component 2: Hub Bundle
```
Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
Branch: main
Component name: ramen-hub-bundle
Dockerfile path: bundle/hub/Dockerfile
Pipeline: docker-build-oci-ta
```

#### Component 3: Cluster Operator
```
Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
Branch: main
Component name: ramen-cluster-operator
Dockerfile path: cluster.Dockerfile
Pipeline: docker-build-multi-platform-oci-ta
```

#### Component 4: Cluster Bundle
```
Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
Branch: main
Component name: ramen-cluster-bundle
Dockerfile path: bundle/cluster/Dockerfile
Pipeline: docker-build-oci-ta
```

#### Component 5: Console UI
```
Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console
Branch: main
Component name: ramen-console-ui
Dockerfile path: Dockerfile
Pipeline: docker-build-oci-ta
```

#### Component 6: FBC Catalog
```
Repository: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
Branch: main
Component name: ramen-fbc-catalog
Dockerfile path: fbc/Dockerfile
Pipeline: docker-build-oci-ta
```

---

## 🖥️ Approach B: Programmatic Registration (CLI/kubectl)

### Step 1: Create Application YAML

Create `ramen-application.yaml`:

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: Application
metadata:
  name: ramen-dr-standalone-0-1
  namespace: rh-ocp-dr-tenant
spec:
  displayName: "RamenDR Standalone v0.1"
  description: "RamenDR Hub and Cluster operators with console UI"
```

Apply it:
```bash
kubectl apply -f ramen-application.yaml
```

### Step 2: Create All Components YAML

Create `ramen-components.yaml`:

```yaml
---
# Component 1: Hub Operator
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: ramen-hub-operator
  namespace: rh-ocp-dr-tenant
spec:
  application: ramen-dr-standalone-0-1
  componentName: ramen-hub-operator
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
      revision: main
      context: ./
      dockerfileUrl: hub.Dockerfile

---
# Component 2: Hub Bundle
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: ramen-hub-bundle
  namespace: rh-ocp-dr-tenant
spec:
  application: ramen-dr-standalone-0-1
  componentName: ramen-hub-bundle
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
      revision: main
      context: ./
      dockerfileUrl: bundle/hub/Dockerfile

---
# Component 3: Cluster Operator
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: ramen-cluster-operator
  namespace: rh-ocp-dr-tenant
spec:
  application: ramen-dr-standalone-0-1
  componentName: ramen-cluster-operator
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
      revision: main
      context: ./
      dockerfileUrl: cluster.Dockerfile

---
# Component 4: Cluster Bundle
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: ramen-cluster-bundle
  namespace: rh-ocp-dr-tenant
spec:
  application: ramen-dr-standalone-0-1
  componentName: ramen-cluster-bundle
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
      revision: main
      context: ./
      dockerfileUrl: bundle/cluster/Dockerfile

---
# Component 5: Console UI
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: ramen-console-ui
  namespace: rh-ocp-dr-tenant
spec:
  application: ramen-dr-standalone-0-1
  componentName: ramen-console-ui
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen-console
      revision: main
      context: ./
      dockerfileUrl: Dockerfile

---
# Component 6: FBC Catalog
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: ramen-fbc-catalog
  namespace: rh-ocp-dr-tenant
spec:
  application: ramen-dr-standalone-0-1
  componentName: ramen-fbc-catalog
  source:
    git:
      url: https://gitlab.cee.redhat.com/rh-ocp-dr/ramen
      revision: main
      context: ./
      dockerfileUrl: fbc/Dockerfile
```

Apply all components:
```bash
kubectl apply -f ramen-components.yaml -n rh-ocp-dr-tenant
```

Verify they were created:
```bash
kubectl get components -n rh-ocp-dr-tenant
```

Expected output:
```
NAME                            AGE   STATUS   REASON   TYPE
ramen-hub-operator              2m    True     OK       Updated
ramen-hub-bundle                2m    True     OK       Updated
ramen-cluster-operator          2m    True     OK       Updated
ramen-cluster-bundle            2m    True     OK       Updated
ramen-console-ui                2m    True     OK       Updated
ramen-fbc-catalog               2m    True     OK       Updated
```

---

## 🔗 Adding build-nudges-ref Dependencies

This is the key pattern from RHWA samples that automatically sequences builds.

### What It Does

```
Hub Operator builds → completes → nudges → Hub Bundle starts
Hub Bundle builds → completes → nudges → FBC Catalog starts
```

### How to Configure

Edit `.tekton/ramen-hub-bundle-on-push.yaml` that Konflux generated and add:

```yaml
metadata:
  annotations:
    build.appstudio.openshift.io/request: build-nudges-ref: [ramen-hub-operator]
```

Do the same for:
- `ramen-cluster-bundle-on-push.yaml` → nudges: `[ramen-cluster-operator]`
- `ramen-fbc-catalog-on-push.yaml` → nudges: `[ramen-hub-bundle, ramen-cluster-bundle]`

**Better approach:** Edit Component metadata with build-nudges-ref directly:

```bash
# Patch hub-bundle to depend on hub-operator
kubectl patch component ramen-hub-bundle -n rh-ocp-dr-tenant --type merge -p \
  '{"spec":{"build-nudges-ref":["ramen-hub-operator"]}}'  

# Patch cluster-bundle to depend on cluster-operator
kubectl patch component ramen-cluster-bundle -n rh-ocp-dr-tenant --type merge -p \
  '{"spec":{"build-nudges-ref":["ramen-cluster-operator"]}}'  

# Patch fbc-catalog to depend on both bundles
kubectl patch component ramen-fbc-catalog -n rh-ocp-dr-tenant --type merge -p \
  '{"spec":{"build-nudges-ref":["ramen-hub-bundle","ramen-cluster-bundle"]}}'
```

---

## 📁 Repository Structure After Registration

After component registration, Konflux automatically creates this structure in your repos:

```
ramen/
├── .tekton/
│   ├── ramen-hub-operator-on-push.yaml       ✅ Auto-generated
│   ├── ramen-hub-operator-on-pull-request.yaml
│   ├── ramen-hub-bundle-on-push.yaml
│   ├── ramen-hub-bundle-on-pull-request.yaml
│   ├── ramen-cluster-operator-on-push.yaml
│   ├── ramen-cluster-operator-on-pull-request.yaml
│   ├── ramen-cluster-bundle-on-push.yaml
│   ├── ramen-cluster-bundle-on-pull-request.yaml
│   ├── ramen-fbc-catalog-on-push.yaml
│   └── ramen-fbc-catalog-on-pull-request.yaml
│
├── hub.Dockerfile               ⏳ To create (Phase 2)
├── cluster.Dockerfile           ⏳ To create (Phase 2)
│
└── bundle/
    ├── hub/
    │   ├── Dockerfile           ⏳ To create (Phase 2)
    │   └── manifests/           ⏳ To create
    │
    └── cluster/
        ├── Dockerfile           ⏳ To create (Phase 2)
        └── manifests/           ⏳ To create

fbc/
├── Dockerfile                   ⏳ To create (Phase 2)
└── catalog.yaml                 ⏳ To create
```

---

## ✅ Verification Checklist

After completing registration:

- [ ] Application `ramen-dr-standalone-0-1` exists in Konflux UI
- [ ] All 6 components appear in Konflux UI
- [ ] `.tekton/` directory created in both repos (ramen, ramen-console)
- [ ] All 12 `.tekton/*.yaml` files exist (push + pull-request for each)
- [ ] Components show status "OK" in CLI: `kubectl get components -n rh-ocp-dr-tenant`
- [ ] Can view component details: `kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant -o yaml`

---

## 🔍 Real-World Example Reference

The RHWA projects follow this exact pattern:

**fence-agents-remediation project has:**
```
.tekton/
├── far-operator-0-8-push.yaml
├── far-operator-0-8-pull-request.yaml
├── far-bundle-0-8-push.yaml
└── far-bundle-0-8-pull-request.yaml

Containerfile.fence-agents-remediation        # Operator image
Containerfile.fence-agents-remediation-bundle # Bundle image
```

**Your RamenDR will have:**
```
.tekton/
├── ramen-hub-operator-on-push.yaml
├── ramen-hub-operator-on-pull-request.yaml
├── ramen-hub-bundle-on-push.yaml
├── ramen-hub-bundle-on-pull-request.yaml
... (same for cluster and fbc)

hub.Dockerfile                   # Hub operator image
cluster.Dockerfile               # Cluster operator image
bundle/hub/Dockerfile            # Hub bundle image
bundle/cluster/Dockerfile        # Cluster bundle image
fbc/Dockerfile                   # FBC catalog image
```

---

## 🚨 Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| `.tekton/` files not created | GitLab webhook not triggered | Manually push to `main` or create test commit |
| Components show "Not Started" | Dockerfile doesn't exist | Create the Dockerfile (move to Phase 2) |
| Build fails immediately | Missing container.yaml | Not needed; Konflux uses Component CR instead |
| Can't access GitLab | No credentials linked | Create GitLab secret in Konflux UI |
| Too many components in one PR | Just creating them | Normal; all 6 can be in one PR, split for readability |

---

## 📞 Next Steps

### After Phase 1 Complete

1. ✅ **Phase 1:** Create workspace + components (THIS PAGE)
2. ⏳ **Phase 2:** Create Dockerfiles for all 6 components
3. ⏳ **Phase 3:** Trigger first build and verify
4. ⏳ **Phase 4:** Configure build-nudges-ref and test sequences
5. ⏳ **Phase 5:** Add OLM bundle manifests and FBC configuration

---

## 💡 Pro Tips

1. **Start with Hub Operator first** - It's the simplest (already has some code)
2. **Don't worry about Dockerfiles yet** - You can register components without them; builds fail gracefully until Dockerfile exists
3. **Use Approach A for first 1-2 components** - Understand the flow visually
4. **Use Approach B for remaining components** - Much faster once you know the process
5. **Keep component names consistent** - Use hyphenated names like `ramen-hub-operator` not `ramen_hub_operator`
6. **Test one at a time** - Get hub-operator building before adding the others

---

## 📚 Related Documentation

- [Konflux Creating Applications & Components](https://konflux-ci.dev/docs/building/creating/)
- [Konflux Getting Started](https://konflux-ci.dev/docs/getting-started/)
- [RHWA fence-agents-remediation reference](../projectSamples/fence-agents-remediation/)
- [RAMEN_PROJECT_TEMPLATE.md](./RAMEN_PROJECT_TEMPLATE.md) - Template definitions

---

## 🎓 Understanding Component Registration Flow

**What Happens When You Register a Component:**

1. You provide:
   - GitLab repository URL
   - Branch (main)
   - Dockerfile path (hub.Dockerfile)
   - Component name

2. Konflux:
   - Creates Component CR in Kubernetes
   - Sets up GitLab webhook
   - Pushes `.tekton/` pipeline files to your repo
   - Waits for first commit to `main`

3. On first push:
   - Webhook triggers
   - `.tekton/*-on-push.yaml` executes
   - Build PipelineRun starts
   - (Currently fails if Dockerfile missing—that's normal)

4. After Phase 2 (Dockerfiles added):
   - Push triggers rebuild
   - Pipeline runs successfully
   - Image built and pushed to registry
   - Component `.status.containerImage` updated

This is the key flow. Understanding this makes everything else make sense.
