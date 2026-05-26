# CLI/kubectl Access to Konflux Cluster

Guide to set up command-line access to your Konflux cluster for managing applications and components.

---

## 🎯 Your Cluster Details

From your ArgoCD configuration:

| Setting | Value |
|---------|-------|
| **Cluster** | stone-prod-p02 |
| **API Endpoint** | `https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443` |
| **Namespace** | `rh-ocp-dr-tenant` |
| **Role** | `konflux-contributor-user-actions` |
| **Users** | abeekhof, martjack, oaharoni, sughosh |
| **Workspace Type** | Tenant workspace (stone-prd-rh01) |

---

## 📋 Prerequisites

Before using CLI, you need:

1. ✅ **kube config file** - Credentials to access the cluster
2. ✅ **kubectl installed** - Command-line tool
3. ✅ **Your Red Hat credentials** - To authenticate
4. ✅ **LDAP username** - Same as one in RoleBinding above

---

## 🎫 Getting Your Login Token

Before you can run `oc login`, you need a valid authentication token. Here are the ways to get one:

### Method 1: From OpenShift OAuth Server (Recommended)

The token comes from OpenShift's OAuth server, not from ArgoCD:

1. **Open the OAuth token display page:**
   ```
   https://oauth-openshift.apps.stone-prod-p02.hjvn.p1.openshiftapps.com/oauth/token/display
   ```

2. **Login with your Red Hat credentials** (if prompted)

3. **Copy the token** displayed on the page
   - It will look like: `sha256~aBcDeFgHiJkLmNoPqRsTuVwXyZ123...`

4. **Use the token with oc login:**
   ```bash
   oc login --token=<COPIED_TOKEN> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
   ```

5. **Verify it worked:**
   ```bash
   kubectl cluster-info
   kubectl get namespace rh-ocp-dr-tenant
   ```

**Token Expiration:** These tokens expire. When you need a fresh one, just revisit the OAuth token display page.

### Method 2: Using oc CLI (If Already Logged In)

If you already have `oc` installed and logged in:

```bash
# Get your current token
oc whoami -t

# Use it for API calls or share with others
```

### Method 3: From Your Platform Engineer

If the OAuth page doesn't work for you, ask your PE:

```
"Can you provide me with an authentication token or login command 
for accessing the rh-ocp-dr-tenant namespace on stone-prod-p02?"
```

They can provide:
- A pre-generated token
- A kubeconfig file
- Help accessing the OAuth token display page

---

## 🔗 Step 2: Configure kubectl

### Method 1: Using `oc login` (Red Hat OpenShift)

```bash
# Login to the cluster
oc login --token=<YOUR_TOKEN> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Or with username/password
oc login -u <your-username> https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Verify login worked
kubectl cluster-info
kubectl config current-context
```

### Method 2: Manual kubeconfig Setup

If you have a kubeconfig file from your PE:

```bash
# Copy kubeconfig to standard location
mkdir -p ~/.kube
cp /path/to/kubeconfig ~/.kube/config

# Set permissions
chmod 600 ~/.kube/config

# Verify access
kubectl config view
kubectl cluster-info
```

### Method 3: Using kubeconfig Environment Variable

If you have multiple kubeconfig files:

```bash
# Export specific kubeconfig
export KUBECONFIG=/path/to/your/kubeconfig:$KUBECONFIG

# Or temporarily
KUBECONFIG=~/.kube/stone-prod-p02-config kubectl get namespaces
```

---

## ✅ Step 3: Verify Access

### Test Basic Connectivity

```bash
# Check cluster connection
kubectl cluster-info

# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts
```

**Expected output:**
```
Kubernetes control plane is running at https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
```

### Verify Namespace Access

```bash
# Check if you can access your namespace
kubectl get namespace rh-ocp-dr-tenant

# List all namespaces (if you have permission)
kubectl get namespaces

# Check your current namespace
kubectl config get-contexts
```

**Expected output:**
```
NAME                 STATUS   AGE
rh-ocp-dr-tenant     Active   45d
```

### Verify Your RBAC Role

```bash
# Check your permissions
kubectl auth can-i create applications -n rh-ocp-dr-tenant
kubectl auth can-i create components -n rh-ocp-dr-tenant

# Should output: yes
```

