# Phase 2: Testing Single Component Build

## Status

✅ **Application Created:** `ramen-dr-standalone`  
✅ **Component Created:** `ramen-hub-operator`  
✅ **Dockerfile Created:** `hub.Dockerfile`

## Next Steps: Trigger the Build

### Step 1: Adjust Dockerfile if Needed

The `hub.Dockerfile` I created assumes a specific cmd structure. Check the actual structure:

```bash
cd ~/workspace/RamenDRStandAlone/ramen
ls -la cmd/
```

**If the structure is different:**
- Adjust the build path in `hub.Dockerfile` line that says: `./cmd/hub-manager/main.go`
- Or find the actual main.go location and update accordingly

Example structures:
```
cmd/hub-manager/main.go  ← Build with: ./cmd/hub-manager/main.go
cmd/hub/main.go          ← Build with: ./cmd/hub/main.go
cmd/main.go              ← Build with: ./cmd/main.go
```

### Step 2: Push Dockerfile to GitLab

```bash
cd ~/workspace/RamenDRStandAlone/ramen

# Add the Dockerfile
git add hub.Dockerfile

# Commit with a meaningful message
git commit -m "Add hub.Dockerfile for Konflux multi-platform build"

# Push to main branch (this triggers the build!)
git push origin main
```

### Step 3: Monitor the Build

Immediately after push, watch for the build:

```bash
# Watch components for changes
kubectl get components -n rh-ocp-dr-tenant --watch

# Watch PipelineRuns (builds)
kubectl get pipelineruns -n rh-ocp-dr-tenant --watch

# Or check specific component
kubectl describe component ramen-hub-operator -n rh-ocp-dr-tenant

# Get detailed status
kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant -o yaml | grep -A 20 status
```

### Step 4: Check Build Logs

If build starts:

```bash
# List PipelineRuns
kubectl get pipelineruns -n rh-ocp-dr-tenant

# View logs from specific run (replace with actual name)
kubectl logs pipelinerun/<pipelinerun-name> -n rh-ocp-dr-tenant -f

# Or follow all pods in namespace
kubectl get pods -n rh-ocp-dr-tenant --watch
```

### Step 5: View Build Results

```bash
# Check if image was built
kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant -o jsonpath='{.status.containerImage}'

# Check in Konflux UI
# Navigate to: ramen-dr-standalone application → ramen-hub-operator component
# Look for build status, image digest, and pipeline run details
```

---

## Important Notes

1. **First Build:** The first build may take 5-10 minutes as it pulls base images
2. **Multi-platform:** If pipeline is `docker-build-multi-platform-oci-ta`, it builds for x86_64, ppc64le, s390x, arm64
3. **Build may fail initially:** That's OK! Common issues:
   - Binary path wrong in Dockerfile → Fix path and push again
   - Missing dependencies → Add to Dockerfile
   - Base image issues → Update image references

4. **To retry:** Just push another commit with fixes:
   ```bash
   git add hub.Dockerfile
   git commit -m "Fix Dockerfile build path"
   git push origin main
   ```

---

## What Happens Next

After successful build:

1. **Component status updates** - Shows build passed
2. **Container image created** - Can be viewed in Quay.io or image registry
3. **ImageRepository updated** - Points to new image
4. **Ready for next phases:**
   - Create more components (hub-bundle, cluster-operator, etc.)
   - Add build-nudges-ref dependencies
   - Test multi-component builds

---

## Troubleshooting

### Build not starting?
```bash
# Check if webhook fired
kubectl get events -n rh-ocp-dr-tenant | grep ramen-hub-operator

# Check component annotations
kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant -o yaml | grep -A 5 annotations
```

### Build fails?
```bash
# View error logs
kubectl logs pipelinerun/<name> -n rh-ocp-dr-tenant -f

# Common issues:
# 1. Dockerfile path wrong → Fix in Dockerfile
# 2. Binary not compiling → Check go.mod, dependencies
# 3. Base image pull issues → Check network/image registry access
```

### Component shows empty status?
```bash
# Give it a minute, then check again
sleep 60
kubectl get component ramen-hub-operator -n rh-ocp-dr-tenant -o yaml
```

---

## Next Phase (After Successful Build)

Once this component builds successfully:

1. Create `cluster.Dockerfile` for cluster-operator component
2. Create bundle Dockerfiles (OLM bundles)
3. Register additional components
4. Configure build-nudges-ref dependencies
5. Test the full 6-component build pipeline
