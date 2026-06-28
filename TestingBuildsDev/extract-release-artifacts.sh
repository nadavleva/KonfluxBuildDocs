#!/bin/bash

# Extract published image artifacts from Release objects
# Shows exactly what was published from your Konflux releases

set -euo pipefail

NAMESPACE="${1:-rhdr-tenant}"
RELEASE_PATTERN="${2:-*}"

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== RHDR Release Artifacts ===${NC}"
echo "Namespace: $NAMESPACE"
echo ""

# Get all successful releases and find the one with the most images (the complete build)
# This handles cases where individual component releases exist alongside the full release
LATEST_RELEASE=$(kubectl get releases -n "$NAMESPACE" -o json 2>/dev/null | \
  jq -r '.items[] | select(.status.conditions[]? | select(.type=="Released" and .status=="True")) | "\(.metadata.name) \(.status.artifacts.images | length)"' | \
  sort -k2 -rn | head -1 | awk '{print $1}')

if [ -z "$LATEST_RELEASE" ]; then
  echo -e "${YELLOW}⚠️  No successful releases found in namespace $NAMESPACE${NC}"
  echo ""
  echo "Check release status:"
  echo "  kubectl get releases -n $NAMESPACE -o wide"
  echo ""
  echo "Get details of a specific release:"
  echo "  kubectl get release <name> -n $NAMESPACE -o yaml"
  exit 1
fi

echo -e "${GREEN}Latest Complete Release (most images):${NC} $LATEST_RELEASE"
CREATION_TIME=$(kubectl get release "$LATEST_RELEASE" -n "$NAMESPACE" -o jsonpath='{.metadata.creationTimestamp}')
COMPLETION_TIME=$(kubectl get release "$LATEST_RELEASE" -n "$NAMESPACE" -o jsonpath='{.status.completionTime}')
echo "  Created:   $CREATION_TIME"
echo "  Completed: $COMPLETION_TIME"
echo ""

# Process the latest release
FOUND_COUNT=0
  
# Extract images
# Get the Release as JSON once to avoid multiple kubectl calls
RELEASE_JSON=$(kubectl get release "$LATEST_RELEASE" -n "$NAMESPACE" -o json 2>/dev/null)

# Count images
IMAGE_COUNT=$(echo "$RELEASE_JSON" | jq '.status.artifacts.images | length' 2>/dev/null || echo 0)

if [ "$IMAGE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  No images found in release${NC}"
  exit 1
fi

echo -e "${GREEN}Found $IMAGE_COUNT component image(s) in Release${NC}"
echo ""

# Get all defined components in the namespace
TOTAL_COMPONENTS=$(kubectl get components -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
PUBLISHED_COUNT=$IMAGE_COUNT
UNPUBLISHED_COUNT=$((TOTAL_COMPONENTS - PUBLISHED_COUNT))

if [ "$UNPUBLISHED_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Note: $UNPUBLISHED_COUNT component(s) defined but NOT in this release${NC}"
  echo ""
fi

# Extract and display each image using jq
FOUND_COUNT=$(echo "$RELEASE_JSON" | jq -r '.status.artifacts.images | length')

for (( i=0; i<$FOUND_COUNT; i++ )); do
  IMAGE=$(echo "$RELEASE_JSON" | jq ".status.artifacts.images[$i]")
  
  NAME=$(echo "$IMAGE" | jq -r '.name')
  SHASUM=$(echo "$IMAGE" | jq -r '.shasum')
  
  echo -e "${GREEN}Component $(($i + 1))/${FOUND_COUNT}: $NAME${NC}"
  echo "  Digest: $SHASUM"
  
  # Show backing store URLs
  echo "  Backing store (reference only - use registry.stage.redhat.io to pull):"
  echo "$IMAGE" | jq -r '.urls[]' | sed 's/^/    - /'
  
  # Extract best tag for pulling
  TAG=$(echo "$IMAGE" | jq -r '.urls[]' | grep -oP 'v[0-9.]+' | head -1)
  if [ -z "$TAG" ]; then
    TAG=$(echo "$IMAGE" | jq -r '.urls[]' | grep -oP '[0-9]{10,}' | head -1)
  fi
  
  REPO_NAME=$(echo "$NAME" | sed 's/-4-22$//')
  
  echo "  "
  echo "  To pull, use registry.stage.redhat.io proxy:"
  if [ -n "$TAG" ]; then
    echo "    ✅ podman pull registry.stage.redhat.io/rhdr/$REPO_NAME:$TAG"
    echo "    or by digest: podman pull registry.stage.redhat.io/rhdr/$REPO_NAME@$SHASUM"
  else
    echo "    ✅ podman pull registry.stage.redhat.io/rhdr/$REPO_NAME@$SHASUM"
  fi
  
  echo ""
done

echo -e "${GREEN}✅ Successfully extracted $FOUND_COUNT component image(s) from latest release${NC}"
echo ""

# Check if there are components NOT in the release
if [ "$UNPUBLISHED_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}Components defined but NOT published in this release:${NC}"
  
  # Get published component names
  PUBLISHED_NAMES=$(echo "$RELEASE_JSON" | jq -r '.status.artifacts.images[].name' | sed 's/-4-22$//')
  
  # Get all component names
  ALL_COMPONENTS=$(kubectl get components -n "$NAMESPACE" --no-headers 2>/dev/null | awk '{print $1}' | sed 's/-4-22$//')
  
  # Find components not in the release
  while IFS= read -r comp; do
    if ! echo "$PUBLISHED_NAMES" | grep -q "^${comp}$"; then
      echo "  ❌ $comp"
    fi
  done < <(echo "$ALL_COMPONENTS" | sort -u)
  
  echo ""
  echo "Possible reasons for unpublished components:"
  echo "  1. Not included in the ReleasePlan (check ReleasePlan spec.targets)"
  echo "  2. Builds excluded or skipped in this release"
  echo "  3. Build pipeline not triggered"
  echo ""
  echo "To investigate:"
  echo "  - Check ReleasePlan: kubectl get releaseplan -n $NAMESPACE -o yaml"
  echo "  - Check Component build pipeline config:"
  echo "    kubectl get component <name>-4-22 -n $NAMESPACE -o jsonpath='{.spec.build}'"
  echo "  - Look for recent build events:"
  echo "    kubectl describe application rhdr-4-22 -n $NAMESPACE"
  echo ""
fi

echo "To pull an image:"
echo "  podman pull <pullspec-from-list-above>"
echo ""
echo "To create a CatalogSource for OLM (using bundle URL):"
echo "  kubectl apply -f - <<EOF"
echo "  apiVersion: operators.coreos.com/v1alpha1"
echo "  kind: CatalogSource"
echo "  metadata:"
echo "    name: rhdr-staging-catalog"
echo "    namespace: openshift-marketplace"
echo "  spec:"
echo "    sourceType: grpc"
echo "    image: <bundle-pullspec-from-list>"
echo "  EOF"
