#!/bin/bash
# validate-container-repos.sh
# 
# Validates container repositories for Red Hat products in both production and staging Pyxis environments.
# Tests repository creation and readiness before RPA configuration.
# Supports: RHDR, RHODF
#
# Usage:
#   ./validate-container-repos.sh                    # Check RHDR (default)
#   ./validate-container-repos.sh rhdr               # Check RHDR
#   ./validate-container-repos.sh rhodf              # Check RHODF
#   ./validate-container-repos.sh rhdr --prod-only   # Check RHDR production only
#   ./validate-container-repos.sh --detailed         # Check RHDR with detailed output

set -o pipefail

# Default product to RHDR if not specified
PRODUCT="${1:-rhdr}"

# Validate product name
if [[ ! "$PRODUCT" =~ ^(rhdr|rhodf)$ ]]; then
  # Check if it's a flag instead of product name
  if [[ "$PRODUCT" =~ ^-- ]]; then
    PRODUCT="rhdr"
    # Shift arguments back so flags are processed correctly
    set -- "$@"
  else
    echo "Error: Unknown product '$PRODUCT'"
    echo "Supported products: rhdr, rhodf"
    exit 1
  fi
fi

# Remove product from argument list if specified
if [[ "${1:-}" =~ ^(rhdr|rhodf)$ ]]; then
  shift
fi

# Repository Lists by Product
RHDR_REPOS=(
  "rhdr/rhdr-hub-rhel9-operator"
  "rhdr/rhdr-hub-operator-bundle"
  "rhdr/rhdr-cluster-rhel9-operator"
  "rhdr/rhdr-cluster-operator-bundle"
  "rhdr/rhdr-multicluster-rhel9-operator"
  "rhdr/rhdr-multicluster-operator-bundle"
  "rhdr/rhdr-csi-addons-rhel9-operator"
  "rhdr/rhdr-csi-addons-operator-bundle"
)

RHODF_REPOS=(
  # Operator Bundles (16 total)
  "odf4/ocs-tls-profiles-operator-bundle"
  "odf4/odr-volsync-plugin-operator-bundle"
  "odf4/cephcsi-operator-bundle"
  "odf4/mcg-operator-bundle"
  "odf4/ocs-client-operator-bundle"
  "odf4/ocs-operator-bundle"
  "odf4/odf-csi-addons-operator-bundle"
  "odf4/odf-dependencies-operator-bundle"
  "odf4/cnsa-dependencies-operator-bundle"
  "odf4/odf-external-snapshotter-operator-bundle"
  "odf4/odf-multicluster-operator-bundle"
  "odf4/odf-operator-bundle"
  "odf4/odf-prometheus-operator-bundle"
  "odf4/odr-cluster-operator-bundle"
  "odf4/odr-hub-operator-bundle"
  "odf4/odr-recipe-operator-bundle"
  "odf4/rook-ceph-operator-bundle"
  # Operator Controllers (12 total)
  "odf4/odr-volsync-plugin-rhel9-operator"
  "odf4/cephcsi-rhel9-operator"
  "odf4/mcg-rhel9-operator"
  "odf4/ocs-client-rhel9-operator"
  "odf4/ocs-rhel9-operator"
  "odf4/odf-cloudnative-pg-rhel9-operator"
  "odf4/odf-csi-addons-rhel9-operator"
  "odf4/odf-external-snapshotter-rhel9-operator"
  "odf4/odf-multicluster-rhel9-operator"
  "odf4/odf-rhel9-operator"
  "odf4/odr-rhel9-operator"
  "odf4/rook-ceph-rhel9-operator"
)

# Select repositories based on product
case "$PRODUCT" in
  rhdr)
    REPOS=("${RHDR_REPOS[@]}")
    ;;
  rhodf)
    REPOS=("${RHODF_REPOS[@]}")
    ;;
esac

