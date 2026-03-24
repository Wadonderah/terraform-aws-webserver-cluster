# terraform-aws-webserver-cluster

A reusable Terraform module that provisions a production-ready auto-scaled web server cluster on AWS. It creates a Launch Template, Auto Scaling Group, Application Load Balancer with listener and target group, and properly separated security groups — all wired together and ready to serve HTTP traffic. Optional CloudWatch CPU alarms are available via a feature flag. The module is designed to be called from multiple environments (dev, staging, production) with different versions, instance types, and scale parameters.

---

## Requirements

| Name      | Version           |
|-----------|-------------------|
| terraform | >= 1.0.0          |
| aws       | >= 4.0.0, < 6.0.0 |

---

## Usage

### Minimum required inputs

```hcl
module "webserver_cluster" {
  source = "github.com/your-username/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name  = "webservers-dev"
  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 4
}
```

### Full example with all optional inputs

```hcl
module "webserver_cluster" {
  source = "github.com/your-username/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name              = "webservers-production"
  instance_type             = "t3.medium"
  ami_id                    = "ami-0abc123def456"   # your hardened AMI
  min_size                  = 4
  max_size                  = 10
  desired_capacity          = 4
  server_port               = 8080
  alb_port                  = 80
  health_check_grace_period = 600

  enable_cloudwatch_alarms  = true
  cpu_alarm_threshold       = 70
  alarm_sns_topic_arns      = ["arn:aws:sns:us-east-1:123456789012:ops-alerts"]

  extra_tags = {
    Environment = "production"
    Team        = "platform"
    CostCenter  = "engineering"
  }
}
```

---

## Input Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `cluster_name` | `string` | **required** | Name used to namespace all resources. Must be unique per AWS account/region. |
| `instance_type` | `string` | `"t2.micro"` | EC2 instance type for web server nodes. |
| `ami_id` | `string` | `"ami-0c55b159cbfafe1f0"` | AMI ID. Defaults to Amazon Linux 2 in us-east-1. Override per region or for custom AMIs. |
| `min_size` | `number` | `2` | Minimum number of instances in the ASG. Must be >= 1. |
| `max_size` | `number` | `4` | Maximum number of instances. Must be >= min_size. |
| `desired_capacity` | `number` | `null` | Desired instance count. Defaults to min_size when null. |
| `server_port` | `number` | `8080` | Port the web server process listens on inside EC2. |
| `alb_port` | `number` | `80` | Port the ALB listens on externally. |
| `health_check_grace_period` | `number` | `300` | Seconds after instance launch before ASG health checks begin. Increase for slow-starting apps. *(Added in v0.0.2)* |
| `enable_cloudwatch_alarms` | `bool` | `false` | When true, creates a CloudWatch CPU alarm for the ASG. *(Added in v0.0.2)* |
| `cpu_alarm_threshold` | `number` | `80` | CPU % threshold that triggers the alarm. Used when `enable_cloudwatch_alarms = true`. *(Added in v0.0.2)* |
| `alarm_sns_topic_arns` | `list(string)` | `[]` | SNS topic ARNs for alarm notifications. *(Added in v0.0.2)* |
| `extra_tags` | `map(string)` | `{}` | Additional tags applied to all resources. |

---

## Outputs

| Name | Description |
|------|-------------|
| `alb_dns_name` | DNS name of the ALB — your app's public endpoint. |
| `alb_arn` | ARN of the Application Load Balancer. |
| `asg_name` | Name of the Auto Scaling Group. Use this for granular `depends_on` to avoid full-module dependency evaluation. |
| `asg_arn` | ARN of the Auto Scaling Group. |
| `instance_security_group_id` | Security group ID for EC2 instances. Reference this externally to add rules without modifying the module. |
| `alb_security_group_id` | Security group ID for the ALB. Reference this to add HTTPS/443 or other rules externally. |
| `launch_template_id` | ID of the EC2 Launch Template. |
| `target_group_arn` | ARN of the ALB Target Group. Useful for CodeDeploy integration. |

---

## Known Limitations and Gotchas

### 1. File path resolution (path.module)
All file references inside this module use `${path.module}/filename` rather than `./filename`. This is intentional. Without `path.module`, Terraform resolves relative paths from wherever the `terraform` command is run — not from the module directory. If you fork this module and add files, always reference them with `path.module`.

### 2. Security group rules — do not add inline blocks
This module uses `aws_security_group_rule` resources, not inline `ingress`/`egress` blocks inside `aws_security_group`. Mixing the two approaches on the same security group causes Terraform to remove inline-declared rules on every apply. If you need to add rules from your calling configuration, do it with additional `aws_security_group_rule` resources referencing `module.webserver_cluster.instance_security_group_id` or `module.webserver_cluster.alb_security_group_id`.

### 3. depends_on and module-level dependencies
Avoid `depends_on = [module.webserver_cluster]` in your root configuration. When Terraform sees a `depends_on` pointing at a whole module, it treats every resource in that module as a dependency of the downstream resource — even resources that have nothing to do with it. This forces unnecessary re-evaluation and can cause resource recreation. Instead, use granular outputs: `depends_on = [module.webserver_cluster.asg_name]`.

### 4. AMI ID is region-specific
The default `ami_id` is valid for `us-east-1` only. If you deploy to another region, you must provide a valid AMI ID for that region, or use a `data "aws_ami"` lookup in your root configuration and pass the result as `ami_id`.

### 5. Default VPC dependency
This module uses `data "aws_vpc" "default"` and `data "aws_subnets" "default"`. It assumes a default VPC exists in the target region. For accounts where the default VPC has been deleted, you will need to fork the module and parameterize the VPC and subnet IDs.

---

## Versioning

This module follows [Semantic Versioning](https://semver.org/).

| Version | Notes |
|---------|-------|
| v0.0.1  | Initial release: ASG, ALB, Launch Template, security groups |
| v0.0.2  | Added `health_check_grace_period`, CloudWatch alarms (`enable_cloudwatch_alarms`, `cpu_alarm_threshold`, `alarm_sns_topic_arns`), `desired_capacity` variable, and input validation |

---

## Development

```bash
git clone https://github.com/your-username/terraform-aws-webserver-cluster
cd terraform-aws-webserver-cluster

# Tag a new version after changes
git tag -a "v0.0.3" -m "Description of changes"
git push origin main --tags
```
