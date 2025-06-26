# EKS Module Outputs

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = aws_eks_cluster.main.status
}

# Node Group Outputs
output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status of the EKS Node Group"
  value       = aws_eks_node_group.main.status
}

output "node_group_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  value       = aws_eks_node_group.main.capacity_type
}

output "node_group_instance_types" {
  description = "List of instance types associated with EKS Node Group"
  value       = aws_eks_node_group.main.instance_types
}

output "node_group_ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  value       = aws_eks_node_group.main.ami_type
}

output "node_group_remote_access_ec2_ssh_key" {
  description = "EC2 Key Pair name that provides access for SSH communication with the worker nodes"
  value       = aws_eks_node_group.main.remote_access[0].ec2_ssh_key
}

output "node_group_resources" {
  description = "List of objects containing information about underlying resources"
  value       = aws_eks_node_group.main.resources
}

# IAM Outputs
output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "ebs_csi_driver_role_arn" {
  description = "The ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}
