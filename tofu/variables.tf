variable "admin_cidrs" {
  description = "CIDRs allowed to reach SSH (22) and the k3s API (6443)."
  type        = list(string)
}
