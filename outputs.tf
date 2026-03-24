# -----------------------------------------------------------------------------
# Outputs — terraform-aws-webserver-cluster
#
# GOTCHA NOTE: These outputs are intentionally granular. If a caller uses
# depends_on = [module.webserver_cluster], Terraform must resolve the ENTIRE
# module before proceeding — even if only one resource is actually needed.
# Exposing specific resource IDs/ARNs lets callers create precise dependencies
# (depends_on = [module.webserver_cluster.asg_name]) and avoids unnecessary
# resource recreation.
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer. Use this as your app's public endpoint."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "asg_name" {
  description = "The name of the Auto Scaling Group. Use this for granular depends_on references to avoid full-module dependency evaluation."
  value       = aws_autoscaling_group.this.name
}

output "asg_arn" {
  description = "The ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.this.arn
}

output "instance_security_group_id" {
  description = "The ID of the security group attached to EC2 instances. Callers can reference this to add additional security group rules without modifying the module."
  value       = aws_security_group.instance.id
}

output "alb_security_group_id" {
  description = "The ID of the security group attached to the ALB. Callers can reference this to add additional inbound rules (e.g. HTTPS/443) without modifying the module."
  value       = aws_security_group.alb.id
}

output "launch_template_id" {
  description = "The ID of the Launch Template used by the ASG."
  value       = aws_launch_template.this.id
}

output "target_group_arn" {
  description = "The ARN of the ALB Target Group. Expose this for use with CodeDeploy or external ALB rules."
  value       = aws_lb_target_group.this.arn
}