### List Current Resources

```bash
# List applications in your namespace
kubectl get applications -n rh-ocp-dr-tenant

# List components
kubectl get components -n rh-ocp-dr-tenant

# List all AppStudio resources
kubectl api-resources | grep appstudio
```

---

## 🚀 Now You Can Use kubectl Commands

### Step 1: Authenticate with oc login

**The process:**

1. Get a token from OpenShift OAuth: `https://oauth-openshift.apps.stone-prod-p02.hjvn.p1.openshiftapps.com/oauth/token/display`
2. Use the token with `oc login`

```bash
# Login with token from OAuth server
oc login --token=<YOUR_TOKEN> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Or use username/password (it will prompt and generate a token)
oc login -u <your-username> https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Verify login worked
kubectl cluster-info
kubectl config current-context
```

**If you get a 403 error when visiting the API URL directly:** That's expected and correct. The API endpoint requires authentication via `oc login` - it's not meant to be accessed in a browser.

### Step 2: Create Application

```bash
# Create application using kubectl
kubectl create -f - <<EOF
apiVersion: appstudio.redhat.com/v1alpha1
kind: Application
metadata:
  name: ramen-dr-standalone-0-1
  namespace: rh-ocp-dr-tenant
spec:
  displayName: "RamenDR Standalone v0.1"
  description: "RamenDR Hub and Cluster operators with console UI"
EOF

# Verify it was created
kubectl get application ramen-dr-standalone-0-1 -n rh-ocp-dr-tenant
```

### Create Component

```bash
# Create a component
kubectl create -f - <<EOF
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
EOF

# Verify creation
kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant
```

### Apply Multiple Resources

```bash
# From the WORKSPACE_SETUP_GUIDE.md
kubectl apply -f ramen-application.yaml -n rh-ocp-dr-tenant
kubectl apply -f ramen-components.yaml -n rh-ocp-dr-tenant
```

---

## 🔍 Useful kubectl Commands for Konflux

```bash
# Set default namespace (save typing)
kubectl config set-context --current --namespace=rh-ocp-dr-tenant

# List all resources
kubectl get all -n rh-ocp-dr-tenant

# Get applications
kubectl get applications -n rh-ocp-dr-tenant
kubectl get app -n rh-ocp-dr-tenant

# Get components
kubectl get components -n rh-ocp-dr-tenant
kubectl get component -n rh-ocp-dr-tenant

# Watch component status in real-time
kubectl get components -n rh-ocp-dr-tenant --watch

# Get detailed info
kubectl describe component ramen-hub-operator -n rh-ocp-dr-tenant

# Get YAML of a resource
kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant -o yaml

# Edit a resource
kubectl edit application ramen-dr-standalone-0-1 -n rh-ocp-dr-tenant

# Delete a resource
kubectl delete component ramen-hub-operator -n rh-ocp-dr-tenant

# Get events
kubectl get events -n rh-ocp-dr-tenant --sort-by='.lastTimestamp'

# Get build pipeline runs
kubectl get pipelineruns -n rh-ocp-dr-tenant

# Watch pipeline run status
kubectl get pipelinerun <name> -n rh-ocp-dr-tenant --watch

# Get logs from pipeline run
kubectl logs -f pipelinerun/<name> -n rh-ocp-dr-tenant
```

---

## 📝 Helpful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Konflux-specific aliases
alias kconf='kubectl config'
alias kget='kubectl get -n rh-ocp-dr-tenant'
alias kdesc='kubectl describe -n rh-ocp-dr-tenant'
alias kedit='kubectl edit -n rh-ocp-dr-tenant'
alias klogs='kubectl logs -n rh-ocp-dr-tenant'
alias kapply='kubectl apply -n rh-ocp-dr-tenant'

# Usage:
# kget components
# kdesc component ramen-hub-operator
# kapply -f resources.yaml
```

---

## 🚨 Troubleshooting

### "Access Denied" or "Forbidden"

```bash
# Check your permissions
kubectl auth can-i list components -n rh-ocp-dr-tenant
kubectl auth can-i create applications -n rh-ocp-dr-tenant

# If these return "no", you don't have the right role
# Solution: Ask your Platform Engineer to add you to the RoleBinding

