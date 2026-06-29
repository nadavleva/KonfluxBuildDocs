#!/bin/bash

# Extract published image artifacts from Release objects
# Searches through last 10 successful releases (latest to oldest)
# Takes latest version of each component if it appears in multiple releases
# Stops once all target components are found

set -u
set -o pipefail

NAMESPACE="${1:-rhdr-tenant}"
RELEASE_LIMIT="${2:-10}"

# Setup output directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
if [ ! -d "$OUTPUT_DIR" ]; then
  mkdir -p "$OUTPUT_DIR"
  echo "Created output directory: $OUTPUT_DIR"
fi

# Generate timestamp for output files
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PODMAN_PULL_FILE="$OUTPUT_DIR/podman-pull-${TIMESTAMP}.sh"
CATALOGSOURCE_FILE="$OUTPUT_DIR/catalogsource-${TIMESTAMP}.yaml"

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Define target components
TARGET_COMPONENTS=(
  "rhdr-hub-operator-bundle"
  "rhdr-cluster-operator-bundle"
  "rhdr-multicluster-operator-bundle"
  "rhdr-multicluster-operator-image"
  "rhdr-csi-addons-operator"
  "rhdr-csi-addons-operator-bundle"
  "rhdr-csi-addons-sidecar"
  "rhdr-ramen-operator-base-image"
  "rhdr-ramendr-console"
)

# Initialize tracking associative arrays
declare -A FOUND_COMPONENTS
declare -A COMPONENT_RELEASE
declare -A COMPONENT_TIME

echo -e "${BLUE}=== RHDR Release Artifacts Multi-Release Search ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Searching last $RELEASE_LIMIT successful releases..."
echo ""

# Get successful releases sorted by creation time (newest first)
echo "Fetching release data..."
RELEASES_DATA=$(kubectl get releases -n "$NAMESPACE" -o json 2>/dev/null | \
  jq -r '.items[] | select(.status.conditions[]? | select(.type=="Released" and .status=="True")) | "\(.metadata.creationTimestamp) \(.metadata.name)"' || echo "")

if [ -z "$RELEASES_DATA" ]; then
  echo -e "${RED}❌ No successful releases found in namespace $NAMESPACE${NC}"
  exit 1
fi

# Sort and limit
SORTED_RELEASES=$(echo "$RELEASES_DATA" | sort -rV | head -n "$RELEASE_LIMIT")

# Display found releases
echo -e "${GREEN}Found releases to search:${NC}"
RELEASE_COUNT=$(echo "$SORTED_RELEASES" | grep -c . || echo 0)
line_num=0

while IFS=' ' read -r CREATION_TIME RELEASE_NAME; do
  line_num=$((line_num + 1))
  echo "  [$line_num] $RELEASE_NAME (created: $CREATION_TIME)"
done <<< "$SORTED_RELEASES"
echo ""