# Pyxis API endpoints
PYXIS_PROD="https://pyxis.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository"
PYXIS_STAGE="https://pyxis.stage.engineering.redhat.com/v1/repositories/registry/registry.access.redhat.com/repository"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_usage() {
  cat << 'EOF'
Usage: validate-container-repos.sh [PRODUCT] [OPTIONS]

Validates container repositories in Pyxis (production and staging environments).
Supports: RHDR, RHODF

ARGUMENTS:
  PRODUCT         Product to validate: rhdr (default) or rhodf

OPTIONS:
  --prod-only     Check production environment only (registry.redhat.io)
  --stage-only    Check staging environment only (registry.stage.redhat.io)
  --detailed      Show full JSON response for each repository
  --help          Show this help message

EXAMPLES:
  # Check RHDR (default) in both environments
  ./validate-container-repos.sh

  # Check RHDR explicitly
  ./validate-container-repos.sh rhdr

  # Check RHODF in both environments
  ./validate-container-repos.sh rhodf

  # Check production only
  ./validate-container-repos.sh rhdr --prod-only

  # Check RHODF staging only
  ./validate-container-repos.sh rhodf --stage-only

  # Check with detailed response
  ./validate-container-repos.sh rhdr --detailed

REQUIREMENTS:
  - curl command-line tool
  - jq JSON processor
  - Kerberos authentication (kinit USERNAME@REDHAT.COM)
  - Network access to pyxis.engineering.redhat.com

RHDR REPOSITORIES:
  Layer 1 (Core):
    - rhdr/rhdr-hub-operator & rhdr/rhdr-hub-operator-bundle
    - rhdr/rhdr-cluster-operator & rhdr/rhdr-cluster-operator-bundle

  Layer 2 (Multicluster):
    - rhdr/rhdr-multicluster-operator & rhdr/rhdr-multicluster-operator-bundle

  Layer 3 (CSI Addons):
    - rhdr/rhdr-csi-addons-operator & rhdr/rhdr-csi-addons-operator-bundle

RHODF REPOSITORIES:
  Container Storage Interface & Addons: 16 repositories (8 operators + 8 bundles)
  Operators: ocs-tls-profiles, odr-volsync-plugin, cephcsi, mcg, ocs-client, ocs, odf-csi-addons, odf-dependencies, cnsa-dependencies, odf-external-snapshotter, odf-multicluster, odf, odf-prometheus, odr-cluster, odr-hub
EOF
}

# Parse command-line arguments
PROD_ONLY=false
STAGE_ONLY=false
DETAILED=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --prod-only)
      PROD_ONLY=true
      shift
      ;;
    --stage-only)
      STAGE_ONLY=true
      shift
      ;;
    --detailed)
      DETAILED=true
      shift
      ;;
    --help)
      show_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

validate_repo() {
  local env=$1
  local url=$2
  local repo=$3
  local full_path="$url/$repo"
  
  # Get response with HTTP code
  local response=$(curl --negotiate -u: -s -w "\n%{http_code}" "$full_path" 2>/dev/null)
  local http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | head -n-1)
  
  if [ "$DETAILED" = true ]; then
    echo ""
    echo "Repository: $repo"
    echo "Path: $full_path"
    echo "$body" | jq . 2>/dev/null || echo "Error querying repository"
    # Return appropriate code based on HTTP status
    [ "$http_code" = "200" ] && return 0 || return 1
  fi
  
  # Silent check with error handling
  if [ "$http_code" = "200" ]; then
    # Repository exists - extract repository name from response
    local repo_name=$(echo "$body" | jq -r '.repository // "unknown"' 2>/dev/null)
    echo -e "${GREEN}✓ EXISTS${NC}  $repo"
    echo "  Path: $full_path"
    return 0
  elif [ "$http_code" = "404" ]; then
    echo -e "${RED}✗ MISSING${NC} $repo"
    echo "  Path: $full_path"
    return 1
  else
    echo -e "${YELLOW}? ERROR${NC}   $repo (HTTP $http_code)"
    echo "  Path: $full_path"
    return 2
  fi
}

check_kerberos() {
  if ! klist &>/dev/null; then
    echo -e "${YELLOW}⚠ Warning: Kerberos ticket not found${NC}"
    echo "  Run: kinit USERNAME@REDHAT.COM"
    echo ""
  fi
}