# Check which user you're authenticated as
kubectl config current-context
kubectl whoami  # May not work in all clusters

# View current RBAC bindings
kubectl get rolebindings -n rh-ocp-dr-tenant
kubectl describe rolebinding rh-ocp-dr-tenant-konflux-contributors -n rh-ocp-dr-tenant
```

### "Connection Refused" or "Connection Reset"

The API endpoint must be accessed with `oc login`, not by visiting the URL in a browser:

```bash
# Correct way:
oc login --token=<TOKEN> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Wrong way (will give 403 or connection error):
# Don't visit https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443 in your browser
```

If `oc login` itself fails:

```bash
# Verify the API is accessible from command line
kubectl cluster-info

# Check if oc/kubectl is installed
which oc
which kubectl

# Ask your Platform Engineer for:
# 1. A valid authentication token
# 2. Confirmation that the API endpoint is correct
```

### Troubleshooting "oc login" failures

```bash
# Make sure oc is installed
oc version

# Check if token is valid (tokens expire)
# Get a fresh token from the OpenShift OAuth page:
# 1. Open: https://oauth-openshift.apps.stone-prod-p02.hjvn.p1.openshiftapps.com/oauth/token/display
# 2. Login with Red Hat credentials
# 3. Copy the token shown
# 4. Use it with oc login

# Test the exact server URL
echo "https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443"

# If oc login still fails, ask your Platform Engineer for:
# - Confirmation the cluster is accessible from your network
# - A fresh authentication token from the OAuth server
# - Help accessing the OAuth token display URL
```

### "User 'system:anonymous' cannot get path" (403 Forbidden)

This error means you're accessing the API without authentication. **This is expected and correct.**

```bash
# Don't try to curl the API directly:
# ❌ curl https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
# This will give: "User \"system:anonymous\" cannot get path\""

# Instead, use oc login to authenticate first:
# ✅ oc login --token=<TOKEN> --server=https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443

# Get a token from:
# 1. Web dashboard (Copy Login Command)
# 2. Platform Engineer
# 3. Your existing kubeconfig file
```

---

## 🎯 Next Steps

Once you have kubectl access:

1. **Run verification commands** from "Useful kubectl Commands" section
2. **Create test application** using the example above
3. **Follow WORKSPACE_SETUP_GUIDE.md** - Use Approach B (CLI/kubectl)
4. **Monitor builds** using `kubectl get pipelineruns --watch`

---

## 📞 Quick Reference

### Your Specific Configuration

```bash
# Your cluster
Cluster: stone-prod-p02
API: https://api.stone-prod-p02.hjvn.p1.openshiftapps.com:6443
Namespace: rh-ocp-dr-tenant
Role: konflux-contributor-user-actions

# Commands for your setup
kubectl get applications -n rh-ocp-dr-tenant
kubectl get components -n rh-ocp-dr-tenant
kubectl apply -f <file> -n rh-ocp-dr-tenant
```

### Environment Setup (One-Time)

```bash
# Add to ~/.bashrc or ~/.zshrc
export KUBECONFIG=~/.kube/config
export KUBE_NAMESPACE=rh-ocp-dr-tenant

# Set as default
kubectl config set-context --current --namespace=$KUBE_NAMESPACE
```

### Health Check Script

```bash
#!/bin/bash
echo "=== Cluster Connection ==="
kubectl cluster-info

echo "=== Current User ==="
kubectl config current-context

echo "=== Namespace Access ==="
kubectl get namespace rh-ocp-dr-tenant

echo "=== Your Permissions ==="
kubectl auth can-i create applications -n rh-ocp-dr-tenant
kubectl auth can-i create components -n rh-ocp-dr-tenant

echo "=== Resources in Namespace ==="
kubectl get all -n rh-ocp-dr-tenant
```

Save this as `check-access.sh`, run `chmod +x check-access.sh`, then `./check-access.sh` anytime.

---

## 📚 Related Documentation

- [WORKSPACE_SETUP_GUIDE.md](./WORKSPACE_SETUP_GUIDE.md) - Use this after CLI is set up
- [Konflux CLI Documentation](https://konflux-ci.dev/docs/getting-started/#getting-started-with-the-cli)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [AppStudio Custom Resources](https://konflux-ci.dev/docs/reference/kube-apis/)
