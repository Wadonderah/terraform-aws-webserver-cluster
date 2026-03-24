
# Input Variables — terraform-aws-webserver-cluster

variable "cluster_name" {
  description = "The name used to namespace all resources created by this module (e.g. webservers-dev, webservers-prod). Must be unique per AWS account/region."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web server nodes (e.g. t2.micro, t3.medium)."
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID to use for the web server instances. Defaults to a recent Amazon Linux 2 AMI. Override this for custom hardened AMIs."
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 us-east-1 — update per region
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 2

  validation {
    condition     = var.min_size >= 1
    error_message = "min_size must be at least 1."
  }
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 4

  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be greater than or equal to min_size."
  }
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group. Defaults to min_size."
  type        = number
  default     = null
}

variable "server_port" {
  description = "The port the web server process listens on inside the EC2 instance."
  type        = number
  default     = 8080
}

variable "alb_port" {
  description = "The port the Application Load Balancer listens on externally."
  type        = number
  default     = 80
}

# v0.0.2 addition

variable "health_check_grace_period" {
  description = "Seconds after a new instance launches before the ASG starts checking its health. Increase this if your app has a slow startup time."
  type        = number
  default     = 300
}

# v0.0.2 addition

variable "enable_cloudwatch_alarms" {
  description = "Set to true to create a CloudWatch CPU alarm for the ASG. Requires alarm_sns_topic_arns to be set for notifications."
  type        = bool
  default     = false
}

# v0.0.2 addition

variable "cpu_alarm_threshold" {
  description = "CPU utilization percentage that triggers the CloudWatch alarm. Only used when enable_cloudwatch_alarms = true."
  type        = number
  default     = 80
}

# v0.0.2 addition

variable "alarm_evaluation_periods" {
  description = "Number of periods over which data is compared to the threshold. Only used when enable_cloudwatch_alarms = true."
  type        = number
  default     = 2
}

variable "alarm_comparison_operator" {
  description = "Operator to use for comparing the alarm threshold (e.g. GreaterThanThreshold, LessThanThreshold). Only used when enable_cloudwatch_alarms = true."
  type        = string
  default     = "GreaterThanThreshold"
}

variable "alarm_metric_name" {
  description = "CloudWatch metric to use for the alarm (e.g. CPUUtilization, HealthyHostCount). Only used when enable_cloudwatch_alarms = true."
  type        = string
  default     = "CPUUtilization"
}

variable "alarm_namespace" {
  description = "Namespace for the CloudWatch alarm metric. Only used when enable_cloudwatch_alarms = true."
  type        = string
  default     = "AWS/EC2"
}

variable "alarm_statistic" {
  description = "Statistic to apply to the alarm metric (e.g. Average, Sum, SampleCount). Only used when enable_cloudwatch_alarms = true."
  type        = string
  default     = "Average"
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to notify when CloudWatch alarms fire. Only used when enable_cloudwatch_alarms = true."
  type        = list(string)
  default     = []
}

variable "extra_tags" {
  description = "A map of extra tags to apply to all resources created by this module. Useful for cost allocation, environment tracking, or compliance tagging."
  type        = map(string)
  default     = {}
}
