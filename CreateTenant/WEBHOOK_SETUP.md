# GitLab Webhook Configuration for Pipelines-as-Code

## Overview

To enable Pipelines-as-Code (PAC) automation for your Konflux components, you need to configure GitLab webhooks. This guide explains how to extract webhook secrets from the shared Kubernetes secret and set up the webhook in GitLab.

## Prerequisites

- Access to the rhdr-tenant namespace via `oc` CLI
- Access to GitLab group `rh-ocp-dr` with admin permissions
- One or more components already onboarded to Konflux with the `configure-pac` annotation

## Architecture

The webhook secrets are stored in a shared Kubernetes secret called `pipelines-as-code-webhooks-secret` in your namespace. Each repository has its own unique webhook secret value, keyed by the GitLab URL path with underscores replacing special characters:

```
Pattern: https___gitlab.cee.redhat.com_<group>_<repo-name>
Example: https___gitlab.cee.redhat.com_rh-ocp-dr_rhdr-hub-operator-bundle
```

---

## Step 1: Check Existing Webhook Secrets

First, see what webhook secret keys already exist in your namespace:

```bash
oc get secret pipelines-as-code-webhooks-secret -n rhdr-tenant \
  -o jsonpath='{.data}' | python3 -m json.tool
```

This shows all keys (repository paths) and their values (base64-encoded). Look for your repository's key in the list.

---

## Step 2: Extract Your Webhook Secret

### If the key already exists:

```bash
# Extract and decode the webhook secret for your repo
# Replace the key name with your actual repo path
oc get secret pipelines-as-code-webhooks-secret -n rhdr-tenant \
  -o go-template='{{index .data "https___gitlab.cee.redhat.com_rh-ocp-dr_rhdr-hub-operator-bundle"}}' | base64 -d
```

Copy the decoded value — this is your webhook secret.

### If the key does NOT exist:

Generate a new webhook secret:

```bash
# Generate a random webhook secret
WEBHOOK_SECRET=$(head -c 30 /dev/random | base64)
echo "Save this for GitLab webhook: $WEBHOOK_SECRET"

# Add it to the shared secret with your repo's key
# Replace the key name with your actual GitLab repo path
oc patch secret pipelines-as-code-webhooks-secret -n rhdr-tenant \
  --type=json \
  -p='[{"op":"add","path":"/data/https___gitlab.cee.redhat.com_rh-ocp-dr_rhdr-hub-operator-bundle","value":"'"$(echo -n "$WEBHOOK_SECRET" | base64 -w0)"'"}]'
```

Save the `$WEBHOOK_SECRET` value for the next step.

---

## Step 3: Configure GitLab Webhook

1. **Navigate to GitLab:**
   - Go to GitLab group `rh-ocp-dr`
   - Click **Settings** → **Webhooks**

2. **Create or Update the webhook:**
   - **URL:** 
     ```
     https://pipelines-as-code-controller-openshift-pipelines.apps.stone-prod-p02.hjvn.p1.openshiftapps.com
     ```
   - **Secret token:** Paste the webhook secret value from Step 2
   - **Trigger events:** Select:
     - ✓ Push events
     - ✓ Merge request events
     - ✓ Comments
     - ✓ Tag push events
   - **SSL verification:** Enabled (default)

3. **Click "Add webhook"** (or "Update webhook" if editing)

4. **Test the webhook:**
   - Click the webhook entry
   - Scroll to **Recent deliveries**
   - Look for successful `push_events` or other test requests

---

## Step 4: Verify the Setup

Check that your component is properly configured in Konflux:

```bash
# Verify the Repository CR references the correct secret
oc get repository gitlab-cee-redhat-com-rh-ocp-dr-rhdr-hub-operator-bundle \
  -n rhdr-tenant -o yaml | grep -A 5 webhook_secret
```

Expected output:
```yaml
webhook_secret:
  name: pipelines-as-code-webhooks-secret
  key: https___gitlab.cee.redhat.com_rh-ocp-dr_rhdr-hub-operator-bundle
```

---

## Troubleshooting

### Webhook secret key name doesn't match your repo

Check the actual key pattern in the secret:

```bash
oc get secret pipelines-as-code-webhooks-secret -n rhdr-tenant \
  -o jsonpath='{.data}' | python3 -c "
import json, sys
data = json.load(sys.stdin)
for key in sorted(data.keys()):
    print(key)
"
```

Look for a key containing your repository name, then adjust the `oc get-template` or `oc patch` command accordingly.

### Webhook not triggering on push/MR

1. Verify the webhook URL is reachable:
   ```bash
   curl -k https://pipelines-as-code-controller-openshift-pipelines.apps.stone-prod-p02.hjvn.p1.openshiftapps.com
   ```

2. Check PAC controller logs:
   ```bash
   oc logs -n openshift-pipelines -l app=pipelines-as-code-controller -f
   ```

3. Ensure the Repository CR exists and is active:
   ```bash
   oc get repository -n rhdr-tenant
   ```

### Secret value doesn't decode

Verify the secret key name is correct and the value is properly base64-encoded:

```bash
oc get secret pipelines-as-code-webhooks-secret -n rhdr-tenant \
  -o jsonpath='{.data.<key-name>}' | base64 -d
```

---

## Key Reference

| Item | Value |
|------|-------|
| **Shared Secret Name** | `pipelines-as-code-webhooks-secret` |
| **Namespace** | `rhdr-tenant` |
| **PAC Controller URL** | `https://pipelines-as-code-controller-openshift-pipelines.apps.stone-prod-p02.hjvn.p1.openshiftapps.com` |
| **Key Pattern** | `https___gitlab.cee.redhat.com_<group>_<repo-name>` |
| **GitLab Group** | `rh-ocp-dr` |

---

## Next Steps

Once the webhook is configured:
1. Push a commit or create a pull request in your GitLab repository
2. Verify that Konflux creates a PipelineRun automatically
3. Check the Konflux UI to monitor build progress

For more information, see the [Konflux Architecture documentation](../KONFLUX_ARCHITECTURE.md).
