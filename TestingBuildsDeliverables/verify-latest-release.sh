#!/bin/bash

# Verify Latest RHDR Release - Published Images
# Shows which components from the latest snapshot made it to the Release/published to staging
# No credentials needed - reads directly from Konflux Release objects

set -euo pipefail

NAMESPACE="${1:-rhdr-tenant}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== RHDR Latest Release Verification ===${NC}"
echo "Namespace: $NAMESPACE"
echo ""

# Get the latest successful release (most images)
LATEST_RELEASE=$(kubectl get releases -n "$NAMESPACE" -o json 2>/dev/null | \
  jq -r '.items[] | select(.status.conditions[]? | select(.type=="Released" and .status=="True")) | "\(.metadata.name) \(.status.artifacts.images | length)"' | \
  sort -k2 -rn | head -1 | awk '{print $1}')

if [ -z "$LATEST_RELEASE" ]; then
  echo -e "${RED}❌ No successful releases found${NC}"
  exit 1
fi

# Get release details
RELEASE_JSON=$(kubectl get release "$LATEST_RELEASE" -n "$NAMESPACE" -o json 2>/dev/null)
CREATION_TIME=$(echo "$RELEASE_JSON" | jq -r '.metadata.creationTimestamp')
COMPLETION_TIME=$(echo "$RELEASE_JSON" | jq -r '.status.completionTime // "N/A"')
IMAGE_COUNT=$(echo "$RELEASE_JSON" | jq '.status.artifacts.images | length' 2>/dev/null || echo 0)

echo -e "${GREEN}Latest Complete Release:${NC} $LATEST_RELEASE"
echo "  Created:   $CREATION_TIME"
echo "  Completed: $COMPLETION_TIME"
echo "  Published: $IMAGE_COUNT components"
echo ""

if [ "$IMAGE_COUNT" -eq 0 ]; then
  echo -e "${RED}⚠️  No images found in this release${NC}"
  exit 1
fi

# Get all defined components in snapshot for comparison
LATEST_SNAPSHOT=$(kubectl get snapshots -n "$NAMESPACE" -o json 2>/dev/null | \
  jq -r '.items | sort_by(.metadata.creationTimestamp) | reverse | .[0].metadata.name')

TOTAL_COMPONENTS=0
if [ -n "$LATEST_SNAPSHOT" ]; then
  TOTAL_COMPONENTS=$(kubectl get snapshot "$LATEST_SNAPSHOT" -n "$NAMESPACE" -o json 2>/dev/null | \
    jq '.spec.components | length' 2>/dev/null || echo 0)
fi

echo -e "${BLUE}Component Breakdown:${NC}"
echo "  Total built (snapshot):    $TOTAL_COMPONENTS"
echo "  Published in release:      $IMAGE_COUNT"
echo "  Not published:             $((TOTAL_COMPONENTS - IMAGE_COUNT))"
echo ""

# Extract and display published components
echo -e "${GREEN}Published Components:${NC}"
echo ""

PUBLISHED_COUNT=0
echo "$RELEASE_JSON" | jq -r '.status.artifacts.images[] | "\(.name)|\(.shasum)"' | while IFS='|' read -r NAME SHASUM; do
  ((PUBLISHED_COUNT++)) || true
  
  # Extract component name (remove -4-22 suffix)
  COMP_NAME=$(echo "$NAME" | sed 's/-4-22$//')
  
  # Find best tag from urls
  TAG=$(echo "$RELEASE_JSON" | jq -r ".status.artifacts.images[] | select(.name==\"$NAME\") | .urls[]" | \
    grep -oP 'v[0-9]+\.[0-9]+' | head -1)
  
  if [ -z "$TAG" ]; then
    TAG="latest"
  fi
  
  DIGEST_SHORT=$(echo "$SHASUM" | cut -d':' -f2 | cut -c1-12)
  
  echo "  ✅ $COMP_NAME"
  echo "     Pullspec: registry.stage.redhat.io/rhdr/$COMP_NAME:$TAG"
  echo "     Digest:   $SHASUM"
  echo "     Pull cmd: podman pull registry.stage.redhat.io/rhdr/$COMP_NAME:$TAG"
  echo ""
done

# Show unpublished components (from snapshot)
echo ""
if [ "$TOTAL_COMPONENTS" -gt "$IMAGE_COUNT" ]; then
  echo -e "${YELLOW}Components Built But NOT Published:${NC}"
  echo ""
  
  # Get published names
  PUBLISHED_NAMES=$(echo "$RELEASE_JSON" | jq -r '.status.artifacts.images[].name' | sed 's/-4-22$//' | sort -u)
  
  # Get all snapshot component names
  if [ -n "$LATEST_SNAPSHOT" ]; then
    kubectl get snapshot "$LATEST_SNAPSHOT" -n "$NAMESPACE" -o json 2>/dev/null | \
      jq -r '.spec.components[].name' | sed 's/-4-22$//' | sort -u | while read -r SNAP_COMP; do
        if ! echo "$PUBLISHED_NAMES" | grep -q "^${SNAP_COMP}$"; then
          echo "  ❌ $SNAP_COMP (built but not in release)"
        fi
      done
  fi
  
  echo ""
  echo "Reason: These components may be filtered by the ReleasePlan or failed validation"
fi

echo -e "${BLUE}=== To pull images ===${NC}"
echo ""
echo "These images are published to registry.stage.redhat.io and ready to pull:"
echo ""
echo "  podman pull registry.stage.redhat.io/rhdr/<component-name>:latest"
echo ""
echo "Use the Pullspec URLs shown above for QE testing."
echo ""

echo -e "${BLUE}=== To view all releases ===${NC}"
echo ""
echo "kubectl get releases -n $NAMESPACE"
echo "kubectl describe release $LATEST_RELEASE -n $NAMESPACE"
echo ""
