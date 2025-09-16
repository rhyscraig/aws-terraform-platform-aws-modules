# AVM Guardrails & Compliance

## Overview
This repository contains **AWS Control Tower guardrails, SCPs, and Config rules** that enforce compliance across the organization.  

---

## Contents
- **Service Control Policies (SCPs)**
  - Predefined policies that restrict account permissions.
- **AWS Config Rules**
  - Continuous compliance checks.
- **Custom Guardrails**
  - Organizationally-specific compliance requirements.

---

## Inputs
| Variable | Description | Example |
|----------|-------------|---------|
| `target_ou` | The OU to apply the controls | `Infrastructure` |
| `allowed_regions` | List of allowed AWS regions | `["eu-west-1"]` |
| `control_ids` | List of Control Tower guardrail ARNs | `["AWS-GR_EC2_VOLUME_INUSE_CHECK"]` |

---

## Outputs
| Output | Description |
|--------|-------------|
| `enabled_controls` | List of ARNs of applied guardrails |
| `scp_ids` | List of SCP ARNs |

---

## Terraform AFT & Control Tower
- **Control Tower Guardrails** defined here via `aws_controltower_control` resources.
- **AFT is not deployed from this repo**, but this repo depends on the OIDC roles from `avm-bootstrap`.

---

## Deployment Order
1. Deploy `avm-platform` first to create the foundational OU structure.
2. Deploy guardrails after OIDC roles exist.

---

## Notes
- Designed to be safe to re-apply multiple times.
- Only GitHub Actions required; no CodePipeline/CodeBuild.
