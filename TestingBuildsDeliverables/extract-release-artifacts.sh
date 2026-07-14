#!/bin/bash

# Extract published image artifacts from Release objects
# Searches through last 10 successful releases (latest to oldest)
# Takes latest version of each component if it appears in multiple releases
# Stops once all target components are found
#
# Optional: Mirror images to quay.io registry (recommended for QE)
# Usage: ./extract-release-artifacts.sh [namespace] [release-limit] [quay-mirror]
# Example: ./extract-release-artifacts.sh rhdr-tenant 10 true
#
# For complete QE delivery (IIB index + IDMS + CatalogSource + prod-path aliases),
# use prepare-qe-delivery.sh instead:
#   ./prepare-qe-delivery.sh              # extract only
#   ./prepare-qe-delivery.sh --mirror     # full no-VPN mirror package

set -u
set -o pipefail

NAMESPACE="${1:-rhdr-tenant}"
RELEASE_LIMIT="${2:-10}"
MIRROR_TO_QUAY="${3:-false}"
QUAY_ORG="${RHDR_QUAY_ORG:-openshift-virtualization-dr}"
QUAY_ORG_URL="https://quay.io/organization/${QUAY_ORG}"
QUAY_REGISTRY="quay.io/${QUAY_ORG}"
STAGING_REGISTRY="registry.stage.redhat.io"

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
MIRRORED_PULL_FILE="$OUTPUT_DIR/mirrored-pull-${TIMESTAMP}.sh"
MIRROR_LOG_FILE="$OUTPUT_DIR/mirror-log-${TIMESTAMP}.txt"

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

# Load staging registry username/password from an auth JSON file.
load_staging_creds() {
  local authfile candidate

  if [ -n "${RHDR_STAGING_AUTHFILE:-}" ] && [ -f "${RHDR_STAGING_AUTHFILE}" ]; then
    candidate="${RHDR_STAGING_AUTHFILE}"
    STAGING_USER=$(jq -r --arg reg "$STAGING_REGISTRY" \
      '.auths[$reg].username // .auths[$reg + "/"].username // empty' "$candidate")
    STAGING_PASS=$(jq -r --arg reg "$STAGING_REGISTRY" \
      '.auths[$reg].password // .auths[$reg + "/"].password // empty' "$candidate")
    if [ -n "$STAGING_USER" ] && [ -n "$STAGING_PASS" ]; then
      STAGING_CREDS_SOURCE="$candidate"
      return 0
    fi
  fi

  for candidate in \
      "${HOME}/.docker/.rhdr-staging-auth.json" \
      "${HOME}/.rhdr-staging-auth.json"; do
    [ -f "$candidate" ] || continue
    STAGING_USER=$(jq -r --arg reg "$STAGING_REGISTRY" \
      '.auths[$reg].username // .auths[$reg + "/"].username // empty' "$candidate")
    STAGING_PASS=$(jq -r --arg reg "$STAGING_REGISTRY" \
      '.auths[$reg].password // .auths[$reg + "/"].password // empty' "$candidate")
    if [ -n "$STAGING_USER" ] && [ -n "$STAGING_PASS" ]; then
      STAGING_CREDS_SOURCE="$candidate"
      return 0
    fi
  done

  return 1
}

# Log in to the staging registry using username + token from the auth JSON file.
login_staging_registry() {
  local login_err
  login_err=$(echo "$STAGING_PASS" | podman login --authfile="$STAGING_CREDS_SOURCE" \
    -u "$STAGING_USER" \
    --password-stdin \
    "$STAGING_REGISTRY" 2>&1) || {
    echo "$login_err" >&2
    return 1
  }
}

# Load quay.io username/password from an auth JSON file (supports auth or username/password fields).
load_quay_creds() {
  local authfile="$1"
  local b64_auth decoded

  QUAY_USER=$(jq -r '.auths["quay.io"].username // empty' "$authfile")
  QUAY_PASS=$(jq -r '.auths["quay.io"].password // empty' "$authfile")
  if [ -n "$QUAY_USER" ] && [ -n "$QUAY_PASS" ]; then
    return 0
  fi

  b64_auth=$(jq -r '.auths["quay.io"].auth // empty' "$authfile")
  if [ -n "$b64_auth" ] && [ "$b64_auth" != "null" ]; then
    decoded=$(echo "$b64_auth" | base64 -d 2>/dev/null) || return 1
    QUAY_USER="${decoded%%:*}"
    QUAY_PASS="${decoded#*:}"
    [ -n "$QUAY_USER" ] && [ -n "$QUAY_PASS" ]
    return $?
  fi

  return 1
}

# Log in to quay.io using credentials extracted from the auth JSON file.
login_quay_registry() {
  local login_err
  login_err=$(echo "$QUAY_PASS" | podman login --authfile="$QUAY_AUTHFILE" \
    -u "$QUAY_USER" \
    --password-stdin \
    quay.io 2>&1) || {
    echo "$login_err" >&2
    return 1
  }
}

