# Product Security Onboarding

This guide covers the process for registering a new product or service stream with Red Hat's Product Security (ProdSec) team as part of your Konflux release configuration.

## Overview

When onboarding a new product to Konflux, you need to register your product stream with ProdSec by submitting a Merge Request to the `product-definitions` repository. For new products (not new streams of existing products), ProdSec will provision a CPE (Common Platform Enumeration) identifier.

## Prerequisites

Before starting, gather the following information:

- **Jira Project ID**: The project where security vulnerabilities will be tracked (e.g., `VIRTDR`)
- **Default Jira Component**: The component for security tickets (e.g., `Security`)
- **Product Version**: The version string for your product (e.g., `red-hat-disaster-recovery-4.22`)
- **RHEL Target**: The base RHEL version your product is built on (recommended to use a variable in prodsec files for easy updates)

## Step-by-Step Process

### 1. Prepare Your ProdSec Configuration

In your `prodsec/<product>.yaml` file in `konflux-release-data`, configure:

```yaml
# prodsec/rhdr.yaml (example)
streams:
  - stream: "red-hat-disaster-recovery-{{ rhel_target }}"
    cpe: "cpe:/a:redhat:red_hat_disaster_recovery:{{ version }}"
    jira_project: "VIRTDR"
    jira_component: "Security"
```

**Tip**: Use templated variables (e.g., `{{ rhel_target }}`) for RHEL version and product version so you can update them without modifying the prodsec file.

### 2. Contact Product Security

Reach out to the Product Security team:

- **Primary**: Ping in the **#wg-cpe-assignments** Slack channel to request a CPE ID and stream for your product
- **Alternative**: Work directly with your assigned Product Security architect if you have one
- **Urgent**: See escalation contacts in test failure output if you need expedited processing

Provide them with:
- Product name and version
- Jira project ID
- Default Jira component for security issues
- Lifecycle policy documentation (if available)

### 3. Submit Merge Request to product-definitions

Once you have the correct CPE and stream values from ProdSec, open an MR at:

```
gitlab.cee.redhat.com/prodsec/product-definitions
```

**Location**: Add your product to the appropriate product definitions file

**Reference**: Workflow documentation: `product-definitions/-/blob/master/docs/workflow.md`

**Example MR**: See [MR #19224](https://gitlab.cee.redhat.com/releng/konflux-release-data/-/merge_requests/19224) in konflux-release-data for context

### 4. Stream Name Alignment (Critical)

Ensure **exact matching** between your prodsec template and the product-definitions registry:

- Your `prodsec/product.yaml` must render the **exact same** stream name and CPE
- If your template renders `red-hat-disaster-recovery-4.22`, that exact string must exist in ProdSec's master list
- Misalignment causes pipeline failures in your Konflux release-data MR

### 5. Wait for Merge and Retest

- Wait for ProdSec to merge the product-definitions MR
- After the product definitions are published, re-run your Konflux release-data pipeline
- The `test_stream_names_are_in_prodsec_repo` test will pass once registration is complete

## RHDR Example (Reference)

For Red Hat Disaster Recovery (RHDR):

- **Jira Project**: VIRTDR
- **Jira Component**: Security
- **Stream Template**: `red-hat-disaster-recovery-{{ rhel_target }}`
- **Status**: Onboarding in progress (see MR #19224)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `test_stream_names_are_in_prodsec_repo` fails | Stream name mismatch — verify exact CPE and stream values in product-definitions |
| ProdSec needs Jira details | Provide Jira project ID and default component early |
| CPE not provisioned | Contact #wg-cpe-assignments or escalation contacts in test output |
| Product definitions MR blocked | Work with your Product Security architect or escalate through #wg-cpe-assignments |

## Related Resources

- **Konflux Release Data**: [konflux-release-data repo](https://gitlab.cee.redhat.com/releng/konflux-release-data)
- **Product Definitions**: [product-definitions repo](https://gitlab.cee.redhat.com/prodsec/product-definitions)
- **Slack**: #wg-cpe-assignments (for CPE and stream assignments)
- **ProdSec Workflow**: Check product-definitions repo for detailed workflow docs

## Additional Tips

- **Use variables in prodsec files**: Avoid hardcoding version numbers — use templates to simplify future updates
- **Coordinate with Product Security architect**: If one is assigned to your product, work with them directly for faster turnaround
- **Plan ahead**: The full registration process can take several days, so start early
