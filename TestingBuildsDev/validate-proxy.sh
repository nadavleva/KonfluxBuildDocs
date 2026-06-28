#!/bin/bash

echo "=== RHDR Proxy Validation ==="
echo ""

echo "1. Checking proxy environment variables..."
if [ -z "$HTTP_PROXY" ] || [ -z "$HTTPS_PROXY" ]; then
    echo "   ⚠️  Proxy env vars NOT set in current shell"
    echo "   (May still work via GNOME settings)"
else
    echo "   ✅ HTTP_PROXY=$HTTP_PROXY"
    echo "   ✅ HTTPS_PROXY=$HTTPS_PROXY"
fi
echo ""

echo "2. Checking proxy server reachability..."
if nc -zv squid.corp.redhat.com 3128 &>/dev/null; then
    echo "   ✅ Proxy server (squid.corp.redhat.com:3128) is reachable"
else
    echo "   ❌ Cannot reach proxy server - check VPN connection"
fi
echo ""

echo "3. Testing Red Hat internal site access..."
if curl -s -I https://www.dev.redhat.com/ | grep -q "200\|302"; then
    echo "   ✅ Can reach www.dev.redhat.com (proxy working)"
else
    echo "   ❌ Cannot reach www.dev.redhat.com"
fi
echo ""

echo "4. Testing staging registry access..."
if curl -s -I https://access.stage.redhat.com/terms-based-registry/ | grep -q "200\|302\|401\|403"; then
    echo "   ✅ Can reach staging infrastructure"
else
    echo "   ❌ Cannot reach staging infrastructure"
fi
echo ""

echo "5. Testing image registry..."
if curl -s -I https://registry.stage.redhat.io/ | grep -q "200\|302\|401\|403"; then
    echo "   ✅ Can reach registry.stage.redhat.io"
else
    echo "   ❌ Cannot reach registry.stage.redhat.io"
fi
echo ""

echo "=== Summary ==="
echo "If all checks pass: Proxy is configured and working ✅"
echo "If proxy checks fail: Verify VPN + GNOME proxy settings"
echo "If registry checks fail: Proxy may work but credentials needed"