# Resolve an auth file for a registry (used for quay.io and other base64-auth entries).
resolve_authfile() {
  local registry="$1"
  local env_var="$2"
  shift 2
  local candidate

  if [ -n "${!env_var:-}" ] && [ -f "${!env_var}" ]; then
    echo "${!env_var}"
    return 0
  fi

  for candidate in "$@"; do
    if [ -f "$candidate" ] && jq -e --arg registry "$registry" \
        '.auths[$registry] // .auths[$registry + "/"] // empty' "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

# Mirror images to quay.io if requested
if [ "$MIRROR_TO_QUAY" = "true" ] || [ "$MIRROR_TO_QUAY" = "yes" ] || [ "$MIRROR_TO_QUAY" = "1" ]; then

  echo ""
  echo -e "${BLUE}=== Mirroring Images to Quay.io ===${NC}"
  echo "Target registry: $QUAY_REGISTRY"
  echo "Checking for podman..."

  if ! command -v podman &> /dev/null; then
    echo -e "${RED}❌ podman not found. Install it to mirror images:${NC}"
    echo "   sudo dnf install podman"
    echo ""
    exit 1
  fi

  echo "✅ podman found"
  echo ""

  STAGING_USER=""
  STAGING_PASS=""
  STAGING_CREDS_SOURCE=""

  if ! load_staging_creds; then
    echo -e "${RED}❌ No staging registry credentials found for $STAGING_REGISTRY${NC}"
    echo ""
    echo "Create an auth file with username and password fields:"
    echo "  ${HOME}/.docker/.rhdr-staging-auth.json"
    echo ""
    echo "Or set RHDR_STAGING_AUTHFILE to your auth JSON path."
    echo "See Docs/TestingBuildsDeliverables/VerifyBuildImages.md for service account setup."
    exit 1
  fi

  QUAY_AUTHFILE=$(resolve_authfile "quay.io" RHDR_QUAY_AUTHFILE \
    "${HOME}/.docker/config.json" \
    "${HOME}/.config/containers/auth.json" || true)

  if [ -z "$QUAY_AUTHFILE" ]; then
    echo -e "${RED}❌ No quay.io credentials found${NC}"
    echo ""
    echo "Log in before mirroring:"
    echo "  podman login --authfile=\$HOME/.docker/config.json quay.io"
    exit 1
  fi

  QUAY_USER=""
  QUAY_PASS=""
  if ! load_quay_creds "$QUAY_AUTHFILE"; then
    echo -e "${RED}❌ Cannot read quay.io credentials from $QUAY_AUTHFILE${NC}"
    echo ""
    echo "Log in before mirroring:"
    echo "  podman login --authfile=\$HOME/.docker/config.json quay.io"
    exit 1
  fi

  echo "Staging credentials: $STAGING_CREDS_SOURCE (username + token)"
  echo "Quay.io credentials: $QUAY_AUTHFILE"
  echo "Quay organization: $QUAY_ORG_URL"
  echo ""
  echo "Mirroring via podman login → pull → tag → push"
  echo "Images are pushed to $QUAY_REGISTRY/<component>:staging"
  echo ""
  echo "Ensure your quay.io user has push access to these repositories"
  echo "(create them under the org if they do not exist yet):"
  for comp in $(echo "${!FOUND_COMPONENTS[@]}" | tr ' ' '\n' | sort); do
    echo "  $QUAY_REGISTRY/$comp"
  done
  echo ""
  echo "First image may take a few minutes..."
  echo ""

  echo -n "Logging in to $STAGING_REGISTRY..."
  if ! login_staging_registry; then
    echo -e " ${RED}❌${NC}"
    echo ""
    echo -e "${RED}❌ Cannot log in to $STAGING_REGISTRY${NC}"
    echo "Credentials source: $STAGING_CREDS_SOURCE"
    echo ""
    echo "Verify username and token in the auth file, then rerun."
    exit 1
  fi
  echo -e " ${GREEN}✅${NC}"

  echo -n "Logging in to quay.io..."
  if ! login_quay_registry; then
    echo -e " ${RED}❌${NC}"
    echo ""
    echo -e "${RED}❌ Cannot log in to quay.io${NC}"
    echo "Credentials source: $QUAY_AUTHFILE"
    echo ""
    echo "Run: podman login --authfile=\$HOME/.docker/config.json quay.io"
    exit 1
  fi
  echo -e " ${GREEN}✅${NC}"
  echo ""

  # Initialize mirror log and mirrored pull script
  {
    echo "=== Image Mirror Log ==="
    echo "Started: $(date)"
    echo "Source Registry: $STAGING_REGISTRY"
    echo "Target Registry: $QUAY_REGISTRY"
    echo "Quay organization: $QUAY_ORG_URL"
    echo "Method: podman login → pull → tag → push"
    echo "Staging creds: $STAGING_CREDS_SOURCE (username + token)"
    echo "Quay auth: $QUAY_AUTHFILE"
    echo "Total components to mirror: $FOUND_COUNT"
    echo ""
  } > "$MIRROR_LOG_FILE"

  {
    echo "#!/bin/bash"
    echo "# Auto-generated pull commands for mirrored RHDR components"
    echo "# Generated: $(date)"
    echo "# Source mirror: $QUAY_REGISTRY"
    echo ""
  } > "$MIRRORED_PULL_FILE"

  MIRROR_SUCCESS=0
  MIRROR_FAILED=0
  MIRROR_COUNT=0

  # Mirror each component: pull from staging, tag for quay, push to quay
  for comp in $(echo "${!FOUND_COMPONENTS[@]}" | tr ' ' '\n' | sort); do
    MIRROR_COUNT=$((MIRROR_COUNT + 1))
    SHASUM="${FOUND_COMPONENTS[$comp]}"
    SOURCE_IMAGE="${STAGING_REGISTRY}/rhdr/${comp}@${SHASUM}"
    DEST_IMAGE="${QUAY_REGISTRY}/${comp}:staging"

    echo -ne "${YELLOW}[$MIRROR_COUNT/$FOUND_COUNT] Mirroring $comp...${NC}"

    {
      echo "[$MIRROR_COUNT/$FOUND_COUNT] $comp"
      echo "  From: $SOURCE_IMAGE"
      echo "  To:   $DEST_IMAGE"
    } >> "$MIRROR_LOG_FILE"

    MIRROR_STEP_FAILED=""

    # Re-login before each pull; staging tokens can expire mid-run
    login_staging_registry >> "$MIRROR_LOG_FILE" 2>&1 || true

    echo "  Pulling from staging..." >> "$MIRROR_LOG_FILE"
    if podman pull --authfile="$STAGING_CREDS_SOURCE" "$SOURCE_IMAGE" >> "$MIRROR_LOG_FILE" 2>&1; then
      echo "  ✅ Pulled successfully" >> "$MIRROR_LOG_FILE"

      echo "  Tagging for quay.io..." >> "$MIRROR_LOG_FILE"
      if podman tag "$SOURCE_IMAGE" "$DEST_IMAGE" >> "$MIRROR_LOG_FILE" 2>&1; then
        echo "  ✅ Tagged successfully" >> "$MIRROR_LOG_FILE"

        echo "  Pushing to quay.io..." >> "$MIRROR_LOG_FILE"
        if podman push --authfile="$QUAY_AUTHFILE" --remove-signatures "$DEST_IMAGE" >> "$MIRROR_LOG_FILE" 2>&1; then
          echo -e " ${GREEN}✅${NC}"
          echo "  From: $SOURCE_IMAGE"
          echo "  To:   $DEST_IMAGE"
          echo "  Pull: podman pull $DEST_IMAGE"

          echo "podman pull $DEST_IMAGE" >> "$MIRRORED_PULL_FILE"
          MIRROR_SUCCESS=$((MIRROR_SUCCESS + 1))
        else
          MIRROR_STEP_FAILED="push"
        fi
      else
        MIRROR_STEP_FAILED="tag"
      fi
    else
      MIRROR_STEP_FAILED="pull"
    fi

    if [ -n "$MIRROR_STEP_FAILED" ]; then
      echo -e " ${RED}❌ (${MIRROR_STEP_FAILED} failed)${NC}"
      echo "  From: $SOURCE_IMAGE"
      echo "  To:   $DEST_IMAGE"
      if [ "$MIRROR_STEP_FAILED" = "push" ]; then
        echo "  Error: push failed for $QUAY_REGISTRY/$comp:staging"
        echo "         Manage repos and permissions at: $QUAY_ORG_URL"
        echo "         Your account needs write/create access to: $comp"
      else
        echo "  Error: ${MIRROR_STEP_FAILED} failed - Check mirror log for details"
      fi
      MIRROR_FAILED=$((MIRROR_FAILED + 1))
    fi

    echo ""
  done

  if [ -f "$MIRRORED_PULL_FILE" ]; then
    chmod +x "$MIRRORED_PULL_FILE"
  fi

  echo "================================================================"
  echo -e "${BLUE}=== Mirror Results ===${NC}"
  echo "Successfully mirrored: $MIRROR_SUCCESS / $FOUND_COUNT"
  echo "Failed: $MIRROR_FAILED / $FOUND_COUNT"
  echo ""

  if [ "$MIRROR_SUCCESS" -eq "$FOUND_COUNT" ]; then
    echo -e "${GREEN}✅ All components mirrored successfully!${NC}"
    echo ""
    echo "To use mirrored components (no staging credentials needed):"
    echo "  bash $MIRRORED_PULL_FILE"
    echo ""
    echo "Update CatalogSource to use mirror:"
    echo "  image: $QUAY_REGISTRY/rhdr-hub-operator-bundle:staging"
  elif [ "$MIRROR_SUCCESS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Partial success: $MIRROR_SUCCESS components mirrored${NC}"
    echo "Failed components can be retried. Check: $MIRROR_LOG_FILE"
  else
    echo -e "${RED}❌ Mirror failed for all components${NC}"
    echo "Check: $MIRROR_LOG_FILE"
  fi

  echo ""
  echo "Mirror log saved to: $MIRROR_LOG_FILE"
  echo "================================================================"
fi