# Process each release
RELEASE_COUNTER=0
while IFS=' ' read -r CREATION_TIME RELEASE_NAME; do
  RELEASE_COUNTER=$((RELEASE_COUNTER + 1))
  
  # Get image count for this release
  IMAGE_COUNT=$(kubectl get release "$RELEASE_NAME" -n "$NAMESPACE" -o json 2>/dev/null | \
    jq '.status.artifacts.images | length' 2>/dev/null || echo 0)
  
  if [ "$IMAGE_COUNT" -eq 0 ]; then
    continue
  fi
  
  echo -e "${YELLOW}[Release $RELEASE_COUNTER/$RELEASE_COUNT] Processing: $RELEASE_NAME ($IMAGE_COUNT images)${NC}"
  
  # Fetch all release details
  RELEASE_JSON=$(kubectl get release "$RELEASE_NAME" -n "$NAMESPACE" -o json 2>/dev/null)
  
  # Extract each component from this release
  img_idx=0
  while [ "$img_idx" -lt "$IMAGE_COUNT" ]; do
    NAME=$(echo "$RELEASE_JSON" | jq -r ".status.artifacts.images[$img_idx].name" 2>/dev/null || echo "")
    SHASUM=$(echo "$RELEASE_JSON" | jq -r ".status.artifacts.images[$img_idx].shasum" 2>/dev/null || echo "")
    
    if [ -n "$NAME" ] && [ -n "$SHASUM" ]; then
      # Normalize component name (remove -4-22 suffix)
      COMP_NAME=$(echo "$NAME" | sed 's/-4-22$//')
      
      # Check if this is a target component
      for target in "${TARGET_COMPONENTS[@]}"; do
        if [ "$COMP_NAME" = "$target" ]; then
          # Only add if we haven't seen this component yet
          if [ -z "${FOUND_COMPONENTS[$COMP_NAME]:-}" ]; then
            FOUND_COMPONENTS[$COMP_NAME]="$SHASUM"
            COMPONENT_RELEASE[$COMP_NAME]="$RELEASE_NAME"
            COMPONENT_TIME[$COMP_NAME]="$CREATION_TIME"
            echo "  ✅ Found: $COMP_NAME"
          fi
          break
        fi
      done
    fi
    
    img_idx=$((img_idx + 1))
  done
  
  # Check if we've found all target components
  FOUND_COUNT=${#FOUND_COMPONENTS[@]}
  TARGET_COUNT=${#TARGET_COMPONENTS[@]}
  
  if [ "$FOUND_COUNT" -eq "$TARGET_COUNT" ]; then
    echo ""
    echo -e "${GREEN}✅ All $TARGET_COUNT target components found!${NC}"
    break
  fi
  
done <<< "$SORTED_RELEASES"

echo ""
echo "================================================================"
echo -e "${BLUE}=== Summary: Components Found ===${NC}"
echo "================================================================"
echo ""

FOUND_COUNT=${#FOUND_COMPONENTS[@]}
TARGET_COUNT=${#TARGET_COMPONENTS[@]}

echo "Collected: $FOUND_COUNT / $TARGET_COUNT target components"
echo ""

# Display all found components (sorted)
DISPLAY_COUNT=0
for comp in $(echo "${!FOUND_COMPONENTS[@]}" | tr ' ' '\n' | sort); do
  DISPLAY_COUNT=$((DISPLAY_COUNT + 1))
  SHASUM="${FOUND_COMPONENTS[$comp]}"
  RELEASE="${COMPONENT_RELEASE[$comp]}"
  TIME="${COMPONENT_TIME[$comp]}"
  
  echo -e "${GREEN}Component $DISPLAY_COUNT/$FOUND_COUNT: $comp${NC}"
  echo "  Digest:   $SHASUM"
  echo "  From:     $RELEASE"
  echo "  Created:  $TIME"
  echo "  Pull:     podman pull registry.stage.redhat.io/rhdr/$comp@$SHASUM"
  echo "  OR:       podman pull registry.stage.redhat.io/rhdr/$comp:v4.22"
  echo ""
done

# Show missing components if any
MISSING_COUNT=$((TARGET_COUNT - FOUND_COUNT))
if [ "$MISSING_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}Missing components ($MISSING_COUNT):${NC}"
  
  for target in "${TARGET_COMPONENTS[@]}"; do
    if [ -z "${FOUND_COMPONENTS[$target]:-}" ]; then
      echo "  ❌ $target"
    fi
  done
  
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if components were built: kubectl get snapshot -n $NAMESPACE -o yaml"
  echo "  2. Check ReleasePlan filters: kubectl get releaseplan -n $NAMESPACE -o yaml"
  echo "  3. Increase search depth: $0 $NAMESPACE 20"
  echo ""
fi

echo "================================================================"
echo ""

# Generate output files
echo -e "${BLUE}=== Generating Output Files ===${NC}"
echo ""

# 1. Generate podman pull commands file
{
  echo "#!/bin/bash"
  echo "# Auto-generated podman pull commands for RHDR components"
  echo "# Generated: $(date)"
  echo "# Namespace: $NAMESPACE"
  echo ""
  echo "# Pull all RHDR components"
  echo ""
  
  for comp in $(echo "${!FOUND_COMPONENTS[@]}" | tr ' ' '\n' | sort); do
    SHASUM="${FOUND_COMPONENTS[$comp]}"
    echo "podman pull registry.stage.redhat.io/rhdr/$comp@$SHASUM"
  done
  
  echo ""
  echo "# Alternative: pull by tag (may not be latest)"
  echo "# for comp in ${!FOUND_COMPONENTS[@]}; do"
  echo "#   podman pull registry.stage.redhat.io/rhdr/\$comp:v4.22"
  echo "# done"
} > "$PODMAN_PULL_FILE"

chmod +x "$PODMAN_PULL_FILE"
echo -e "${GREEN}✅ Podman pull commands saved to:${NC}"
echo "   $PODMAN_PULL_FILE"
echo ""

# 2. Generate CatalogSource YAML
{
  echo "---"
  echo "# Auto-generated CatalogSource for RHDR components"
  echo "# Generated: $(date)"
  echo "# Namespace: $NAMESPACE"
  echo "# Total components: $FOUND_COUNT"
  echo ""
  echo "apiVersion: operators.coreos.com/v1alpha1"
  echo "kind: CatalogSource"
  echo "metadata:"
  echo "  name: rhdr-staging-catalog"
  echo "  namespace: openshift-marketplace"
  echo "spec:"
  echo "  sourceType: grpc"
  echo "  image: registry.stage.redhat.io/rhdr/rhdr-hub-operator-bundle@${FOUND_COMPONENTS[rhdr-hub-operator-bundle]:-}"
  echo ""
  echo "---"
  echo "# Individual component image references for reference"
  echo ""
  
  COMP_NUM=0
  for comp in $(echo "${!FOUND_COMPONENTS[@]}" | tr ' ' '\n' | sort); do
    COMP_NUM=$((COMP_NUM + 1))
    SHASUM="${FOUND_COMPONENTS[$comp]}"
    RELEASE="${COMPONENT_RELEASE[$comp]}"
    TIME="${COMPONENT_TIME[$comp]}"
    
    echo "# Component $COMP_NUM: $comp"
    echo "# Source Release: $RELEASE (created: $TIME)"
    echo "# Image: registry.stage.redhat.io/rhdr/$comp@$SHASUM"
    echo ""
  done
} > "$CATALOGSOURCE_FILE"

echo -e "${GREEN}✅ CatalogSource YAML saved to:${NC}"
echo "   $CATALOGSOURCE_FILE"
echo ""

echo -e "${BLUE}=== Output Files Summary ===${NC}"
echo "To use podman pull commands:"
echo "  bash $PODMAN_PULL_FILE"
echo ""
echo "To apply CatalogSource:"
echo "  kubectl apply -f $CATALOGSOURCE_FILE"
echo ""
echo "All output files are in: $OUTPUT_DIR"
echo "================================================================"
echo "  EOF"
