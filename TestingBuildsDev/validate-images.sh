#!/bin/bash

# RHDR Staging Image Validation Script
# Checks which RHDR images are present in registry.stage.redhat.io
# Requires: podman/skopeo login to registry.stage.redhat.io (or ~/.docker/config.json)

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# RHDR component repositories
declare -a REPOS=(
  "rhdr/rhdr-hub-rhel9-operator"
  "rhdr/rhdr-hub-operator-bundle"
  "rhdr/rhdr-cluster-rhel9-operator"
  "rhdr/rhdr-cluster-operator-bundle"
  "rhdr/rhdr-multicluster-rhel9-operator"
  "rhdr/rhdr-multicluster-operator-bundle"
  "rhdr/rhdr-csi-addons-rhel9-operator"
  "rhdr/rhdr-csi-addons-operator-bundle"
)

REGISTRY="registry.stage.redhat.io"
FOUND_COUNT=0
NOT_FOUND_COUNT=0

# Determine auth file to use
if [ $# -gt 0 ]; then
  # Use provided argument
  AUTHFILE="$1"
else
  # Check common locations in priority order
  if [ -f "$HOME/.rhdr-staging-auth.json" ]; then
    AUTHFILE="$HOME/.rhdr-staging-auth.json"
  elif [ -f "$HOME/.docker/config.json" ]; then
    AUTHFILE="$HOME/.docker/config.json"
  elif [ -f ".docker/config.json" ]; then
    AUTHFILE=".docker/config.json"
  else
    echo -e "${RED}❌ Error: No auth file found!${NC}"
    echo ""
    echo "Expected one of:"
    echo "  - $HOME/.rhdr-staging-auth.json"
    echo "  - $HOME/.docker/config.json"
    echo "  - ./.docker/config.json"
    echo ""
    echo "To create: podman login registry.stage.redhat.io"
    echo "Or pass auth file as argument: $0 /path/to/auth.json"
    exit 1
  fi
fi

echo -e "${BLUE}=== RHDR Staging Image Validation ===${NC}"
echo ""
echo "Registry: $REGISTRY"
echo "Auth file: $AUTHFILE"
echo ""

# Verify auth file exists
if [ ! -f "$AUTHFILE" ]; then
  echo -e "${RED}❌ Error: Auth file not found: $AUTHFILE${NC}"
  exit 1
fi

echo -e "${BLUE}Checking RHDR components...${NC}"
echo ""

# First, try a direct inspect instead of listing (more permissive)
# This tells us if the images exist and we have access
printf "  Testing access with a sample image: "
if skopeo inspect --authfile="$AUTHFILE" --no-tags \
    "docker://$REGISTRY/rhdr/rhdr-cluster-rhel9-operator:latest" > /tmp/skopeo_test.json 2>&1; then
  echo -e "${GREEN}✅ Access OK${NC}"
else
  TEST_ERROR=$(cat /tmp/skopeo_test.json 2>/dev/null || echo "unknown")
  if echo "$TEST_ERROR" | grep -q "manifest unknown\|not found"; then
    echo -e "${RED}❌ Image not found${NC}"
    echo ""
    echo "This means the RHDR repositories don't exist in registry.stage.redhat.io"
    echo ""
    echo "Possible reasons:"
    echo "1. Release pipeline published to a different registry (check Konflux Artifacts)"
    echo "2. Images are still in build output (quay.io/redhat-user-workloads/)"
    echo "3. Release process hasn't completed yet"
    echo ""
    echo "Check where images actually published:"
    echo "  - Konflux console: Applications > Your App > Releases > Artifacts"
    echo "  - Look for 'image pull' or 'digest' in the artifacts section"
    echo ""
    rm -f /tmp/skopeo_test.json
    exit 1
  else
    echo -e "${RED}❌ Access denied or other error${NC}"
    echo "   Error: $TEST_ERROR"
    echo ""
  fi
fi
echo ""
for repo in "${REPOS[@]}"; do
  # Extract component name from path (last part)
  component=$(echo "$repo" | cut -d'/' -f2)
  
  printf "  %-50s " "$component:"
  
  # Try to inspect the image
  if skopeo inspect --authfile="$AUTHFILE" --no-tags \
      "docker://$REGISTRY/$repo:latest" > /tmp/skopeo_output.json 2>&1; then
    
    # Extract image digest and size
    digest=$(jq -r '.Digest' /tmp/skopeo_output.json 2>/dev/null || echo "unknown")
    digest_short=$(echo "$digest" | cut -d':' -f2 | cut -c1-12)
    size=$(jq -r '.Size // "unknown"' /tmp/skopeo_output.json 2>/dev/null)
    
    # Format size nicely
    if [ "$size" != "unknown" ] && [ "$size" -gt 0 ]; then
      if [ "$size" -gt 1073741824 ]; then
        size_mb=$(echo "scale=1; $size / 1073741824" | bc)
        size_str="${size_mb}GB"
      elif [ "$size" -gt 1048576 ]; then
        size_mb=$(echo "scale=1; $size / 1048576" | bc)
        size_str="${size_mb}MB"
      else
        size_mb=$(echo "scale=1; $size / 1024" | bc)
        size_str="${size_mb}KB"
      fi
    else
      size_str="unknown"
    fi
    
    echo -e "${GREEN}✅ found${NC} (${size_str})"
    echo "     Pullspec: $REGISTRY/$repo:latest"
    echo "     Digest:   $digest"
    echo ""
    ((FOUND_COUNT++))
    
  else
    echo -e "${RED}❌ not found or not accessible${NC}"
    echo ""
    ((NOT_FOUND_COUNT++))
  fi
done

# Summary
echo -e "${BLUE}=== Summary ===${NC}"
echo "Found:     $FOUND_COUNT / ${#REPOS[@]} images"
echo "Not found: $NOT_FOUND_COUNT / ${#REPOS[@]} images"
echo ""

if [ "$FOUND_COUNT" -eq "${#REPOS[@]}" ]; then
  echo -e "${GREEN}✅ All RHDR components are present in staging!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Pull images for testing:"
  echo "   podman pull $REGISTRY/rhdr/rhdr-cluster-rhel9-operator:latest"
  echo ""
  echo "2. Or create a CatalogSource for OLM testing:"
  echo "   kubectl apply -f - <<EOF"
  echo "   apiVersion: operators.coreos.com/v1alpha1"
  echo "   kind: CatalogSource"
  echo "   metadata:"
  echo "     name: rhdr-staging-catalog"
  echo "     namespace: openshift-marketplace"
  echo "   spec:"
  echo "     sourceType: grpc"
  echo "     image: $REGISTRY/rhdr/rhdr-cluster-operator-bundle:latest"
  echo "   EOF"
  echo ""
  exit 0
elif [ "$FOUND_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Partial build: $FOUND_COUNT / ${#REPOS[@]} components are ready${NC}"
  echo ""
  echo "Builds still in progress. Check status:"
  echo "  kubectl get components -n rhdr-tenant"
  echo "  kubectl get pipelinerun -n rhdr-tenant --watch"
  echo ""
  exit 1
else
  echo -e "${RED}❌ No RHDR components found in staging${NC}"
  echo ""
  echo "The images may not be published to registry.stage.redhat.io/rhdr/ yet."
  echo ""
  echo "Next steps:"
  echo ""
  echo "1. Check Konflux console for actual image location:"
  echo "   - Log into Konflux"
  echo "   - Applications > Your Application > Releases"
  echo "   - Click on your release (should show from Thursday)"
  echo "   - Look at 'Artifacts' or 'Image' sections"
  echo "   - The pullspecs may be under a different registry path"
  echo ""
  echo "2. Images may be in build output instead:"
  echo "   - Check: quay.io/redhat-user-workloads/rhdr-tenant/rhdr/"
  echo "   - These are pre-release images before the release pipeline publishes them"
  echo ""
  echo "3. Or pull directly from Konflux-provided artifacts:"
  echo "   - The Konflux Artifacts page lists the exact pullspecs to use"
  echo ""
  exit 1
fi

# Cleanup
rm -f /tmp/skopeo_output.json
