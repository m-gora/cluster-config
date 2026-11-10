variable "admin_cidrs" {
  description = "CIDRs allowed to reach SSH (22) and the k3s API (6443)."
  type        = list(string)
}

variable "k3s_version" {
  description = "k3s release to install on every node. Keep all nodes on one version."
  type        = string
  default     = "v1.37.2+k3s1"
}

variable "k3s_api_domain" {
  description = "Optional API hostname for --tls-san, so kubeconfig certs cover it. Empty = only IPs."
  type        = string
  default     = ""
}
