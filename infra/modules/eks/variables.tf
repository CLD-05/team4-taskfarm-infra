variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "eks_cluster_role_arn" {
  description = "IAM role ARN for EKS cluster"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS version"
  type        = string
  default     = "1.35"
}

variable "enabled_cluster_log_types" {
  description = "EKS control plane log types"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "private_subnet_ids" {
  description = "connected private subnet id"
  type        = list(string)
}

variable "eks_cluster_sg_id" {
  description = "Security Group ID for EKS"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "eks_node_sg_id" {
  description = "Security Group ID for worker nodes"
  type        = string
}

variable "endpoint_public_access" {
  description = "public access"
  type        = bool

}

variable "endpoint_private_access" {
  description = "private access"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  type = list(string)
  # public endpoint 안 쓰니까 CIDR 없음 => terraform validate로 확인 필수!
  default = []
}

variable "node_group_disk_size" {
  description = "Disk size for EKS worker nodes"
  type        = number
  default     = 20
}

variable "eks_node_role_arn" {
  description = "IAM Role ARN for EKS managed node group"
  type        = string
}

variable "node_group_instance_types" {
  description = "EC2 instance types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
}

variable "admin_iam_role_arn" {
  description = "IAM Role ARN for admin"
  type        = string
}

variable "s3_bucket_arn" {
  description = "S3 bucket ARN"
  type        = string
}

variable "s3_object_actions" {
  description = "s3 object-lovel action"
  type        = list(string)
  default     = ["s3:ListBucket"]
  #  default = [ "s3:GetObject", "s3:PutObject", "s3:DeleteObject" ]
  # 이것도 default로 할건지 dev/prod에서 할건지 정해야 해요
}

variable "namespace" {
  description = "namespace"
  type        = string
}

variable "service_account" {
  description = "serviceaccount"
  type        = string
}

variable "compute_type" {
  description = "Compute type for EKS workloads. fargate or node_group"
  type        = string

  validation {
    condition     = contains(["fargate", "node_group"], var.compute_type)
    error_message = "compute_type must be either fargate or node_group."
  }
}

variable "fargate_pod_execution_role_arn" {
  description = "IAM role ARN for EKS Fargate pod execution"
  type        = string
  default     = null
}

variable "enable_pod_identity_s3" {
  description = "Whether to create Pod Identity resources for S3 access. Use true only for node_group compute type."
  type        = bool
  default     = false
}