print_header() {
  local mode=$1
  local product_name=$2
  local product_id=$3
  local mode_text="Production & Staging"
  
  if [ "$mode" = "prod-only" ]; then
    mode_text="Production Only"
  elif [ "$mode" = "stage-only" ]; then
    mode_text="Staging Only"
  fi
  
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC}  Container Repository Validation"
  echo -e "${BLUE}║${NC}  Product: $product_name (EngID: $product_id)"
  echo -e "${BLUE}║${NC}  Pyxis Environments: $mode_text"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_summary() {
  local env=$1
  local found=$2
  local total=$3
  local missing=$((total - found))
  
  echo ""
  if [ $found -eq $total ]; then
    echo -e "${GREEN}✓ $env: All $total repositories ready${NC}"
  elif [ $found -gt 0 ]; then
    echo -e "${YELLOW}⚠ $env: $found/$total repositories found ($missing missing)${NC}"
  else
    echo -e "${RED}✗ $env: No repositories found${NC}"
  fi
}

main() {
  local do_prod=true
  local do_stage=true
  local header_mode="prod-stage"
  
  if [ "$PROD_ONLY" = true ]; then
    do_stage=false
    header_mode="prod-only"
  elif [ "$STAGE_ONLY" = true ]; then
    do_prod=false
    header_mode="stage-only"
  fi
  
  # Product-specific metadata
  local product_name="Unknown"
  local product_id="0000"
  
  case "$PRODUCT" in
    rhdr)
      product_name="Red Hat Disaster Recovery"
      product_id="1119"
      ;;
    rhodf)
      product_name="Red Hat OpenShift Data Foundation"
      product_id="321"
      ;;
  esac
  
  print_header "$header_mode" "$product_name" "$product_id"
  check_kerberos
  
  local prod_found=0
  local stage_found=0
  local total_repos=${#REPOS[@]}
  
  # === PRODUCTION ===
  if [ "$do_prod" = true ]; then
    echo ""
    echo -e "${BLUE}Production Environment (registry.redhat.io)${NC}"
    echo -e "${BLUE}Endpoint: pyxis.engineering.redhat.com${NC}"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    
    for repo in "${REPOS[@]}"; do
      validate_repo "PROD" "$PYXIS_PROD" "$repo" && ((prod_found++))
    done
    
    print_summary "Production" $prod_found $total_repos
  fi
  
  # === STAGING ===
  if [ "$do_stage" = true ]; then
    echo ""
    echo -e "${BLUE}Staging Environment (registry.stage.redhat.io)${NC}"
    echo -e "${BLUE}Endpoint: pyxis.stage.engineering.redhat.com${NC}"
    echo -e "${YELLOW}Note: Syncs from production with ~24-hour delay${NC}"
    echo "─────────────────────────────────────────────────────────────"
    echo ""
    
    for repo in "${REPOS[@]}"; do
      validate_repo "STAGE" "$PYXIS_STAGE" "$repo" && ((stage_found++))
    done
    
    print_summary "Staging" $stage_found $total_repos
  fi
  
  # === FINAL STATUS ===
  echo ""
  echo "─────────────────────────────────────────────────────────────"
  
  if [ "$do_prod" = true ] && [ "$do_stage" = true ]; then
    if [ $prod_found -eq $total_repos ] && [ $stage_found -eq $total_repos ]; then
      echo -e "${GREEN}✓ SUCCESS: All repositories ready in both environments${NC}"
      echo "  Proceed with RPA creation"
      exit 0
    elif [ $prod_found -eq $total_repos ]; then
      echo -e "${YELLOW}⚠ PARTIAL: Production ready, staging syncing${NC}"
      echo "  Check staging in ~24 hours"
      exit 1
    else
      echo -e "${RED}✗ NOT READY: Repositories not yet created${NC}"
      echo "  Verify $PRODUCT pyxis-repo-configs MR is merged and Cicada pipeline completed"
      exit 1
    fi
  elif [ "$do_prod" = true ]; then
    if [ $prod_found -eq $total_repos ]; then
      echo -e "${GREEN}✓ PRODUCTION READY: All repositories ready${NC}"
      exit 0
    else
      echo -e "${RED}✗ NOT READY: Repositories not yet created in production${NC}"
      exit 1
    fi
  elif [ "$do_stage" = true ]; then
    if [ $stage_found -eq $total_repos ]; then
      echo -e "${GREEN}✓ STAGING READY: All repositories ready${NC}"
      exit 0
    else
      echo -e "${RED}✗ NOT READY: Repositories not yet created in staging${NC}"
      exit 1
    fi
  fi
  
  echo ""
}

# Run main function
main "$@"
