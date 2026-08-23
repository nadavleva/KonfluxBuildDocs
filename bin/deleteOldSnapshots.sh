#!/bin/bash

NAMESPACE="rhdr-tenant"
DAYS_OLD=10

# Calculate the cutoff time in seconds (Current time minus X days)
# Works on both GNU (Linux) and BSD (macOS) systems
if date -d "@0" >/dev/null 2>&1; then
    # GNU date (Linux)
    CUTOFF_SEC=$(date -d "$DAYS_OLD days ago" +%s)
else
    # BSD date (macOS)
    CUTOFF_SEC=$(date -v-"${DAYS_OLD}"d +%s)
fi

echo "--------------------------------------------------------"
echo "Starting snapshot cleanup in namespace: $NAMESPACE"
echo "Looking for snapshots older than $DAYS_OLD days..."
echo "--------------------------------------------------------"

# Fetch snapshot names and their creation timestamps
# Format: name creationTimestamp
oc get snapshots -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.creationTimestamp}{"\n"}{end}' | while read -r NAME CREATION_TIME; do
    
    # Skip if fields are empty
    [ -z "$NAME" ] || [ -z "$CREATION_TIME" ] && continue

    # Convert creation timestamp (ISO 8601) to epoch seconds
    if date -d "@0" >/dev/null 2>&1; then
        SNAPSHOT_SEC=$(date -d "$CREATION_TIME" +%s)
    else
        SNAPSHOT_SEC=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATION_TIME" +%s)
    fi

    # Compare dates
    if [ "$SNAPSHOT_SEC" -lt "$CUTOFF_SEC" ]; then
        echo "--> Deleting expired snapshot: $NAME (Created: $CREATION_TIME)"
        oc delete snapshot "$NAME" -n "$NAMESPACE"
    else
        echo "    Keeping snapshot: $NAME (Within $DAYS_OLD day limit)"
    fi
done

echo "--------------------------------------------------------"
echo "Cleanup complete."
echo "--------------------------------------------------------"
