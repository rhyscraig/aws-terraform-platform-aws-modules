# 📚 Terraform Module Catalog (aws-modules)

**Classification:** Public (Internal)
**Standard:** Semantic Versioning

This is the **Golden Catalog** of hardened, compliant-by-design Terraform modules. All platform infrastructure **MUST** consume these modules instead of raw resources.

## 📦 Available Modules

| Module | Description | Version Strategy |
| :--- | :--- | :--- |
| **vpc-standard** | Tiered VPC (Public/Private/Iso) | Pinned Tags (`v1.x`) |
| **s3-secure** | Encrypted, Private, Versioned Bucket | Pinned Tags (`v1.x`) |
| **eks-cluster** | FIPS-compliant EKS Cluster | Pinned Tags (`v1.x`) |
| **security-baseline** | Account-level hardening controls | Pinned Tags (`v1.x`) |

## 🧪 Testing & Validation

* **Linting:** `tflint` enforces AWS best practices.
* **Security:** `checkov` scans for misconfigurations.
* **Releasing:** Merges to `main` automatically tag a new SemVer release (e.g., `v1.2.0`).

## 👩‍💻 Usage

```hcl
module "vpc" {
  source = "git::[https://github.com/hoad-org/aws-modules.git//modules/vpc-standard?ref=v1.2.0](https://github.com/hoad-org/aws-modules.git//modules/vpc-standard?ref=v1.2.0)"
  # ...
}
